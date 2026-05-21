import 'package:cotahub/models/invoice_xml_record.dart';
import 'package:cotahub/models/proposal.dart';
import 'package:cotahub/models/quotation.dart';
import 'package:cotahub/models/quotation_item.dart';
import 'package:cotahub/features/support/widgets/ai_assistant_fab.dart';
import 'package:cotahub/repositories/invoice_xml_repository.dart';
import 'package:cotahub/repositories/proposal_repository.dart';
import 'package:cotahub/repositories/quotation_repository.dart';
import 'package:cotahub/theme/cotahub_theme.dart';
import 'package:flutter/material.dart';

class QuotationDetailsPage extends StatelessWidget {
  final Quotation quotation;

  QuotationDetailsPage({super.key, required this.quotation});

  final ProposalRepository proposalRepository = ProposalRepository();
  final QuotationRepository quotationRepository = QuotationRepository();
  final InvoiceXmlRepository invoiceRepository = InvoiceXmlRepository();

  Future<void> selectProposal({
    required BuildContext context,
    required Proposal proposal,
  }) async {
    try {
      await quotationRepository.selectProposal(
        quotationId: quotation.id,
        proposalId: proposal.id,
        supplierId: proposal.supplierId,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proposta escolhida. Cotacao fechada.')),
      );

      Navigator.pop(context);
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao escolher proposta: $error')),
      );
    }
  }

  Future<void> reviewInvoice({
    required BuildContext context,
    required String proposalId,
    required String reviewStatus,
    required String reviewNote,
  }) async {
    try {
      await invoiceRepository.reviewInvoiceXml(
        quotationId: quotation.id,
        proposalId: proposalId,
        reviewStatus: reviewStatus,
        reviewNote: reviewNote,
      );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reviewStatus == 'verified'
                ? 'XML validado. Compra marcada como concluida.'
                : 'XML marcado com divergencia. O fornecedor precisa reenviar.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao revisar XML: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final headerTitle = quotation.hasMultipleItems
        ? '${quotation.itemCount} itens na cotacao'
        : (quotation.firstItem?.name ?? quotation.product);

    return Scaffold(
      backgroundColor: CotahubTheme.background,
      floatingActionButton: const AiAssistantFab(),
      appBar: AppBar(title: const Text('Ofertas recebidas')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        children: [
          _HeaderBand(quotation: quotation, title: headerTitle),
          const SizedBox(height: 24),
          const _SectionHeader(
            title: 'Itens do pedido',
            subtitle:
                'Tudo o que o fornecedor precisa enxergar antes de ofertar.',
          ),
          const SizedBox(height: 14),
          ...quotation.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _QuotationItemCard(item: item),
            ),
          ),
          const SizedBox(height: 24),
          const _SectionHeader(
            title: 'Ofertas',
            subtitle: 'Preco, prazo e status da decisao na mesma vista.',
          ),
          const SizedBox(height: 14),
          StreamBuilder<List<Proposal>>(
            stream: proposalRepository.getProposalsByQuotation(quotation.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return const _EmptyProposalState(
                  title: 'Erro ao carregar ofertas',
                  message:
                      'Verifique a conexao, regras do Firestore ou o indice da consulta.',
                );
              }

              final proposals = snapshot.data ?? [];

              if (proposals.isEmpty) {
                return const _EmptyProposalState(
                  title: 'Nenhuma oferta ainda',
                  message:
                      'Quando os fornecedores responderem, as propostas aparecem aqui em tempo real.',
                );
              }

              return Column(
                children: [
                  _OfferSummary(proposals: proposals, quotation: quotation),
                  const SizedBox(height: 14),
                  ...proposals.asMap().entries.map((entry) {
                    final index = entry.key;
                    final proposal = entry.value;
                    final isSelected =
                        quotation.selectedProposalId == proposal.id ||
                        proposal.status == 'accepted';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _OfferCard(
                        proposal: proposal,
                        highlight: _highlightFor(proposal),
                        isBest: index == 0 && proposal.status == 'sent',
                        isSelected: isSelected,
                        isClosed: quotation.isClosed,
                        onSelect: () {
                          selectProposal(context: context, proposal: proposal);
                        },
                      ),
                    );
                  }),
                ],
              );
            },
          ),
          if (quotation.isClosed) ...[
            const SizedBox(height: 24),
            const _SectionHeader(
              title: 'Fechamento fiscal',
              subtitle:
                  'O fornecedor envia o XML da nota aqui e o comprador confere CNPJ, emitente e valor total sem sair do fluxo.',
            ),
            const SizedBox(height: 14),
            StreamBuilder<List<InvoiceXmlRecord>>(
              stream: invoiceRepository.getQuotationInvoices(quotation.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return const _EmptyProposalState(
                    title: 'Erro ao carregar XML',
                    message:
                        'Verifique as regras do Storage e a subcolecao de documentos fiscais.',
                  );
                }

                final invoices = snapshot.data ?? [];

                if (invoices.isEmpty) {
                  return _EmptyProposalState(
                    title: 'Nenhum XML enviado ainda',
                    message: quotation.awaitingInvoice
                        ? 'A proposta ja foi escolhida. Agora o fornecedor precisa subir o XML da nota fiscal.'
                        : 'O fechamento fiscal ainda nao entrou na etapa de revisao.',
                  );
                }

                return Column(
                  children: invoices
                      .map(
                        (invoice) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _InvoiceXmlCard(
                            invoice: invoice,
                            onApprove: invoice.isPending
                                ? () {
                                    reviewInvoice(
                                      context: context,
                                      proposalId: invoice.proposalId,
                                      reviewStatus: 'verified',
                                      reviewNote:
                                          'XML conferido pelo comprador.',
                                    );
                                  }
                                : null,
                            onReject: invoice.isPending
                                ? () {
                                    reviewInvoice(
                                      context: context,
                                      proposalId: invoice.proposalId,
                                      reviewStatus: 'rejected',
                                      reviewNote:
                                          'Divergencia identificada na conferencia.',
                                    );
                                  }
                                : null,
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  static String _highlightFor(Proposal proposal) {
    if (proposal.status == 'accepted') {
      return 'Oferta escolhida';
    }

    if (proposal.status == 'rejected') {
      return 'Oferta recusada';
    }

    if (proposal.deliveryDays <= 1) {
      return 'Entrega rapida';
    }

    return 'Oferta recebida';
  }

  static String formatPrice(double value) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }
}

class _HeaderBand extends StatelessWidget {
  final Quotation quotation;
  final String title;

  const _HeaderBand({required this.quotation, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CotahubTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeaderPill(
                label: quotation.isClosed ? 'Concluida' : 'Aberta',
                color: quotation.isClosed
                    ? CotahubTheme.green
                    : CotahubTheme.blue,
              ),
              _HeaderPill(
                label: quotation.itemCountLabel,
                color: CotahubTheme.accent,
              ),
              if (quotation.workflowStage.isNotEmpty)
                _HeaderPill(
                  label: quotation.workflowStageLabel,
                  color: quotation.purchaseCompleted
                      ? CotahubTheme.green
                      : quotation.invoiceUnderReview
                      ? CotahubTheme.accent
                      : quotation.awaitingInvoice
                      ? CotahubTheme.blue
                      : CotahubTheme.primary,
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 1.03,
              color: CotahubTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            quotation.notes.isNotEmpty
                ? quotation.notes
                : 'Pedido montado com contexto por item para facilitar uma resposta melhor.',
            style: const TextStyle(
              color: CotahubTheme.textSecondary,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          if (quotation.items.isNotEmpty) ...[
            const SizedBox(height: 18),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: quotation.items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return _MiniItemTile(item: quotation.items[index]);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniItemTile extends StatelessWidget {
  final QuotationItem item;

  const _MiniItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CotahubTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CotahubTheme.line),
      ),
      child: Row(
        children: [
          _ItemThumbnail(item: item, size: 54),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: CotahubTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.quantity,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: CotahubTheme.textSecondary,
                    fontSize: 13,
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

class _QuotationItemCard extends StatelessWidget {
  final QuotationItem item;

  const _QuotationItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CotahubTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CotahubTheme.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ItemThumbnail(item: item, size: 92),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: CotahubTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.quantity,
                  style: const TextStyle(color: CotahubTheme.textSecondary),
                ),
                if (item.brandModelLabel.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _InlineTag(
                    icon: Icons.sell_outlined,
                    label: item.brandModelLabel,
                  ),
                ],
                if (item.notes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    item.notes,
                    style: const TextStyle(
                      color: CotahubTheme.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemThumbnail extends StatelessWidget {
  final QuotationItem item;
  final double size;

  const _ItemThumbnail({required this.item, required this.size});

  @override
  Widget build(BuildContext context) {
    if (item.hasImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CotahubTheme.line),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.inventory_2_rounded, color: CotahubTheme.accent),
    );
  }
}

class _OfferSummary extends StatelessWidget {
  final List<Proposal> proposals;
  final Quotation quotation;

  const _OfferSummary({required this.proposals, required this.quotation});

  @override
  Widget build(BuildContext context) {
    final lowestPrice = proposals.first.price;
    final fastestDelivery = proposals
        .map((proposal) => proposal.deliveryDays)
        .reduce((a, b) => a < b ? a : b);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CotahubTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CotahubTheme.line),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _HeaderPill(
            label:
                '${proposals.length} ${proposals.length == 1 ? 'oferta' : 'ofertas'}',
            color: CotahubTheme.blue,
          ),
          _HeaderPill(
            label:
                'Menor preco ${QuotationDetailsPage.formatPrice(lowestPrice)}',
            color: CotahubTheme.accent,
          ),
          _HeaderPill(
            label:
                'Entrega mais rapida em $fastestDelivery ${fastestDelivery == 1 ? 'dia' : 'dias'}',
            color: CotahubTheme.green,
          ),
          _HeaderPill(
            label: quotation.workflowStageLabel,
            color: quotation.purchaseCompleted
                ? CotahubTheme.green
                : quotation.invoiceUnderReview
                ? CotahubTheme.accent
                : quotation.awaitingInvoice
                ? CotahubTheme.blue
                : CotahubTheme.primary,
          ),
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  final Proposal proposal;
  final String highlight;
  final bool isBest;
  final bool isSelected;
  final bool isClosed;
  final VoidCallback onSelect;

  const _OfferCard({
    required this.proposal,
    required this.highlight,
    required this.isBest,
    required this.isSelected,
    required this.isClosed,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isRejected = proposal.status == 'rejected';
    final color = isSelected
        ? CotahubTheme.green
        : isRejected
        ? CotahubTheme.textSecondary
        : isBest
        ? CotahubTheme.accent
        : CotahubTheme.blue;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CotahubTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CotahubTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (isSelected)
                const _HeaderPill(label: 'Escolhida', color: CotahubTheme.green)
              else if (isRejected)
                const _HeaderPill(
                  label: 'Recusada',
                  color: CotahubTheme.textSecondary,
                )
              else if (isBest)
                const _HeaderPill(
                  label: 'Menor preco',
                  color: CotahubTheme.accent,
                ),
              _HeaderPill(label: highlight, color: color),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      proposal.supplier,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: CotahubTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      QuotationDetailsPage.formatPrice(proposal.price),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: CotahubTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${proposal.deliveryDays} ${proposal.deliveryDays == 1 ? 'dia' : 'dias'}',
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.local_shipping_outlined,
                size: 18,
                color: CotahubTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Entrega em ${proposal.deliveryDays} ${proposal.deliveryDays == 1 ? 'dia' : 'dias'}',
                style: const TextStyle(color: CotahubTheme.textSecondary),
              ),
            ],
          ),
          if (!isClosed) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onSelect,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Escolher oferta'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InvoiceXmlCard extends StatelessWidget {
  final InvoiceXmlRecord invoice;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _InvoiceXmlCard({
    required this.invoice,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CotahubTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CotahubTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeaderPill(
                label: invoice.isVerified
                    ? 'XML validado'
                    : invoice.isRejected
                    ? 'XML rejeitado'
                    : 'Aguardando revisao',
                color: invoice.isVerified
                    ? CotahubTheme.green
                    : invoice.isRejected
                    ? CotahubTheme.accent
                    : CotahubTheme.blue,
              ),
              _HeaderPill(
                label: invoice.recipientMatchesBuyer
                    ? 'CNPJ confere'
                    : invoice.recipientMismatch
                    ? 'CNPJ divergente'
                    : 'CNPJ sem base',
                color: invoice.recipientMatchesBuyer
                    ? CotahubTheme.green
                    : invoice.recipientMismatch
                    ? CotahubTheme.accent
                    : CotahubTheme.textSecondary,
              ),
              _HeaderPill(
                label: invoice.consistencyPass
                    ? 'Consistência OK'
                    : invoice.consistencyFail
                    ? 'Consistência crítica'
                    : invoice.consistencyWarning
                    ? 'Consistência com alerta'
                    : 'Consistência não avaliada',
                color: invoice.consistencyPass
                    ? CotahubTheme.green
                    : invoice.consistencyFail
                    ? CotahubTheme.accent
                    : invoice.consistencyWarning
                    ? CotahubTheme.blue
                    : CotahubTheme.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            invoice.supplierName,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: CotahubTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            invoice.fileName,
            style: const TextStyle(
              color: CotahubTheme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 18,
            runSpacing: 12,
            children: [
              _InvoiceFact(
                label: 'Emitente',
                value: invoice.issuerName.isEmpty
                    ? '-'
                    : '${invoice.issuerName}\n${invoice.issuerTaxId}',
              ),
              _InvoiceFact(
                label: 'Destinatario',
                value: invoice.recipientName.isEmpty
                    ? '-'
                    : '${invoice.recipientName}\n${invoice.recipientTaxId}',
              ),
              _InvoiceFact(
                label: 'Total',
                value: QuotationDetailsPage.formatPrice(invoice.totalAmount),
              ),
              _InvoiceFact(
                label: 'Emissao',
                value: invoice.issueDate == null
                    ? '-'
                    : _formatDate(invoice.issueDate!),
              ),
            ],
          ),
          if (invoice.invoiceKey.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CotahubTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Chave de acesso: ${invoice.invoiceKey}',
                style: const TextStyle(
                  color: CotahubTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          if (invoice.reviewNote.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              invoice.reviewNote,
              style: const TextStyle(
                color: CotahubTheme.textSecondary,
                height: 1.45,
              ),
            ),
          ],
          if (invoice.consistencyIssues.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CotahubTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: CotahubTheme.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: invoice.consistencyIssues
                    .map(
                      (issue) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '• $issue',
                          style: const TextStyle(
                            color: CotahubTheme.textSecondary,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          if (onApprove != null || onReject != null) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.verified_rounded),
                    label: const Text('Validar XML'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.report_problem_outlined),
                    label: const Text('Marcar divergencia'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day/$month/$year';
  }
}

class _InvoiceFact extends StatelessWidget {
  final String label;
  final String value;

  const _InvoiceFact({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: CotahubTheme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: CotahubTheme.textPrimary,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  final String label;
  final Color color;

  const _HeaderPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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

class _InlineTag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InlineTag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: CotahubTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: CotahubTheme.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: CotahubTheme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: CotahubTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            color: CotahubTheme.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _EmptyProposalState extends StatelessWidget {
  final String title;
  final String message;

  const _EmptyProposalState({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CotahubTheme.surface,
        borderRadius: BorderRadius.circular(10),
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
