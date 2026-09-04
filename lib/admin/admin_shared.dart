/// admin_shared.dart
/// Reusable widgets + constants for the Admin dashboard tabs.
/// Styled to match the FoodShare app_theme (light, green accent, white cards).
library;

import 'package:flutter/material.dart';
import '../core/app_theme.dart';

// ── Colour tokens (maps to app_theme) ────────────────────────────────────────
abstract class AdminShared {
  // These remain for backward compat inside tab files
  static const Color bg = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color card = Colors.white;
  static const Color border = Color(0xFFE5E7EB);
  static final Color accent = AppTheme.primaryGreen;
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color success = Color(0xFF10B981);

  static const TextStyle cellStyle =
      TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500);
  static const TextStyle cellMutedStyle =
      TextStyle(color: textMuted, fontSize: 12);
  static const TextStyle cellNumStyle =
      TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.bold);

  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'approved':
      case 'delivered':
      case 'completed':
      case 'ongoing':
        return success;
      case 'pending':
      case 'upcoming':
      case 'assigned':
        return warning;
      case 'claimed':
      case 'in_progress':
        return info;
      case 'rejected':
      case 'cancelled':
        return danger;
      default:
        return textMuted;
    }
  }

  static Color roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':     return danger;
      case 'donor':     return AppTheme.primaryGreen;
      case 'ngo':       return purple;
      case 'volunteer': return info;
      case 'receiver':  return warning;
      default:          return textMuted;
    }
  }

  static Future<void> runAsync({
    required BuildContext context,
    required Future<void> Function() action,
    required String successMsg,
    VoidCallback? onComplete,
  }) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.green),
      ),
    );

    try {
      // Add a timeout to prevent infinite hang
      await action().timeout(const Duration(seconds: 10));
      
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        if (onComplete != null) onComplete(); // Close edit/delete dialog if provided
        
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(successMsg),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e, st) {
      debugPrint("ERROR in runAsync: $e\n$st");
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}

// ── AdminTabScaffold ──────────────────────────────────────────────────────────
/// Wraps each tab with an optional filter row + scrollable white body.
class AdminTabScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? filterRow;
  final Widget child;

  const AdminTabScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.filterRow,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminShared.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (filterRow != null)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: filterRow!,
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

// ── AdminTable ────────────────────────────────────────────────────────────────
class AdminTable extends StatelessWidget {
  final List<String> columns;
  final Map<int, TableColumnWidth>? columnWidths;
  final List<List<Widget>> rows;

