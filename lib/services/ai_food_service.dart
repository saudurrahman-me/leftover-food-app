/// AI Food Freshness & Safety Detection Service — v3.1
///
/// Changes from v3:
///   • Removed unsupported responseMimeType (caused silent 400 errors)
///   • Per-stage soft-fail: failure in any stage uses safe defaults, pipeline continues
///   • Retry-once on HTTP errors
///   • Full debugPrint logging per stage (timing + raw response + parse result)
///   • Image validation before sending (size, null check)
///   • Robust JSON extraction (strips markdown fences, extracts first {...} block)
///   • Consolidated to 2 Gemini calls (recognition+spoilage merged, freshness separate)
///     to reduce latency and rate-limit exposure
library;

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/app_config.dart';
import '../models/food_analysis_model.dart';

class AiFoodService {
  static String get _apiKey => AppConfig.geminiApiKey;
  // gemini-1.5-flash is deprecated and removed. Using gemini-flash-latest instead.
  static const String _model = 'gemini-flash-latest';
  static const String _apiVersion = 'v1beta'; // Keep on v1beta for now, it's safer for newer models
  static const bool hardBlockUnsafe = true;

  // ── Cache ────────────────────────────────────────────────────────────────
  static final Map<int, FoodAnalysisResult> _cache = {};
  static void clearCache() => _cache.clear();

  // ── Public API ───────────────────────────────────────────────────────────

  static Future<FoodAnalysisResult> analyze({Uint8List? imageBytes}) async {
    if (imageBytes == null || imageBytes.isEmpty) {
      debugPrint('[AI] ❌ analyze() called with null/empty imageBytes');
      return _errorFallback('No image provided');
    }
    debugPrint('[AI] 📷 Image size: ${imageBytes.lengthInBytes} bytes');

    // FIX 1: Content-based hash (not identity hash — Dart's .hashCode on
    // Uint8List is identity-based and changes every time for same content).
    final hash = _contentHash(imageBytes);
    if (_cache.containsKey(hash)) {
      debugPrint('[AI] 💾 Cache hit');
      return _cache[hash]!;
    }

    // Images >800KB take >35s to upload on slow web connections — warn early.
    if (imageBytes.lengthInBytes > 819200) {
      debugPrint('[AI] ⚠️ Large image ${imageBytes.lengthInBytes ~/ 1024}KB — may be slow on web. Consider compressing to <500KB.');
    }
    // Hard limit at 4MB (Gemini inline limit)
    if (imageBytes.lengthInBytes > 4194304) {
      debugPrint('[AI] ❌ Image too large (${imageBytes.lengthInBytes} bytes) — returning cautious fallback');
      return _largeImageFallback();
    }

    // FIX 3: Detect real MIME type from magic bytes.
    final mime = _detectMime(imageBytes);
    debugPrint('[AI] 🖼️ Detected MIME: $mime');

    // FIX 4: Offload CPU-heavy base64 encoding to an isolate to prevent UI freezing
    final b64 = await compute(base64Encode, imageBytes);
    debugPrint('[AI] 🔐 Base64 length: ${b64.length} chars');

    final result = await _runPipeline(b64, mime);
    
    // Save to cache and enforce LRU limit of 5 to prevent OOM
    _cache[hash] = result;
    if (_cache.length > 5) {
      _cache.remove(_cache.keys.first);
    }
    
    return result;
  }

  /// Stable content hash: sample 128 bytes evenly across the image.
  static int _contentHash(Uint8List bytes) {
    if (bytes.length <= 128) {
      return bytes.fold(17, (h, b) => h * 31 + b);
    }
    final step = bytes.length ~/ 128;
    int h = 17;
    for (int i = 0; i < 128; i++) {
      h = h * 31 + bytes[i * step];
    }
    return h;
  }

