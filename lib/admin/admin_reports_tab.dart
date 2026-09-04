import 'package:flutter/material.dart';
import 'admin_service.dart';
import 'admin_shared.dart';
import '../core/app_theme.dart';

/// Reports & Analytics Tab — charts built with Flutter's built-in Canvas.
/// No additional packages needed — uses CustomPainter bar charts.
class AdminReportsTab extends StatefulWidget {
  const AdminReportsTab({super.key});

  @override
  State<AdminReportsTab> createState() => _AdminReportsTabState();
}

class _AdminReportsTabState extends State<AdminReportsTab> {
  Map<String, int> _postStatusData = {};
  Map<String, int> _donationsPerDay = {};
  Map<String, int> _registrationsPerDay = {};
  Map<String, int> _categoryData = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final postStatus = AdminService.getPostStatusBreakdown();
      final donations = AdminService.getDonationsPerDay(7);
      final registrations = AdminService.getUserRegistrationsPerDay(7);
      final categories = AdminService.getFoodCategoryBreakdown();
      final results = await Future.wait([postStatus, donations, registrations, categories]);
      if (mounted) {
        setState(() {
          _postStatusData = Map<String, int>.from(results[0] as Map);
          _donationsPerDay = Map<String, int>.from(results[1] as Map);
          _registrationsPerDay = Map<String, int>.from(results[2] as Map);
          _categoryData = Map<String, int>.from(results[3] as Map);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminTabScaffold(
      title: 'Reports & Analytics',
      subtitle: 'Platform statistics and performance metrics',
      icon: Icons.bar_chart_rounded,
      filterRow: Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onTap: _load,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text('Refresh',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
      child: _loading
          ? const AdminLoader()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildChartCard('Donations Last 7 Days', _donationsPerDay, Colors.green),
                const SizedBox(height: 16),
                _buildChartCard('New Users Last 7 Days', _registrationsPerDay, Colors.blue),
                const SizedBox(height: 16),
                _buildPieSection('Post Status Breakdown', _postStatusData),
                const SizedBox(height: 16),
                _buildPieSection('Food Categories', _categoryData),
              ],
            ),
    );
  }

  Widget _buildChartCard(String title, Map<String, int> data, Color color) {
    if (data.isEmpty) {
      return _emptyChart(title);
    }
    final maxVal = data.values.fold(1, (a, b) => a > b ? a : b);
    final entries = data.entries.toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF1F2937))),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: entries.map((e) {
                final heightFactor = maxVal > 0 ? e.value / maxVal : 0.0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${e.value}',
                            style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOut,
                          height: (100 * heightFactor).clamp(4, 100),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(e.key,
                            style: const TextStyle(
                                fontSize: 9, color: AdminShared.textMuted)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieSection(String title, Map<String, int> data) {
    if (data.isEmpty) return _emptyChart(title);
    final total = data.values.fold(0, (a, b) => a + b);
    final colors = [
      Colors.green, Colors.blue, Colors.orange,
      Colors.purple, Colors.teal, Colors.red, Colors.indigo, Colors.pink,
    ];
    final entries = data.entries.toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF1F2937))),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(entries.length, (i) {
              final e = entries[i];
              final pct = total > 0 ? (e.value / total * 100).toStringAsFixed(1) : '0';
              final col = colors[i % colors.length];
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                        color: col, borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: 5),
                  Text('${e.key} ($pct%)',
                      style: const TextStyle(
                          fontSize: 12, color: AdminShared.textPrimary)),
                ],
              );
            }),
          ),
          const SizedBox(height: 16),
          // Stacked bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 16,
              child: Row(
                children: List.generate(entries.length, (i) {
                  final ratio = total > 0 ? entries[i].value / total : 0.0;
                  return Flexible(
                    flex: (ratio * 1000).round().clamp(1, 1000),
                    child: Container(color: colors[i % colors.length]),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(entries.length, (i) {
            final e = entries[i];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: colors[i % colors.length],
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 8),
                  Text(e.key, style: AdminShared.cellMutedStyle),
                  const Spacer(),
                  Text('${e.value}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AdminShared.textPrimary)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _emptyChart(String title) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ]),
      child: Column(
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF1F2937))),
          const SizedBox(height: 20),
          const AdminEmpty(message: 'No data available yet.'),
        ],
      ),
    );
  }
}
