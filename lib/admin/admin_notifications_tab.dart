import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_shared.dart';
import '../core/app_theme.dart';
import '../notification_service.dart';

class AdminNotificationsTab extends StatefulWidget {
  const AdminNotificationsTab({super.key});

  @override
  State<AdminNotificationsTab> createState() => _AdminNotificationsTabState();
}

class _AdminNotificationsTabState extends State<AdminNotificationsTab> {
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  String _targetRole = 'All';
  bool _isSending = false;

  final _roles = ['All', 'Donor', 'Receiver', 'Volunteer', 'NGO'];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  // ── Backend logic unchanged ───────────────────────────────────────────────────
  Future<void> _sendNotification() async {
    if (_titleCtrl.text.trim().isEmpty || _messageCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and message are required.')),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      // 1. Keep a record for admin history
      await FirebaseFirestore.instance.collection('notifications').add({
        'title': _titleCtrl.text.trim(),
        'message': _messageCtrl.text.trim(),
        'targetRole': _targetRole,
        'sentAt': FieldValue.serverTimestamp(),
        'sentBy': 'admin',
        'type': 'announcement',
        // Admin broadcast history uses 'recipientId'='admin_broadcast' so it won't clutter normal user feeds directly.
        'recipientId': 'admin_broadcast',
      });

      // 2. Actually send individual notifications to all users of that role
      if (_targetRole == 'All') {
        for (String r in ['Donor', 'Receiver', 'Volunteer', 'NGO']) {
          await NotificationService.notifyAllByRole(
            role: r,
            title: _titleCtrl.text.trim(),
            message: _messageCtrl.text.trim(),
            type: 'announcement',
          );
        }
      } else {
        await NotificationService.notifyAllByRole(
          role: _targetRole,
          title: _titleCtrl.text.trim(),
          message: _messageCtrl.text.trim(),
          type: 'announcement',
        );
      }
      _titleCtrl.clear();
      _messageCtrl.clear();
      setState(() => _targetRole = 'All');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Notification sent successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _deleteNotification(String docId) {
    AdminShared.runAsync(
      context: context,
      action: () => FirebaseFirestore.instance.collection('notifications').doc(docId).delete(),
      successMsg: 'Notification deleted',
    );
  }

  // ── UI ────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Compose card ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card header
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.edit_notifications_rounded,
                            color: AppTheme.primaryGreen, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Compose Notification',
                              style: TextStyle(
                                  color: AdminShared.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                          Text('Broadcast or targeted messages',
                              style: TextStyle(
                                  color: AdminShared.textMuted, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // Target audience chips
                  const Text('Target Audience',
                      style: TextStyle(
                          color: AdminShared.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _roles.map((r) {
                      final sel = _targetRole == r;
                      return GestureDetector(
                        onTap: () => setState(() => _targetRole = r),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppTheme.primaryGreen
                                : const Color(0xFFF4F6FA),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: sel
                                ? [
                                    BoxShadow(
                                      color: AppTheme.primaryGreen
                                          .withValues(alpha: 0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          child: Text(
                            r,
                            style: TextStyle(
                              color: sel ? Colors.white : AdminShared.textMuted,
                              fontSize: 13,
                              fontWeight: sel
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  // Title field
                  _AppTextField(
                    controller: _titleCtrl,
                    label: 'Notification Title',
                    hint: 'e.g. System Maintenance, New Feature…',
                    icon: Icons.title_rounded,
                  ),
                  const SizedBox(height: 12),

                  // Message field
                  _AppTextField(
                    controller: _messageCtrl,
                    label: 'Message Body',
                    hint: 'Write your announcement here…',
                    icon: Icons.message_rounded,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 20),

                  // Send button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(_isSending ? 'Sending…' : 'Send Notification'),
                      onPressed: _isSending ? null : _sendNotification,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── History section ───────────────────────────────────────────────
            const Text('Recent Notifications',
                style: TextStyle(
                    color: AdminShared.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 17)),
            const SizedBox(height: 14),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('recipientId', isEqualTo: 'admin_broadcast')
                  .limit(50)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const AdminLoader();
                }
                if (snap.hasError) {
                  return AdminError(message: snap.error.toString());
                }
                final docs = snap.data?.docs.toList() ?? [];
                docs.sort((a, b) {
                  final aTime = (a.data() as Map<String, dynamic>)['sentAt'] as Timestamp?;
                  final bTime = (b.data() as Map<String, dynamic>)['sentAt'] as Timestamp?;
                  if (aTime == null || bTime == null) return 0;
                  return bTime.compareTo(aTime); // Descending
                });

                if (docs.isEmpty) {
                  return const AdminEmpty(message: 'No notifications sent yet.');
                }
                return Column(
                  children: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final ts = data['sentAt'] as Timestamp?;
                    final dtStr = ts != null
                        ? '${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year}  ${ts.toDate().hour}:${ts.toDate().minute.toString().padLeft(2, '0')}'
                        : '—';
                    return _NotificationHistoryCard(
                      title: data['title'] ?? '—',
                      message: data['message'] ?? '—',
                      targetRole: data['targetRole'] ?? 'All',
                      sentAt: dtStr,
                      onDelete: () => _deleteNotification(doc.id),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Light-themed text field ───────────────────────────────────────────────────

class _AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;

  const _AppTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
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
          decoration: BoxDecoration(
            color: const Color(0xFFF4F6FA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(
                color: AdminShared.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                  color: AdminShared.textMuted, fontSize: 13),
              prefixIcon: Icon(icon,
                  color: AppTheme.primaryGreen, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Notification history card ─────────────────────────────────────────────────

class _NotificationHistoryCard extends StatelessWidget {
  final String title;
  final String message;
  final String targetRole;
  final String sentAt;
  final VoidCallback onDelete;

  const _NotificationHistoryCard({
    required this.title,
    required this.message,
    required this.targetRole,
    required this.sentAt,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.notifications_active_rounded,
                color: AppTheme.primaryGreen, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              color: AdminShared.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '→ $targetRole',
                        style: TextStyle(
                            color: AppTheme.primaryGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(message,
                    style: const TextStyle(
                        color: AdminShared.textMuted, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(sentAt,
                    style: const TextStyle(
                        color: AdminShared.textMuted, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.delete_outline_rounded,
                color: AdminShared.danger, size: 20),
          ),
        ],
      ),
    );
  }
}
