import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_shared.dart';

/// Tasks tab — full CRUD: status update, reassign volunteer, delete with confirm.
class AdminTasksTab extends StatefulWidget {
  const AdminTasksTab({super.key});

  @override
  State<AdminTasksTab> createState() => _AdminTasksTabState();
}

class _AdminTasksTabState extends State<AdminTasksTab> {
  String _filterStatus = 'All';
  final _statuses = ['All', 'pending', 'assigned', 'in_progress', 'delivered', 'completed'];



  @override
  Widget build(BuildContext context) {
    return AdminTabScaffold(
      title: 'Manage Tasks',
      subtitle: 'View and update volunteer delivery tasks',
      icon: Icons.assignment_rounded,
      filterRow: AdminFilterChips(
        options: _statuses,
        selected: _filterStatus,
        onSelected: (v) => setState(() => _filterStatus = v),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tasks')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const AdminLoader();
          if (snap.hasError) return AdminError(message: snap.error.toString());

          var docs = snap.data!.docs;

          if (_filterStatus != 'All') {
            docs = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              return (data['status'] ?? '') == _filterStatus;
            }).toList();
          }

          if (docs.isEmpty) return const AdminEmpty(message: 'No tasks found.');

          return Column(
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final status = data['status'] ?? 'pending';
              final title = data['title'] ?? data['postId'] ?? 'Task';
              return _TaskCard(
                docId: doc.id,
                data: data,
                title: title,
                status: status,
                onDelete: () => _confirmDelete(context, doc.id, title),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext ctx, String docId, String title) {
    showDialog(
      context: ctx,
      builder: (_) => AdminConfirmDialog(
        title: 'Delete Task',
        message: 'Delete task "$title"? This cannot be undone.',
        confirmLabel: 'Delete',
        isDestructive: true,
        onConfirm: () {
          AdminShared.runAsync(
            context: ctx,
            action: () => FirebaseFirestore.instance.collection('tasks').doc(docId).delete(),
            successMsg: 'Task deleted',
            onComplete: () {
              if (ctx.mounted) Navigator.pop(ctx);
            },
          );
        },
      ),
    );
  }
}

// ── Card widget for each task ─────────────────────────────────────────────────
class _TaskCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final String title;
  final String status;
  final VoidCallback onDelete;

  const _TaskCard({
    required this.docId,
    required this.data,
    required this.title,
    required this.status,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AdminShared.textPrimary),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              AdminStatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 8),
          if (data['pickup'] != null)
            _InfoRow(Icons.store_rounded, 'Pickup', data['pickup']),
          if (data['dropoff'] != null)
            _InfoRow(Icons.location_on_rounded, 'Dropoff', data['dropoff']),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              AdminIconBtn(
                icon: Icons.delete_rounded,
                color: AdminShared.danger,
                tooltip: 'Delete Task',
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AdminShared.textMuted),
          const SizedBox(width: 6),
          Text('$label: ', style: AdminShared.cellMutedStyle),
          Expanded(
            child: Text(value,
                style: AdminShared.cellStyle,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
