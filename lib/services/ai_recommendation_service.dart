/// AiRecommendationService — Phase 2
///
/// Provides:
///   1. recommendVolunteers()    — ranks volunteers for a task by score
///   2. buildMatchScore()        — receiver ↔ post affinity scoring
///   3. refreshReceiverProfile() — persists preference profile to Firestore
///   4. getSuggestedPosts()      — "Best Match For You" ranked post list
library;

import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data transfer objects
// ─────────────────────────────────────────────────────────────────────────────

class VolunteerScore {
  final String volunteerId;
  final String name;
  final double score;            // 0–100 composite
  final int activeTasks;
  final int completedDeliveries;
  final String recommendation;   // human-readable reason

  const VolunteerScore({
    required this.volunteerId,
    required this.name,
    required this.score,
    required this.activeTasks,
    required this.completedDeliveries,
    required this.recommendation,
  });
}

class PostMatchScore {
  final String postId;
  final double score;            // 0–100 match affinity
  final String reason;

  const PostMatchScore({
    required this.postId,
    required this.score,
    required this.reason,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

class AiRecommendationService {
  static final _db = FirebaseFirestore.instance;

  // In-memory cache (cleared on logout)
  static final Map<String, List<VolunteerScore>> _volunteerCache = {};
  static final Map<String, List<PostMatchScore>> _matchCache = {};

  // ── 1. VOLUNTEER RECOMMENDATION ──────────────────────────────────────────

  /// Returns top [maxResults] volunteers ranked by composite score for [taskId].
  /// Factors: active task load, completion history, availability status.
  /// [pickupLocation] is a free-text string used for label display only
  /// (real GPS routing is a TODO for production).
  static Future<List<VolunteerScore>> recommendVolunteers({
    required String taskId,
    required String ngoId,
    String pickupLocation = '',
    int maxResults = 5,
  }) async {
    final cacheKey = '${taskId}_$ngoId';
    if (_volunteerCache.containsKey(cacheKey)) return _volunteerCache[cacheKey]!;

    try {
      // Fetch all volunteers
      final vSnap = await _db
          .collection('users')
          .where('role', isEqualTo: 'Volunteer')
          .limit(50)
          .get();

      if (vSnap.docs.isEmpty) return [];

      final scores = <VolunteerScore>[];

      for (final vDoc in vSnap.docs) {
        final vData = vDoc.data();
        final vId = vDoc.id;
        final name = vData['name'] as String? ?? 'Volunteer';
        final status = vData['status'] as String? ?? 'Available';

        // Count active (assigned but not delivered) tasks
        final activeSnap = await _db
            .collection('tasks')
            .where('assignedTo', isEqualTo: vId)
            .where('status', isEqualTo: 'assigned')
            .get();
        final activeTasks = activeSnap.docs.length;

        // Count completed deliveries
        final doneSnap = await _db
            .collection('tasks')
            .where('assignedTo', isEqualTo: vId)
            .where('status', isEqualTo: 'delivered')
            .get();
        final completed = doneSnap.docs.length;

        // Composite score (0–100)
        // Availability: 30 pts (available = 30, busy = 10, offline = 0)
        final availPts = status == 'Available' ? 30.0 : status == 'Busy' ? 10.0 : 0.0;

        // Load balance: 40 pts (0 active = 40, -8 per active task)
        final loadPts = (40.0 - activeTasks * 8).clamp(0.0, 40.0);

        // Experience: 30 pts (10 pts per 5 deliveries, capped at 30)
        final expPts = (completed / 5 * 10).clamp(0.0, 30.0);

        final composite = availPts + loadPts + expPts;

        String reason;
        if (composite >= 70) {
          reason = 'Excellent availability, low workload';
        } else if (composite >= 45) {
          reason = 'Good fit, moderate workload';
        } else {
          reason = 'Available but currently busy';
        }

        scores.add(VolunteerScore(
          volunteerId: vId,
          name: name,
          score: composite,
          activeTasks: activeTasks,
          completedDeliveries: completed,
          recommendation: reason,
        ));
      }

      // Sort descending by score
      scores.sort((a, b) => b.score.compareTo(a.score));
      final result = scores.take(maxResults).toList();
      _volunteerCache[cacheKey] = result;
      return result;
    } catch (e) {
      return [];
    }
  }

  // ── 2. RECEIVER FOOD MATCHING ─────────────────────────────────────────────

  /// Score a list of posts against a receiver's preference profile.
  /// Returns sorted list of [PostMatchScore] (best first).
  static Future<List<PostMatchScore>> getSuggestedPosts({
    required String receiverId,
    required List<QueryDocumentSnapshot> posts,
  }) async {
    final cacheKey = receiverId;
    if (_matchCache.containsKey(cacheKey)) return _matchCache[cacheKey]!;

    try {
      // Load receiver profile
      final profDoc = await _db.collection('receiverProfiles').doc(receiverId).get();
      final profile = profDoc.data() ?? {};

      final preferredCategories =
          List<String>.from(profile['preferredCategories'] ?? []);
      final familySize = (profile['familySize'] as num?)?.toInt() ?? 1;
      final requestedPostIds =
          List<String>.from(profile['recentRequestIds'] ?? []);

      final scores = <PostMatchScore>[];

      for (final doc in posts) {
        final d = doc.data() as Map<String, dynamic>;
        double score = 0;
        final reasons = <String>[];

        // Category preference: 30 pts
        final cat = (d['category'] as String? ?? '').toLowerCase();
        if (preferredCategories.any((p) => p.toLowerCase() == cat)) {
          score += 30;
          reasons.add('matches your food preference');
        }

        // AI urgency: 25 pts for critical, 15 for urgent
        final urgency = d['aiUrgencyLevel'] as String? ?? 'normal';
        if (urgency == 'critical') {
          score += 25;
          reasons.add('critically expiring');
        } else if (urgency == 'urgent') {
          score += 15;
          reasons.add('expiring soon');
        }

        // Serves family: 25 pts if qty ≥ familySize
        final qty = (d['quantity'] as num?)?.toInt() ?? 1;
        if (qty >= familySize) {
          score += 25;
          reasons.add('enough for your family');
        }

        // Not already requested: 10 pts
        if (!requestedPostIds.contains(doc.id)) {
          score += 10;
          reasons.add('new for you');
        }

        // Fresh score bonus: up to 10 pts
        final freshnessScore =
            (d['aiFreshnessScore'] as num?)?.toInt() ?? 50;
        score += (freshnessScore / 100 * 10);

        final reason = reasons.isEmpty
            ? 'Available nearby'
            : reasons.take(2).join(' · ');

        scores.add(PostMatchScore(
          postId: doc.id,
          score: score.clamp(0, 100),
          reason: reason,
        ));
      }

      scores.sort((a, b) => b.score.compareTo(a.score));
      _matchCache[cacheKey] = scores;
      return scores;
    } catch (e) {
      return [];
    }
  }

  // ── 3. RECEIVER PROFILE MANAGEMENT ───────────────────────────────────────

  /// Persist receiver preference profile to Firestore.
  /// Called from ReceiverProfilePage settings.
  static Future<void> saveReceiverProfile({
    required String receiverId,
    required int familySize,
    required List<String> preferredCategories,
  }) async {
    await _db.collection('receiverProfiles').doc(receiverId).set({
      'receiverId': receiverId,
      'familySize': familySize,
      'preferredCategories': preferredCategories,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _matchCache.remove(receiverId); // invalidate cache
  }

  /// Record a request to build preference history.
  static Future<void> recordRequest({
    required String receiverId,
    required String postId,
    required String category,
  }) async {
    await _db.collection('receiverProfiles').doc(receiverId).set({
      'recentRequestIds': FieldValue.arrayUnion([postId]),
      'categoryHistory': FieldValue.arrayUnion([category]),
    }, SetOptions(merge: true));
    _matchCache.remove(receiverId);
  }

  // ── Cache management ──────────────────────────────────────────────────────
  static void clearCache() {
    _volunteerCache.clear();
    _matchCache.clear();
  }
}