  /// Detect MIME type from file magic bytes.
  static String _detectMime(Uint8List bytes) {
    if (bytes.length >= 4) {
      // PNG: \x89PNG
      if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
        return 'image/png';
      }
      // JPEG: \xFF\xD8
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) return 'image/jpeg';
      // WebP: RIFF....WEBP
      if (bytes.length >= 12 &&
          bytes[0] == 0x52 && bytes[1] == 0x49 && // RI
          bytes[8] == 0x57 && bytes[9] == 0x45) {  // WE
        return 'image/webp';
      }
      // GIF
      if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return 'image/gif';
      // HEIC/HEIF (ftyp box)
      if (bytes.length >= 12 && bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70) {
        return 'image/heic';
      }
    }
    // Default: Gemini accepts image/jpeg as fallback
    return 'image/jpeg';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PIPELINE (soft-fail per stage)
  // ─────────────────────────────────────────────────────────────────────────

  static Future<FoodAnalysisResult> _runPipeline(String b64, String mime) async {
    // ── STAGE 1+2: Recognition + Spoilage (single call) ──────────────────
    final t1 = DateTime.now();
    Map<String, dynamic> s12 = {};
    try {
      s12 = await _callStage12(b64, mime);
      final ms = DateTime.now().difference(t1).inMilliseconds;
      debugPrint('[AI] ✅ Stage 1+2 OK in ${ms}ms → ${s12.toString().substring(0, s12.toString().length.clamp(0, 200))}');
    } catch (e) {
      debugPrint('[AI] ⚠️ Stage 1+2 FAILED: $e — using defaults');
    }

    // If image is not food → hard block immediately
    final isFood = s12['isFood'] as bool? ?? true; // default true on failure
    if (s12.containsKey('isFood') && !isFood) {
      final reason = s12['moderationReason'] as String? ?? 'Not food';
      debugPrint('[AI] 🚫 Stage 1: Not food — $reason');
      return _nonFoodResult(reason);
    }

    final cat = s12['category'] as String? ?? 'other';
    final catConf = (s12['categoryConfidence'] as num?)?.toDouble() ?? 0.5;
    final spoilageScore = (s12['overallSpoilageScore'] as num?)?.toInt() ?? 30;
    final moldVisible = s12['moldVisible'] as bool? ?? false;
    final moldSev = s12['moldSeverity'] as String? ?? 'none';
    final liquidLeakage = s12['liquidLeakage'] as bool? ?? false;
    final rottingSpots = s12['rottingSpots'] as bool? ?? false;
    final spoilageEvidence = s12['spoilageEvidence'] as String? ?? '';
    final imageOk = s12['isImageClear'] as bool? ?? true;
    
    final detectedItemsJson = s12['detectedItems'] as List<dynamic>? ?? [];
    final detectedItems = detectedItemsJson.map((item) {
      return DetectedItem(
        name: item['name'] as String? ?? 'Unknown item',
        details: item['details'] as String? ?? 'No details provided',
      );
    }).toList();

    if (!imageOk) debugPrint('[AI] ⚠️ Stage 1: Image quality poor');

    // ── STAGE 3: Freshness Score (TEXT-ONLY — no second image upload) ────────
    final foodName = s12['foodName'] as String? ?? cat;
    final t3 = DateTime.now();
    Map<String, dynamic> s3 = {};
    try {
      s3 = await _callStage3TextOnly(cat, spoilageScore, moldSev, foodName, spoilageEvidence);
      final ms = DateTime.now().difference(t3).inMilliseconds;
      debugPrint('[AI] ✅ Stage 3 OK in ${ms}ms → $s3');
    } catch (e) {
      debugPrint('[AI] ⚠️ Stage 3 FAILED: $e — deriving from spoilage score');
      s3 = _deriveFromSpoilage(spoilageScore);
    }

    var freshnessStr = s3['freshnessStatus'] as String? ?? 'moderate';
    var freshnessScore = (s3['freshnessScore'] as num?)?.toInt() ?? 50;
    final confidence = (s3['confidence'] as num?)?.toDouble() ?? 0.5;

    debugPrint('[AI] 📊 Pre-override: freshness=$freshnessStr score=$freshnessScore conf=$confidence');

    // ── STAGE 4: Shelf Life (local) ───────────────────────────────────────
    final shelf = _stageShelfLife(cat, freshnessStr, freshnessScore);
    var expiryRisk = shelf['expiryRisk'] as String;
    var remainHours = (shelf['estimatedRemainingHours'] as num).toDouble();
    debugPrint('[AI] ⏱️ Stage 4: $cat → ${remainHours}h, risk=$expiryRisk');

    // ── STAGE 5: Rule overrides + synthesize ─────────────────────────────
    // Rule 1: Any visible mold → minimum expiringSoon
    if (moldVisible && freshnessStr == 'fresh') {
      freshnessStr = 'expiringSoon';
      freshnessScore = freshnessScore.clamp(0, 45);
      debugPrint('[AI] 🔒 Override R1: mold visible → expiringSoon');
    }
    // Rule 2: Moderate/severe mold → unsafe
    if (moldSev == 'severe' || moldSev == 'moderate') {
      freshnessStr = 'unsafe';
      freshnessScore = freshnessScore.clamp(0, 15);
      expiryRisk = 'unsafeToConsume';
      remainHours = 0;
      debugPrint('[AI] 🔒 Override R2: mold $moldSev → unsafe');
    }
    // Rule 3: Liquid leakage on meat/dairy → unsafe
    if (liquidLeakage && (cat == 'meat' || cat == 'dairy')) {
      freshnessStr = 'unsafe';
      freshnessScore = freshnessScore.clamp(0, 10);
      expiryRisk = 'unsafeToConsume';
      remainHours = 0;
      debugPrint('[AI] 🔒 Override R3: liquid leakage on $cat → unsafe');
    }
    // Rule 4: Rotting spots on fresh → expiringSoon
    if (rottingSpots && freshnessStr == 'fresh') {
      freshnessStr = 'expiringSoon';
      freshnessScore = freshnessScore.clamp(0, 48);
      debugPrint('[AI] 🔒 Override R4: rotting spots → expiringSoon');
    }
    // Rule 5: High spoilage score
    if (spoilageScore > 70) {
      freshnessStr = 'unsafe';
      freshnessScore = freshnessScore.clamp(0, 19);
      expiryRisk = 'unsafeToConsume';
      remainHours = 0;
      debugPrint('[AI] 🔒 Override R5: spoilageScore=$spoilageScore → unsafe');
    }
    // Rule 6: Low confidence → moderate/uncertain (don't fake precision)
    final lowConf = confidence < 0.55 || catConf < 0.50;
    if (lowConf && freshnessStr != 'unsafe') {
      debugPrint('[AI] ⚠️ Low confidence (conf=$confidence catConf=$catConf) → capping at moderate');
      freshnessStr = 'moderate';
      freshnessScore = 50;
      expiryRisk = 'donateQuickly';
      remainHours = remainHours.clamp(0, 6);
    }

    final urgency = switch (freshnessStr) {
      'unsafe' || 'expiringSoon' => AiUrgencyLevel.critical,
      'moderate' => AiUrgencyLevel.urgent,
      _ => AiUrgencyLevel.normal,
    };

    final rec = _buildRecommendation(
      cat: cat,
      freshnessStr: freshnessStr,
      lowConf: lowConf,
      moldSev: moldSev,
      remainHours: remainHours,
    );

    final finalResult = FoodAnalysisResult(
      freshnessStatus: _toFreshnessStatus(freshnessStr),
      expiryRisk: _toExpiryRisk(expiryRisk),
      foodCategory: _toFoodCategory(cat),
      urgencyLevel: urgency,
      confidence: lowConf ? 0.45 : confidence.clamp(0.0, 1.0),
      freshnessScore: freshnessScore.clamp(0, 100),
      estimatedRemainingHours: remainHours,
      scanEnabled: true,
      moderationPassed: freshnessStr != 'unsafe',
      safetyRecommendation: rec,
      analyzedAt: DateTime.now(),
      rawNotes: spoilageEvidence.isNotEmpty ? spoilageEvidence : 'stage12=${s12.isNotEmpty}',
      foodName: foodName,
      detectedItems: detectedItems,
      isFood: true,
    );

    debugPrint('[AI] ✅ Final: $freshnessStr score=$freshnessScore hours=${remainHours}h urgency=${urgency.name}');
    return finalResult;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GEMINI CALL: Stage 1+2 — Recognition + Spoilage (merged into ONE call)
  // ─────────────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _callStage12(String b64, String mime) async {
    const prompt = r'''
You are a food safety AI. Analyze this food image carefully.
Respond with ONLY a JSON object — no markdown, no explanation, no code fences.

Return exactly this structure:
{
  "isFood": true,
  "isImageClear": true,
  "moderationReason": "",
  "foodName": "banana",
  "category": "fruits",
  "categoryConfidence": 0.92,
  "moldVisible": false,
  "moldSeverity": "none",
  "discoloration": false,
  "discolorationSeverity": "none",
  "textureDegradation": false,
  "liquidLeakage": false,
  "rottingSpots": false,
  "overallSpoilageScore": 5,
  "spoilageEvidence": "vibrant yellow color, firm texture",
  "detectedItems": [
    {"name": "Banana", "details": "Consume within 48 hours"},
    {"name": "Apple", "details": "Safe for 1-2 weeks if refrigerated"}
  ]
}

Field rules:
- isFood: false if image shows person, object, text, blank, screenshot
- isImageClear: false if image is too blurry or dark to analyze
- category must be one of: fruits, vegetables, cookedMeals, bakery, dairy, meat, beverages, other
- categoryConfidence: your certainty about category (0.0–1.0)
- moldSeverity: none | trace | moderate | severe
- discolorationSeverity: none | slight | moderate | severe
- overallSpoilageScore: 0=perfectly fresh, 100=completely rotten
- spoilageEvidence: brief list of what you see (max 80 chars)
- detectedItems: array of objects, one for each distinct food item visible. Provide its 'name' and for 'details', estimate its safe expiry timeline (e.g. "Consume within 2 days"). Do not describe the item's visual appearance here.

Spoilage scoring guide:
0–10: perfectly fresh, no issues
11–30: minor natural variation, safe
31–50: moderate aging, some deterioration
51–70: significant spoilage, donate quickly
71–100: severe spoilage, unsafe
''';

    final raw = await _geminiCall(prompt, b64, mime: mime, stage: '1+2');
    final parsed = _extractJson(raw);
    if (parsed == null) throw Exception('JSON parse failed: $raw');
    return parsed;
  }

  // Stage 3 is TEXT-ONLY — does not resend the image (avoids double-upload
  // timeout). It uses the structured data from Stage 1+2 to infer freshness.
  static Future<Map<String, dynamic>> _callStage3TextOnly(
      String cat, int spoilageScore, String moldSev,
      String foodName, String spoilageEvidence) async {
    final prompt = '''
You are a food freshness scorer. Analyze the following data about a food item.
Respond with ONLY a JSON object — no markdown, no explanation.

Food data:
- Name: $foodName
- Category: $cat
- Spoilage score: $spoilageScore/100
- Mold severity: $moldSev
- Observed evidence: $spoilageEvidence

Return exactly this structure:
{
  "freshnessStatus": "fresh",
  "freshnessScore": 88,
  "colorHealth": 90,
  "textureHealth": 85,
  "confidence": 0.82
}

Rules:
- freshnessStatus: fresh | moderate | expiringSoon | unsafe
- If spoilageScore > 70 → unsafe, freshnessScore < 20
- If spoilageScore 40–70 → at most expiringSoon
- If moldSeverity moderate/severe → unsafe
- If spoilageScore < 30 and no mold → fresh or moderate
- confidence < 0.55 → set freshnessStatus=moderate, freshnessScore=50

Freshness guide for $cat:
${_freshnessGuide(cat)}
''';

    // Text-only call — no image data, no mime type needed
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/$_apiVersion/models/$_model:generateContent?key=$_apiKey',
    );
    final body = jsonEncode({
      'contents': [
        {'parts': [{'text': prompt}]},
      ],
      'generationConfig': {'temperature': 0.05, 'maxOutputTokens': 2048},
    });

    debugPrint('[AI] 📡 Stage 3 (text-only) — no image re-upload...');
    Exception? lastError;

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final resp = await http
            .post(url, headers: {'Content-Type': 'application/json'}, body: body)
            .timeout(const Duration(seconds: 20));

        debugPrint('[AI] 📥 Stage 3 attempt $attempt — HTTP ${resp.statusCode}');

        if (resp.statusCode != 200) {
          lastError = Exception('HTTP ${resp.statusCode}: ${resp.body.substring(0, resp.body.length.clamp(0, 150))}');
          debugPrint('[AI] ❌ Stage 3 HTTP error: $lastError');
          final backoff = (pow(2, attempt) * 1000).toInt() + Random().nextInt(1000);
          await Future.delayed(Duration(milliseconds: backoff));
          continue;
        }

        final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
        final candidates = decoded['candidates'] as List<dynamic>?;
        if (candidates == null || candidates.isEmpty) {
          lastError = Exception('empty candidates');
          final backoff = (pow(2, attempt) * 1000).toInt() + Random().nextInt(1000);
          await Future.delayed(Duration(milliseconds: backoff));
          continue;
        }
        final text = candidates[0]['content']?['parts']?[0]?['text'] as String?;
        if (text == null || text.trim().isEmpty) {
          lastError = Exception('empty text');
          final backoff = (pow(2, attempt) * 1000).toInt() + Random().nextInt(1000);
          await Future.delayed(Duration(milliseconds: backoff));
          continue;
        }
        debugPrint('[AI] 📝 Stage 3 raw: ${text.substring(0, text.length.clamp(0, 200))}');
        final parsed = _extractJson(text);
        if (parsed != null) return parsed;
        lastError = Exception('JSON parse failed: $text');
      } on Exception catch (e) {
        lastError = e;
        debugPrint('[AI] ❌ Stage 3 attempt $attempt: $e');
        if (attempt < 3) {
          final backoff = (pow(2, attempt) * 1000).toInt() + Random().nextInt(1000);
          await Future.delayed(Duration(milliseconds: backoff));
        }
      }
    }
    throw lastError ?? Exception('Stage 3: all attempts failed');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GEMINI HTTP CALLER — with retry + full logging
  // ─────────────────────────────────────────────────────────────────────────

  static Future<String> _geminiCall(String prompt, String b64,
      {required String stage, String mime = 'image/jpeg'}) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/$_apiVersion/models/$_model:generateContent?key=$_apiKey',
    );

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'inline_data': {'mime_type': mime, 'data': b64}},
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {'temperature': 0.05, 'maxOutputTokens': 4096},
    });

    debugPrint('[AI] 📡 Stage $stage — calling Gemini ($mime)...');
    Exception? lastError;

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final resp = await http
            .post(url, headers: {'Content-Type': 'application/json'}, body: body)
            .timeout(const Duration(seconds: 35));

        debugPrint('[AI] 📥 Stage $stage attempt $attempt — HTTP ${resp.statusCode} (${resp.body.length} bytes)');

        if (resp.statusCode != 200) {
          lastError = Exception('HTTP ${resp.statusCode}: ${resp.body.substring(0, resp.body.length.clamp(0, 200))}');
          debugPrint('[AI] ❌ Stage $stage HTTP error: $lastError');
          final backoff = (pow(2, attempt) * 1000).toInt() + Random().nextInt(1000);
          await Future.delayed(Duration(milliseconds: backoff));
          continue; // retry
        }

        // Parse candidates
        final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
        final candidates = decoded['candidates'] as List<dynamic>?;

        // Gemini blocked response (SAFETY / RECITATION)
        if (candidates == null || candidates.isEmpty) {
          final blockReason = decoded['promptFeedback']?['blockReason'] as String?;
          debugPrint('[AI] ⚠️ Stage $stage: empty candidates. blockReason=$blockReason');
          lastError = Exception('empty candidates: blockReason=$blockReason');
          // Safety blocks won't resolve on retry — break early
          if (blockReason != null) break;
          final backoff = (pow(2, attempt) * 1000).toInt() + Random().nextInt(1000);
          await Future.delayed(Duration(milliseconds: backoff));
          continue;
        }

        // Check finish reason
        final finishReason = candidates[0]['finishReason'] as String?;
        if (finishReason == 'SAFETY') {
          debugPrint('[AI] ⚠️ Stage $stage blocked by SAFETY filter');
          throw Exception('Stage $stage: blocked by SAFETY filter');
        }

        final text = candidates[0]['content']?['parts']?[0]?['text'] as String?;
        if (text == null || text.trim().isEmpty) {
          debugPrint('[AI] ❌ Stage $stage: null/empty text in response');
          lastError = Exception('empty text in response');
          final backoff = (pow(2, attempt) * 1000).toInt() + Random().nextInt(1000);
          await Future.delayed(Duration(milliseconds: backoff));
          continue;
        }

        debugPrint('[AI] 📝 Stage $stage raw[${text.length}]: ${text.substring(0, text.length.clamp(0, 250))}');
        return text;

      } on Exception catch (e) {
        lastError = e;
        debugPrint('[AI] ❌ Stage $stage attempt $attempt exception: $e');
        if (attempt < 3) {
          final backoff = (pow(2, attempt) * 1000).toInt() + Random().nextInt(1000);
          await Future.delayed(Duration(milliseconds: backoff));
        }
      }
    }

    throw lastError ?? Exception('Stage $stage: all 3 attempts failed');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // JSON EXTRACTION — strips markdown fences, finds first {...} block
  // ─────────────────────────────────────────────────────────────────────────

  static Map<String, dynamic>? _extractJson(String raw) {
    // Try 1: direct parse
    try {
      return jsonDecode(raw.trim()) as Map<String, dynamic>;
    } catch (_) {}

    // Try 2: strip markdown fences
    final stripped = raw
        .replaceAll(RegExp(r'```json\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();
    try {
      return jsonDecode(stripped) as Map<String, dynamic>;
    } catch (_) {}

    // Try 3: extract first {...} block via regex
    final match = RegExp(r'\{[\s\S]*\}').firstMatch(stripped);
    if (match != null) {
      try {
        return jsonDecode(match.group(0)!) as Map<String, dynamic>;
      } catch (_) {}
    }

    debugPrint('[AI] ❌ _extractJson failed on: $stripped');
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STAGE 4 — Shelf Life (local, no API)
  // ─────────────────────────────────────────────────────────────────────────

  static Map<String, dynamic> _stageShelfLife(
      String cat, String status, int score) {
    const baselines = {
      'fruits':      {'fresh': 48.0, 'moderate': 24.0, 'expiringSoon': 6.0, 'unsafe': 0.0},
      'vegetables':  {'fresh': 72.0, 'moderate': 36.0, 'expiringSoon': 12.0, 'unsafe': 0.0},
      'cookedMeals': {'fresh': 6.0,  'moderate': 3.0,  'expiringSoon': 1.0,  'unsafe': 0.0},
      'bakery':      {'fresh': 48.0, 'moderate': 24.0, 'expiringSoon': 6.0,  'unsafe': 0.0},
      'dairy':       {'fresh': 24.0, 'moderate': 12.0, 'expiringSoon': 3.0,  'unsafe': 0.0},
      'meat':        {'fresh': 4.0,  'moderate': 2.0,  'expiringSoon': 0.5,  'unsafe': 0.0},
      'beverages':   {'fresh': 24.0, 'moderate': 12.0, 'expiringSoon': 4.0,  'unsafe': 0.0},
      'other':       {'fresh': 24.0, 'moderate': 12.0, 'expiringSoon': 4.0,  'unsafe': 0.0},
    };

    final catMap = baselines[cat] ?? baselines['other']!;
    final baseHours = catMap[status] ?? 4.0;

    // Scale hours within tier based on score
    final tierPct = switch (status) {
      'fresh'        => (score - 85).clamp(0, 15) / 15.0,
      'moderate'     => (score - 50).clamp(0, 34) / 34.0,
      'expiringSoon' => (score - 20).clamp(0, 29) / 29.0,
      _              => 0.0,
    };
    final hours = (baseHours * (0.7 + tierPct * 0.6)).clamp(0.0, 72.0);

    final expiryRisk = switch (status) {
      'unsafe'       => 'unsafeToConsume',
      'expiringSoon' => 'donateQuickly',
      'moderate'     => 'donateQuickly',
      _              => 'safeToDonate',
    };

    return {'estimatedRemainingHours': hours, 'expiryRisk': expiryRisk};
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Derive freshness tier from spoilage score when Stage 3 fails
  static Map<String, dynamic> _deriveFromSpoilage(int spoilageScore) {
    final String status;
    final int score;
    if (spoilageScore > 70) {
      status = 'unsafe';
      score = 10;
    } else if (spoilageScore > 50) {
      status = 'expiringSoon';
      score = 35;
    } else if (spoilageScore > 30) {
      status = 'moderate';
      score = 55;
    } else {
      status = 'fresh';
      score = 85;
    }
    return {'freshnessStatus': status, 'freshnessScore': score, 'confidence': 0.50};
  }

  static String _freshnessGuide(String cat) => switch (cat) {
    'fruits'      => 'fresh≥85: vibrant color, firm. moderate 50–84: minor blemishes. expiringSoon 20–49: heavy browning/soft. unsafe<20: mold/rot',
    'vegetables'  => 'fresh≥85: crisp vivid. moderate 50–84: slight wilt. expiringSoon 20–49: slimy patches. unsafe<20: rot/mold',
    'cookedMeals' => 'fresh≥85: looks just cooked. moderate 50–84: slightly dried. expiringSoon 20–49: discolored/dried. unsafe<20: mold/off-color',
    'meat'        => 'fresh≥85: pink/red firm. moderate 50–84: edge color change. expiringSoon 20–49: grey patches. unsafe<20: grey/slimy',
    'dairy'       => 'fresh≥85: normal color intact. moderate 50–84: slight shift. expiringSoon 20–49: separation. unsafe<20: mold/swelling',
    'bakery'      => 'fresh≥85: normal no spots. moderate 50–84: slightly stale. expiringSoon 20–49: very dry. unsafe<20: ANY mold spot',
    _             => 'fresh≥85: looks good. moderate 50–84: minor issues. expiringSoon 20–49: deteriorating. unsafe<20: clear spoilage',
  };

  static String _buildRecommendation({
    required String cat,
    required String freshnessStr,
    required bool lowConf,
    required String moldSev,
    required double remainHours,
  }) {
    if (lowConf) return 'AI uncertain — inspect manually before donating.';
    return switch (freshnessStr) {
      'unsafe'       => moldSev != 'none' ? 'Mold detected. Do not donate.' : 'Spoilage detected. Not safe for donation.',
      'expiringSoon' => 'Donate immediately — ~${remainHours.round()}h remaining.',
      'moderate'     => 'Donate within ${remainHours.round()}h. Keep refrigerated.',
      _              => 'Food looks fresh. Safe to donate (~${remainHours.round()}h).',
    };
  }

  static FoodAnalysisResult _nonFoodResult(String reason) => FoodAnalysisResult(
        freshnessStatus: FreshnessStatus.unsafe,
        expiryRisk: ExpiryRisk.unsafeToConsume,
        foodCategory: FoodCategory.other,
        urgencyLevel: AiUrgencyLevel.critical,
        confidence: 0.95,
        freshnessScore: 0,
        estimatedRemainingHours: 0,
        scanEnabled: true,
        moderationPassed: false,
        safetyRecommendation: reason.isNotEmpty ? 'Not food: $reason' : 'Image does not contain food.',
        analyzedAt: DateTime.now(),
        rawNotes: 'moderation_failed',
        isFood: false,
        foodName: 'Not Food',
      );

  static FoodAnalysisResult _errorFallback(String err) {
    debugPrint('[AI] 🔴 _errorFallback: $err');
    return FoodAnalysisResult(
      freshnessStatus: FreshnessStatus.moderate,
      expiryRisk: ExpiryRisk.donateQuickly,
      foodCategory: FoodCategory.other,
      urgencyLevel: AiUrgencyLevel.normal,
      confidence: 0.40,
      freshnessScore: 50,
      estimatedRemainingHours: 4,
      scanEnabled: false,
      moderationPassed: true,
      safetyRecommendation: 'AI scan failed — verify freshness manually.',
      analyzedAt: DateTime.now(),
      rawNotes: 'error: $err',
      isFood: null,
      foodName: null,
    );
  }

  static FoodAnalysisResult _largeImageFallback() => FoodAnalysisResult(
        freshnessStatus: FreshnessStatus.moderate,
        expiryRisk: ExpiryRisk.donateQuickly,
        foodCategory: FoodCategory.other,
        urgencyLevel: AiUrgencyLevel.urgent,
        confidence: 0.40,
        freshnessScore: 50,
        estimatedRemainingHours: 6,
        scanEnabled: false,
        moderationPassed: true,
        safetyRecommendation: 'Image too large for AI scan — verify freshness manually.',
        analyzedAt: DateTime.now(),
        rawNotes: 'image_too_large',
        isFood: null,
        foodName: null,
      );

  static FreshnessStatus _toFreshnessStatus(String s) =>
      FreshnessStatus.values.firstWhere((e) => e.name == s, orElse: () => FreshnessStatus.moderate);

  static ExpiryRisk _toExpiryRisk(String s) =>
      ExpiryRisk.values.firstWhere((e) => e.name == s, orElse: () => ExpiryRisk.donateQuickly);

  static FoodCategory _toFoodCategory(String s) =>
      FoodCategory.values.firstWhere((e) => e.name == s, orElse: () => FoodCategory.other);
}

