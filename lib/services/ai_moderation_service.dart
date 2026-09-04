/// AiModerationService — Phase 2
///
/// Advanced moderation:
///   1. Duplicate image detection (perceptual hash comparison)
///   2. Suspicious spam-behaviour detection (flood detection)
///   3. Fraud risk scoring (0–100)
///   4. Moderation flag writing to Firestore
///
/// NOTE: Full perceptual-hash (pHash) requires the `image` package.
/// This implementation uses a lightweight byte-sample approach as a
/// production-ready approximation. Replace with a proper pHash or
/// Vision API call in a full production deployment.
library;

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Result model
// ─────────────────────────────────────────────────────────────────────────────

class ModerationResult {
  final bool passed;
  final int fraudRiskScore;           // 0–100 (higher = more suspicious)
  final List<String> moderationFlags; // human-readable flag labels
  final String summary;

  const ModerationResult({
    required this.passed,
    required this.fraudRiskScore,
    required this.moderationFlags,
    required this.summary,
  });

  Map<String, dynamic> toFirestore() => {
        'moderationPassed': passed,
        'fraudRiskScore': fraudRiskScore,
        'moderationFlags': moderationFlags,
        'moderationSummary': summary,
        'moderationCheckedAt': FieldValue.serverTimestamp(),
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

class AiModerationService {
  static final _db = FirebaseFirestore.instance;

  // Lightweight perceptual fingerprint cache: hash → first postId seen
  static final Map<int, String> _imageHashRegistry = {};

  // ── 1. FULL MODERATION CHECK ─────────────────────────────────────────────

  /// Run all moderation checks on a new post before / after upload.
  ///
  /// [imageBytes]  : raw image bytes for duplicate detection
  /// [donorId]     : UID of the uploading user
  /// [title]       : post title (for spam keyword detection)
  static Future<ModerationResult> checkPost({
    required Uint8List imageBytes,
    required String donorId,
    required String title,
  }) async {
    final flags = <String>[];
    int riskScore = 0;

    // ── a. Duplicate image detection ─────────────────────────────────────
    final imgHash = _lightweightHash(imageBytes);
    if (_imageHashRegistry.containsKey(imgHash)) {
      flags.add('duplicate_image');
      riskScore += 40;
    } else {
      _imageHashRegistry[imgHash] = donorId;
    }

    // ── b. Flood detection (>3 posts in 10 minutes) ────────────────────
    final floodResult = await _checkFlood(donorId);
    if (floodResult) {
      flags.add('flood_detected');
      riskScore += 35;
    }

    // ── c. Spam keyword detection ─────────────────────────────────────
    if (_hasSpamKeywords(title)) {
      flags.add('spam_keywords');
      riskScore += 20;
    }

    // ── d. Account age check (new accounts = higher risk) ─────────────
    final newAccount = await _isNewAccount(donorId);
    if (newAccount) {
      flags.add('new_account');
      riskScore += 10;
    }

    riskScore = riskScore.clamp(0, 100);
    final passed = riskScore < 60 && !flags.contains('duplicate_image');

    String summary;
    if (flags.isEmpty) {
      summary = 'No moderation issues detected.';
    } else if (riskScore >= 60) {
      summary = 'High fraud risk: ${flags.join(", ")}. Flagged for NGO review.';
    } else {
      summary = 'Minor flags: ${flags.join(", ")}. Monitoring active.';
    }

    return ModerationResult(
      passed: passed,
      fraudRiskScore: riskScore,
      moderationFlags: flags,
      summary: summary,
    );
  }

  // ── 2. WRITE MODERATION RESULT TO FIRESTORE ───────────────────────────────

  /// Persist moderation result to the post document and optionally
  /// write to a 'moderationQueue' collection for NGO review.
  static Future<void> persistModerationResult({
    required String postId,
    required ModerationResult result,
  }) async {
    final batch = _db.batch();

    // Update the post
    batch.update(_db.collection('posts').doc(postId), result.toFirestore());

    // If high risk, add to NGO moderation queue
    if (!result.passed || result.fraudRiskScore >= 60) {
      final queueRef = _db.collection('moderationQueue').doc(postId);
      batch.set(queueRef, {
        'postId': postId,
        'fraudRiskScore': result.fraudRiskScore,
        'flags': result.moderationFlags,
        'summary': result.summary,
        'status': 'pending_review',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // ── 3. GET FLAGGED POSTS FOR NGO REVIEW ──────────────────────────────────

  static Stream<QuerySnapshot> streamFlaggedPosts() {
    return _db
        .collection('moderationQueue')
        .where('status', isEqualTo: 'pending_review')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots();
  }

  /// Mark a flagged post as reviewed by an NGO.
  static Future<void> markReviewed(String postId, {bool approve = false}) async {
    await _db.collection('moderationQueue').doc(postId).update({
      'status': approve ? 'approved' : 'rejected',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
    });
    if (!approve) {
      await _db.collection('posts').doc(postId).update({'status': 'rejected'});
    }
  }

  // ── PRIVATE HELPERS ───────────────────────────────────────────────────────

  /// Lightweight image fingerprint: sample 64 evenly-spaced bytes and hash.
  /// Not a true pHash but sufficient for exact-duplicate detection.
  static int _lightweightHash(Uint8List bytes) {
    if (bytes.isEmpty) return 0;
    const sampleCount = 64;
    final step = (bytes.length / sampleCount).floor().clamp(1, bytes.length);
    int hash = 17;
    for (int i = 0; i < sampleCount; i++) {
      final idx = (i * step).clamp(0, bytes.length - 1);
      hash = hash * 31 + bytes[idx];
    }
    return hash;
  }

  static Future<bool> _checkFlood(String donorId) async {
    try {
      final since = Timestamp.fromDate(
          DateTime.now().subtract(const Duration(minutes: 10)));
      final snap = await _db
          .collection('posts')
          .where('userID', isEqualTo: donorId)
          .where('createdAt', isGreaterThan: since)
          .get();
      return snap.docs.length > 3;
    } catch (_) {
      return false;
    }
  }

  static bool _hasSpamKeywords(String title) {
    const spamWords = ['free money', 'click here', 'win', '!!!', 'buy now', '100% free'];
    final lower = title.toLowerCase();
    return spamWords.any((w) => lower.contains(w));
  }

  static Future<bool> _isNewAccount(String userId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final created = user.metadata.creationTime;
      if (created == null) return false;
      return DateTime.now().difference(created).inDays < 3;
    } catch (_) {
      return false;
    }
  }

  /// Clear the image hash registry (call on logout).
  static void clearRegistry() => _imageHashRegistry.clear();
}

