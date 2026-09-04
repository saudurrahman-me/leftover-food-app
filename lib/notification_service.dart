import 'package:cloud_firestore/cloud_firestore.dart';

/// Centralized notification writer.
/// Writes to the Firestore `notifications` collection.
/// relatedType clarifies what relatedId points to: "post"|"request"|"task"|"drive"
class NotificationService {
  static Future<void> sendNotification({
    required String recipientId,
    required String title,
    required String message,
    required String type,
    String? relatedId,
    String? relatedType,
  }) async {
    if (recipientId.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'recipientId': recipientId,
        'title': title,
        'message': message,
        'type': type,
        'relatedId': relatedId ?? '',
        'relatedType': relatedType ?? '',
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Notification failure should not crash the app
    }
  }

  /// Notify all users of a given role (batched to avoid whereIn limits)
  static Future<void> notifyAllByRole({
    required String role,
    required String title,
    required String message,
    required String type,
    String? relatedId,
    String? relatedType,
    String? excludeUserId,
  }) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: role)
          .get();
      for (final doc in snap.docs) {
        if (doc.id == excludeUserId) continue;
        await sendNotification(
          recipientId: doc.id,
          title: title,
          message: message,
          type: type,
          relatedId: relatedId,
          relatedType: relatedType,
        );
      }
    } catch (_) {}
  }
}

