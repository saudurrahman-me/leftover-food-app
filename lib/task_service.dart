import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Central service for creating and managing delivery tasks.
/// Called by NGODonationsPage (on claim) and NGORequestsPage (on accept).
///
/// AI Integration (v2):
///   Tasks now carry taskPriority and aiFreshnessRisk propagated from the
///   parent post's AI scan results, enabling volunteer dashboard sorting.
class TaskService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─────────────────────────────────────────────────────────────────────────
  // CREATE TASK: when NGO claims a large donation
  // This task represents "pick up from donor → bring to NGO"
  // ─────────────────────────────────────────────────────────────────────────
  static Future<String?> createClaimTask({
    required String ngoId,
    required String postId,
    required String donorId,
    required String donorName,
    required String title,
    required String pickup,   // donor address
    required String dropoff,  // NGO location / warehouse
    // ── AI fields (optional – read from post if available) ────────────────
    String taskPriority = 'normal',        // 'normal' | 'urgent'
    String aiFreshnessRisk = 'moderate',   // freshness status from AI
    String aiUrgencyLevel = 'normal',      // 'normal' | 'urgent' | 'critical'
    double estimatedRemainingHours = 0,
  }) async {
    try {
      final taskRef = await _db.collection('tasks').add({
        'ngoId': ngoId,
        'postId': postId,
        'donorId': donorId,
        'receiverId': ngoId, // NGO acts as receiver for this pickup leg
        'title': 'Collect: $title from $donorName',
        'pickup': pickup,
        'dropoff': dropoff,
        'status': 'pending',
        'assignedTo': '',
        'estimatedMinutes': 30,
        // ── AI fields ──────────────────────────────────────────────────────
        'taskPriority': taskPriority,
        'aiFreshnessRisk': aiFreshnessRisk,
        'aiUrgencyLevel': aiUrgencyLevel,
        'estimatedRemainingHours': estimatedRemainingHours,
        'createdAt': FieldValue.serverTimestamp(),
      });
      // Notify all available volunteers
      _notifyVolunteers(
        title: 'New Pickup Task Available!',
        message: 'A new donation "$title" needs to be collected from $donorName.',
        relatedId: taskRef.id,
      );

      return taskRef.id;
    } catch (e) {
      debugPrint('TaskService.createClaimTask error: $e');
      return null;
    }
  }

  static Future<void> _notifyVolunteers({
    required String title,
    required String message,
    required String relatedId,
  }) async {
    try {
      final volunteers = await _db.collection('users').where('role', isEqualTo: 'Volunteer').get();
      for (var doc in volunteers.docs) {
        await _db.collection('notifications').add({
          'recipientId': doc.id,
          'title': title,
          'message': message,
          'type': 'task',
          'relatedId': relatedId,
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('TaskService._notifyVolunteers error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CREATE TASK: when NGO accepts a receiver request
  // This task represents "deliver from NGO warehouse → receiver"
  // ─────────────────────────────────────────────────────────────────────────
  static Future<String?> createDeliveryTask({
    required String ngoId,
    required String postId,
    required String requestId,
    required String donorId,
    required String receiverId,
    required String title,
    required String pickup,   // NGO warehouse / donor location
    required String dropoff,  // receiver address
    required String receiverName,
    // ── AI fields (optional – read from post if available) ────────────────
    String taskPriority = 'normal',
    String aiFreshnessRisk = 'moderate',
    String aiUrgencyLevel = 'normal',
    double estimatedRemainingHours = 0,
  }) async {
    try {
      final taskRef = await _db.collection('tasks').add({
        'ngoId': ngoId,
        'postId': postId,
        'requestId': requestId,
        'donorId': donorId,
        'receiverId': receiverId,
        'title': 'Deliver: $title to $receiverName',
        'pickup': pickup,
        'dropoff': dropoff,
        'status': 'pending',
        'assignedTo': '',
        'estimatedMinutes': 30,
        // ── AI fields ──────────────────────────────────────────────────────
        'taskPriority': taskPriority,
        'aiFreshnessRisk': aiFreshnessRisk,
        'aiUrgencyLevel': aiUrgencyLevel,
        'estimatedRemainingHours': estimatedRemainingHours,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Back-link taskId into the request document
      await _db.collection('requests').doc(requestId).update({
        'taskId': taskRef.id,
      });

      // Notify all available volunteers
      _notifyVolunteers(
        title: 'New Delivery Task Available!',
        message: 'A new delivery for "$title" is ready for pickup.',
        relatedId: taskRef.id,
      );

      return taskRef.id;
    } catch (e) {
      debugPrint('TaskService.createDeliveryTask error: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPER: Read AI fields from a post document and return as task params
  // Call this before createClaimTask / createDeliveryTask to propagate AI data
  // ─────────────────────────────────────────────────────────────────────────
  static ({
    String taskPriority,
    String aiFreshnessRisk,
    String aiUrgencyLevel,
    double estimatedRemainingHours,
  }) aiFieldsFromPost(Map<String, dynamic> postData) {
    return (
      taskPriority: postData['postPriority'] as String? ?? 'normal',
      aiFreshnessRisk: postData['aiFreshnessStatus'] as String? ?? 'moderate',
      aiUrgencyLevel: postData['aiUrgencyLevel'] as String? ?? 'normal',
      estimatedRemainingHours:
          ((postData['estimatedRemainingHours'] ?? 0) as num).toDouble(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UTIL: Firestore whereIn is limited to 30 values.
  // This batches the IDs into chunks of 10 and merges results.
  // ─────────────────────────────────────────────────────────────────────────
  static Future<List<QueryDocumentSnapshot>> whereInBatched({
    required String collection,
    required String field,
    required List<String> ids,
  }) async {
    if (ids.isEmpty) return [];
    final results = <QueryDocumentSnapshot>[];
    const chunkSize = 10;

    for (int i = 0; i < ids.length; i += chunkSize) {
      final chunk = ids.sublist(i, i + chunkSize > ids.length ? ids.length : i + chunkSize);
      final snap = await _db.collection(collection).where(field, whereIn: chunk).get();
      results.addAll(snap.docs);
    }
    return results;
  }
}

// No local debugPrint redefinition needed, use Flutter's foundation.dart or foundation-provided debugPrint.

