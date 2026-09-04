/// AiMonitoringService — Phase 2
///
/// Real-time AI monitoring data for the NGO Live Dashboard.
/// All methods return streams or futures directly from Firestore —
/// no extra network calls, reads are minimal and batched.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Monitoring snapshot model
// ─────────────────────────────────────────────────────────────────────────────

class MonitoringSnapshot {
  final int activeUrgentDonations;
  final int deliveriesAtSpoilageRisk;
  final int unsafeUploadsBlocked;
  final double avgDeliveryMinutes;
  final double foodWastePreventedKg;
  final double aiInterventionSuccessRate; // % of urgent posts that got claimed
  final DateTime computedAt;

  const MonitoringSnapshot({
    required this.activeUrgentDonations,
    required this.deliveriesAtSpoilageRisk,
    required this.unsafeUploadsBlocked,
    required this.avgDeliveryMinutes,
    required this.foodWastePreventedKg,
    required this.aiInterventionSuccessRate,
    required this.computedAt,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Predictive analytics snapshot
// ─────────────────────────────────────────────────────────────────────────────

class PredictiveInsight {
  final String label;
  final String value;
  final String trend; // '↑' | '↓' | '→'
  final String insight;

  const PredictiveInsight({
    required this.label,
    required this.value,
    required this.trend,
    required this.insight,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

class AiMonitoringService {
  static final _db = FirebaseFirestore.instance;

  // ── 1. LIVE MONITORING SNAPSHOT ───────────────────────────────────────────

  /// Computes the full monitoring snapshot for the NGO dashboard.
  /// Single read-burst: 4 Firestore queries, results cached for 60s.
  static DateTime? _lastComputed;
  static MonitoringSnapshot? _cachedSnapshot;

  static Future<MonitoringSnapshot> getMonitoringSnapshot() async {
    // 60-second cache
    if (_cachedSnapshot != null &&
        _lastComputed != null &&
        DateTime.now().difference(_lastComputed!).inSeconds < 60) {
      return _cachedSnapshot!;
    }

    try {
      // Q1: Active urgent/critical posts
      final urgentSnap = await _db
          .collection('posts')
          .where('status', whereIn: ['active', 'claimed'])
          .where('aiUrgencyLevel', whereIn: ['urgent', 'critical'])
          .get();

      // Q2: Tasks at spoilage risk
      final spoilageSnap = await _db
          .collection('tasks')
          .where('status', isEqualTo: 'assigned')
          .where('spoilageRiskDuringDelivery', whereIn: ['high', 'critical'])
          .get();

      // Q3: Unsafe blocked (posts with moderation failure or unsafe status)
      final blockedSnap = await _db
          .collection('posts')
          .where('aiModerationPassed', isEqualTo: false)
          .get();
      final unsafeSnap = await _db
          .collection('posts')
          .where('aiFreshnessStatus', isEqualTo: 'unsafe')
          .get();
      final totalBlocked = blockedSnap.docs.length + unsafeSnap.docs.length;

      // Q4: Completed tasks — compute average delivery time
      final completedSnap = await _db
          .collection('tasks')
          .where('status', isEqualTo: 'delivered')
          .limit(100)
          .get();
      double totalMins = 0;
      int withPrediction = 0;
      for (final doc in completedSnap.docs) {
        final mins =
            (doc.data()['predictedDeliveryMinutes'] as num?)?.toDouble();
        if (mins != null) {
          totalMins += mins;
          withPrediction++;
        }
      }
      final avgMins = withPrediction > 0 ? totalMins / withPrediction : 0.0;

      // Waste prevented estimate: each blocked unsafe post ≈ 3 kg saved
      final wasteKg = totalBlocked * 3.0;

      // AI intervention success rate:
      // % of urgent posts that were subsequently claimed
      final urgentTotal = urgentSnap.docs.length;
      final urgentClaimed = urgentSnap.docs.where((d) {
        final data = d.data();
        return data['status'] == 'claimed' || data['ngoId'] != null;
      }).length;
      final successRate =
          urgentTotal > 0 ? urgentClaimed / urgentTotal * 100 : 0.0;

      final snap = MonitoringSnapshot(
        activeUrgentDonations: urgentSnap.docs.length,
        deliveriesAtSpoilageRisk: spoilageSnap.docs.length,
        unsafeUploadsBlocked: totalBlocked,
        avgDeliveryMinutes: avgMins,
        foodWastePreventedKg: wasteKg,
        aiInterventionSuccessRate: successRate,
        computedAt: DateTime.now(),
      );
      _cachedSnapshot = snap;
      _lastComputed = DateTime.now();
      return snap;
    } catch (_) {
      return MonitoringSnapshot(
        activeUrgentDonations: 0,
        deliveriesAtSpoilageRisk: 0,
        unsafeUploadsBlocked: 0,
        avgDeliveryMinutes: 0,
        foodWastePreventedKg: 0,
        aiInterventionSuccessRate: 0,
        computedAt: DateTime.now(),
      );
    }
  }

  // ── 2. LIVE STREAM: Active urgent donations ───────────────────────────────

  static Stream<int> streamUrgentCount() {
    return _db
        .collection('posts')
        .where('status', whereIn: ['active', 'claimed'])
        .where('aiUrgencyLevel', whereIn: ['urgent', 'critical'])
        .snapshots()
        .map((s) => s.docs.length);
  }

  // ── 3. PREDICTIVE ANALYTICS ───────────────────────────────────────────────

  /// Generates AI insights from historical Firestore data.
  /// Returns a list of [PredictiveInsight] cards for the dashboard.
  static Future<List<PredictiveInsight>> getPredictiveInsights() async {
    try {
      final allPostsSnap = await _db
          .collection('posts')
          .where('aiScanEnabled', isEqualTo: true)
          .limit(200)
          .get();

      final docs = allPostsSnap.docs;
      if (docs.isEmpty) return _emptyInsights();

      // Category analysis
      final Map<String, int> catCount = {};
      final Map<String, int> catWasted = {};
      final Map<int, int> hourCount = {}; // donation hour → count
      int totalUrgent = 0, totalClaimed = 0;
      double totalScore = 0;
      int scoredCount = 0;

      for (final doc in docs) {
        final d = doc.data();
        final cat = d['aiFoodCategory'] as String? ?? 'other';
        final freshness = d['aiFreshnessStatus'] as String? ?? 'moderate';
        final status = d['status'] as String? ?? 'active';
        final urgency = d['aiUrgencyLevel'] as String? ?? 'normal';
        final createdAt = d['createdAt'] as Timestamp?;
        final score = (d['aiFreshnessScore'] as num?)?.toInt();

        catCount[cat] = (catCount[cat] ?? 0) + 1;
        if (freshness == 'expiringSoon' || freshness == 'unsafe') {
          catWasted[cat] = (catWasted[cat] ?? 0) + 1;
        }
        if (urgency != 'normal') totalUrgent++;
        if (status == 'claimed' || status == 'assigned' || status == 'delivered') {
          totalClaimed++;
        }
        if (score != null) {
          totalScore += score;
          scoredCount++;
        }
        if (createdAt != null) {
          final h = createdAt.toDate().hour;
          hourCount[h] = (hourCount[h] ?? 0) + 1;
        }
      }

      // Most wasted category
      final topWasted = catWasted.isEmpty
          ? 'N/A'
          : (catWasted.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .first
              .key;

      // Peak donation hour
      final peakEntry = hourCount.isEmpty
          ? null
          : (hourCount.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .first;
      final peakHour = peakEntry?.key;
      final peakLabel = peakHour == null
          ? 'N/A'
          : '${peakHour == 0 ? 12 : peakHour > 12 ? peakHour - 12 : peakHour}'
              '${peakHour < 12 ? 'am' : 'pm'}';

      // Most requested category
      final topCat = catCount.isEmpty
          ? 'N/A'
          : (catCount.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .first
              .key;

      // NGO efficiency score
      final efficiency =
          totalUrgent > 0 ? (totalClaimed / docs.length * 100).round() : 0;
      final avgFreshness =
          scoredCount > 0 ? (totalScore / scoredCount).round() : 0;

      return [
        PredictiveInsight(
          label: 'Most Wasted Category',
          value: _catLabel(topWasted),
          trend: '↑',
          insight:
              'Consider partnering with donors in this category to reduce waste.',
        ),
        PredictiveInsight(
          label: 'Peak Donation Time',
          value: peakLabel,
          trend: '→',
          insight: 'Schedule more volunteers during peak hours for faster pickup.',
        ),
        PredictiveInsight(
          label: 'Most Donated Category',
          value: _catLabel(topCat),
          trend: '↑',
          insight: 'High supply — match with receivers who prefer this type.',
        ),
        PredictiveInsight(
          label: 'Claim Rate',
          value: '$efficiency%',
          trend: efficiency >= 70 ? '↑' : '↓',
          insight: efficiency >= 70
              ? 'Excellent NGO responsiveness.'
              : 'Increase volunteer coverage to improve claim rate.',
        ),
        PredictiveInsight(
          label: 'Avg Freshness Score',
          value: '$avgFreshness/100',
          trend: avgFreshness >= 65 ? '↑' : '↓',
          insight: avgFreshness >= 65
              ? 'Good overall food quality from donors.'
              : 'Encourage donors to post earlier for higher quality scores.',
        ),
      ];
    } catch (_) {
      return _emptyInsights();
    }
  }

  static List<PredictiveInsight> _emptyInsights() => [
        const PredictiveInsight(
          label: 'No Data Yet',
          value: '—',
          trend: '→',
          insight: 'Analytics will appear once AI-scanned posts are available.',
        ),
      ];

  static String _catLabel(String cat) {
    const labels = {
      'fruits': 'Fruits',
      'vegetables': 'Vegetables',
      'cookedMeals': 'Cooked Meals',
      'bakery': 'Bakery',
      'dairy': 'Dairy',
      'meat': 'Meat',
      'beverages': 'Beverages',
      'other': 'Other',
    };
    return labels[cat] ?? cat;
  }

  static void clearCache() {
    _cachedSnapshot = null;
    _lastComputed = null;
  }
}

