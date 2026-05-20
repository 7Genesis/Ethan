import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cotahub/models/quotation.dart';

class QuotationRepository {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Future<void> createQuotation(Quotation quotation) async {
    await firestore.collection('quotations').add({
      'product': quotation.product,
      'quantity': quotation.quantity,
      'notes': quotation.notes,
      'createdAt': quotation.createdAt.toIso8601String(),
    });
  }

  Stream<List<Quotation>> getQuotations() {
    return firestore
        .collection('quotations')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();

        return Quotation(
          product: data['product'] ?? '',
          quantity: data['quantity'] ?? '',
          notes: data['notes'] ?? '',
          createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
        );
      }).toList();
    });
  }
}