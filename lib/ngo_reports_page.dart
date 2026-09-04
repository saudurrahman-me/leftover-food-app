import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';


class NGOReportsPage extends StatefulWidget {
  const NGOReportsPage({super.key});

  @override
  State<NGOReportsPage> createState() => _NGOReportsPageState();
}

class _NGOReportsPageState extends State<NGOReportsPage> {
  // Use cached uid — FirebaseAuth.currentUser may be null briefly after navigation
  final String _ngoId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    // Guard: if ngoId is empty, show a clear error instead of blank/hanging screen
    if (_ngoId.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xffF7F9FC),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, size: 56, color: Colors.orange),
              SizedBox(height: 16),
              Text('Session expired. Please log in again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black54)),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xffF7F9FC),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildSectionTitle('Performance Overview'),
            const SizedBox(height: 16),
            _buildPerformanceCards(),
            const SizedBox(height: 32),
            _buildSectionTitle('Volunteer Performance'),
            const SizedBox(height: 16),
            _buildVolunteerPerformance(),
            const SizedBox(height: 32),
            _buildSectionTitle('Recent Accomplishments'),
            const SizedBox(height: 16),
            _buildRecentAccomplishments(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ─── HEADER ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Impact Analytics',
                        style: TextStyle(color: Colors.white70, fontSize: 16)),
                    SizedBox(height: 4),
                    Text('Organization Reports',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Export button
              GestureDetector(
                onTap: _showExportDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.download, size: 16, color: Color(0xFF2E7D32)),
                      SizedBox(width: 8),
                      Text('Export', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Glassmorphism stats card – scoped to this NGO
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              // filter removed for Web stability
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Meals Delivered = tasks by this NGO with status=delivered
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('tasks')
                            .where('ngoId', isEqualTo: _ngoId)
                            .where('status', isEqualTo: 'delivered')
                            .snapshots(),
                        builder: (context, snap) => _heroStat(
                            snap.hasData ? snap.data!.docs.length.toString() : '0',
                            'Meals\nDelivered',
                            Icons.restaurant),
                      ),
                    ),
                    Container(width: 1, height: 40, color: Colors.white24),
                    // Active volunteers who have ever worked with this NGO
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('tasks')
                            .where('ngoId', isEqualTo: _ngoId)
                            .snapshots(),
                        builder: (context, snap) {
                          int uniqueVols = 0;
                          if (snap.hasData) {
                            final ids = snap.data!.docs
                                .map((d) =>
                                    (d.data() as Map)['assignedTo'] as String? ??
                                    '')
                                .where((id) => id.isNotEmpty)
                                .toSet();
                            uniqueVols = ids.length;
                          }
                          return _heroStat(uniqueVols.toString(),
                              'Volunteers\nEngaged', Icons.people);
                        },
                      ),
                    ),
                    Container(width: 1, height: 40, color: Colors.white24),
                    // Receiver requests accepted by this NGO
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('requests')
                            .where('ngoId', isEqualTo: _ngoId)
                            .where('status', isEqualTo: 'accepted')
                            .snapshots(),
                        builder: (context, snap) => _heroStat(
                            snap.hasData ? snap.data!.docs.length.toString() : '0',
                            'Families\nHelped',
                            Icons.volunteer_activism),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }



  // ─── PERFORMANCE CARDS ─────────────────────────────────────────────────────
  Widget _buildPerformanceCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Claimed Donations card
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .where('ngoId', isEqualTo: _ngoId)
                .snapshots(),
            builder: (context, snap) {
              final total = snap.hasData ? snap.data!.docs.length : 0;
              final claimed = snap.hasData
                  ? snap.data!.docs
                      .where((d) =>
                          (d.data() as Map)['status'] == 'claimed')
                      .length
                  : 0;
              final completed = snap.hasData
                  ? snap.data!.docs
                      .where((d) =>
                          (d.data() as Map)['status'] == 'completed')
                      .length
                  : 0;
              return _reportCard(
                title: 'Donations Managed',
                subtitle:
                    '$total total  •  $claimed active  •  $completed completed',
                color: Colors.green,
                icon: Icons.inventory_2_outlined,
                onTap: () => _showDetailSheet(
                    context, 'Claimed Donations', snap.data?.docs ?? []),
              );
            },
          ),
          const SizedBox(height: 16),
          // Pending requests card
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('requests')
                .where('ngoId', isEqualTo: _ngoId)
                .snapshots(),
            builder: (context, snap) {
              final total = snap.hasData ? snap.data!.docs.length : 0;
              final pending = snap.hasData
                  ? snap.data!.docs
                      .where((d) =>
                          (d.data() as Map)['status'] == 'pending')
                      .length
                  : 0;
              return _reportCard(
                title: 'Receiver Requests',
                subtitle: '$total total  •  $pending still pending',
                color: Colors.orange,
                icon: Icons.inbox_outlined,
                onTap: () => _showDetailSheet(
                    context, 'All Requests', snap.data?.docs ?? []),
              );
            },
          ),
          const SizedBox(height: 16),
          // Active drives card
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('drives')
                .where('ngoId', isEqualTo: _ngoId)
                .snapshots(),
            builder: (context, snap) {
              final total = snap.hasData ? snap.data!.docs.length : 0;
              return _reportCard(
                title: 'Food Drives Created',
                subtitle: '$total drives organised by your NGO',
                color: Colors.blue,
                icon: Icons.campaign_outlined,
                onTap: () => _showDetailSheet(
                    context, 'Food Drives', snap.data?.docs ?? []),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── VOLUNTEER PERFORMANCE ─────────────────────────────────────────────────
  Widget _buildVolunteerPerformance() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tasks')
            .where('ngoId', isEqualTo: _ngoId)
            .where('status', isEqualTo: 'delivered')
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return _emptyCard(
                'No completed deliveries yet.',
                'Once volunteers complete tasks for your NGO, their stats will appear here.');
          }

          // Aggregate deliveries per volunteer
          final Map<String, int> volCount = {};
          for (final doc in snap.data!.docs) {
            final id =
                (doc.data() as Map)['assignedTo'] as String? ?? '';
            if (id.isNotEmpty) volCount[id] = (volCount[id] ?? 0) + 1;
          }

          // Sort descending
          final sorted = volCount.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          return Column(
            children: sorted.take(5).map((entry) {
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(entry.key)
                    .get(),
                builder: (context, uSnap) {
                  final name = uSnap.hasData && uSnap.data!.exists
                      ? (uSnap.data!.data() as Map)['name'] ?? 'Volunteer'
                      : 'Loading…';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10)
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.green.shade50,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold))),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${entry.value} deliveries',
                            style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }

  // ─── ACCOMPLISHMENTS ───────────────────────────────────────────────────────
  Widget _buildRecentAccomplishments() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tasks')
            .where('ngoId', isEqualTo: _ngoId)
            .where('status', isEqualTo: 'delivered')
            .orderBy('createdAt', descending: true)
            .limit(5)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return _emptyCard(
                'No completed deliveries yet.',
                'When a volunteer marks a delivery as done it will appear here.');
          }
          return Column(
            children: snap.data!.docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final title = d['title'] ?? 'Delivery';
              final ts = (d['createdAt'] as Timestamp?)?.toDate();
              final date =
                  ts != null ? DateFormat('MMM dd, yyyy').format(ts) : '';
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: Colors.green.shade100),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle,
                          color: Colors.green, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                          if (date.isNotEmpty)
                            Text(date,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Delivered',
                          style: TextStyle(
                              color: Colors.green,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  // ─── HELPERS ───────────────────────────────────────────────────────────────
  Widget _heroStat(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label,
            textAlign: TextAlign.center,
            style:
                const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _reportCard({
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 20)
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(title,
          style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87)),
    );
  }

  Widget _emptyCard(String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Icon(Icons.bar_chart, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ],
      ),
    );
  }

  // ─── DETAIL BOTTOM SHEET ───────────────────────────────────────────────────
  void _showDetailSheet(
      BuildContext context, String title, List<QueryDocumentSnapshot> docs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: docs.isEmpty
                  ? const Center(child: Text('No records found.'))
                  : ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        final d = docs[i].data() as Map<String, dynamic>;
                        final label = d['title'] ??
                            d['name'] ??
                            d['itemTitle'] ??
                            'Record #${i + 1}';
                        final status = d['status'] ?? '';
                        return ListTile(
                          leading: const Icon(Icons.circle,
                              size: 10, color: Colors.green),
                          title: Text(label),
                          trailing: status.isNotEmpty
                              ? Chip(
                                  label: Text(status,
                                      style: const TextStyle(fontSize: 11)),
                                  backgroundColor: Colors.green.shade50,
                                  side: BorderSide.none,
                                )
                              : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── EXPORT DIALOG ─────────────────────────────────────────────────────────
  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Export Report',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            'A summary report of your NGO activity will be prepared.\n\n'
            'Export formats: PDF and CSV will be available in a future release. '
            'For now your data is safely stored in Firestore.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Colors.grey))),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Report data ready. PDF export coming soon.'),
                    backgroundColor: Colors.green),
              );
            },
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Confirm'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

}

