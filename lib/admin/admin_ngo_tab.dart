import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_service.dart';
import 'admin_shared.dart';
import '../core/app_theme.dart';

/// NGO Management Tab — approve, reject, suspend, edit, delete NGOs.
class AdminNgoTab extends StatefulWidget {
  const AdminNgoTab({super.key});

  @override
  State<AdminNgoTab> createState() => _AdminNgoTabState();
}

class _AdminNgoTabState extends State<AdminNgoTab> {
  String _search = '';
  String _filter = 'All'; // All | active | suspended | pending
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    return AdminTabScaffold(
      title: 'NGO Management',
      subtitle: 'Approve, suspend, and manage all NGOs',
      icon: Icons.apartment_rounded,
      filterRow: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSearchField(
            controller: _searchCtrl,
            hint: 'Search NGO name or email…',
            onChanged: (v) => setState(() => _search = v.toLowerCase()),
          ),
          const SizedBox(height: 12),
          AdminFilterChips(
            options: const ['All', 'active', 'suspended', 'pending'],
            selected: _filter,
            onSelected: (v) => setState(() => _filter = v),
          ),
        ],
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: AdminService.streamNGOs(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const AdminLoader();
          if (snap.hasError) return AdminError(message: snap.error.toString());
          var docs = snap.data!.docs;

          if (_filter != 'All') {
            docs = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              return (data['status'] ?? 'active') == _filter;
            }).toList();
          }
          if (_search.isNotEmpty) {
            docs = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              final name = (data['name'] ?? data['ngoName'] ?? '').toString().toLowerCase();
              final email = (data['email'] ?? '').toString().toLowerCase();
              return name.contains(_search) || email.contains(_search);
            }).toList();
          }

          if (docs.isEmpty) return const AdminEmpty(message: 'No NGOs found.');

          return Column(
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final status = data['status'] ?? 'active';
              final name = data['name'] ?? data['ngoName'] ?? 'NGO';
              return _NgoCard(
                docId: doc.id,
                data: data,
                name: name,
                status: status,
                onStatusChange: (s) {
                  AdminShared.runAsync(
                    context: context,
                    action: () => AdminService.updateUser(doc.id, {'status': s}),
                    successMsg: 'Status changed to $s',
                  );
                },
                onDelete: () => _confirmDelete(context, doc.id, name),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id, String name) {
    showDialog(
      context: context,
      builder: (_) => AdminConfirmDialog(
        title: 'Delete NGO',
        message: 'Delete "$name"? This cannot be undone.',
        confirmLabel: 'Delete',
        isDestructive: true,
        onConfirm: () {
          AdminShared.runAsync(
            context: context,
            action: () => AdminService.deleteUser(id),
            successMsg: 'NGO deleted',
            onComplete: () {
              if (context.mounted) Navigator.pop(context);
            },
          );
        },
      ),
    );
  }
}

class _NgoCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final String name;
  final String status;
  final VoidCallback onDelete;
  final ValueChanged<String> onStatusChange;

  const _NgoCard({
    required this.docId,
    required this.data,
    required this.name,
    required this.status,
    required this.onDelete,
    required this.onStatusChange,
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
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'N',
                  style: TextStyle(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AdminShared.textPrimary)),
                    Text(data['email'] ?? '—',
                        style: const TextStyle(
                            color: AdminShared.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              AdminStatusBadge(status: status),
            ],
          ),
          if (data['location'] != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_rounded,
                    size: 14, color: AdminShared.textMuted),
                const SizedBox(width: 4),
                Text(data['location'],
                    style: const TextStyle(
                        color: AdminShared.textMuted, fontSize: 12)),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              AdminIconBtn(
                icon: Icons.check_circle_rounded,
                color: AdminShared.success,
                tooltip: 'Approve / Activate',
                onTap: () => onStatusChange('active'),
              ),
              const SizedBox(width: 8),
              AdminIconBtn(
                icon: Icons.block_rounded,
                color: AdminShared.warning,
                tooltip: 'Suspend',
                onTap: () => onStatusChange('suspended'),
              ),
              const SizedBox(width: 8),
              AdminIconBtn(
                icon: Icons.delete_rounded,
                color: AdminShared.danger,
                tooltip: 'Delete',
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
