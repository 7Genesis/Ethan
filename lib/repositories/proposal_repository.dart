import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:projeto_ethan/models/proposal.dart';

class ProposalRepository {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  Future<void> createProposal({
    required String quotationId,
    required double price,
    required int deliveryDays,
  }) async {
    final user = auth.currentUser;

    if (user == null) {
      throw Exception('Usuário não autenticado.');
    }

    final userDoc = await firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};
    final companyName = userData['companyName'] ?? '';
    final profileCompleted = userData['profileCompleted'] == true;

    if (!profileCompleted) {
      throw Exception('Conclua o cadastro completo antes de enviar proposta.');
    }

    if (companyName.toString().trim().isEmpty) {
      throw Exception('Nome da empresa não encontrado no perfil.');
    }

    final existingProposal = await firestore
        .collection('proposals')
        .where('quotationId', isEqualTo: quotationId)
        .where('supplierId', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (existingProposal.docs.isNotEmpty) {
      throw Exception('Você já enviou uma proposta para esta cotação.');
    }

    await firestore.collection('proposals').add({
      'quotationId': quotationId,
      'supplierId': user.uid,
      'supplier': companyName,
      'price': price,
      'deliveryDays': deliveryDays,
      'createdAt': Timestamp.now(),
      'status': 'sent',
    });
  }

  Stream<List<Proposal>> getProposalsByQuotation(String quotationId) {
    return firestore
        .collection('proposals')
        .where('quotationId', isEqualTo: quotationId)
        .snapshots()
        .map((snapshot) {
          final proposals = snapshot.docs.map(Proposal.fromFirestore).toList();
          proposals.sort((a, b) => a.price.compareTo(b.price));
          return proposals;
        });
  }

  Stream<List<Proposal>> getMySentProposals() {
    final user = auth.currentUser;

    if (user == null) {
      return Stream.value([]);
    }

    return firestore
        .collection('proposals')
        .where('supplierId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          final proposals = snapshot.docs.map(Proposal.fromFirestore).toList();
          proposals.sort((a, b) {
            final statusOrder = _statusRank(
              a.status,
            ).compareTo(_statusRank(b.status));

            if (statusOrder != 0) {
              return statusOrder;
            }

            return b.createdAt.compareTo(a.createdAt);
          });
          return proposals;
        });
  }

  int _statusRank(String status) {
    switch (status) {
      case 'accepted':
        return 0;
      case 'sent':
        return 1;
      case 'rejected':
        return 2;
      default:
        return 3;
    }
  }
}
