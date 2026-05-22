import 'package:projeto_ethan/repositories/support_ticket_repository.dart';
import 'package:projeto_ethan/services/ai_support_service.dart';
import 'package:projeto_ethan/theme/cotahub_theme.dart';
import 'package:flutter/material.dart';

class AiAssistantFab extends StatelessWidget {
  const AiAssistantFab({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: CotahubTheme.blue,
      foregroundColor: Colors.white,
      onPressed: () {
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const _AiSupportSheet(),
        );
      },
      child: const Icon(Icons.smart_toy_outlined),
    );
  }
}

class _AiSupportSheet extends StatefulWidget {
  const _AiSupportSheet();

  @override
  State<_AiSupportSheet> createState() => _AiSupportSheetState();
}

class _AiSupportSheetState extends State<_AiSupportSheet> {
  final AiSupportService _service = AiSupportService();
  final SupportTicketRepository _ticketRepository = SupportTicketRepository();
  final TextEditingController _messageController = TextEditingController();
  final List<_AiMessage> _messages = <_AiMessage>[
    const _AiMessage(
      fromUser: false,
      text:
          'Olá. Posso ajudar com cadastro, cotação, proposta, XML fiscal e suporte.',
    ),
  ];
  bool _isLoading = false;
  String _ticketCategory = SupportTicketRepository.categories.first;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) {
      return;
    }

    setState(() {
      _messages.add(_AiMessage(fromUser: true, text: text));
      _isLoading = true;
      _messageController.clear();
    });

    final response = await _service.askSupportAI(text);

    if (!mounted) {
      return;
    }

    setState(() {
      _messages.add(_AiMessage(fromUser: false, text: response));
      _isLoading = false;
    });
  }

  Future<void> _openTicket() async {
    final latestUserMessage = _messages.lastWhere(
      (item) => item.fromUser,
      orElse: () =>
          _AiMessage(fromUser: true, text: _messageController.text.trim()),
    );
    final text = latestUserMessage.text.trim();

    if (text.isEmpty) {
      _show('Escreva sua dúvida antes de abrir o chamado.');
      return;
    }

    try {
      await _ticketRepository.createTicket(
        category: _ticketCategory,
        message: '[IA] $text',
      );
      _show('Chamado aberto a partir da conversa.');
    } catch (error) {
      _show('Falha ao abrir chamado: $error');
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          height: 560,
          decoration: const BoxDecoration(
            color: CotahubTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: CotahubTheme.line,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Assistente Ethan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: CotahubTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final align = message.fromUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft;
                    final bg = message.fromUser
                        ? CotahubTheme.blue.withValues(alpha: 0.2)
                        : CotahubTheme.surfaceAlt;
                    return Align(
                      alignment: align,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        constraints: const BoxConstraints(maxWidth: 320),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: CotahubTheme.line),
                        ),
                        child: Text(
                          message.text,
                          style: const TextStyle(
                            color: CotahubTheme.textPrimary,
                            height: 1.35,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _ticketCategory,
                        decoration: const InputDecoration(
                          labelText: 'Categoria chamado',
                        ),
                        items: SupportTicketRepository.categories
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _ticketCategory = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _openTicket,
                      icon: const Icon(Icons.support_agent_outlined),
                      label: const Text('Abrir'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        enabled: !_isLoading,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Pergunte algo',
                          hintText: 'Ex.: Como envio XML fiscal?',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filled(
                      onPressed: _isLoading ? null : _send,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiMessage {
  final bool fromUser;
  final String text;

  const _AiMessage({required this.fromUser, required this.text});
}
