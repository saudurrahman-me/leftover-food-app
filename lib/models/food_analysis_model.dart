/// AI Food Analysis Result Model — v2
///
/// Extended with:
///   • aiUrgencyLevel  (normal / urgent / critical)
///   • aiFreshnessScore (0–100 numeric for sorting)
///   • estimatedRemainingHours (how many hours food is safe)
///   • postPriority    (normal / urgent)
///   • aiModerationPassed (image is real food + usable quality)
library;

enum FreshnessStatus { fresh, moderate, expiringSoon, unsafe }

enum ExpiryRisk { safeToDonate, donateQuickly, unsafeToConsume }

enum AiUrgencyLevel { normal, urgent, critical }

enum FoodCategory {
  fruits,
  vegetables,
  cookedMeals,
  bakery,
  dairy,
  meat,
  beverages,
  other,
}

class DetectedItem {
  final String name;
  final String details;
  
  DetectedItem({required this.name, required this.details});
  
  Map<String, dynamic> toMap() => {'name': name, 'details': details};
  factory DetectedItem.fromMap(Map<String, dynamic> map) => 
      DetectedItem(name: map['name'] ?? '', details: map['details'] ?? '');
}

class FoodAnalysisResult {
  final FreshnessStatus freshnessStatus;
  final ExpiryRisk expiryRisk;
  final FoodCategory foodCategory;
  final AiUrgencyLevel urgencyLevel;

  /// 0.0 – 1.0 confidence from AI (displayed as percentage)
  final double confidence;

  /// 0–100 freshness score for numeric sorting (100 = perfectly fresh)
  final int freshnessScore;

  /// Estimated hours the food remains safe for consumption
  final double estimatedRemainingHours;

  /// Whether the AI scan was actually performed (vs. skipped/failed)
  final bool scanEnabled;

  /// true = image is real food AND meets quality bar (not blurry/dark/non-food)
  final bool moderationPassed;

  /// Human-readable safety recommendation
  final String safetyRecommendation;

  /// Timestamp of when analysis was performed
  final DateTime analyzedAt;

  /// Optional raw notes from the AI model for debugging
  final String? rawNotes;

  /// The specific name/type of food detected by AI (e.g., "Apple", "Pizza")
  final String? foodName;

  /// List of individual food items detected and their details
  final List<DetectedItem> detectedItems;

  /// Whether the AI determined the image contains food
  final bool? isFood;

  const FoodAnalysisResult({
    required this.freshnessStatus,
    required this.expiryRisk,
    required this.foodCategory,
    required this.urgencyLevel,
    required this.confidence,
    required this.freshnessScore,
    required this.estimatedRemainingHours,
    required this.scanEnabled,
    required this.moderationPassed,
    required this.safetyRecommendation,
    required this.analyzedAt,
    this.rawNotes,
    this.foodName,
    this.detectedItems = const [],
    this.isFood,
  });

  // ─── Firestore serialization ──────────────────────────────────────────────

  Map<String, dynamic> toFirestore() {
    return {
      'aiFreshnessStatus': freshnessStatus.name,
      'aiExpiryRisk': expiryRisk.name,
      'aiFoodCategory': foodCategory.name,
      'aiUrgencyLevel': urgencyLevel.name,
      'aiConfidence': confidencePercent,
      'aiFreshnessScore': freshnessScore,
      'estimatedRemainingHours': estimatedRemainingHours,
      'postPriority': urgencyLevel == AiUrgencyLevel.normal ? 'normal' : 'urgent',
      'aiModerationPassed': moderationPassed,
      'aiSafetyRecommendation': safetyRecommendation,
      'aiScanEnabled': scanEnabled,
      'aiAnalyzedAt': analyzedAt.toUtc().toIso8601String(),
      if (foodName != null) 'aiFoodName': foodName,
      'detectedItems': detectedItems.map((i) => i.toMap()).toList(),
      if (isFood != null) 'aiIsFood': isFood,
    };
  }

