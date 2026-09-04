import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notifications_page.dart';
import 'ngo_profile_page.dart';
import 'ngo_volunteers_page.dart';
import 'ngo_donations_page.dart';
import 'ngo_events_page.dart';
import 'ngo_reports_page.dart';
import 'ngo_requests_page.dart';

class NGODashboardPage extends StatefulWidget {
  final String userId;
  const NGODashboardPage({super.key, required this.userId});

  @override
  State<NGODashboardPage> createState() => _NGODashboardPageState();
}

class _NGODashboardPageState extends State<NGODashboardPage> {
  int selectedIndex = 0;
  String ngoName = "NGO";

  @override
  void initState() {
    super.initState();
    _loadNGOData();
  }

  Future<void> _loadNGOData() async {
    final doc = await FirebaseFirestore.instance.collection("users").doc(widget.userId).get();
    if (doc.exists && mounted) {
      setState(() {
        ngoName = doc.data()?['name'] ?? "NGO";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF7F9FC),
      body: _getPage(selectedIndex),
      bottomNavigationBar: _modernBottomNav(),
    );
  }

  Widget _getPage(int index) {
    switch (index) {
      case 0: return _homeDashboard();
      case 1: return const NGODonationsPage();
      case 2: return const NGOReportsPage();
      case 3: return NGOProfilePage(userId: widget.userId);
      default: return _homeDashboard();
    }
  }

  Widget _homeDashboard() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium Hero Banner
          Container(
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
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Organization Dashboard", style: TextStyle(color: Colors.white70, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text(ngoName, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    _buildNotificationBell(),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.business, color: Colors.white, size: 28),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                // Glassmorphism Impact Card
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: SizedBox(
                    // filter removed for Web stability
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          const Text("My Impact Today", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              // PHASE 3 FIX: Scope stats to current NGO, not global system
                              Expanded(
                                child: StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance.collection("posts").where("ngoId", isEqualTo: widget.userId).snapshots(),
                                  builder: (context, snap) => _impactStat(snap.hasData ? snap.data!.docs.length.toString() : "0", "Claimed\nPosts"),
                                ),
                              ),
                              Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.3)),
                              Expanded(
                                child: StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance.collection("requests").where("ngoId", isEqualTo: widget.userId).where("status", isEqualTo: "pending").snapshots(),
                                  builder: (context, snap) => _impactStat(snap.hasData ? snap.data!.docs.length.toString() : "0", "Pending\nRequests"),
                                ),
                              ),
                              Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.3)),
                              Expanded(
                                child: StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance.collection("tasks").where("ngoId", isEqualTo: widget.userId).where("status", whereIn: ["pending", "assigned"]).snapshots(),
                                  builder: (context, snap) => _impactStat(snap.hasData ? snap.data!.docs.length.toString() : "0", "Active\nDeliveries"),
                                ),
                              ),
                              Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.3)),
                              Expanded(
                                child: StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance.collection("tasks").where("ngoId", isEqualTo: widget.userId).where("status", isEqualTo: "delivered").snapshots(),
                                  builder: (context, snap) => _impactStat(snap.hasData ? snap.data!.docs.length.toString() : "0", "Completed"),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // Quick Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Quick Actions", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _actionCard("View Requests", Icons.notification_important_outlined, Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NGORequestsPage()))),
                    const SizedBox(width: 16),
                    _actionCard("Manage Events", Icons.campaign_outlined, Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NGOEventsPage()))),
                    const SizedBox(width: 16),
                    _actionCard("Volunteers", Icons.people_outline, Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NGOVolunteersPage()))),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // Active Spotlight (Drive Progress)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Active Spotlight", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection("drives").limit(1).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(24),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.campaign_outlined, color: Colors.grey.shade300, size: 40),
                            const SizedBox(height: 12),
                            const Text("No Active Spotlight", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text("Create a new food drive to see its progress here.", style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                          ],
                        ),
                      );
                    }
                    final drive = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                    final progress = (drive['progress'] ?? 0.0).toDouble();
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(drive['name'] ?? "Food Drive", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 8),
                          Text("Goal: ${drive['goal']} meals", style: TextStyle(color: Colors.grey.shade600)),
                          const SizedBox(height: 20),
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.green.shade50,
                            valueColor: const AlwaysStoppedAnimation(Colors.green),
                            minHeight: 10,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          const SizedBox(height: 12),
                          Text("${(progress * 100).toInt()}% Complete", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildNotificationBell() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientId', isEqualTo: widget.userId)
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        bool hasUnread = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

        return Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 28),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => NotificationsPage(userId: widget.userId)),
                );
              },
            ),
            if (hasUnread)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _impactStat(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _actionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modernBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (i) => setState(() => selectedIndex = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey.shade400,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.card_giftcard), activeIcon: Icon(Icons.card_giftcard_sharp), label: "Donations"),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), activeIcon: Icon(Icons.bar_chart), label: "Reports"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }

}

