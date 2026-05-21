import 'package:cotahub/theme/cotahub_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  bool _isLoading = false;

  Future<void> _resendVerificationEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      await user.sendEmailVerification();
      if (!mounted) {
        return;
      }
      _show(
        'Reenviamos o e-mail de confirmação. Verifique caixa de entrada e spam.',
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }
      _show('Falha ao reenviar e-mail: ${error.message ?? error.code}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      await user.reload();
      if (!mounted) {
        return;
      }
      if (FirebaseAuth.instance.currentUser?.emailVerified == true) {
        _show('E-mail confirmado. Liberando acesso...');
      } else {
        _show('Ainda não confirmado. Abra o link do e-mail e tente novamente.');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _show('Falha ao atualizar status: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  void _show(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'sem e-mail';

    return Scaffold(
      backgroundColor: CotahubTheme.background,
      appBar: AppBar(
        title: const Text('Confirmar e-mail'),
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : _signOut,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sair'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
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
                    'Verificação obrigatória de e-mail',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: CotahubTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Conta: $email',
                    style: const TextStyle(
                      color: CotahubTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Para liberar o app, confirme o e-mail enviado no cadastro. Sem confirmação, o acesso fica bloqueado.',
                    style: TextStyle(
                      color: CotahubTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _refreshVerification,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.verified_user_outlined),
                          label: const Text('Já confirmei, atualizar'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoading
                              ? null
                              : _resendVerificationEmail,
                          icon: const Icon(Icons.mark_email_read_outlined),
                          label: const Text('Reenviar e-mail'),
                        ),
                      ),
                    ],
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
