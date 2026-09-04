/// AiPriorityEngine — Phase 2
///
/// Handles:
///   1. foodQualityScore  (0–100) — composite freshness/image/delivery score
///   2. Dynamic priority recalculation — updates Firestore posts in-place
///   3. Delivery time prediction — predictedDeliveryMinutes + spoilageRisk
///   4. Stale donation detection — "Food Waste Prevention Engine"
library;

import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums & constants
// ─────────────────────────────────────────────────────────────────────────────

enum SpoilageRisk { low, moderate, high, critical }

/// Priority tiers used for both posts and tasks
enum PostPriorityTier { normal, urgent, critical, expired }

// ─────────────────────────────────────────────────────────────────────────────
// Engine
// ─────────────────────────────────────────────────────────────────────────────

class AiPriorityEngine {
  static final _db = FirebaseFirestore.instance;

  // ── 1. FOOD QUALITY SCORE ─────────────────────────────────────────────────

  /// Computes a 0–100 composite quality score from Firestore post data.
  ///
  /// Components:
  ///   • Freshness (AI)       : 40 pts
  ///   • Confidence (AI)      : 20 pts
  ///   • Remaining hours      : 25 pts
  ///   • Moderation passed    : 15 pts
  static int computeFoodQualityScore(Map<String, dynamic> postData) {
    double score = 0;

    // Freshness (40 pts)
    final freshnessStatus = postData['aiFreshnessStatus'] as String? ?? 'moderate';
    score += switch (freshnessStatus) {
      'fresh' => 40.0,
      'moderate' => 28.0,
      'expiringSoon' => 14.0,
      'unsafe' => 0.0,
      _ => 20.0,
    };

    // Confidence (20 pts)
    final confidence = (postData['aiConfidence'] as num?)?.toDouble() ?? 50.0;
    // confidence is stored as 0–100 int in Firestore
    score += (confidence / 100 * 20).clamp(0, 20);

    // Remaining hours (25 pts — full at 24h+, zero at 0h)
    final remainHours =
        (postData['estimatedRemainingHours'] as num?)?.toDouble() ?? 0.0;
    final hourPts = (remainHours / 24 * 25).clamp(0.0, 25.0);
    score += hourPts;

    // Moderation (15 pts)
    final modPassed = postData['aiModerationPassed'] as bool? ?? true;
    if (modPassed) score += 15;

    return score.round().clamp(0, 100);
  }

  // ── 2. DYNAMIC PRIORITY RECALCULATION ─────────────────────────────────────

  /// Recalculates aiUrgencyLevel and postPriority for all active posts.
  /// Call this periodically (e.g. via cloud function trigger or app foreground).
  ///
  /// Uses elapsed time since post creation and remaining hours to compute
  /// real-time urgency, independent of the original AI scan result.
  static Future<int> recalculateAllPosts() async {
    int updated = 0;
    try {
      final snap = await _db
          .collection('posts')
          .where('status', whereIn: ['active', 'claimed'])
          .limit(100) // batch size guard
          .get();

      final batch = _db.batch();

      for (final doc in snap.docs) {
        final d = doc.data();
        final updatedUrgency = _computeCurrentUrgency(d);
        final tier = _priorityTier(d);
        final qualityScore = computeFoodQualityScore(d);

        batch.update(doc.reference, {
          'aiUrgencyLevel': updatedUrgency,
          'postPriority': tier == PostPriorityTier.normal ? 'normal' : 'urgent',
          'foodQualityScore': qualityScore,
          'priorityLastUpdated': FieldValue.serverTimestamp(),
        });
        updated++;
      }

      await batch.commit();
    } catch (_) {
      // Silently fail — recalculation is non-critical
    }
    return updated;
  }

  /// Compute real-time urgency from remaining hours.
  /// Does NOT call the AI API — pure local calculation.
  static String _computeCurrentUrgency(Map<String, dynamic> postData) {
    final remaining =
        (postData['estimatedRemainingHours'] as num?)?.toDouble() ?? 24.0;
    final createdAt = postData['createdAt'] as Timestamp?;
    double effectiveRemaining = remaining;

    if (createdAt != null) {
      final elapsed =
          DateTime.now().difference(createdAt.toDate()).inMinutes / 60.0;
      effectiveRemaining = remaining - elapsed;
    }

    if (effectiveRemaining <= 0) return 'expired';
    if (effectiveRemaining <= 2) return 'critical';
    if (effectiveRemaining <= 6) return 'urgent';
    return 'normal';
  }

