import 'package:projeto_ethan/models/quotation_item.dart';

class Quotation {
  final String id;
  final String product;
  final String quantity;
  final String notes;
  final DateTime createdAt;
  final String status;
  final String workflowStage;
  final String selectedProposalId;
  final String selectedSupplierId;
  final List<QuotationItem> items;

  Quotation({
    required this.id,
    required this.product,
    required this.quantity,
    required this.notes,
    required this.createdAt,
    required this.status,
    required this.workflowStage,
    required this.selectedProposalId,
    required this.selectedSupplierId,
    required this.items,
  });

  bool get isClosed => status == 'closed';

  bool get awaitingInvoice => workflowStage == 'awaiting_invoice_xml';

  bool get invoiceUnderReview => workflowStage == 'invoice_under_review';

  bool get purchaseCompleted => workflowStage == 'purchase_completed';

  bool get hasMultipleItems => items.length > 1;

  int get itemCount => items.length;

  QuotationItem? get firstItem => items.isEmpty ? null : items.first;

  String get summaryTitle {
    if (items.isEmpty) {
      return product;
    }

    if (items.length == 1) {
      return items.first.name;
    }

    return '${items.length} itens';
  }

  String get summaryQuantity {
    if (items.isEmpty) {
      return quantity;
    }

    if (items.length == 1) {
      return items.first.quantity;
    }

    return '${items.length} itens no lote';
  }

  String get itemCountLabel => itemCount == 1 ? '1 item' : '$itemCount itens';

  String get workflowStageLabel {
    switch (workflowStage) {
      case 'awaiting_invoice_xml':
        return 'Aguardando XML';
      case 'invoice_under_review':
        return 'XML em revisao';
      case 'invoice_rejected':
        return 'XML rejeitado';
      case 'purchase_completed':
        return 'Compra validada';
      default:
        return isClosed ? 'Cotacao fechada' : 'Coletando ofertas';
    }
  }
}
