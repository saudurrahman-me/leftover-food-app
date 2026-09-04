import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_shared.dart';

/// Drives tab — edit + delete with confirm dialog + snackbar feedback.
class AdminDrivesTab extends StatefulWidget {
  const AdminDrivesTab({super.key});

  @override
  State<AdminDrivesTab> createState() => _AdminDrivesTabState();
}

class _AdminDrivesTabState extends State<AdminDrivesTab> {
  String _filterStatus = 'All';
  final _statuses = ['All', 'upcoming', 'ongoing', 'completed', 'cancelled'];



  @override
  Widget build(BuildContext context) {
    return AdminTabScaffold(
      title: 'Manage Drives',
      subtitle: 'View and edit NGO food drives',
      icon: Icons.campaign_rounded,
      filterRow: AdminFilterChips(
        options: _statuses,
        selected: _filterStatus,
        onSelected: (v) => setState(() => _filterStatus = v),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('drives')
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

          if (docs.isEmpty) return const AdminEmpty(message: 'No drives found.');

          return Column(
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final status = data['status'] ?? 'upcoming';
              final name = data['name'] ?? data['title'] ?? 'Drive';
              return _DriveCard(
                docId: doc.id,
                data: data,
                name: name,
                status: status,
                onDelete: () => _confirmDelete(context, doc.id, name),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext ctx, String docId, String name) {
    showDialog(
      context: ctx,
      builder: (_) => AdminConfirmDialog(
        title: 'Delete Drive',
        message: 'Delete "$name"? This cannot be undone.',
        confirmLabel: 'Delete',
        isDestructive: true,
        onConfirm: () {
          AdminShared.runAsync(
            context: ctx,
            action: () => FirebaseFirestore.instance.collection('drives').doc(docId).delete(),
            successMsg: 'Drive deleted',
            onComplete: () {
              if (ctx.mounted) Navigator.pop(ctx);
            },
          );
        },
      ),
    );
  }
}

// ── Drive card ────────────────────────────────────────────────────────────────
class _DriveCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final String name;
  final String status;
  final VoidCallback onDelete;

  const _DriveCard({
    required this.docId,
    required this.data,
    required this.name,
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
                child: Text(name,
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
          if ((data['location'] ?? '').isNotEmpty)
            Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 13, color: AdminShared.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(data['location'],
                      style: AdminShared.cellMutedStyle,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          if ((data['ngoId'] ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(
                children: [
                  const Icon(Icons.apartment_rounded, size: 13, color: AdminShared.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('NGO: ${data['ngoId']}',
                        style: AdminShared.cellMutedStyle,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              AdminIconBtn(
                icon: Icons.delete_rounded,
                color: AdminShared.danger,
                tooltip: 'Delete Drive',
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
