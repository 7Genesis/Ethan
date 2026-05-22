import 'package:projeto_ethan/models/support_ticket.dart';
import 'package:projeto_ethan/repositories/support_ticket_repository.dart';
import 'package:projeto_ethan/theme/cotahub_theme.dart';
import 'package:flutter/material.dart';

class SupportPage extends StatefulWidget {
  final String? initialCategory;
  final String? initialMessage;

  const SupportPage({super.key, this.initialCategory, this.initialMessage});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  final SupportTicketRepository _repository = SupportTicketRepository();
  final TextEditingController _messageController = TextEditingController();
  bool _isSubmitting = false;
  late String _category;

  @override
  void initState() {
    super.initState();
    _category =
        SupportTicketRepository.categories.contains(widget.initialCategory)
        ? widget.initialCategory!
        : SupportTicketRepository.categories.first;
    _messageController.text = widget.initialMessage?.trim() ?? '';
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _openTicket() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      _show('Descreva o problema para abrir o chamado.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _repository.createTicket(category: _category, message: message);
      _show('Chamado aberto com sucesso.');
      _messageController.clear();
    } catch (error) {
      _show('Falha ao abrir chamado: $error');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CotahubTheme.background,
      appBar: AppBar(title: const Text('Suporte')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'FAQ rápido',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: CotahubTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 10),
                _FaqItem(
                  question: 'Como criar cotação?',
                  answer:
                      'Entre em Home, clique no botão +, preencha os itens e publique.',
                ),
                _FaqItem(
                  question: 'Como enviar proposta?',
                  answer:
                      'No painel Fornecedor, abra uma cotação disponível e envie preço/prazo.',
                ),
                _FaqItem(
                  question: 'Como alterar CNPJ?',
                  answer:
                      'Alteração de CNPJ exige suporte para validação de segurança.',
                ),
                _FaqItem(
                  question: 'Como funciona XML fiscal?',
                  answer:
                      'Após proposta aceita, o fornecedor envia XML para revisão do comprador.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Falar com suporte',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: CotahubTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'Categoria do problema',
                  ),
                  items: SupportTicketRepository.categories
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _category = value);
                          }
                        },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _messageController,
                  enabled: !_isSubmitting,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Mensagem',
                    hintText: 'Descreva o que aconteceu e o impacto.',
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _openTicket,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.support_agent_outlined),
                    label: Text(
                      _isSubmitting
                          ? 'Abrindo chamado...'
                          : 'Abrir solicitação',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chamados recentes',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: CotahubTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                StreamBuilder<List<SupportTicket>>(
                  stream: _repository.currentUserTickets(),
                  builder: (context, snapshot) {
                    final tickets = snapshot.data ?? const <SupportTicket>[];
                    if (tickets.isEmpty) {
                      return const Text(
                        'Nenhum chamado aberto por enquanto.',
                        style: TextStyle(color: CotahubTheme.textSecondary),
                      );
                    }

                    return Column(
                      children: tickets
                          .map(
                            (ticket) => Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: CotahubTheme.surfaceAlt,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: CotahubTheme.line),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ticket.category,
                                    style: const TextStyle(
                                      color: CotahubTheme.textPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    ticket.message,
                                    style: const TextStyle(
                                      color: CotahubTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Status: ${ticket.status}',
                                    style: const TextStyle(
                                      color: CotahubTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CotahubTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CotahubTheme.line),
      ),
      child: child,
    );
  }
}

class _FaqItem extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqItem({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(
              color: CotahubTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            answer,
            style: const TextStyle(color: CotahubTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
