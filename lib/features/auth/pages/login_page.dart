import 'package:cotahub/repositories/user_repository.dart';
import 'package:cotahub/theme/cotahub_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

enum _RegisterRole { buyer, supplier }

void _logDebug(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _userRepository = UserRepository();

  bool _isLoading = false;
  bool _obscureLoginPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _validateAuthFields() {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Preencha e-mail e senha.');
      return false;
    }

    if (!email.contains('@')) {
      _showMessage('Digite um e-mail valido.');
      return false;
    }

    if (password.length < 6) {
      _showMessage('A senha precisa ter pelo menos 6 caracteres.');
      return false;
    }

    return true;
  }

  Future<void> _loginWithEmail() async {
    if (!_validateAuthFields()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (credential.user?.emailVerified != true) {
        try {
          await credential.user?.sendEmailVerification();
        } catch (_) {}
        _showMessage(
          'Seu e-mail ainda não foi confirmado. Abrimos o fluxo de confirmação.',
        );
      }

      await _userRepository.ensureUserProfileDocument();
      final profile = await _userRepository.getCurrentUserProfile(
        forceServer: true,
      );
      _logDebug(
        '[loginWithEmail] profileExists=${profile != null} profileCompleted=${profile?.profileCompleted} role=${profile?.role}',
      );
    } on FirebaseAuthException catch (error) {
      _showMessage(_humanizeAuthError(error));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      if (kIsWeb) {
        await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
      } else {
        await GoogleSignIn.instance.initialize();
        final googleUser = await GoogleSignIn.instance.authenticate(
          scopeHint: const ['email'],
        );
        final googleAuth = googleUser.authentication;

        if (googleAuth.idToken == null || googleAuth.idToken!.isEmpty) {
          throw Exception('Google nao retornou idToken para autenticar.');
        }

        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

        await FirebaseAuth.instance.signInWithCredential(credential);
      }
      await _userRepository.ensureUserProfileDocument();
      final profile = await _userRepository.getCurrentUserProfile(
        forceServer: true,
      );
      _logDebug(
        '[loginWithGoogle] profileExists=${profile != null} profileCompleted=${profile?.profileCompleted} role=${profile?.role}',
      );
    } on FirebaseAuthException catch (error) {
      _showMessage(_humanizeAuthError(error));
    } catch (error) {
      _showMessage('Erro no login Google: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openForgotPasswordFlow() async {
    final email = _emailController.text.trim();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ForgotPasswordPage(initialEmail: email),
      ),
    );
  }

  Future<void> _openRegisterFlow() async {
    final registeredEmail = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) =>
            _RegisterAccountPage(initialEmail: _emailController.text.trim()),
      ),
    );

    if (registeredEmail != null && registeredEmail.trim().isNotEmpty) {
      _emailController.text = registeredEmail.trim();
      _passwordController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 940;

    return Scaffold(
      backgroundColor: CotahubTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _BrandBar(),
                  const SizedBox(height: 24),
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(flex: 12, child: _VisualPane()),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 9,
                          child: _AuthPane(
                            emailController: _emailController,
                            passwordController: _passwordController,
                            isLoading: _isLoading,
                            onLogin: _loginWithEmail,
                            onOpenRegister: _openRegisterFlow,
                            onGoogle: _loginWithGoogle,
                            onForgotPassword: _openForgotPasswordFlow,
                            obscurePassword: _obscureLoginPassword,
                            onTogglePasswordVisibility: () {
                              setState(
                                () => _obscureLoginPassword =
                                    !_obscureLoginPassword,
                              );
                            },
                          ),
                        ),
                      ],
                    )
                  else ...[
                    const _VisualPane(),
                    const SizedBox(height: 18),
                    _AuthPane(
                      emailController: _emailController,
                      passwordController: _passwordController,
                      isLoading: _isLoading,
                      onLogin: _loginWithEmail,
                      onOpenRegister: _openRegisterFlow,
                      onGoogle: _loginWithGoogle,
                      onForgotPassword: _openForgotPasswordFlow,
                      obscurePassword: _obscureLoginPassword,
                      onTogglePasswordVisibility: () {
                        setState(
                          () => _obscureLoginPassword = !_obscureLoginPassword,
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandBar extends StatelessWidget {
  const _BrandBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            color: CotahubTheme.surfaceSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: CotahubTheme.line),
          ),
          child: const Icon(Icons.hub_rounded, color: CotahubTheme.blue),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cotahub',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: CotahubTheme.textPrimary,
              ),
            ),
            Text(
              'Compra, proposta e validacao fiscal no mesmo fluxo.',
              style: TextStyle(
                color: CotahubTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _VisualPane extends StatelessWidget {
  const _VisualPane();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CotahubTheme.surface,
            CotahubTheme.surfaceAlt,
            CotahubTheme.surfaceSoft,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: CotahubTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fluxo completo de compra.',
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w900,
              height: 1.02,
              color: CotahubTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'A direção certa aqui não é só cotar mais bonito. É operar ponta a ponta: identidade da empresa, decisão da oferta e XML da nota fiscal dentro do mesmo produto.',
            style: TextStyle(
              fontSize: 16,
              height: 1.55,
              color: CotahubTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SignalChip(
                icon: Icons.verified_user_outlined,
                label: 'Cadastro forte',
              ),
              _SignalChip(
                icon: Icons.currency_exchange_outlined,
                label: 'Oferta e decisao',
              ),
              _SignalChip(
                icon: Icons.description_outlined,
                label: 'XML fiscal revisado',
              ),
            ],
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: CotahubTheme.overlay,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: CotahubTheme.line),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MetricRow(label: 'Cadastro', value: 'Empresa + responsavel'),
                SizedBox(height: 12),
                _MetricRow(label: 'Fechamento', value: 'Fornecedor envia XML'),
                SizedBox(height: 12),
                _MetricRow(
                  label: 'Conferencia',
                  value: 'Comprador valida CNPJ e valor',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthPane extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoading;
  final bool obscurePassword;
  final Future<void> Function() onLogin;
  final Future<void> Function() onOpenRegister;
  final Future<void> Function() onGoogle;
  final Future<void> Function() onForgotPassword;
  final VoidCallback onTogglePasswordVisibility;

  const _AuthPane({
    required this.emailController,
    required this.passwordController,
    required this.isLoading,
    required this.obscurePassword,
    required this.onLogin,
    required this.onOpenRegister,
    required this.onGoogle,
    required this.onForgotPassword,
    required this.onTogglePasswordVisibility,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: CotahubTheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: CotahubTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Acessar conta',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: CotahubTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Se ainda não tem conta, clique em cadastrar para abrir a tela de cadastro (comprador/fornecedor).',
            style: TextStyle(color: CotahubTheme.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'E-mail',
              hintText: 'compras@empresa.com',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: passwordController,
            obscureText: obscurePassword,
            decoration: InputDecoration(
              labelText: 'Senha',
              hintText: 'Minimo de 6 caracteres',
              suffixIcon: IconButton(
                tooltip: obscurePassword ? 'Mostrar senha' : 'Ocultar senha',
                onPressed: isLoading ? null : onTogglePasswordVisibility,
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: isLoading ? null : onForgotPassword,
              child: const Text('Esqueci minha senha'),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading ? null : onLogin,
              child: Text(isLoading ? 'Entrando...' : 'Entrar com e-mail'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: isLoading ? null : onOpenRegister,
              child: const Text('Cadastrar nova conta'),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(child: Divider(color: CotahubTheme.line)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'ou',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: CotahubTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Expanded(child: Divider(color: CotahubTheme.line)),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isLoading ? null : onGoogle,
              icon: const Icon(Icons.account_circle_outlined),
              label: const Text('Continuar com Google'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegisterAccountPage extends StatefulWidget {
  final String initialEmail;

  const _RegisterAccountPage({required this.initialEmail});

  @override
  State<_RegisterAccountPage> createState() => _RegisterAccountPageState();
}

class _RegisterAccountPageState extends State<_RegisterAccountPage> {
  final _userRepository = UserRepository();
  late final TextEditingController _emailController;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  _RegisterRole _selectedRole = _RegisterRole.buyer;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _showMessage('Digite um e-mail valido.');
      return;
    }
    if (password.length < 6) {
      _showMessage('A senha precisa ter pelo menos 6 caracteres.');
      return;
    }
    if (password != confirmPassword) {
      _showMessage('A confirmacao da senha esta diferente.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final roleHint = _selectedRole == _RegisterRole.supplier
          ? 'supplier'
          : 'buyer';
      try {
        await _userRepository.ensureUserProfileDocument(roleHint: roleHint);
      } catch (firstError) {
        _logDebug('[createAccount.profileDoc.retry] error=$firstError');
        await _userRepository.ensureUserProfileDocument(roleHint: roleHint);
      }

      try {
        await credential.user?.sendEmailVerification();
      } catch (emailError) {
        _logDebug('[createAccount.sendEmailVerification] error=$emailError');
      }

      if (!mounted) {
        return;
      }
      _showMessage(
        'Conta criada. Enviamos e-mail de confirmação e você precisa validar para liberar o app.',
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'email-already-in-use') {
        _showEmailAlreadyInUseActions(email);
        return;
      }
      _showMessage(_humanizeAuthError(error));
    } catch (error) {
      _showMessage(
        'Conta criada no Auth, mas o perfil nao foi confirmado no Firestore. Tente novamente em instantes.',
      );
      _logDebug('[createAccount] profile bootstrap error=$error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showEmailAlreadyInUseActions(String email) async {
    _showMessage(
      'Este e-mail já está cadastrado. Tente entrar ou redefinir sua senha.',
    );

    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: CotahubTheme.surface,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'E-mail já cadastrado',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: CotahubTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Você pode entrar com este e-mail ou redefinir sua senha.',
                  style: TextStyle(color: CotahubTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context).pop(email);
                  },
                  child: const Text('Entrar com este e-mail'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            _ForgotPasswordPage(initialEmail: email),
                      ),
                    );
                  },
                  child: const Text('Redefinir senha'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CotahubTheme.background,
      appBar: AppBar(title: const Text('Cadastrar conta')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: CotahubTheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: CotahubTheme.line),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Criar acesso',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: CotahubTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Selecione aqui se a conta será comprador ou fornecedor.',
                    style: TextStyle(
                      color: CotahubTheme.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: CupertinoSlidingSegmentedControl<_RegisterRole>(
                      groupValue: _selectedRole,
                      backgroundColor: CotahubTheme.surfaceAlt,
                      thumbColor: CotahubTheme.surfaceSoft,
                      padding: const EdgeInsets.all(4),
                      children: const {
                        _RegisterRole.buyer: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          child: Text(
                            'Comprador',
                            style: TextStyle(
                              color: CotahubTheme.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _RegisterRole.supplier: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          child: Text(
                            'Fornecedor',
                            style: TextStyle(
                              color: CotahubTheme.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      },
                      onValueChanged: (value) {
                        if (_isLoading || value == null) {
                          return;
                        }
                        setState(() => _selectedRole = value);
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      hintText: 'Minimo de 6 caracteres',
                      suffixIcon: IconButton(
                        onPressed: _isLoading
                            ? null
                            : () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirmar senha',
                      suffixIcon: IconButton(
                        onPressed: _isLoading
                            ? null
                            : () => setState(
                                () => _obscureConfirmPassword =
                                    !_obscureConfirmPassword,
                              ),
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _createAccount,
                      child: Text(
                        _isLoading
                            ? 'Criando conta...'
                            : 'Cadastrar e continuar',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignalChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SignalChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: CotahubTheme.overlay,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: CotahubTheme.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: CotahubTheme.blue),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: CotahubTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetricRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: const TextStyle(
              color: CotahubTheme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: CotahubTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _ForgotPasswordPage extends StatefulWidget {
  final String initialEmail;

  const _ForgotPasswordPage({required this.initialEmail});

  @override
  State<_ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<_ForgotPasswordPage> {
  late final TextEditingController _emailController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      _showMessage('Digite um e-mail valido para recuperar a senha.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'invalid-email') {
        _showMessage('E-mail invalido.');
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }

    if (!mounted) {
      return;
    }

    _showMessage(
      'Enviamos um link de redefinição para seu e-mail, se ele estiver cadastrado.',
    );
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => _ResetPasswordWithCodePage(email: email),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CotahubTheme.background,
      appBar: AppBar(title: const Text('Recuperar senha')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: CotahubTheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: CotahubTheme.line),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Receber código de redefinição',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: CotahubTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enviamos um e-mail com link/código de confirmação para redefinir sua senha.',
                    style: TextStyle(
                      color: CotahubTheme.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail da conta',
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _sendResetEmail,
                      icon: _isLoading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.mark_email_read_outlined),
                      label: Text(
                        _isLoading
                            ? 'Enviando...'
                            : 'Enviar e-mail de redefinição',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Recuperação por celular/WhatsApp ficará para próxima etapa com Phone Auth.',
                    style: TextStyle(
                      color: CotahubTheme.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResetPasswordWithCodePage extends StatefulWidget {
  final String email;

  const _ResetPasswordWithCodePage({required this.email});

  @override
  State<_ResetPasswordWithCodePage> createState() =>
      _ResetPasswordWithCodePageState();
}

class _ResetPasswordWithCodePageState
    extends State<_ResetPasswordWithCodePage> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _confirmReset() async {
    final rawCode = _codeController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (rawCode.isEmpty) {
      _showMessage('Cole o código de confirmação recebido no e-mail.');
      return;
    }

    if (newPassword.length < 6) {
      _showMessage('A nova senha precisa ter pelo menos 6 caracteres.');
      return;
    }

    if (newPassword != confirmPassword) {
      _showMessage('A confirmação da senha está diferente.');
      return;
    }

    final code = _extractOobCode(rawCode);
    if (code.isEmpty) {
      _showMessage(
        'Código inválido. Cole o código ou o link completo do e-mail.',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final emailFromCode = await FirebaseAuth.instance.verifyPasswordResetCode(
        code,
      );

      if (emailFromCode.toLowerCase() != widget.email.toLowerCase()) {
        throw FirebaseAuthException(
          code: 'invalid-action-code',
          message: 'O código pertence a outro e-mail.',
        );
      }

      await FirebaseAuth.instance.confirmPasswordReset(
        code: code,
        newPassword: newPassword,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        'Senha redefinida com sucesso. Faça login com a nova senha.',
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (error) {
      _showMessage(_humanizeAuthError(error));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _extractOobCode(String input) {
    final trimmed = input.trim();

    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      final queryCode = uri.queryParameters['oobCode'];
      if (queryCode != null && queryCode.trim().isNotEmpty) {
        return queryCode.trim();
      }
    }

    return trimmed;
  }

  double _passwordStrengthScore(String password) {
    if (password.isEmpty) {
      return 0;
    }

    var score = 0.0;
    if (password.length >= 8) score += 1;
    if (password.length >= 12) score += 1;
    if (RegExp(r'[A-Z]').hasMatch(password)) score += 1;
    if (RegExp(r'[a-z]').hasMatch(password)) score += 1;
    if (RegExp(r'\d').hasMatch(password)) score += 1;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score += 1;
    return score / 6;
  }

  String _passwordStrengthLabel(double score) {
    if (score >= 0.8) {
      return 'Forte';
    }

    if (score >= 0.5) {
      return 'Média';
    }

    if (score > 0) {
      return 'Fraca';
    }

    return 'Não informada';
  }

  Color _passwordStrengthColor(double score) {
    if (score >= 0.8) {
      return CotahubTheme.green;
    }

    if (score >= 0.5) {
      return CotahubTheme.accent;
    }

    return const Color(0xFFFF6B6B);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final strengthScore = _passwordStrengthScore(_newPasswordController.text);
    final strengthLabel = _passwordStrengthLabel(strengthScore);
    final strengthColor = _passwordStrengthColor(strengthScore);

    return Scaffold(
      backgroundColor: CotahubTheme.background,
      appBar: AppBar(title: const Text('Redefinir senha')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: CotahubTheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: CotahubTheme.line),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Confirmar código e nova senha',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: CotahubTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Conta: ${widget.email}',
                    style: const TextStyle(
                      color: CotahubTheme.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _codeController,
                    minLines: 1,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Código de confirmação ou link',
                      hintText: 'Cole o código ou URL recebida no e-mail',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _newPasswordController,
                    obscureText: _obscureNewPassword,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Nova senha',
                      hintText: 'Mínimo de 6 caracteres',
                      suffixIcon: IconButton(
                        tooltip: _obscureNewPassword
                            ? 'Mostrar senha'
                            : 'Ocultar senha',
                        onPressed: () {
                          setState(
                            () => _obscureNewPassword = !_obscureNewPassword,
                          );
                        },
                        icon: Icon(
                          _obscureNewPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: strengthScore == 0 ? 0.02 : strengthScore,
                            minHeight: 8,
                            color: strengthColor,
                            backgroundColor: CotahubTheme.surfaceAlt,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        strengthLabel,
                        style: TextStyle(
                          color: strengthColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirmar nova senha',
                      suffixIcon: IconButton(
                        tooltip: _obscureConfirmPassword
                            ? 'Mostrar senha'
                            : 'Ocultar senha',
                        onPressed: () {
                          setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword,
                          );
                        },
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _confirmReset,
                      icon: _isLoading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_reset_rounded),
                      label: Text(
                        _isLoading ? 'Confirmando...' : 'Redefinir senha',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _humanizeAuthError(FirebaseAuthException error) {
  switch (error.code) {
    case 'user-not-found':
      return 'E-mail ou senha inválidos.';
    case 'wrong-password':
      return 'E-mail ou senha inválidos.';
    case 'invalid-credential':
      return 'E-mail ou senha inválidos.';
    case 'invalid-email':
      return 'E-mail inválido.';
    case 'email-already-in-use':
      return 'Este e-mail já está cadastrado. Tente entrar ou redefinir sua senha.';
    case 'too-many-requests':
      return 'Muitas tentativas. Aguarde alguns minutos e tente novamente.';
    case 'expired-action-code':
      return 'Código expirado. Solicite um novo e-mail de redefinição.';
    case 'invalid-action-code':
      return 'Código inválido. Solicite um novo e-mail de redefinição.';
    case 'weak-password':
      return 'A nova senha é muito fraca.';
    default:
      return '${error.code}: ${error.message ?? 'Erro de autenticação.'}';
  }
}
