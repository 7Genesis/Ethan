import 'package:cloud_firestore/cloud_firestore.dart';

class InvoiceXmlRecord {
  final String id;
  final String quotationId;
  final String proposalId;
  final String supplierId;
  final String supplierName;
  final String fileName;
  final String storagePath;
  final String downloadUrl;
  final String invoiceKey;
  final String issuerName;
  final String issuerTaxId;
  final String recipientName;
  final String recipientTaxId;
  final String buyerCompanyName;
  final String buyerCompanyTaxId;
  final String recipientMatchStatus;
  final double totalAmount;
  final DateTime? issueDate;
  final DateTime uploadedAt;
  final String reviewStatus;
  final String reviewNote;
  final DateTime? reviewedAt;
  final String consistencyStatus;
  final List<String> consistencyIssues;

  const InvoiceXmlRecord({
    required this.id,
    required this.quotationId,
    required this.proposalId,
    required this.supplierId,
    required this.supplierName,
    required this.fileName,
    required this.storagePath,
    required this.downloadUrl,
    required this.invoiceKey,
    required this.issuerName,
    required this.issuerTaxId,
    required this.recipientName,
    required this.recipientTaxId,
    required this.buyerCompanyName,
    required this.buyerCompanyTaxId,
    required this.recipientMatchStatus,
    required this.totalAmount,
    required this.issueDate,
    required this.uploadedAt,
    required this.reviewStatus,
    required this.reviewNote,
    required this.reviewedAt,
    required this.consistencyStatus,
    required this.consistencyIssues,
  });

  factory InvoiceXmlRecord.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    return InvoiceXmlRecord(
      id: doc.id,
      quotationId: (data['quotationId'] ?? '').toString(),
      proposalId: (data['proposalId'] ?? '').toString(),
      supplierId: (data['supplierId'] ?? '').toString(),
      supplierName: (data['supplierName'] ?? '').toString(),
      fileName: (data['fileName'] ?? '').toString(),
      storagePath: (data['storagePath'] ?? '').toString(),
      downloadUrl: (data['downloadUrl'] ?? '').toString(),
      invoiceKey: (data['invoiceKey'] ?? '').toString(),
      issuerName: (data['issuerName'] ?? '').toString(),
      issuerTaxId: (data['issuerTaxId'] ?? '').toString(),
      recipientName: (data['recipientName'] ?? '').toString(),
      recipientTaxId: (data['recipientTaxId'] ?? '').toString(),
      buyerCompanyName: (data['buyerCompanyName'] ?? '').toString(),
      buyerCompanyTaxId: (data['buyerCompanyTaxId'] ?? '').toString(),
      recipientMatchStatus: (data['recipientMatchStatus'] ?? 'unknown')
          .toString(),
      totalAmount: _toDouble(data['totalAmount']),
      issueDate: _toDate(data['issueDate']),
      uploadedAt: _toDate(data['uploadedAt']) ?? DateTime.now(),
      reviewStatus: (data['reviewStatus'] ?? 'pending_review').toString(),
      reviewNote: (data['reviewNote'] ?? '').toString(),
      reviewedAt: _toDate(data['reviewedAt']),
      consistencyStatus: (data['consistencyStatus'] ?? 'unknown').toString(),
      consistencyIssues:
          (data['consistencyIssues'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .where((item) => item.isNotEmpty)
              .toList(),
    );
  }

  bool get isPending => reviewStatus == 'pending_review';

  bool get isVerified => reviewStatus == 'verified';

  bool get isRejected => reviewStatus == 'rejected';

  bool get recipientMatchesBuyer => recipientMatchStatus == 'matched';

  bool get recipientMismatch => recipientMatchStatus == 'mismatch';

  bool get consistencyPass => consistencyStatus == 'pass';

  bool get consistencyWarning => consistencyStatus == 'warning';

  bool get consistencyFail => consistencyStatus == 'fail';

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }
}
