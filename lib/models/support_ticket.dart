import 'package:cloud_firestore/cloud_firestore.dart';

class SupportTicket {
  final String id;
  final String userId;
  final String userEmail;
  final String companyName;
  final String category;
  final String message;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SupportTicket({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.companyName,
    required this.category,
    required this.message,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory SupportTicket.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return SupportTicket(
      id: doc.id,
      userId: (data['userId'] ?? '').toString(),
      userEmail: (data['userEmail'] ?? '').toString(),
      companyName: (data['companyName'] ?? '').toString(),
      category: (data['category'] ?? 'Outro').toString(),
      message: (data['message'] ?? '').toString(),
      status: (data['status'] ?? 'open').toString(),
      createdAt: _readDate(data['createdAt']),
      updatedAt: _readDate(data['updatedAt']),
    );
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
