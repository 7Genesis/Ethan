import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cotahub/models/quotation.dart';
import 'package:cotahub/models/quotation_item.dart';

class QuotationRepository {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  Future<void> createQuotation(Quotation quotation) async {
    final user = auth.currentUser;

    if (user == null) {
      throw Exception('Usuário não autenticado.');
    }

    await firestore.collection('quotations').add({
      'product': quotation.product,
      'quantity': quotation.quantity,
      'notes': quotation.notes,
      'createdAt': quotation.createdAt.toIso8601String(),
      'buyerId': user.uid,
      'status': 'open',
      'workflowStage': 'collecting_proposals',
      'selectedProposalId': '',
      'selectedSupplierId': '',
      'items': quotation.items.map((item) => item.toMap()).toList(),
    });
  }

  Stream<List<Quotation>> getMyQuotations() {
    final user = auth.currentUser;

    if (user == null) {
      return Stream.value([]);
    }

    return firestore
        .collection('quotations')
        .where('buyerId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          final quotations = snapshot.docs.map<Quotation>((doc) {
            return _quotationFromData(id: doc.id, data: doc.data());
          }).toList();

          quotations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return quotations;
        });
  }

  Stream<List<Quotation>> getOpenQuotations() {
    return firestore
        .collection('quotations')
        .where('status', isEqualTo: 'open')
        .snapshots()
        .map((snapshot) {
          final quotations = snapshot.docs.map<Quotation>((doc) {
            return _quotationFromData(id: doc.id, data: doc.data());
          }).toList();

          quotations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return quotations;
        });
  }

  Future<void> selectProposal({
    required String quotationId,
    required String proposalId,
    required String supplierId,
  }) async {
    final quotationRef = firestore.collection('quotations').doc(quotationId);

    final proposalsSnapshot = await firestore
        .collection('proposals')
        .where('quotationId', isEqualTo: quotationId)
        .get();

    final batch = firestore.batch();

    batch.update(quotationRef, {
      'status': 'closed',
      'workflowStage': 'awaiting_invoice_xml',
      'selectedProposalId': proposalId,
      'selectedSupplierId': supplierId,
      'closedAt': Timestamp.now(),
    });

    for (final proposalDoc in proposalsSnapshot.docs) {
      final status = proposalDoc.id == proposalId ? 'accepted' : 'rejected';
      batch.update(proposalDoc.reference, {'status': status});
    }

    await batch.commit();
  }

  Quotation _quotationFromData({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return Quotation(
      id: id,
      product: data['product'] ?? '',
      quantity: data['quantity'] ?? '',
      notes: data['notes'] ?? '',
      createdAt: _parseCreatedAt(data['createdAt']),
      status: data['status'] ?? 'open',
      workflowStage: data['workflowStage'] ?? 'collecting_proposals',
      selectedProposalId: data['selectedProposalId'] ?? '',
      selectedSupplierId: data['selectedSupplierId'] ?? '',
      items: _itemsFromData(data),
    );
  }

  DateTime _parseCreatedAt(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }

    return DateTime.now();
  }

  List<QuotationItem> _itemsFromData(Map<String, dynamic> data) {
    final rawItems = data['items'];

    if (rawItems is List) {
      final items = rawItems
          .whereType<Map>()
          .map((item) => QuotationItem.fromMap(Map<String, dynamic>.from(item)))
          .where((item) => item.name.isNotEmpty || item.quantity.isNotEmpty)
          .toList();

      if (items.isNotEmpty) {
        return items;
      }
    }

    return [
      QuotationItem(
        id: 'legacy-item',
        name: (data['product'] ?? '').toString(),
        quantity: (data['quantity'] ?? '').toString(),
        brand: '',
        model: '',
        notes: '',
        imageUrl: '',
      ),
    ];
  }
}
