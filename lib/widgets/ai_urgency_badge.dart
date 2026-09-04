/// Reusable AI Urgency & Freshness Badge Widgets
///
/// Used across ReceiverHomePage, NGODonationsPage, VolunteerAvailableTasksPage.
/// Reads directly from Firestore post/task data maps.
library;

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colour palette
// ─────────────────────────────────────────────────────────────────────────────

class AiBadgeColors {
  static const fresh = Color(0xFF27AE60);
  static const moderate = Color(0xFFF39C12);
  static const expiringSoon = Color(0xFFE67E22);
  static const unsafe = Color(0xFFE74C3C);

  static Color forStatus(String? status) {
    switch (status) {
      case 'fresh':
        return fresh;
      case 'moderate':
        return moderate;
      case 'expiringSoon':
        return expiringSoon;
      case 'unsafe':
        return unsafe;
      default:
        return Colors.grey;
    }
  }

  static Color forUrgency(String? urgency) {
    switch (urgency) {
      case 'critical':
        return unsafe;
      case 'urgent':
        return expiringSoon;
      case 'normal':
        return fresh;
      default:
        return Colors.grey.shade400;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI Freshness Status Badge (Green / Yellow / Orange / Red pill)
// ─────────────────────────────────────────────────────────────────────────────

class AiFreshnessBadge extends StatelessWidget {
  final String? status;    // 'fresh' | 'moderate' | 'expiringSoon' | 'unsafe'
  final bool compact;

  const AiFreshnessBadge({super.key, required this.status, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (status == null || status!.isEmpty) return const SizedBox(width: 1, height: 1);

    final color = AiBadgeColors.forStatus(status);
    final label = _label(status!);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 3 : 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: compact ? 10 : 12, color: color),
          SizedBox(width: compact ? 3 : 4),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 9 : 11,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  static String _label(String status) {
    switch (status) {
      case 'fresh': return 'Fresh';
      case 'moderate': return 'Moderate';
      case 'expiringSoon': return 'Expiring Soon';
      case 'unsafe': return 'Unsafe';
      default: return status;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI Urgency Badge (pulsing for critical/urgent)
// ─────────────────────────────────────────────────────────────────────────────

class AiUrgencyBadge extends StatefulWidget {
  final String? urgency;   // 'normal' | 'urgent' | 'critical'
  final bool compact;

  const AiUrgencyBadge({super.key, required this.urgency, this.compact = false});

  @override
  State<AiUrgencyBadge> createState() => _AiUrgencyBadgeState();
}

class _AiUrgencyBadgeState extends State<AiUrgencyBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _shouldPulse =>
      widget.urgency == 'critical' || widget.urgency == 'urgent';

  @override
  Widget build(BuildContext context) {
    if (widget.urgency == null || widget.urgency == 'normal') {
      return const SizedBox(width: 1, height: 1);
    }

    final color = AiBadgeColors.forUrgency(widget.urgency);
    final label = widget.urgency == 'critical' ? '🔴 CRITICAL' : '🟠 URGENT';

    final badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 6 : 10,
        vertical: widget.compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: widget.compact ? 9 : 11,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );

    if (_shouldPulse) {
      return AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) => Opacity(opacity: _pulse.value, child: child),
        child: badge,
      );
    }
    return badge;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Countdown / Remaining Hours Badge
// ─────────────────────────────────────────────────────────────────────────────

class AiCountdownBadge extends StatelessWidget {
  final double? remainingHours;
  final bool compact;

  const AiCountdownBadge({super.key, required this.remainingHours, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (remainingHours == null || remainingHours! <= 0) return const SizedBox(width: 1, height: 1);

    Color color;
    String label;

    if (remainingHours! < 2) {
      color = const Color(0xFFE74C3C);
      label = '${(remainingHours! * 60).round()}m left';
    } else if (remainingHours! < 6) {
      color = const Color(0xFFE67E22);
      label = '${remainingHours!.toStringAsFixed(0)}h left';
    } else {
      color = const Color(0xFF27AE60);
      label = '${remainingHours!.toStringAsFixed(0)}h left';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 8, vertical: compact ? 2 : 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: compact ? 10 : 12, color: color),
          SizedBox(width: compact ? 2 : 4),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 9 : 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Combined AI Info Row (badge + urgency + countdown in one line)
// ─────────────────────────────────────────────────────────────────────────────

class AiInfoRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool compact;

  const AiInfoRow({super.key, required this.data, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final status = data['aiFreshnessStatus'] as String?;
    final urgency = data['aiUrgencyLevel'] as String?;
    final remaining = (data['estimatedRemainingHours'] as num?)?.toDouble();
    final scanEnabled = data['aiScanEnabled'] as bool? ?? false;

    if (!scanEnabled && status == null) return const SizedBox(width: 1, height: 1);

    final List<Widget> badges = [];
    if (status != null) badges.add(AiFreshnessBadge(status: status, compact: compact));
    if (urgency != null && urgency != 'normal') {
      badges.add(AiUrgencyBadge(urgency: urgency, compact: compact));
    }
    if (remaining != null && remaining > 0) {
      badges.add(AiCountdownBadge(remainingHours: remaining, compact: compact));
    }

    if (badges.isEmpty) return const SizedBox(width: 1, height: 1);

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: badges,
    );
  }
}

