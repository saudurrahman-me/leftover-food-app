import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_shared.dart';

class AdminPostsTab extends StatefulWidget {
  const AdminPostsTab({super.key});

  @override
  State<AdminPostsTab> createState() => _AdminPostsTabState();
}

class _AdminPostsTabState extends State<AdminPostsTab> {
  String _filterStatus = 'All';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  final _statuses = ['All', 'active', 'claimed', 'rejected', 'completed'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    return AdminTabScaffold(
      title: 'Manage Posts',
      subtitle: 'View and moderate all food donation posts',
      icon: Icons.restaurant_menu_rounded,
      filterRow: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSearchField(
            controller: _searchCtrl,
            hint: 'Search by food name or donor…',
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
          ),
          const SizedBox(height: 12),
          AdminFilterChips(
            options: _statuses,
            selected: _filterStatus,
            onSelected: (v) => setState(() => _filterStatus = v),
          ),
        ],
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const AdminLoader();
          }
          if (snap.hasError) return AdminError(message: snap.error.toString());

          var docs = snap.data!.docs;

          if (_filterStatus != 'All') {
            docs = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              return (data['status'] ?? '') == _filterStatus;
            }).toList();
          }

          if (_searchQuery.isNotEmpty) {
            docs = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              final food =
                  (data['foodName'] ?? data['title'] ?? '').toString().toLowerCase();
              final donor = (data['donorName'] ?? data['donorId'] ?? '').toString().toLowerCase();
              return food.contains(_searchQuery) || donor.contains(_searchQuery);
            }).toList();
          }

          if (docs.isEmpty) return const AdminEmpty(message: 'No posts found.');

          return Column(
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final status = data['status'] ?? 'active';
              final foodName = data['foodName'] ?? data['title'] ?? 'Food Post';
              final donorName = data['donorName'] ?? data['donorId'] ?? 'Donor';
              
              final created = data['createdAt'];
              String createdStr = '—';
              if (created is Timestamp) {
                final dt = created.toDate();
                createdStr = '${dt.day}/${dt.month}/${dt.year}';
              }

              return _PostCard(
                docId: doc.id,
                foodName: foodName,
                donorName: donorName,
                status: status,
                createdStr: createdStr,
                onDelete: () => _confirmDelete(context, doc.id, foodName),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext ctx, String docId, String label) {
    showDialog(
      context: ctx,
      builder: (_) => AdminConfirmDialog(
        title: 'Delete Post',
        message: 'Are you sure you want to permanently delete this post? This action cannot be undone.',
        confirmLabel: 'Delete',
        isDestructive: true,
        onConfirm: () {
          AdminShared.runAsync(
            context: ctx,
            action: () async {
              await FirebaseFirestore.instance.collection('posts').doc(docId).delete();
              // Cascade delete tasks
              final tasksSnap = await FirebaseFirestore.instance.collection('tasks').where('postId', isEqualTo: docId).get();
              for (var doc in tasksSnap.docs) await doc.reference.delete();
              // Cascade delete requests
              final reqSnap = await FirebaseFirestore.instance.collection('requests').where('postId', isEqualTo: docId).get();
              for (var doc in reqSnap.docs) await doc.reference.delete();
            },
            successMsg: 'Post and related records deleted successfully',
            onComplete: () {
              if (ctx.mounted) Navigator.pop(ctx);
            },
          );
        },
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final String docId;
  final String foodName;
  final String donorName;
  final String status;
  final String createdStr;
  final VoidCallback onDelete;

  const _PostCard({
    required this.docId,
    required this.foodName,
    required this.donorName,
    required this.status,
    required this.createdStr,
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
                child: Text(foodName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
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
              const Icon(Icons.person_rounded, size: 14, color: AdminShared.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Donor: $donorName',
                    style: AdminShared.cellMutedStyle,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 13, color: AdminShared.textMuted),
              const SizedBox(width: 6),
              Text('Posted: $createdStr', style: AdminShared.cellMutedStyle),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              AdminIconBtn(
                icon: Icons.delete_rounded,
                color: AdminShared.danger,
                tooltip: 'Delete Post',
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }

}
