import 'package:cotahub/features/support/pages/support_page.dart';
import 'package:cotahub/models/user_profile.dart';
import 'package:cotahub/repositories/user_repository.dart';
import 'package:cotahub/theme/cotahub_theme.dart';
import 'package:flutter/material.dart';

class CompanyProfilePage extends StatefulWidget {
  const CompanyProfilePage({super.key});

  @override
  State<CompanyProfilePage> createState() => _CompanyProfilePageState();
}

class _CompanyProfilePageState extends State<CompanyProfilePage> {
  final UserRepository _userRepository = UserRepository();
  final _companyNameController = TextEditingController();
  final _companyLegalNameController = TextEditingController();
  final _companyPhoneController = TextEditingController();
  final _companyEmailController = TextEditingController();
  final _buyerNameController = TextEditingController();
  final _buyerRoleTitleController = TextEditingController();
  final _buyerDocumentController = TextEditingController();
  final _buyerPhoneController = TextEditingController();
  bool _initialized = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _companyNameController.dispose();
    _companyLegalNameController.dispose();
    _companyPhoneController.dispose();
    _companyEmailController.dispose();
    _buyerNameController.dispose();
    _buyerRoleTitleController.dispose();
    _buyerDocumentController.dispose();
    _buyerPhoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await _userRepository.updateCompanyProfile(
        companyName: _companyNameController.text,
        companyLegalName: _companyLegalNameController.text,
        companyPhone: _companyPhoneController.text,
        companyEmail: _companyEmailController.text,
        buyerName: _buyerNameController.text,
        buyerRoleTitle: _buyerRoleTitleController.text,
        buyerDocument: _buyerDocumentController.text,
        buyerPhone: _buyerPhoneController.text,
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil atualizado com sucesso.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Falha ao salvar perfil: $error')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CotahubTheme.background,
      appBar: AppBar(title: const Text('Perfil da empresa')),
      body: FutureBuilder<UserProfile?>(
        future: _userRepository.getCurrentUserProfile(forceServer: true),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final profile = snapshot.data;
          if (profile == null) {
            return const Center(
              child: Text(
                'Perfil não encontrado.',
                style: TextStyle(color: CotahubTheme.textSecondary),
              ),
            );
          }

          if (!_initialized) {
            _initialized = true;
            _companyNameController.text = profile.companyName;
            _companyLegalNameController.text = profile.companyLegalName;
            _companyPhoneController.text = profile.companyPhone;
            _companyEmailController.text = profile.companyEmail;
            _buyerNameController.text = profile.buyerName;
            _buyerRoleTitleController.text = profile.buyerRoleTitle;
            _buyerDocumentController.text = profile.buyerDocument;
            _buyerPhoneController.text = profile.buyerPhone;
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CotahubTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: CotahubTheme.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dados da empresa',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: CotahubTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _companyNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome fantasia',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _companyLegalNameController,
                      decoration: const InputDecoration(
                        labelText: 'Razão social',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _companyPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Telefone da empresa',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _companyEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'E-mail da empresa',
                      ),
                    ),
                    const SizedBox(height: 14),
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: profile.companyDocumentType == 'cpf'
                            ? 'CPF da empresa (bloqueado)'
                            : 'CNPJ da empresa (bloqueado)',
                      ),
                      child: Text(
                        profile.companyTaxId,
                        style: const TextStyle(
                          color: CotahubTheme.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Para alterar o CNPJ, entre em contato com o suporte.',
                      style: TextStyle(color: CotahubTheme.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const SupportPage(initialCategory: 'CNPJ'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.support_agent_outlined),
                      label: const Text('Abrir suporte para CNPJ'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CotahubTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: CotahubTheme.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Responsável',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: CotahubTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _buyerNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome do responsável',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _buyerRoleTitleController,
                      decoration: const InputDecoration(
                        labelText: 'Cargo do responsável',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _buyerDocumentController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'CPF do responsável',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _buyerPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Telefone do responsável',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_isSaving ? 'Salvando...' : 'Salvar alterações'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
