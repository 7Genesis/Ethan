import 'package:cloud_firestore/cloud_firestore.dart';

class Proposal {
  final String id;
  final String quotationId;
  final String supplierId;
  final String supplier;
  final double price;
  final int deliveryDays;
  final DateTime createdAt;
  final String status;

  Proposal({
    required this.id,
    required this.quotationId,
    required this.supplierId,
    required this.supplier,
    required this.price,
    required this.deliveryDays,
    required this.createdAt,
    required this.status,
  });

  factory Proposal.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawPrice = data['price'];
    final rawDeliveryDays = data['deliveryDays'];

    return Proposal(
      id: doc.id,
      quotationId: data['quotationId'] ?? '',
      supplierId: data['supplierId'] ?? data['userId'] ?? '',
      supplier: data['supplier'] ?? '',
      price: rawPrice is num ? rawPrice.toDouble() : 0,
      deliveryDays: rawDeliveryDays is num ? rawDeliveryDays.toInt() : 0,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      status: data['status'] ?? 'sent',
    );
  }
}
