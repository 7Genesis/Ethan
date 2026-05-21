import 'package:cotahub/features/home/pages/home_page.dart';
import 'package:cotahub/features/supplier/pages/supplier_home_page.dart';
import 'package:cotahub/models/user_profile.dart';
import 'package:cotahub/core/validators/br_documents.dart';
import 'package:cotahub/repositories/user_repository.dart';
import 'package:cotahub/theme/cotahub_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum _ProfileRole { buyer, supplier }

enum _EntityType { legal, individual }

enum _CompanyDocumentType { cnpj, cpf }

void _logDebug(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

class CompleteProfilePage extends StatefulWidget {
  final UserProfile? profile;

  const CompleteProfilePage({super.key, this.profile});

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _companyLegalNameController = TextEditingController();
  final _companyTaxIdController = TextEditingController();
  final _companyPhoneController = TextEditingController();
  final _companyEmailController = TextEditingController();
  final _buyerNameController = TextEditingController();
  final _buyerRoleTitleController = TextEditingController();
  final _buyerDocumentController = TextEditingController();
  final _buyerPhoneController = TextEditingController();
  final _userRepository = UserRepository();

  bool _isSaving = false;
  late _ProfileRole _selectedRole;
  late _EntityType _selectedEntityType;
  late _CompanyDocumentType _selectedCompanyDocumentType;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;

    _selectedRole = profile?.role.trim().toLowerCase() == 'supplier'
        ? _ProfileRole.supplier
        : _ProfileRole.buyer;
    _selectedEntityType = profile?.entityType == 'individual'
        ? _EntityType.individual
        : _EntityType.legal;
    _selectedCompanyDocumentType = profile?.companyDocumentType == 'cpf'
        ? _CompanyDocumentType.cpf
        : _CompanyDocumentType.cnpj;

    _companyNameController.text = profile?.companyName ?? '';
    _companyLegalNameController.text = profile?.companyLegalName ?? '';
    _companyTaxIdController.text = profile?.companyTaxId ?? '';
    _companyPhoneController.text = profile?.companyPhone ?? '';
    _companyEmailController.text = profile?.companyEmail.isNotEmpty == true
        ? profile!.companyEmail
        : (FirebaseAuth.instance.currentUser?.email ?? '');
    _buyerNameController.text = profile?.buyerName ?? '';
    _buyerRoleTitleController.text = profile?.buyerRoleTitle ?? '';
    _buyerDocumentController.text = profile?.buyerDocument ?? '';
    _buyerPhoneController.text = profile?.buyerPhone ?? '';

    if (profile != null &&
        profile.profileCompleted != true &&
        profile.hasRequiredIdentity) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoRepairProfileCompletion(profile);
      });
    }
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _companyLegalNameController.dispose();
    _companyTaxIdController.dispose();
    _companyPhoneController.dispose();
    _companyEmailController.dispose();
    _buyerNameController.dispose();
    _buyerRoleTitleController.dispose();
    _buyerDocumentController.dispose();
    _buyerPhoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final form = _formKey.currentState;

    if (form == null || !form.validate()) {
      _logDebug(
        '[completeProfile.validate] status=invalid role=${_selectedRole.name} entityType=${_selectedEntityType.name} companyDocumentType=${_selectedCompanyDocumentType.name}',
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('Usuario nao autenticado.');
      }

      await _userRepository.saveCurrentUserProfile(
        UserProfile(
          id: user.uid,
          email: user.email ?? _companyEmailController.text.trim(),
          role: _selectedRole == _ProfileRole.supplier ? 'supplier' : 'buyer',
          entityType: _selectedEntityType == _EntityType.individual
              ? 'individual'
              : 'legal',
          companyDocumentType:
              _selectedCompanyDocumentType == _CompanyDocumentType.cpf
              ? 'cpf'
              : 'cnpj',
          identityVerificationStatus: 'verified',
          registrationStage: 'active',
          companyName: _companyNameController.text.trim(),
          companyLegalName: _companyLegalNameController.text.trim(),
          companyTaxId: _digitsOnly(_companyTaxIdController.text),
          companyPhone: _digitsOnly(_companyPhoneController.text),
          companyEmail: _companyEmailController.text.trim(),
          buyerName: _buyerNameController.text.trim(),
          buyerRoleTitle: _buyerRoleTitleController.text.trim(),
          buyerDocument: _digitsOnly(_buyerDocumentController.text),
          buyerPhone: _digitsOnly(_buyerPhoneController.text),
          profileCompleted: true,
          createdAt: widget.profile?.createdAt,
          updatedAt: DateTime.now(),
        ),
      );

      final verifiedProfile = await _userRepository.getCurrentUserProfile(
        forceServer: true,
      );
      _logDebug(
        '[completeProfile.afterSave] profileExists=${verifiedProfile != null} profileCompleted=${verifiedProfile?.profileCompleted} role=${verifiedProfile?.role}',
      );

      if (verifiedProfile == null || verifiedProfile.profileCompleted != true) {
        throw Exception(
          'Nao foi possivel confirmar profileCompleted=true no Firestore.',
        );
      }

      await _userRepository.sendProfileCompletedEmail(
        verifiedProfile.companyEmail.isNotEmpty
            ? verifiedProfile.companyEmail
            : (user.email ?? ''),
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => verifiedProfile.isSupplier
              ? const SupplierHomePage()
              : const HomePage(),
        ),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar cadastro: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _autoRepairProfileCompletion(UserProfile existingProfile) async {
    if (_isSaving) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    _logDebug(
      '[completeProfile.autoRepair.start] profileCompleted=${existingProfile.profileCompleted} role=${existingProfile.role}',
    );

    setState(() => _isSaving = true);

    try {
      await _userRepository.saveCurrentUserProfile(existingProfile);
      final verifiedProfile = await _userRepository.getCurrentUserProfile(
        forceServer: true,
      );

      _logDebug(
        '[completeProfile.autoRepair.verify] profileExists=${verifiedProfile != null} profileCompleted=${verifiedProfile?.profileCompleted} role=${verifiedProfile?.role}',
      );

      if (!mounted ||
          verifiedProfile == null ||
          verifiedProfile.profileCompleted != true) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => verifiedProfile.isSupplier
              ? const SupplierHomePage()
              : const HomePage(),
        ),
        (route) => false,
      );
    } catch (error) {
      _logDebug('[completeProfile.autoRepair.error] error=$error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'Sem e-mail';
    final profile = widget.profile;
    final canReprocessLegacyProfile =
        profile != null &&
        profile.profileCompleted != true &&
        profile.hasRequiredIdentity;

    return Scaffold(
      backgroundColor: CotahubTheme.background,
      appBar: AppBar(
        title: const Text('Cadastro completo'),
        actions: [
          TextButton.icon(
            onPressed: _isSaving
                ? null
                : () async {
                    await FirebaseAuth.instance.signOut();
                  },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sair'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
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
                            'Ative o perfil com dados completos.',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: CotahubTheme.textPrimary,
                              height: 1.02,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'O app so libera cotacao, proposta e fechamento fiscal depois de empresa e responsavel ficarem completos. Isso reduz cadastro vazio e protege o fluxo.',
                            style: TextStyle(
                              color: CotahubTheme.textSecondary,
                              fontSize: 15,
                              height: 1.55,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _InfoPill(
                                icon: Icons.verified_user_rounded,
                                label: 'Identidade obrigatoria',
                              ),
                              _InfoPill(
                                icon: Icons.description_outlined,
                                label: 'XML fiscal no fechamento',
                              ),
                              _InfoPill(
                                icon: Icons.account_circle_outlined,
                                label: email,
                              ),
                            ],
                          ),
                          if (canReprocessLegacyProfile) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: CotahubTheme.surfaceAlt,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: CotahubTheme.line),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    color: CotahubTheme.blue,
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      'Conta legada detectada: os dados existem, mas a ativação final não foi marcada. Reprocesse para concluir sem perder dados.',
                                      style: TextStyle(
                                        color: CotahubTheme.textSecondary,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  OutlinedButton.icon(
                                    onPressed: _isSaving
                                        ? null
                                        : () {
                                            _autoRepairProfileCompletion(
                                              profile,
                                            );
                                          },
                                    icon: const Icon(Icons.restart_alt_rounded),
                                    label: const Text('Reprocessar cadastro'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: CupertinoSlidingSegmentedControl<_ProfileRole>(
                        groupValue: _selectedRole,
                        backgroundColor: CotahubTheme.surfaceAlt,
                        thumbColor: CotahubTheme.surfaceSoft,
                        padding: const EdgeInsets.all(4),
                        children: const {
                          _ProfileRole.buyer: Padding(
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
                          _ProfileRole.supplier: Padding(
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
                          if (_isSaving || value == null) {
                            return;
                          }

                          setState(() => _selectedRole = value);
                        },
                      ),
                    ),
                    const SizedBox(height: 22),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: CupertinoSlidingSegmentedControl<_EntityType>(
                            groupValue: _selectedEntityType,
                            backgroundColor: CotahubTheme.surfaceAlt,
                            thumbColor: CotahubTheme.surfaceSoft,
                            padding: const EdgeInsets.all(4),
                            children: const {
                              _EntityType.legal: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                child: Text(
                                  'Pessoa Jurídica (PJ)',
                                  style: TextStyle(
                                    color: CotahubTheme.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              _EntityType.individual: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                child: Text(
                                  'Pessoa Física (PF)',
                                  style: TextStyle(
                                    color: CotahubTheme.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            },
                            onValueChanged: (value) {
                              if (_isSaving || value == null) {
                                return;
                              }
                              setState(() {
                                _selectedEntityType = value;
                                if (value == _EntityType.individual) {
                                  _selectedCompanyDocumentType =
                                      _CompanyDocumentType.cpf;
                                }
                              });
                            },
                          ),
                        ),
                        if (_selectedEntityType == _EntityType.legal)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child:
                                CupertinoSlidingSegmentedControl<
                                  _CompanyDocumentType
                                >(
                                  groupValue: _selectedCompanyDocumentType,
                                  backgroundColor: CotahubTheme.surfaceAlt,
                                  thumbColor: CotahubTheme.surfaceSoft,
                                  padding: const EdgeInsets.all(4),
                                  children: const {
                                    _CompanyDocumentType.cnpj: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      child: Text(
                                        'CNPJ',
                                        style: TextStyle(
                                          color: CotahubTheme.textPrimary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    _CompanyDocumentType.cpf: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      child: Text(
                                        'CPF provisório',
                                        style: TextStyle(
                                          color: CotahubTheme.textPrimary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  },
                                  onValueChanged: (value) {
                                    if (_isSaving || value == null) {
                                      return;
                                    }
                                    setState(
                                      () =>
                                          _selectedCompanyDocumentType = value,
                                    );
                                  },
                                ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 860;

                        if (!isWide) {
                          return Column(
                            children: [
                              _CompanySection(
                                companyNameController: _companyNameController,
                                companyLegalNameController:
                                    _companyLegalNameController,
                                companyTaxIdController: _companyTaxIdController,
                                companyPhoneController: _companyPhoneController,
                                companyEmailController: _companyEmailController,
                                entityType: _selectedEntityType,
                                companyDocumentType:
                                    _selectedCompanyDocumentType,
                              ),
                              const SizedBox(height: 18),
                              _BuyerSection(
                                buyerNameController: _buyerNameController,
                                buyerRoleTitleController:
                                    _buyerRoleTitleController,
                                buyerDocumentController:
                                    _buyerDocumentController,
                                buyerPhoneController: _buyerPhoneController,
                              ),
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _CompanySection(
                                companyNameController: _companyNameController,
                                companyLegalNameController:
                                    _companyLegalNameController,
                                companyTaxIdController: _companyTaxIdController,
                                companyPhoneController: _companyPhoneController,
                                companyEmailController: _companyEmailController,
                                entityType: _selectedEntityType,
                                companyDocumentType:
                                    _selectedCompanyDocumentType,
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: _BuyerSection(
                                buyerNameController: _buyerNameController,
                                buyerRoleTitleController:
                                    _buyerRoleTitleController,
                                buyerDocumentController:
                                    _buyerDocumentController,
                                buyerPhoneController: _buyerPhoneController,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveProfile,
                        icon: _isSaving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.shield_rounded),
                        label: Text(
                          _isSaving
                              ? 'Validando cadastro...'
                              : 'Concluir cadastro do perfil',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _validateRequired(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return 'Informe $label.';
    }

    return null;
  }

  String? _validateCompanyEmail(String? value) {
    final requiredError = _validateRequired(value, 'o e-mail da empresa');

    if (requiredError != null) {
      return requiredError;
    }

    if (!value!.contains('@')) {
      return 'Digite um e-mail valido.';
    }

    return null;
  }

  String? _validateCompanyDocument(String? value) {
    final label = _selectedCompanyDocumentType == _CompanyDocumentType.cnpj
        ? 'o CNPJ da empresa'
        : 'o CPF para cadastro sem CNPJ';
    final requiredError = _validateRequired(value, label);

    if (requiredError != null) {
      return requiredError;
    }

    final digits = _digitsOnly(value!);
    if (_selectedCompanyDocumentType == _CompanyDocumentType.cnpj) {
      if (!BrDocumentsValidator.isValidCnpj(digits)) {
        return 'CNPJ invalido.';
      }
      return null;
    }

    if (!BrDocumentsValidator.isValidCpf(digits)) {
      return 'CPF invalido para cadastro sem CNPJ.';
    }

    return null;
  }

  String? _validateCpf(String? value) {
    final requiredError = _validateRequired(value, 'o CPF do responsavel');

    if (requiredError != null) {
      return requiredError;
    }

    final digits = _digitsOnly(value!);

    if (!BrDocumentsValidator.isValidCpf(digits)) {
      return 'CPF invalido.';
    }

    return null;
  }

  String? _validateWhatsApp(String? value, String label) {
    final requiredError = _validateRequired(value, label);

    if (requiredError != null) {
      return requiredError;
    }

    final digits = BrDocumentsValidator.normalizeBrazilPhone(value!);

    if (!BrDocumentsValidator.isValidBrazilWhatsApp(digits)) {
      return 'WhatsApp invalido. Use DDD + 9 digitos.';
    }

    return null;
  }

  String _digitsOnly(String value) {
    return BrDocumentsValidator.digitsOnly(value);
  }
}

class _CompanySection extends StatelessWidget {
  final TextEditingController companyNameController;
  final TextEditingController companyLegalNameController;
  final TextEditingController companyTaxIdController;
  final TextEditingController companyPhoneController;
  final TextEditingController companyEmailController;
  final _EntityType entityType;
  final _CompanyDocumentType companyDocumentType;

  const _CompanySection({
    required this.companyNameController,
    required this.companyLegalNameController,
    required this.companyTaxIdController,
    required this.companyPhoneController,
    required this.companyEmailController,
    required this.entityType,
    required this.companyDocumentType,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_CompleteProfilePageState>();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: CotahubTheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: CotahubTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Empresa',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: CotahubTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            entityType == _EntityType.individual
                ? 'Cadastro PF habilitado. Use CPF como documento principal.'
                : 'Cadastro PJ com CNPJ. Se ainda nao tiver CNPJ, pode usar CPF provisoriamente.',
            style: const TextStyle(
              color: CotahubTheme.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: companyNameController,
            validator: (value) =>
                state?._validateRequired(value, 'o nome de exibicao'),
            decoration: InputDecoration(
              labelText: entityType == _EntityType.individual
                  ? 'Nome de exibicao'
                  : 'Nome fantasia',
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: companyLegalNameController,
            validator: (value) =>
                state?._validateRequired(value, 'o nome legal'),
            decoration: InputDecoration(
              labelText: entityType == _EntityType.individual
                  ? 'Nome completo'
                  : 'Razao social',
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: companyTaxIdController,
            keyboardType: TextInputType.number,
            inputFormatters: companyDocumentType == _CompanyDocumentType.cnpj
                ? const [_CnpjFormatter()]
                : const [_CpfFormatter()],
            validator: state?._validateCompanyDocument,
            decoration: InputDecoration(
              labelText: companyDocumentType == _CompanyDocumentType.cnpj
                  ? 'CNPJ'
                  : 'CPF',
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: companyPhoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: const [_BrazilWhatsAppFormatter()],
            validator: (value) =>
                state?._validateWhatsApp(value, 'o WhatsApp da empresa'),
            decoration: const InputDecoration(labelText: 'WhatsApp da empresa'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: companyEmailController,
            keyboardType: TextInputType.emailAddress,
            validator: state?._validateCompanyEmail,
            decoration: const InputDecoration(labelText: 'E-mail da empresa'),
          ),
        ],
      ),
    );
  }
}

class _BuyerSection extends StatelessWidget {
  final TextEditingController buyerNameController;
  final TextEditingController buyerRoleTitleController;
  final TextEditingController buyerDocumentController;
  final TextEditingController buyerPhoneController;

  const _BuyerSection({
    required this.buyerNameController,
    required this.buyerRoleTitleController,
    required this.buyerDocumentController,
    required this.buyerPhoneController,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_CompleteProfilePageState>();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: CotahubTheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: CotahubTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Responsavel',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: CotahubTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Quem compra ou vende precisa ficar vinculado a um responsavel real dentro da empresa.',
            style: TextStyle(color: CotahubTheme.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: buyerNameController,
            validator: (value) =>
                state?._validateRequired(value, 'o nome do responsavel'),
            decoration: const InputDecoration(labelText: 'Nome do responsavel'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: buyerRoleTitleController,
            validator: (value) =>
                state?._validateRequired(value, 'o cargo do responsavel'),
            decoration: const InputDecoration(labelText: 'Cargo'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: buyerDocumentController,
            keyboardType: TextInputType.number,
            inputFormatters: const [_CpfFormatter()],
            validator: state?._validateCpf,
            decoration: const InputDecoration(labelText: 'CPF do responsavel'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: buyerPhoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: const [_BrazilWhatsAppFormatter()],
            validator: (value) =>
                state?._validateWhatsApp(value, 'o WhatsApp do responsavel'),
            decoration: const InputDecoration(
              labelText: 'WhatsApp do responsavel',
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: CotahubTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: CotahubTheme.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: CotahubTheme.blue),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: CotahubTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CpfFormatter extends TextInputFormatter {
  const _CpfFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 11 ? digits.substring(0, 11) : digits;
    final formatted = _formatCpf(limited);
    final digitsBeforeCursor = _countDigitsUntil(
      newValue.text,
      newValue.selection.baseOffset,
    ).clamp(0, limited.length);
    final cursorOffset = _cursorOffsetFromDigits(formatted, digitsBeforeCursor);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorOffset),
    );
  }

  String _formatCpf(String digits) {
    if (digits.length <= 3) {
      return digits;
    }

    if (digits.length <= 6) {
      return '${digits.substring(0, 3)}.${digits.substring(3)}';
    }

    if (digits.length <= 9) {
      return '${digits.substring(0, 3)}.${digits.substring(3, 6)}.${digits.substring(6)}';
    }

    return '${digits.substring(0, 3)}.${digits.substring(3, 6)}.${digits.substring(6, 9)}-${digits.substring(9)}';
  }
}

class _CnpjFormatter extends TextInputFormatter {
  const _CnpjFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 14 ? digits.substring(0, 14) : digits;
    final formatted = _formatCnpj(limited);
    final digitsBeforeCursor = _countDigitsUntil(
      newValue.text,
      newValue.selection.baseOffset,
    ).clamp(0, limited.length);
    final cursorOffset = _cursorOffsetFromDigits(formatted, digitsBeforeCursor);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorOffset),
    );
  }

  String _formatCnpj(String digits) {
    if (digits.length <= 2) {
      return digits;
    }

    if (digits.length <= 5) {
      return '${digits.substring(0, 2)}.${digits.substring(2)}';
    }

    if (digits.length <= 8) {
      return '${digits.substring(0, 2)}.${digits.substring(2, 5)}.${digits.substring(5)}';
    }

    if (digits.length <= 12) {
      return '${digits.substring(0, 2)}.${digits.substring(2, 5)}.${digits.substring(5, 8)}/${digits.substring(8)}';
    }

    return '${digits.substring(0, 2)}.${digits.substring(2, 5)}.${digits.substring(5, 8)}/${digits.substring(8, 12)}-${digits.substring(12)}';
  }
}

class _BrazilWhatsAppFormatter extends TextInputFormatter {
  const _BrazilWhatsAppFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final normalized = _trimToMaxAllowedDigits(digits);
    final formatted = _formatBrWhatsApp(normalized);
    final digitsBeforeCursor = _countDigitsUntil(
      newValue.text,
      newValue.selection.baseOffset,
    ).clamp(0, normalized.length);
    final cursorOffset = _cursorOffsetFromDigits(formatted, digitsBeforeCursor);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorOffset),
    );
  }

  String _trimToMaxAllowedDigits(String digits) {
    if (digits.startsWith('55')) {
      return digits.length > 13 ? digits.substring(0, 13) : digits;
    }

    return digits.length > 11 ? digits.substring(0, 11) : digits;
  }

  String _formatBrWhatsApp(String digits) {
    if (digits.isEmpty) {
      return '';
    }

    var countryCode = '';
    var local = digits;

    if (digits.startsWith('55') && digits.length > 11) {
      countryCode = '+55 ';
      local = digits.substring(2);
    }

    if (local.length <= 2) {
      return '$countryCode($local';
    }

    final ddd = local.substring(0, 2);
    final number = local.substring(2);

    if (number.length <= 5) {
      return '$countryCode($ddd) $number';
    }

    final firstBlock = number.substring(0, 5);
    final secondBlock = number.substring(5);
    return '$countryCode($ddd) $firstBlock-$secondBlock';
  }
}

int _countDigitsUntil(String text, int cursorOffset) {
  final safeOffset = cursorOffset.clamp(0, text.length);
  final upToCursor = text.substring(0, safeOffset);
  return RegExp(r'\d').allMatches(upToCursor).length;
}

int _cursorOffsetFromDigits(String formatted, int digitsBeforeCursor) {
  if (digitsBeforeCursor <= 0) {
    return 0;
  }

  var digitCount = 0;
  for (var i = 0; i < formatted.length; i++) {
    if (RegExp(r'\d').hasMatch(formatted[i])) {
      digitCount++;
      if (digitCount == digitsBeforeCursor) {
        return i + 1;
      }
    }
  }

  return formatted.length;
}
