import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_service.dart';
import 'admin_shared.dart';

class AdminVolunteerTab extends StatefulWidget {
  const AdminVolunteerTab({super.key});

  @override
  State<AdminVolunteerTab> createState() => _AdminVolunteerTabState();
}

class _AdminVolunteerTabState extends State<AdminVolunteerTab> {
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    return AdminTabScaffold(
      title: 'Volunteer Management',
      subtitle: 'Monitor and manage all volunteers',
      icon: Icons.volunteer_activism_rounded,
      filterRow: AdminSearchField(
        controller: _searchCtrl,
        hint: 'Search volunteer name or email…',
        onChanged: (v) => setState(() => _search = v.toLowerCase()),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: AdminService.streamVolunteers(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const AdminLoader();
          if (snap.hasError) return AdminError(message: snap.error.toString());

          var docs = snap.data!.docs;
          if (_search.isNotEmpty) {
            docs = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              final name = (data['name'] ?? '').toString().toLowerCase();
              final email = (data['email'] ?? '').toString().toLowerCase();
              return name.contains(_search) || email.contains(_search);
            }).toList();
          }

          if (docs.isEmpty) return const AdminEmpty(message: 'No volunteers found.');

          return Column(
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final disabled = data['disabled'] == true;
              final available = data['available'] == true;
              final name = data['name'] ?? '—';
              
              return _VolunteerCard(
                docId: doc.id,
                name: name,
                email: data['email'] ?? '—',
                disabled: disabled,
                available: available,
                onToggleStatus: () {
                  AdminShared.runAsync(
                    context: context,
                    action: () => AdminService.setUserStatus(doc.id, disabled),
                    successMsg: disabled ? 'Volunteer enabled' : 'Volunteer disabled',
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
        title: 'Delete Volunteer',
        message: 'Delete "$name"?',
        confirmLabel: 'Delete',
        isDestructive: true,
        onConfirm: () {
          AdminShared.runAsync(
            context: context,
            action: () => AdminService.deleteUser(id),
            successMsg: 'Volunteer deleted',
            onComplete: () {
              if (context.mounted) Navigator.pop(context);
            },
          );
        },
      ),
    );
  }
}

class _VolunteerCard extends StatelessWidget {
  final String docId;
  final String name;
  final String email;
  final bool disabled;
  final bool available;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  const _VolunteerCard({
    required this.docId,
    required this.name,
    required this.email,
    required this.disabled,
    required this.available,
    required this.onToggleStatus,
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
                        fontSize: 15,
                        color: AdminShared.textPrimary),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              AdminStatusBadge(status: available ? 'available' : 'busy'),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.email_outlined, size: 14, color: AdminShared.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(email,
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
              AdminIconBtn(
                icon: disabled ? Icons.lock_open_rounded : Icons.lock_rounded,
                color: disabled ? AdminShared.success : AdminShared.warning,
                tooltip: disabled ? 'Enable' : 'Disable',
                onTap: onToggleStatus,
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
