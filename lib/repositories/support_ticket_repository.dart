import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:ethan/models/support_ticket.dart';
import 'package:ethan/repositories/user_repository.dart';

class SupportTicketRepository {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseFunctions functions = FirebaseFunctions.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  final UserRepository userRepository = UserRepository();

  void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  static const List<String> categories = <String>[
    'Cadastro',
    'Login',
    'CNPJ',
    'Cotacao',
    'Proposta',
    'XML fiscal',
    'Outro',
  ];

  Future<void> createTicket({
    required String category,
    required String message,
  }) async {
    final user = auth.currentUser;
    if (user == null) {
      throw Exception('Usuario nao autenticado.');
    }

    final normalizedCategory = categories.contains(category)
        ? category
        : 'Outro';
    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) {
      throw Exception('Descreva o problema para abrir o chamado.');
    }

    try {
      final callable = functions.httpsCallable('createSupportTicket');
      final response = await callable.call({
        'category': normalizedCategory,
        'message': trimmedMessage,
      });
      final data = Map<String, dynamic>.from(response.data as Map);
      _log(
        '[createSupportTicket] source=callable category=$normalizedCategory ticketId=${(data['ticketId'] ?? '').toString()} status=${(data['status'] ?? '').toString()}',
      );
      return;
    } on FirebaseFunctionsException catch (error) {
      if (error.code != 'not-found' && error.code != 'unavailable') {
        rethrow;
      }
      _log(
        '[createSupportTicket] callable_fallback code=${error.code} message=${error.message}',
      );
    }

    final profile = await userRepository.getCurrentUserProfile();
    final now = Timestamp.now();
    final docRef = firestore.collection('support_tickets').doc();

    await docRef.set({
      'userId': user.uid,
      'userEmail': user.email ?? '',
      'companyName': profile?.companyName ?? '',
      'category': normalizedCategory,
      'message': trimmedMessage,
      'status': 'open',
      'createdAt': now,
      'updatedAt': now,
    });

    _log(
      '[createSupportTicket] source=firestore_fallback category=$normalizedCategory ticketId=${docRef.id} status=open',
    );
  }

  Stream<List<SupportTicket>> currentUserTickets() {
    final user = auth.currentUser;
    if (user == null) {
      return Stream.value(const <SupportTicket>[]);
    }

    return firestore
        .collection('support_tickets')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SupportTicket.fromFirestore(doc))
              .toList(),
        );
  }
}