  factory FoodAnalysisResult.fromFirestore(Map<String, dynamic> data) {
    return FoodAnalysisResult(
      freshnessStatus: FreshnessStatus.values.firstWhere(
        (e) => e.name == data['aiFreshnessStatus'],
        orElse: () => FreshnessStatus.moderate,
      ),
      expiryRisk: ExpiryRisk.values.firstWhere(
        (e) => e.name == data['aiExpiryRisk'],
        orElse: () => ExpiryRisk.donateQuickly,
      ),
      foodCategory: FoodCategory.values.firstWhere(
        (e) => e.name == data['aiFoodCategory'],
        orElse: () => FoodCategory.other,
      ),
      urgencyLevel: AiUrgencyLevel.values.firstWhere(
        (e) => e.name == data['aiUrgencyLevel'],
        orElse: () => AiUrgencyLevel.normal,
      ),
      confidence: ((data['aiConfidence'] ?? 0) as num) / 100.0,
      freshnessScore: (data['aiFreshnessScore'] ?? 50) as int,
      estimatedRemainingHours:
          ((data['estimatedRemainingHours'] ?? 0) as num).toDouble(),
      scanEnabled: data['aiScanEnabled'] ?? false,
      moderationPassed: data['aiModerationPassed'] ?? true,
      safetyRecommendation: data['aiSafetyRecommendation'] ?? '',
      analyzedAt: DateTime.tryParse(data['aiAnalyzedAt'] ?? '') ?? DateTime.now(),
      foodName: data['aiFoodName'],
      detectedItems: (data['detectedItems'] as List<dynamic>?)
              ?.map((item) => DetectedItem.fromMap(Map<String, dynamic>.from(item)))
              .toList() ??
          [],
      isFood: data['aiIsFood'],
    );
  }

  // ─── Display helpers ──────────────────────────────────────────────────────

  String get freshnessLabel {
    switch (freshnessStatus) {
      case FreshnessStatus.fresh:
        return 'Fresh';
      case FreshnessStatus.moderate:
        return 'Moderate';
      case FreshnessStatus.expiringSoon:
        return 'Expiring Soon';
      case FreshnessStatus.unsafe:
        return 'Unsafe';
    }
  }

  String get expiryRiskLabel {
    switch (expiryRisk) {
      case ExpiryRisk.safeToDonate:
        return 'Safe for Donation';
      case ExpiryRisk.donateQuickly:
        return 'Donate Quickly';
      case ExpiryRisk.unsafeToConsume:
        return 'Unsafe to Consume';
    }
  }

  String get urgencyLabel {
    switch (urgencyLevel) {
      case AiUrgencyLevel.normal:
        return 'Normal';
      case AiUrgencyLevel.urgent:
        return 'Urgent';
      case AiUrgencyLevel.critical:
        return 'Critical';
    }
  }

  String get foodCategoryLabel {
    switch (foodCategory) {
      case FoodCategory.fruits:
        return 'Fruits';
      case FoodCategory.vegetables:
        return 'Vegetables';
      case FoodCategory.cookedMeals:
        return 'Cooked Meals';
      case FoodCategory.bakery:
        return 'Bakery';
      case FoodCategory.dairy:
        return 'Dairy';
      case FoodCategory.meat:
        return 'Meat';
      case FoodCategory.beverages:
        return 'Beverages';
      case FoodCategory.other:
        return 'Other';
    }
  }

  int get confidencePercent => (confidence * 100).round();

  /// Returns true when food is unsafe — upload MUST be blocked
  bool get isUnsafe =>
      freshnessStatus == FreshnessStatus.unsafe ||
      expiryRisk == ExpiryRisk.unsafeToConsume ||
      !moderationPassed;

  /// Returns true when donor should see a caution warning (non-blocking)
  bool get requiresWarning =>
      freshnessStatus == FreshnessStatus.expiringSoon ||
      expiryRisk == ExpiryRisk.donateQuickly ||
      confidence < 0.5;

  String get countdownLabel {
    if (estimatedRemainingHours <= 0) return 'Expired';
    if (estimatedRemainingHours < 1) {
      return '${(estimatedRemainingHours * 60).round()} min left';
    }
    return '${estimatedRemainingHours.toStringAsFixed(0)}h left';
  }
}

