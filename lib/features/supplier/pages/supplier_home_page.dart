import 'package:projeto_ethan/models/invoice_xml_record.dart';
import 'package:projeto_ethan/models/app_notification.dart';
import 'package:projeto_ethan/models/proposal.dart';
import 'package:projeto_ethan/models/quotation.dart';
import 'package:projeto_ethan/features/profile/pages/company_profile_page.dart';
import 'package:projeto_ethan/features/support/pages/support_page.dart';
import 'package:projeto_ethan/features/support/widgets/ai_assistant_fab.dart';
import 'package:projeto_ethan/repositories/invoice_xml_repository.dart';
import 'package:projeto_ethan/repositories/notification_repository.dart';
import 'package:projeto_ethan/repositories/proposal_repository.dart';
import 'package:projeto_ethan/repositories/quotation_repository.dart';
import 'package:projeto_ethan/theme/cotahub_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum _SupplierFilter { opportunities, sent }

class SupplierHomePage extends StatefulWidget {
  const SupplierHomePage({super.key});

  @override
  State<SupplierHomePage> createState() => _SupplierHomePageState();
}

class _SupplierHomePageState extends State<SupplierHomePage> {
  final QuotationRepository quotationRepository = QuotationRepository();
  final ProposalRepository proposalRepository = ProposalRepository();
  final InvoiceXmlRepository invoiceXmlRepository = InvoiceXmlRepository();
  final NotificationRepository notificationRepository =
      NotificationRepository();

