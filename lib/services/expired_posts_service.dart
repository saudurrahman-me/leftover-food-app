/// ExpiredPostsService — CLIENT-SIDE FALLBACK
///
/// ⚠️  PRIMARY cleanup is handled by the scheduled Cloud Function
///    at /functions/index.js (deleteExpiredPosts, runs every hour).
///
/// This service is kept as a best-effort fallback for posts that
/// were created BEFORE the expiryTimestamp field was introduced
/// (i.e., older posts that only have the text `expiryDate` field).
/// It should NOT be called on every page load — call it only
/// from a dedicated admin maintenance action if needed.
///
/// NOTE: All public Firestore queries already filter on
/// expiryTimestamp > now, so expired posts are never shown to users
/// even without a cleanup job.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ExpiredPostsService {
  static final _db = FirebaseFirestore.instance;

  /// One-time maintenance: deletes posts whose [expiryTimestamp] has passed.
  /// Use this from an admin action, NOT on every page load.
  /// The scheduled Cloud Function handles ongoing cleanup automatically.
  static Future<int> cleanupExpiredPosts() async {
    try {
      final now = Timestamp.now();

      final snap = await _db
          .collection('posts')
          .where('expiryTimestamp', isLessThanOrEqualTo: now)
          .where('status', whereIn: ['active', 'claimed'])
          .get();

      if (snap.docs.isEmpty) return 0;

      final batch = _db.batch();
      for (final doc in snap.docs) {
        debugPrint('[ExpiredPostsService] Scheduling delete: ${doc.id}');
        batch.delete(doc.reference);
      }
      await batch.commit();
      debugPrint('[ExpiredPostsService] Deleted ${snap.docs.length} expired post(s).');
      return snap.docs.length;
    } catch (e) {
      debugPrint('[ExpiredPostsService] Cleanup error: $e');
      return 0;
    }
  }
}
