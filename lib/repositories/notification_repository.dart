import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:cotahub/models/app_notification.dart';

class NotificationRepository {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  Stream<List<AppNotification>> currentUserNotifications({int limit = 20}) {
    final user = auth.currentUser;
    if (user == null) {
      return Stream.value(const []);
    }

    return firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AppNotification.fromFirestore(doc))
              .toList(),
        );
  }

  Future<void> markAsRead(String notificationId) async {
    final user = auth.currentUser;
    if (user == null) {
      throw Exception('Usuário não autenticado.');
    }

    await firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .doc(notificationId)
        .set({'readAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }
}