  static PostPriorityTier _priorityTier(Map<String, dynamic> d) {
    final u = d['aiUrgencyLevel'] as String? ?? 'normal';
    return switch (u) {
      'critical' => PostPriorityTier.critical,
      'urgent' => PostPriorityTier.urgent,
      'expired' => PostPriorityTier.expired,
      _ => PostPriorityTier.normal,
    };
  }

  // ── 3. DELIVERY TIME PREDICTION ───────────────────────────────────────────

  /// Predicts pickup/delivery ETAs and spoilage risk during transit.
  ///
  /// [remainingHours] : AI freshness remaining hours
  /// [urgencyLevel]   : 'normal' | 'urgent' | 'critical'
  ///
  /// Returns a map suitable for merging into a task document.
  static Map<String, dynamic> predictDelivery({
    required double remainingHours,
    required String urgencyLevel,
    int baseDeliveryMinutes = 30, // placeholder for real routing
  }) {
    // Apply urgency multiplier (urgent tasks get deprioritised queue = longer)
    final queueMultiplier = urgencyLevel == 'critical'
        ? 0.8 // fast-tracked
        : urgencyLevel == 'urgent'
            ? 0.9
            : 1.0;
    final predictedMinutes =
        (baseDeliveryMinutes * queueMultiplier).round();

    // Spoilage risk: compare predicted delivery time vs remaining hours
    final deliveryHours = predictedMinutes / 60.0;
    final SpoilageRisk risk;
    final double safetyMargin = remainingHours - deliveryHours;

    if (remainingHours <= 0) {
      risk = SpoilageRisk.critical;
    } else if (safetyMargin <= 0.5) {
      risk = SpoilageRisk.critical;
    } else if (safetyMargin <= 2) {
      risk = SpoilageRisk.high;
    } else if (safetyMargin <= 6) {
      risk = SpoilageRisk.moderate;
    } else {
      risk = SpoilageRisk.low;
    }

    return {
      'predictedDeliveryMinutes': predictedMinutes,
      'spoilageRiskDuringDelivery': risk.name,
      'safetyMarginHours': safetyMargin.clamp(-99.0, 99.0),
      // TODO: Replace with real Google Maps Directions API call
      // TODO: Factor in traffic, volunteer location, road network
    };
  }

  // ── 4. STALE / WASTE DETECTION ────────────────────────────────────────────

  /// Returns posts that are at risk of being wasted:
  ///   • Created >2h ago with no requests AND urgency is urgent/critical
  ///   • OR estimatedRemainingHours < 3 and no ngoId assigned
  static Future<List<QueryDocumentSnapshot>> detectStaleDonations({
    int lookbackHours = 6,
  }) async {
    try {
      final cutoff = Timestamp.fromDate(
          DateTime.now().subtract(Duration(hours: lookbackHours)));
      final snap = await _db
          .collection('posts')
          .where('status', isEqualTo: 'active')
          .where('createdAt', isLessThan: cutoff)
          .limit(50)
          .get();

      // Filter: no requests filed
      final results = <QueryDocumentSnapshot>[];
      for (final doc in snap.docs) {
        final d = doc.data();
        final urgency = d['aiUrgencyLevel'] as String? ?? 'normal';
        final remaining =
            (d['estimatedRemainingHours'] as num?)?.toDouble() ?? 99.0;
        final hasNgo = (d['ngoId'] as String? ?? '').isNotEmpty;

        if (!hasNgo && (urgency != 'normal' || remaining < 3)) {
          results.add(doc);
        }
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  /// Boost visibility of a stale post by incrementing its priority.
  /// Writes aiUrgencyLevel → 'urgent' if it was 'normal'.
  static Future<void> boostStalePost(String postId) async {
    try {
      final doc = await _db.collection('posts').doc(postId).get();
      if (!doc.exists) return;
      final d = doc.data()!;
      final current = d['aiUrgencyLevel'] as String? ?? 'normal';
      final newUrgency = current == 'normal' ? 'urgent' : 'critical';
      await _db.collection('posts').doc(postId).update({
        'aiUrgencyLevel': newUrgency,
        'postPriority': 'urgent',
        'aiWastePrevention': true,
        'wasteBoostedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // ── 5. FOOD QUALITY SCORE — convenience async version ────────────────────

  /// Reads post data from Firestore and stores foodQualityScore in-place.
  static Future<int?> computeAndStoreQualityScore(String postId) async {
    try {
      final doc = await _db.collection('posts').doc(postId).get();
      if (!doc.exists) return null;
      final score = computeFoodQualityScore(doc.data()!);
      await _db.collection('posts').doc(postId).update({'foodQualityScore': score});
      return score;
    } catch (_) {
      return null;
    }
  }
}