  _SupplierFilter selectedFilter = _SupplierFilter.opportunities;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CotahubTheme.background,
      floatingActionButton: const AiAssistantFab(),
      body: SafeArea(
        child: StreamBuilder<List<Quotation>>(
          stream: quotationRepository.getOpenQuotations(),
          builder: (context, quotationSnapshot) {
            if (quotationSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final quotations = quotationSnapshot.data ?? [];

            return StreamBuilder<List<Proposal>>(
              stream: proposalRepository.getMySentProposals(),
              builder: (context, proposalSnapshot) {
                final sentProposals = proposalSnapshot.data ?? [];
                final acceptedProposals = sentProposals
                    .where((proposal) => proposal.status == 'accepted')
                    .toList();
                final answeredQuotationIds = sentProposals
                    .map((proposal) => proposal.quotationId)
                    .toSet();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
                  children: [
                    _SupplierTopBar(
                      onLogout: () async {
                        await FirebaseAuth.instance.signOut();
                      },
                      onProfile: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CompanyProfilePage(),
                          ),
                        );
                      },
                      onSupport: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SupportPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<List<AppNotification>>(
                      stream: notificationRepository.currentUserNotifications(
                        limit: 6,
                      ),
                      builder: (context, notificationSnapshot) {
                        final notifications =
                            notificationSnapshot.data ?? const [];
                        return _SupplierNotificationPanel(
                          notifications: notifications,
                          onMarkAsRead: (id) =>
                              notificationRepository.markAsRead(id),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Fornecedor',
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        height: 1.02,
                        color: CotahubTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${quotations.length} abertas • ${sentProposals.length} enviadas • ${acceptedProposals.length} aguardando fechamento',
                      style: const TextStyle(
                        color: CotahubTheme.textSecondary,
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: CupertinoSlidingSegmentedControl<_SupplierFilter>(
                        groupValue: selectedFilter,
                        backgroundColor: CotahubTheme.surfaceAlt,
                        thumbColor: CotahubTheme.surfaceSoft,
                        padding: const EdgeInsets.all(4),
                        children: const {
                          _SupplierFilter.opportunities: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            child: Text(
                              'Disponiveis',
                              style: TextStyle(
                                color: CotahubTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _SupplierFilter.sent: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            child: Text(
                              'Enviadas',
                              style: TextStyle(
                                color: CotahubTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        },
                        onValueChanged: (value) {
                          if (value != null) {
                            setState(() => selectedFilter = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SupplierSummaryBand(
                      openCount: quotations.length,
                      sentCount: sentProposals.length,
                      acceptedCount: acceptedProposals.length,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Lista',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: CotahubTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (selectedFilter == _SupplierFilter.opportunities)
                      if (quotations.isEmpty)
                        const _EmptyPanel(
                          title: 'Nenhuma cotacao aberta',
                          message:
                              'Quando novos pedidos forem publicados, eles aparecem aqui.',
                        )
                      else
                        ...quotations.map((quotation) {
                          final alreadyAnswered = answeredQuotationIds.contains(
                            quotation.id,
                          );

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _SupplierQuotationCard(
                              quotation: quotation,
                              alreadyAnswered: alreadyAnswered,
                              onSendProposal: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) {
                                    return _CreateSupplierProposalSheet(
                                      quotation: quotation,
                                      repository: proposalRepository,
                                    );
                                  },
                                );
                              },
                            ),
                          );
                        })
                    else if (sentProposals.isEmpty)
                      const _EmptyPanel(
                        title: 'Nenhuma proposta enviada',
                        message:
                            'Assim que voce responder uma cotacao, ela aparece aqui.',
                      )
                    else
                      ...sentProposals.map(
                        (proposal) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _SentProposalCard(
                            proposal: proposal,
                            invoiceRepository: invoiceXmlRepository,
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SupplierNotificationPanel extends StatelessWidget {
  final List<AppNotification> notifications;
  final Future<void> Function(String notificationId) onMarkAsRead;

  const _SupplierNotificationPanel({
    required this.notifications,
    required this.onMarkAsRead,
  });

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CotahubTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CotahubTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: notifications.take(3).map((notification) {
          return InkWell(
            onTap: () => onMarkAsRead(notification.id),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    notification.isUnread
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_none_outlined,
                    size: 18,
                    color: notification.isUnread
                        ? CotahubTheme.blue
                        : CotahubTheme.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title,
                          style: TextStyle(
                            color: CotahubTheme.textPrimary,
                            fontWeight: notification.isUnread
                                ? FontWeight.w800
                                : FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          notification.body,
                          style: const TextStyle(
                            color: CotahubTheme.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SupplierTopBar extends StatelessWidget {
  final Future<void> Function() onLogout;
  final VoidCallback onProfile;
  final VoidCallback onSupport;

  const _SupplierTopBar({
    required this.onLogout,
    required this.onProfile,
    required this.onSupport,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: CotahubTheme.textPrimary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.storefront_rounded,
            color: CotahubTheme.background,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Projeto Ethan',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: CotahubTheme.textPrimary,
            ),
          ),
        ),
        IconButton(
          onPressed: onProfile,
          style: IconButton.styleFrom(
            backgroundColor: CotahubTheme.surfaceAlt,
            foregroundColor: CotahubTheme.textPrimary,
            side: const BorderSide(color: CotahubTheme.line),
          ),
          icon: const Icon(Icons.apartment_rounded),
        ),
        const SizedBox(width: 10),
        IconButton(
          onPressed: onSupport,
          style: IconButton.styleFrom(
            backgroundColor: CotahubTheme.surfaceAlt,
            foregroundColor: CotahubTheme.textPrimary,
            side: const BorderSide(color: CotahubTheme.line),
          ),
          icon: const Icon(Icons.support_agent_rounded),
        ),
        const SizedBox(width: 10),
        IconButton(
          onPressed: onLogout,
          style: IconButton.styleFrom(
            backgroundColor: CotahubTheme.surfaceAlt,
            foregroundColor: CotahubTheme.textPrimary,
            side: const BorderSide(color: CotahubTheme.line),
          ),
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
    );
  }
}

class _SupplierSummaryBand extends StatelessWidget {
  final int openCount;
  final int sentCount;
  final int acceptedCount;

  const _SupplierSummaryBand({
    required this.openCount,
    required this.sentCount,
    required this.acceptedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CotahubTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: CotahubTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'O pedido chega mais claro. Sua resposta fica mais precisa.',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1.05,
              color: CotahubTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Visual, contexto e especificacao mais bem organizados reduzem ambiguidade na hora de precificar.',
            style: TextStyle(color: CotahubTheme.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _DataChip(
                label: 'Abertas',
                value: '$openCount',
                color: CotahubTheme.blue,
              ),
              _DataChip(
                label: 'Enviadas',
                value: '$sentCount',
                color: CotahubTheme.green,
              ),
              _DataChip(
                label: 'Fechando compra',
                value: '$acceptedCount',
                color: CotahubTheme.accent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SupplierQuotationCard extends StatelessWidget {
  final Quotation quotation;
  final bool alreadyAnswered;
  final VoidCallback onSendProposal;

  const _SupplierQuotationCard({
    required this.quotation,
    required this.alreadyAnswered,
    required this.onSendProposal,
  });

  @override
  Widget build(BuildContext context) {
    final item = quotation.firstItem;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CotahubTheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: CotahubTheme.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ItemThumb(item: item, size: 88),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (alreadyAnswered)
                      const _MiniPill(
                        label: 'Proposta enviada',
                        color: CotahubTheme.green,
                      ),
                    _MiniPill(
                      label: quotation.itemCountLabel,
                      color: CotahubTheme.blue,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  quotation.summaryTitle,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: CotahubTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  quotation.summaryQuantity,
                  style: const TextStyle(color: CotahubTheme.textSecondary),
                ),
                if (item != null && item.brandModelLabel.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.brandModelLabel,
                    style: const TextStyle(
                      color: CotahubTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  quotation.notes.isEmpty
                      ? 'Sem observacoes adicionais.'
                      : quotation.notes,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: CotahubTheme.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                if (alreadyAnswered)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: CotahubTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text(
                        'Voce ja respondeu esta cotacao',
                        style: TextStyle(
                          color: CotahubTheme.textSecondary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onSendProposal,
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('Enviar proposta'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SentProposalCard extends StatelessWidget {
  final Proposal proposal;
  final InvoiceXmlRepository invoiceRepository;

  const _SentProposalCard({
    required this.proposal,
    required this.invoiceRepository,
  });

  @override
  Widget build(BuildContext context) {
    if (proposal.status != 'accepted') {
      return _BaseSentProposalCard(proposal: proposal);
    }

    return StreamBuilder<InvoiceXmlRecord?>(
      stream: invoiceRepository.getProposalInvoice(
        proposal.quotationId,
        proposal.id,
      ),
      builder: (context, snapshot) {
        final invoice = snapshot.data;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CotahubTheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: CotahubTheme.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 54,
                    width: 54,
                    decoration: BoxDecoration(
                      color: CotahubTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: CotahubTheme.line),
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      color: CotahubTheme.green,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          proposal.supplier,
                          style: const TextStyle(
                            color: CotahubTheme.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_formatPrice(proposal.price)} • ${proposal.deliveryDays} ${proposal.deliveryDays == 1 ? 'dia' : 'dias'}',
                          style: const TextStyle(
                            color: CotahubTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  const _MiniPill(
                    label: 'Oferta aceita',
                    color: CotahubTheme.green,
                  ),
                  if (invoice != null)
                    _MiniPill(
                      label: invoice.isVerified
                          ? 'XML validado'
                          : invoice.isRejected
                          ? 'XML rejeitado'
                          : 'XML enviado',
                      color: invoice.isVerified
                          ? CotahubTheme.green
                          : invoice.isRejected
                          ? CotahubTheme.accent
                          : CotahubTheme.blue,
                    )
                  else
                    const _MiniPill(
                      label: 'XML pendente',
                      color: CotahubTheme.blue,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                invoice == null
                    ? 'Para concluir a compra dentro do app, envie o XML da nota fiscal desta proposta.'
                    : invoice.isVerified
                    ? 'O comprador validou o XML e o fechamento operacional foi concluido.'
                    : invoice.isRejected
                    ? 'O comprador marcou divergencia no XML. Reenvie uma versao correta.'
                    : 'XML recebido. O comprador ainda precisa revisar CNPJ e valor.',
                style: const TextStyle(
                  color: CotahubTheme.textSecondary,
                  height: 1.45,
                ),
              ),
              if (invoice != null) ...[
                const SizedBox(height: 10),
                Text(
                  invoice.fileName,
                  style: const TextStyle(
                    color: CotahubTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _uploadInvoiceXml(context),
                  icon: Icon(
                    invoice == null || invoice.isRejected
                        ? Icons.upload_file_rounded
                        : Icons.restart_alt_rounded,
                  ),
                  label: Text(
                    invoice == null
                        ? 'Enviar XML da nota fiscal'
                        : invoice.isRejected
                        ? 'Reenviar XML corrigido'
                        : 'Atualizar XML enviado',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _uploadInvoiceXml(BuildContext context) async {
    try {
      final uploaded = await invoiceRepository.uploadInvoiceXml(
        quotationId: proposal.quotationId,
        proposalId: proposal.id,
        supplierName: proposal.supplier,
      );

      if (!context.mounted || !uploaded) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('XML enviado para revisao do comprador.')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao enviar XML: $error')));
    }
  }

  static String _formatPrice(double value) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }
}

class _BaseSentProposalCard extends StatelessWidget {
  final Proposal proposal;

  const _BaseSentProposalCard({required this.proposal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CotahubTheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: CotahubTheme.line),
      ),
      child: Row(
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: CotahubTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: CotahubTheme.line),
            ),
            child: const Icon(
              Icons.request_quote_rounded,
              color: CotahubTheme.accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  proposal.supplier,
                  style: const TextStyle(
                    color: CotahubTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_SentProposalCard._formatPrice(proposal.price)} • ${proposal.deliveryDays} ${proposal.deliveryDays == 1 ? 'dia' : 'dias'}',
                  style: const TextStyle(color: CotahubTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                _MiniPill(
                  label: proposal.status == 'sent'
                      ? 'Enviada'
                      : proposal.status == 'rejected'
                      ? 'Recusada'
                      : proposal.status,
                  color: proposal.status == 'rejected'
                      ? CotahubTheme.textSecondary
                      : CotahubTheme.blue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateSupplierProposalSheet extends StatefulWidget {
  final Quotation quotation;
  final ProposalRepository repository;

  const _CreateSupplierProposalSheet({
    required this.quotation,
    required this.repository,
  });

  @override
  State<_CreateSupplierProposalSheet> createState() =>
      _CreateSupplierProposalSheetState();
}

class _CreateSupplierProposalSheetState
    extends State<_CreateSupplierProposalSheet> {
  final priceController = TextEditingController();
  final deliveryController = TextEditingController();

  bool isSaving = false;

  @override
  void dispose() {
    priceController.dispose();
    deliveryController.dispose();
    super.dispose();
  }

  Future<void> submitProposal() async {
    final priceText = priceController.text.trim().replaceAll(',', '.');
    final deliveryText = deliveryController.text.trim();

    final price = double.tryParse(priceText);
    final deliveryDays = int.tryParse(deliveryText);

    if (price == null || deliveryDays == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha preco e prazo corretamente.')),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      await widget.repository.createProposal(
        quotationId: widget.quotation.id,
        price: price,
        deliveryDays: deliveryDays,
      );

      if (!mounted) return;

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proposta enviada com sucesso.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar proposta: $error')),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: CotahubTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: CotahubTheme.line,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Enviar proposta',
                style: TextStyle(
                  color: CotahubTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.quotation.summaryTitle,
                style: const TextStyle(
                  color: CotahubTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Preco',
                  hintText: 'Ex: 110,00',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: deliveryController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Prazo em dias',
                  hintText: 'Ex: 3',
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSaving ? null : submitProposal,
                  child: isSaving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: CotahubTheme.background,
                          ),
                        )
                      : const Text('Enviar proposta'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemThumb extends StatelessWidget {
  final dynamic item;
  final double size;

  const _ItemThumb({required this.item, required this.size});

  @override
  Widget build(BuildContext context) {
    if (item != null && item.hasImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: size,
          height: size,
          child: Image.network(
            item.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallback(),
          ),
        ),
      );
    }

    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: CotahubTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CotahubTheme.line),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.inventory_2_rounded, color: CotahubTheme.accent),
    );
  }
}

class _DataChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DataChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final String title;
  final String message;

  const _EmptyPanel({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CotahubTheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: CotahubTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: CotahubTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              color: CotahubTheme.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
