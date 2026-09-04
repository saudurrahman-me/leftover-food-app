/// Food Analysis Result Card Widget
///
/// Displays AI freshness scan results with colour-coded status,
/// confidence bar, risk badge, and safety recommendation.
/// Used inside AddFoodPostPage after an AI scan completes.
library;

import 'package:flutter/material.dart';
import '../models/food_analysis_model.dart';

class FoodAnalysisCard extends StatelessWidget {
  final FoodAnalysisResult result;

  const FoodAnalysisCard({super.key, required this.result});

  // ─── Colour mapping ───────────────────────────────────────────────────────

  static Color _statusColor(FreshnessStatus s) {
    switch (s) {
      case FreshnessStatus.fresh:
        return const Color(0xFF27AE60);
      case FreshnessStatus.moderate:
        return const Color(0xFFF39C12);
      case FreshnessStatus.expiringSoon:
        return const Color(0xFFE67E22);
      case FreshnessStatus.unsafe:
        return const Color(0xFFE74C3C);
    }
  }

  static IconData _statusIcon(FreshnessStatus s) {
    switch (s) {
      case FreshnessStatus.fresh:
        return Icons.check_circle_rounded;
      case FreshnessStatus.moderate:
        return Icons.info_rounded;
      case FreshnessStatus.expiringSoon:
        return Icons.warning_amber_rounded;
      case FreshnessStatus.unsafe:
        return Icons.dangerous_rounded;
    }
  }

  static Color _riskColor(ExpiryRisk r) {
    switch (r) {
      case ExpiryRisk.safeToDonate:
        return const Color(0xFF27AE60);
      case ExpiryRisk.donateQuickly:
        return const Color(0xFFF39C12);
      case ExpiryRisk.unsafeToConsume:
        return const Color(0xFFE74C3C);
    }
  }

  static IconData _categoryIcon(FoodCategory c) {
    switch (c) {
      case FoodCategory.fruits:
        return Icons.apple_rounded;
      case FoodCategory.vegetables:
        return Icons.eco_rounded;
      case FoodCategory.cookedMeals:
        return Icons.restaurant_rounded;
      case FoodCategory.bakery:
        return Icons.bakery_dining_rounded;
      case FoodCategory.dairy:
        return Icons.water_drop_rounded;
      case FoodCategory.meat:
        return Icons.set_meal_rounded;
      case FoodCategory.beverages:
        return Icons.local_drink_rounded;
      case FoodCategory.other:
        return Icons.food_bank_rounded;
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(result.freshnessStatus);
    final isUnsafe = result.isUnsafe;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header banner
          _buildHeader(color),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row: Category + Risk badge
                Row(
                  children: [
                    _buildCategoryChip(),
                    const SizedBox(width: 8),
                    _buildRiskBadge(),
                  ],
                ),
                const SizedBox(height: 14),

                // Confidence bar
                _buildConfidenceBar(color),
                const SizedBox(height: 14),

                // Detected Items (New Section)
                if (result.detectedItems.isNotEmpty) ...[
                  _buildDetectedItems(),
                  const SizedBox(height: 14),
                ],

                // Safety recommendation
                _buildRecommendation(isUnsafe),

                // Unsafe warning banner
                if (isUnsafe) ...[
                  const SizedBox(height: 12),
                  _buildUnsafeWarning(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // AI badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.auto_awesome, color: Colors.white, size: 13),
                SizedBox(width: 4),
                Text(
                  'AI SCAN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Icon(_statusIcon(result.freshnessStatus), color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Text(
            result.freshnessLabel,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const Spacer(),
          // Scan status dot
          if (!result.scanEnabled)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'OFFLINE',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_categoryIcon(result.foodCategory), size: 14, color: const Color(0xFF5C6BC0)),
          const SizedBox(width: 5),
          Text(
            result.foodCategoryLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3949AB),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskBadge() {
    final color = _riskColor(result.expiryRisk);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        result.expiryRiskLabel.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildConfidenceBar(Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Freshness Confidence',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
            Text(
              '${result.confidencePercent}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: result.confidence,
            minHeight: 8,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendation(bool isUnsafe) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isUnsafe ? Icons.block_rounded : Icons.lightbulb_outline_rounded,
          size: 16,
          color: isUnsafe ? const Color(0xFFE74C3C) : const Color(0xFF6B7280),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            result.safetyRecommendation,
            style: TextStyle(
              fontSize: 13,
              color: isUnsafe ? const Color(0xFFE74C3C) : const Color(0xFF374151),
              fontWeight: isUnsafe ? FontWeight.w700 : FontWeight.w500,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUnsafeWarning() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: const [
          Icon(Icons.report_problem_rounded, color: Color(0xFFE74C3C), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'This food may be unsafe for donation. Please review before submitting.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF991B1B),
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectedItems() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Detected Items',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 8),
        ...result.detectedItems.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3, right: 6),
                  child: Icon(Icons.circle, size: 6, color: Color(0xFF6B7280)),
                ),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                      children: [
                        TextSpan(
                          text: '${item.name}: ',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(
                          text: item.details,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading shimmer card shown while AI is scanning
// ─────────────────────────────────────────────────────────────────────────────

class FoodAnalysisLoadingCard extends StatefulWidget {
  const FoodAnalysisLoadingCard({super.key});

  @override
  State<FoodAnalysisLoadingCard> createState() => _FoodAnalysisLoadingCardState();
}

class _FoodAnalysisLoadingCardState extends State<FoodAnalysisLoadingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Opacity(
        opacity: _pulse.value,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD1FAE5), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: const [
                  Icon(Icons.auto_awesome, color: Colors.green, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'AI Scanning Food...',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF065F46),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: const LinearProgressIndicator(
                  minHeight: 6,
                  backgroundColor: Color(0xFFD1FAE5),
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Analysing freshness, detecting food type\nand estimating spoilage risk…',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

