import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_shared.dart';

class AdminRequestsTab extends StatefulWidget {
  const AdminRequestsTab({super.key});

  @override
  State<AdminRequestsTab> createState() => _AdminRequestsTabState();
}

class _AdminRequestsTabState extends State<AdminRequestsTab> {
  String _filterStatus = 'All';
  final _statuses = ['All', 'pending', 'approved', 'rejected'];



  @override
  Widget build(BuildContext context) {
    return AdminTabScaffold(
      title: 'Manage Requests',
      subtitle: 'Monitor and approve/reject receiver requests',
      icon: Icons.inbox_rounded,
      filterRow: AdminFilterChips(
        options: _statuses,
        selected: _filterStatus,
        onSelected: (v) => setState(() => _filterStatus = v),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('requests')
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

          if (docs.isEmpty) return const AdminEmpty(message: 'No requests found.');

          return Column(
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final status = data['status'] ?? 'pending';
              final receiver = data['receiverName'] ?? data['receiverId'] ?? 'Receiver';
              final food = data['foodName'] ?? data['postId'] ?? 'Food';
              return _RequestCard(
                docId: doc.id,
                data: data,
                receiver: receiver,
                food: food,
                status: status,
                onApprove: () => _updateStatus(doc.id, 'approved'),
                onReject: () => _updateStatus(doc.id, 'rejected'),
                onChangeStatus: () => _showStatusDialog(context, doc.id, status),
                onDelete: () => _confirmDelete(context, doc.id),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  void _updateStatus(String docId, String status) {
    AdminShared.runAsync(
      context: context,
      action: () => FirebaseFirestore.instance.collection('requests').doc(docId).update({'status': status}),
      successMsg: 'Request marked as $status',
    );
  }

  void _showStatusDialog(BuildContext ctx, String docId, String current) {
    String selected = current;
    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (_, setSt) => AdminDialog(
          title: 'Change Request Status',
          content: AdminDropdownField<String>(
            label: 'Status',
            value: selected,
            items: const ['pending', 'approved', 'rejected'],
            onChanged: (v) => setSt(() => selected = v!),
          ),
          onConfirm: () {
            AdminShared.runAsync(
              context: ctx,
              action: () => FirebaseFirestore.instance.collection('requests').doc(docId).update({'status': selected}),
              successMsg: 'Request status changed',
              onComplete: () {
                if (ctx.mounted) Navigator.pop(ctx);
              },
            );
          },
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext ctx, String docId) {
    showDialog(
      context: ctx,
      builder: (_) => AdminConfirmDialog(
        title: 'Delete Request',
        message: 'Delete this request? This cannot be undone.',
        confirmLabel: 'Delete',
        isDestructive: true,
        onConfirm: () {
          AdminShared.runAsync(
            context: ctx,
            action: () => FirebaseFirestore.instance.collection('requests').doc(docId).delete(),
            successMsg: 'Request deleted',
            onComplete: () {
              if (ctx.mounted) Navigator.pop(ctx);
            },
          );
        },
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final String receiver;
  final String food;
  final String status;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onChangeStatus;
  final VoidCallback onDelete;

  const _RequestCard({
    required this.docId,
    required this.data,
    required this.receiver,
    required this.food,
    required this.status,
    required this.onApprove,
    required this.onReject,
    required this.onChangeStatus,
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
                child: Text('Food: $food',
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
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 14, color: AdminShared.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Receiver: $receiver',
                    style: AdminShared.cellMutedStyle,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              if (status == 'pending') ...[
                AdminIconBtn(
                  icon: Icons.check_circle_rounded,
                  color: AdminShared.success,
                  tooltip: 'Approve',
                  onTap: onApprove,
                ),
                const SizedBox(width: 8),
                AdminIconBtn(
                  icon: Icons.cancel_rounded,
                  color: AdminShared.danger,
                  tooltip: 'Reject',
                  onTap: onReject,
                ),
                const SizedBox(width: 8),
              ] else ...[
                AdminIconBtn(
                  icon: Icons.swap_horiz_rounded,
                  color: AdminShared.warning,
                  tooltip: 'Change Status',
                  onTap: onChangeStatus,
                ),
                const SizedBox(width: 8),
              ],
              AdminIconBtn(
                icon: Icons.delete_rounded,
                color: AdminShared.danger,
                tooltip: 'Delete Request',
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
