import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_shared.dart';

class AdminUsersTab extends StatefulWidget {
  const AdminUsersTab({super.key});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  String _filterRole = 'All';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  final _roles = ['All', 'Donor', 'Receiver', 'Volunteer', 'NGO', 'Admin'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    return AdminTabScaffold(
      title: 'Manage Users',
      subtitle: 'View, edit, and delete users across all roles',
      icon: Icons.people_alt_rounded,
      filterRow: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSearchField(
            controller: _searchCtrl,
            hint: 'Search by name or email…',
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
          ),
          const SizedBox(height: 12),
          AdminFilterChips(
            options: _roles,
            selected: _filterRole,
            onSelected: (v) => setState(() => _filterRole = v),
          ),
        ],
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const AdminLoader();
          }
          if (snap.hasError) return AdminError(message: snap.error.toString());

          var docs = snap.data!.docs;

          // Filter by role
          if (_filterRole != 'All') {
            docs = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              return (data['role'] ?? '') == _filterRole;
            }).toList();
          }

          // Filter by search
          if (_searchQuery.isNotEmpty) {
            docs = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              final name = (data['name'] ?? data['fullName'] ?? '').toString().toLowerCase();
              final email = (data['email'] ?? '').toString().toLowerCase();
              return name.contains(_searchQuery) || email.contains(_searchQuery);
            }).toList();
          }

          if (docs.isEmpty) return const AdminEmpty(message: 'No users found.');

          return Column(
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final role = data['role'] ?? 'Unknown';
              final name = data['name'] ?? data['fullName'] ?? data['ngoName'] ?? '—';
              final email = data['email'] ?? '—';

              final joined = data['createdAt'];
              String? joinedStr;
              if (joined is Timestamp) {
                final dt = joined.toDate();
                joinedStr = '${dt.day}/${dt.month}/${dt.year}';
              }

              // NGO-specific registration fields
              final ngoContact = role == 'NGO'
                  ? (data['contactNumber'] ?? data['phone'] as String?)
                  : null;
              final ngoLocation = role == 'NGO'
                  ? (data['organizationLocation'] ?? data['location'] as String?)
                  : null;
              final ngoDetails = role == 'NGO'
                  ? (data['organizationDetails'] ?? data['details'] as String?)
                  : null;

              final isDisabled = data['disabled'] == true;

              return _UserCard(
                docId: doc.id,
                name: name,
                email: email,
                role: role,
                joinedStr: joinedStr,
                ngoContact: ngoContact,
                ngoLocation: ngoLocation,
                ngoDetails: ngoDetails,
                isDisabled: isDisabled,
                onToggleStatus: () => _toggleStatus(context, doc.id, name, isDisabled),
                onDelete: () => _confirmDelete(context, doc.id, name),
              );
            }).toList(),
          );
          },
        ),
      );
    }

  void _toggleStatus(BuildContext ctx, String docId, String name, bool currentlyDisabled) {
    final newStatus = !currentlyDisabled;
    final actionName = currentlyDisabled ? 'Activate' : 'Suspend';
    
    showDialog(
      context: ctx,
      builder: (_) => AdminConfirmDialog(
        title: '$actionName User',
        message: 'Are you sure you want to $actionName "$name"?',
        confirmLabel: actionName,
        isDestructive: !currentlyDisabled,
        onConfirm: () {
          AdminShared.runAsync(
            context: ctx,
            action: () => FirebaseFirestore.instance.collection('users').doc(docId).update({'disabled': newStatus}),
            successMsg: 'User status updated',
            onComplete: () {
              if (ctx.mounted) Navigator.pop(ctx);
            },
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext ctx, String docId, String label) {
    showDialog(
      context: ctx,
      builder: (_) => AdminConfirmDialog(
        title: 'Delete User',
        message: 'Delete "$label"? This action cannot be undone.',
        confirmLabel: 'Delete',
        isDestructive: true,
        onConfirm: () {
          AdminShared.runAsync(
            context: ctx,
            action: () => FirebaseFirestore.instance.collection('users').doc(docId).delete(),
            successMsg: 'User deleted',
            onComplete: () {
              if (ctx.mounted) Navigator.pop(ctx);
            },
          );
        },
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final String docId;
  final String name;
  final String email;
  final String role;
  final String? joinedStr;
  final String? ngoContact;
  final String? ngoLocation;
  final String? ngoDetails;
  final bool isDisabled;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  const _UserCard({
    required this.docId,
    required this.name,
    required this.email,
    required this.role,
    this.joinedStr,
    this.ngoContact,
    this.ngoLocation,
    this.ngoDetails,
    required this.isDisabled,
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
              AdminRoleBadge(role: role),
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
          if (joinedStr != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 13, color: AdminShared.textMuted),
                const SizedBox(width: 6),
                Text('Joined: $joinedStr', style: AdminShared.cellMutedStyle),
              ],
            ),
          ],
          // NGO-specific fields
          if (ngoContact != null && ngoContact!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.phone_outlined, size: 13, color: AdminShared.textMuted),
              const SizedBox(width: 6),
              Expanded(child: Text('Contact: $ngoContact', style: AdminShared.cellMutedStyle, overflow: TextOverflow.ellipsis)),
            ]),
          ],
          if (ngoLocation != null && ngoLocation!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.location_on_outlined, size: 13, color: AdminShared.textMuted),
              const SizedBox(width: 6),
              Expanded(child: Text('Location: $ngoLocation', style: AdminShared.cellMutedStyle, overflow: TextOverflow.ellipsis)),
            ]),
          ],
          if (ngoDetails != null && ngoDetails!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.info_outline, size: 13, color: AdminShared.textMuted),
              const SizedBox(width: 6),
              Expanded(child: Text('Details: $ngoDetails', style: AdminShared.cellMutedStyle, overflow: TextOverflow.ellipsis)),
            ]),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              AdminIconBtn(
                icon: isDisabled ? Icons.check_circle_outline_rounded : Icons.block_rounded,
                color: isDisabled ? Colors.green : Colors.orange,
                tooltip: isDisabled ? 'Activate User' : 'Suspend User',
                onTap: onToggleStatus,
              ),
              const SizedBox(width: 8),
              AdminIconBtn(
                icon: Icons.delete_rounded,
                color: AdminShared.danger,
                tooltip: 'Delete User',
                onTap: onDelete,
              ),
            ],
          ),
          if (isDisabled) ...[
             const SizedBox(height: 8),
             Text("SUSPENDED", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}
