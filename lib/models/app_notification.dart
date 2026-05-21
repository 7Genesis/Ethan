import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;
  final Map<String, dynamic> context;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.readAt,
    required this.context,
  });

  bool get isUnread => readAt == null;

  factory AppNotification.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return AppNotification(
      id: doc.id,
      type: (data['type'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      body: (data['body'] ?? '').toString(),
      createdAt: _asDate(data['createdAt']) ?? DateTime.now(),
      readAt: _asDate(data['readAt']),
      context: (data['context'] is Map)
          ? Map<String, dynamic>.from(data['context'] as Map)
          : const {},
    );
  }

  static DateTime? _asDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