  const AdminTable({
    super.key,
    required this.columns,
    required this.rows,
    this.columnWidths,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width - 32,
          ),
          child: Table(
            columnWidths: columnWidths ?? const {},
            border: TableBorder(
              horizontalInside: BorderSide(
                color: AdminShared.border,
                width: 1,
              ),
            ),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              // Header row
              TableRow(
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.06),
                ),
                children: columns
                    .map((col) => Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Text(
                            col,
                            style: TextStyle(
                              color: AppTheme.primaryGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ))
                    .toList(),
              ),
              // Data rows
              ...rows.asMap().entries.map((entry) {
                final i = entry.key;
                final cells = entry.value;
                return TableRow(
                  decoration: BoxDecoration(
                    color: i.isOdd
                        ? const Color(0xFFF9FAFB)
                        : Colors.white,
                  ),
                  children: cells
                      .map((cell) => Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            child: cell,
                          ))
                      .toList(),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// ── AdminStatusBadge ──────────────────────────────────────────────────────────
class AdminStatusBadge extends StatelessWidget {
  final String status;
  const AdminStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = AdminShared.statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ── AdminRoleBadge ────────────────────────────────────────────────────────────
class AdminRoleBadge extends StatelessWidget {
  final String role;
  const AdminRoleBadge({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final color = AdminShared.roleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        role,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ── AdminIconBtn ──────────────────────────────────────────────────────────────
class AdminIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const AdminIconBtn({
    super.key,
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
      ),
    );
  }
}

// ── AdminSearchField ──────────────────────────────────────────────────────────
class AdminSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  const AdminSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: AdminShared.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AdminShared.textMuted, fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded,
              color: AppTheme.primaryGreen, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
        ),
      ),
    );
  }
}

// ── AdminFilterChips ──────────────────────────────────────────────────────────
class AdminFilterChips extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const AdminFilterChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((opt) {
          final sel = opt == selected;
          return GestureDetector(
            onTap: () => onSelected(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? AppTheme.primaryGreen : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sel ? AppTheme.primaryGreen : AdminShared.border,
                ),
                boxShadow: sel
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Text(
                opt,
                style: TextStyle(
                  color: sel ? Colors.white : AdminShared.textMuted,
                  fontSize: 12,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── AdminLoader / AdminEmpty / AdminError ─────────────────────────────────────
class AdminLoader extends StatelessWidget {
  const AdminLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: CircularProgressIndicator(color: AppTheme.primaryGreen),
      ),
    );
  }
}

class AdminEmpty extends StatelessWidget {
  final String message;
  const AdminEmpty({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, color: Colors.grey.shade300, size: 52),
            const SizedBox(height: 14),
            Text(message,
                style: const TextStyle(color: AdminShared.textMuted, fontSize: 14),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class AdminError extends StatelessWidget {
  final String message;
  const AdminError({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AdminShared.danger, size: 44),
            const SizedBox(height: 12),
            Text('Error: $message',
                style: const TextStyle(color: AdminShared.danger, fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── AdminDialog ───────────────────────────────────────────────────────────────
/// Glassmorphism-style dialog matching notifications_page.dart cards.
class AdminDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final VoidCallback onConfirm;
  final String confirmLabel;

  const AdminDialog({
    super.key,
    required this.title,
    required this.content,
    required this.onConfirm,
    this.confirmLabel = 'Save',
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          // filter removed for Web stability
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 30,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.settings_rounded,
                              color: AppTheme.primaryGreen, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(title,
                            style: const TextStyle(
                                color: AdminShared.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 17)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(height: 1),
                    const SizedBox(height: 20),
                    content,
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel',
                              style: TextStyle(color: AdminShared.textMuted)),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 22, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            textStyle: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: onConfirm,
                          child: Text(confirmLabel),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── AdminConfirmDialog ────────────────────────────────────────────────────────
class AdminConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final bool isDestructive;
  final VoidCallback onConfirm;

  const AdminConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onConfirm,
    this.confirmLabel = 'Confirm',
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isDestructive ? AdminShared.danger : AppTheme.primaryGreen;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          // filter removed for Web stability
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: color.withValues(alpha: 0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 30,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDestructive
                        ? Icons.warning_amber_rounded
                        : Icons.help_outline_rounded,
                    color: color,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                Text(title,
                    style: const TextStyle(
                        color: AdminShared.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 17)),
                const SizedBox(height: 10),
                Text(message,
                    style: const TextStyle(
                        color: AdminShared.textMuted, fontSize: 13),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AdminShared.border),
                          foregroundColor: AdminShared.textMuted,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          textStyle: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
                        onPressed: onConfirm,
                        child: Text(confirmLabel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── AdminDialogField ──────────────────────────────────────────────────────────
class AdminDialogField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;

  const AdminDialogField({
    super.key,
    required this.label,
    required this.controller,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AdminShared.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF4F6FA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(
                color: AdminShared.textPrimary, fontSize: 14),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}

// ── AdminDropdownField ────────────────────────────────────────────────────────
class AdminDropdownField<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;

  const AdminDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AdminShared.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F6FA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: Colors.white,
              style: const TextStyle(
                  color: AdminShared.textPrimary, fontSize: 14),
              icon: Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.primaryGreen),
              items: items
                  .map((i) => DropdownMenuItem<T>(
                        value: i,
                        child: Text(i.toString()),
                      ))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
