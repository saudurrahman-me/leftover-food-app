import 'package:flutter/material.dart';
import 'admin_service.dart';
import 'admin_shared.dart';
import '../core/app_theme.dart';
import '../services/ai_monitoring_service.dart';
import '../services/ai_moderation_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// AI Monitoring Tab — reuses AiMonitoringService + AiModerationService.
class AdminAiTab extends StatefulWidget {
  const AdminAiTab({super.key});

  @override
  State<AdminAiTab> createState() => _AdminAiTabState();
}

class _AdminAiTabState extends State<AdminAiTab> {
  MonitoringSnapshot? _snapshot;
  List<PredictiveInsight> _insights = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    AiMonitoringService.clearCache();
    final results = await Future.wait([
      AiMonitoringService.getMonitoringSnapshot(),
      AiMonitoringService.getPredictiveInsights(),
    ]);
    if (mounted) {
      setState(() {
        _snapshot = results[0] as MonitoringSnapshot;
        _insights = results[1] as List<PredictiveInsight>;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminTabScaffold(
      title: 'AI Monitoring',
      subtitle: 'Live AI scan data, moderation queue, and insights',
      icon: Icons.psychology_rounded,
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
                Text('Refresh', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
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
                // ── Live Snapshot Cards ──────────────────────────────────────
                _sectionTitle('Live AI Snapshot'),
                const SizedBox(height: 12),
                if (_snapshot != null) _buildSnapshotGrid(_snapshot!),
                const SizedBox(height: 24),

                // ── Predictive Insights ──────────────────────────────────────
                _sectionTitle('Predictive Insights'),
                const SizedBox(height: 12),
                ..._insights.map(_buildInsightCard),
                const SizedBox(height: 24),

                // ── Moderation Queue ─────────────────────────────────────────
                _sectionTitle('Moderation Queue'),
                const SizedBox(height: 12),
                _buildModerationQueue(),
                const SizedBox(height: 24),

                // ── Unsafe / Blocked Posts ───────────────────────────────────
                _sectionTitle('Flagged / Unsafe Posts'),
                const SizedBox(height: 12),
                _buildUnsafePosts(),
              ],
            ),
    );
  }

  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)));

  Widget _buildSnapshotGrid(MonitoringSnapshot s) {
    final items = [
      _SnapItem('Urgent Donations', '${s.activeUrgentDonations}', Icons.warning_rounded, Colors.red),
      _SnapItem('Spoilage Risk Tasks', '${s.deliveriesAtSpoilageRisk}', Icons.dangerous_rounded, Colors.orange),
      _SnapItem('Blocked Posts', '${s.unsafeUploadsBlocked}', Icons.block_rounded, Colors.deepOrange),
      _SnapItem('Avg Delivery', '${s.avgDeliveryMinutes.toStringAsFixed(1)} min', Icons.timer_rounded, Colors.blue),
      _SnapItem('Waste Prevented', '${s.foodWastePreventedKg.toStringAsFixed(1)} kg', Icons.eco_rounded, Colors.green),
      _SnapItem('AI Success Rate', '${s.aiInterventionSuccessRate.toStringAsFixed(1)}%', Icons.trending_up_rounded, Colors.teal),
    ];

    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: item.color.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(item.icon, color: item.color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(item.value,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1F2937))),
              Text(item.label,
                  style: const TextStyle(color: AdminShared.textMuted, fontSize: 10),
                  textAlign: TextAlign.center),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInsightCard(PredictiveInsight insight) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(insight.trend,
                  style: TextStyle(fontSize: 20, color: AppTheme.primaryGreen)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(insight.label,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AdminShared.textPrimary)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(insight.value,
                          style: TextStyle(
                              color: AppTheme.primaryGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(insight.insight,
                    style: const TextStyle(
                        color: AdminShared.textMuted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModerationQueue() {
    return StreamBuilder<QuerySnapshot>(
      stream: AiModerationService.streamFlaggedPosts(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const AdminLoader();
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const AdminEmpty(message: 'Moderation queue is clear ✓');
        }
        return AdminTable(
          columns: const ['Post ID', 'Risk Score', 'Flags', 'Status', 'Actions'],
          columnWidths: const {
            2: FlexColumnWidth(2),
            4: FixedColumnWidth(140),
          },
          rows: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final flags = (data['flags'] as List?)?.join(', ') ?? '—';
            final score = data['fraudRiskScore'] ?? 0;
            final status = data['status'] ?? 'pending_review';
            return [
              Text(doc.id.substring(0, 8),
                  style: AdminShared.cellMutedStyle),
              Text('$score / 100',
                  style: TextStyle(
                      color: score >= 60 ? AdminShared.danger : AdminShared.warning,
                      fontWeight: FontWeight.bold, fontSize: 12)),
              Text(flags,
                  style: AdminShared.cellMutedStyle,
                  overflow: TextOverflow.ellipsis),
              AdminStatusBadge(status: status),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AdminIconBtn(
                    icon: Icons.check_rounded,
                    color: AdminShared.success,
                    tooltip: 'Approve',
                    onTap: () {
                      AdminShared.runAsync(
                        context: context,
                        action: () => AiModerationService.markReviewed(doc.id, approve: true),
                        successMsg: 'Post approved',
                      );
                    },
                  ),
                  const SizedBox(width: 6),
                  AdminIconBtn(
                    icon: Icons.close_rounded,
                    color: AdminShared.danger,
                    tooltip: 'Reject',
                    onTap: () {
                      AdminShared.runAsync(
                        context: context,
                        action: () => AiModerationService.markReviewed(doc.id, approve: false),
                        successMsg: 'Post rejected',
                      );
                    },
                  ),
                ],
              ),
            ];
          }).toList(),
        );
      },
    );
  }

  Widget _buildUnsafePosts() {
    return StreamBuilder<QuerySnapshot>(
      stream: AdminService.streamUnsafePosts(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const AdminLoader();
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const AdminEmpty(message: 'No unsafe posts flagged.');
        }
        return AdminTable(
          columns: const ['Title', 'Donor', 'AI Status', 'Actions'],
          columnWidths: const {
            2: FixedColumnWidth(120),
            3: FixedColumnWidth(80),
          },
          rows: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return [
              Text(data['foodName'] ?? data['title'] ?? '—',
                  style: AdminShared.cellStyle, overflow: TextOverflow.ellipsis),
              Text(data['donorName'] ?? '—',
                  style: AdminShared.cellMutedStyle, overflow: TextOverflow.ellipsis),
              AdminStatusBadge(status: data['aiFreshnessStatus'] ?? 'flagged'),
              AdminIconBtn(
                icon: Icons.delete_rounded,
                color: AdminShared.danger,
                tooltip: 'Remove',
                onTap: () {
                  AdminShared.runAsync(
                    context: context,
                    action: () => AdminService.deletePost(doc.id),
                    successMsg: 'Unsafe post deleted',
                  );
                },
              ),
            ];
          }).toList(),
        );
      },
    );
  }
}

class _SnapItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _SnapItem(this.label, this.value, this.icon, this.color);
}
