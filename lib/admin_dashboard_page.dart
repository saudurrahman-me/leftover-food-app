import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'admin/admin_service.dart';
import 'admin/admin_users_tab.dart';
import 'admin/admin_posts_tab.dart';
import 'admin/admin_requests_tab.dart';
import 'admin/admin_tasks_tab.dart';
import 'admin/admin_drives_tab.dart';
import 'admin/admin_notifications_tab.dart';
import 'admin/admin_reports_tab.dart';
import 'admin/ai_dataset_dashboard_page.dart';
import 'admin/admin_settings_tab.dart';
import 'admin/admin_ngo_tab.dart';
import 'admin/admin_volunteer_tab.dart';
import 'admin/admin_receiver_tab.dart';
import 'login_screen.dart';
import 'core/app_theme.dart';

class AdminDashboardPage extends StatefulWidget {
  final String userId;
  const AdminDashboardPage({super.key, required this.userId});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _selectedIndex = 0;
  String _adminName = 'Admin';

  // Summary stats (loaded once, refreshable)
  int _totalUsers = 0;
  int _totalPosts = 0;
  int _activePosts = 0;
  int _pendingRequests = 0;
  int _totalTasks = 0;
  int _totalNotifications = 0;
  int _activeDrives = 0;
  int _totalDonors = 0;
  int _totalNGOs = 0;
  int _totalVolunteers = 0;
  int _totalReceivers = 0;
  int _completedDeliveries = 0;
  int _claimedPosts = 0;
  bool _statsLoading = true;

  // ── Nav items ─────────────────────────────────────────────────────────────
  static const _navItems = [
    _NavItem(Icons.dashboard_rounded, 'Dashboard', 0),
    _NavItem(Icons.people_alt_rounded, 'Users', 1),
    _NavItem(Icons.restaurant_menu_rounded, 'Food Posts', 2),
    _NavItem(Icons.inbox_rounded, 'Requests', 3),
    _NavItem(Icons.assignment_rounded, 'Tasks', 4),
    _NavItem(Icons.apartment_rounded, 'NGOs', 5),
    _NavItem(Icons.volunteer_activism_rounded, 'Volunteers', 6),
    _NavItem(Icons.person_search_rounded, 'Receivers', 7),
    _NavItem(Icons.campaign_rounded, 'Food Drives', 8),
    _NavItem(Icons.bar_chart_rounded, 'Reports', 9),
    _NavItem(Icons.notifications_active_rounded, 'Notifications', 10),
    _NavItem(Icons.dataset_rounded, 'AI Dataset', 11),
    _NavItem(Icons.settings_rounded, 'Settings', 12),
  ];

  @override
  void initState() {
    super.initState();
    _loadAdminName();
    _loadStats();
  }

  Future<void> _loadAdminName() async {
    try {
      final doc = await AdminService.users.doc(widget.userId).get();
      if (mounted && doc.exists) {
        setState(() {
          _adminName = (doc.data() as Map<String, dynamic>?)?['name'] ?? 'Admin';
        });
      }
    } catch (_) {}
  }

  Future<void> _loadStats() async {
    setState(() => _statsLoading = true);
    try {
      final fs = FirebaseFirestore.instance;
      final results = await Future.wait([
        fs.collection('users').get(),
        fs.collection('posts').get(),
        fs.collection('posts').where('status', isEqualTo: 'active').get(),
        fs.collection('requests').where('status', isEqualTo: 'pending').get(),
        fs.collection('tasks').get(),
        fs.collection('notifications').get(),
        fs.collection('drives').where('status', isEqualTo: 'ongoing').get(),
        fs.collection('users').where('role', isEqualTo: 'Donor').get(),
        fs.collection('users').where('role', isEqualTo: 'NGO').get(),
        fs.collection('users').where('role', isEqualTo: 'Volunteer').get(),
        fs.collection('users').where('role', isEqualTo: 'Receiver').get(),
        fs.collection('tasks').where('status', isEqualTo: 'delivered').get(),
        fs.collection('posts').where('status', isEqualTo: 'claimed').get(),
      ]);
      if (mounted) {
        setState(() {
          _totalUsers = results[0].size;
          _totalPosts = results[1].size;
          _activePosts = results[2].size;
          _pendingRequests = results[3].size;
          _totalTasks = results[4].size;
          _totalNotifications = results[5].size;
          _activeDrives = results[6].size;
          _totalDonors = results[7].size;
          _totalNGOs = results[8].size;
          _totalVolunteers = results[9].size;
          _totalReceivers = results[10].size;
          _completedDeliveries = results[11].size;
          _claimedPosts = results[12].size;
          _statsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  // ── Tab routing ───────────────────────────────────────────────────────────
  Widget _buildTab() {
    switch (_selectedIndex) {
      case 0:  return _buildOverview();
      case 1:  return const AdminUsersTab();
      case 2:  return const AdminPostsTab();
      case 3:  return const AdminRequestsTab();
      case 4:  return const AdminTasksTab();
      case 5:  return const AdminNgoTab();
      case 6:  return const AdminVolunteerTab();
      case 7:  return const AdminReceiverTab();
      case 8:  return const AdminDrivesTab();
      case 9:  return const AdminReportsTab();
      case 10: return const AdminNotificationsTab();
      case 11: return const AiDatasetDashboardPage();
      case 12: return AdminSettingsTab(onSignOut: _signOut);
      default: return _buildOverview();
    }
  }

  // ── Overview home tab ─────────────────────────────────────────────────────
  Widget _buildOverview() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildHeroHeader()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _sectionTitle('Platform Summary'),
              const SizedBox(height: 14),
              _buildUserRoleRow(),
              const SizedBox(height: 12),
              _buildPostStatsRow(),
              const SizedBox(height: 12),
              _buildMiscStatsRow(),
              const SizedBox(height: 28),
              _sectionTitle('Quick Navigation'),
              const SizedBox(height: 14),
              _buildQuickNav(),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
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
                    Text('Welcome back,',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(_adminName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                onPressed: _loadStats,
                tooltip: 'Refresh Stats',
              ),
              GestureDetector(
                onTap: _signOut,
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(
                    _adminName.isNotEmpty ? _adminName[0].toUpperCase() : 'A',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Glassmorphism banner
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              // filter removed for Web stability
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _heroStat('$_totalUsers', 'Total Users'),
                    _heroDivider(),
                    _heroStat('$_activePosts', 'Active Posts'),
                    _heroDivider(),
                    _heroStat('$_pendingRequests', 'Pending'),
                    _heroDivider(),
                    _heroStat('$_activeDrives', 'Drives'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String val, String label) => Column(
        children: [
          _statsLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Text(val,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
        ],
      );

  Widget _heroDivider() =>
      Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.3));

  Widget _sectionTitle(String title) => Text(title,
      style: const TextStyle(
          fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)));

  Widget _buildUserRoleRow() {
    return Row(
      children: [
        _statCard('Donors', '$_totalDonors', Icons.groups_rounded, Colors.green),
        const SizedBox(width: 10),
        _statCard('NGOs', '$_totalNGOs', Icons.apartment_rounded, Colors.purple),
        const SizedBox(width: 10),
        _statCard('Volunteers', '$_totalVolunteers', Icons.volunteer_activism_rounded, Colors.blue),
        const SizedBox(width: 10),
        _statCard('Receivers', '$_totalReceivers', Icons.person_rounded, Colors.orange),
      ],
    );
  }

  Widget _buildPostStatsRow() {
    return Row(
      children: [
        _statCard('Total Posts', '$_totalPosts', Icons.restaurant_menu_rounded, Colors.teal),
        const SizedBox(width: 10),
        _statCard('Active', '$_activePosts', Icons.check_circle_rounded, Colors.green),
        const SizedBox(width: 10),
        _statCard('Claimed', '$_claimedPosts', Icons.handshake_rounded, Colors.indigo),
        const SizedBox(width: 10),
        _statCard('Delivered', '$_completedDeliveries', Icons.local_shipping_rounded, Colors.cyan),
      ],
    );
  }

  Widget _buildMiscStatsRow() {
    return Row(
      children: [
        _statCard('Tasks', '$_totalTasks', Icons.assignment_rounded, Colors.deepPurple),
        const SizedBox(width: 10),
        _statCard('Requests', '$_pendingRequests', Icons.inbox_rounded, Colors.red),
        const SizedBox(width: 10),
        _statCard('Notifs', '$_totalNotifications', Icons.notifications_rounded, Colors.amber),
        const SizedBox(width: 10),
        _statCard('Drives', '$_activeDrives', Icons.campaign_rounded, Colors.pink),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            _statsLoading
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        color: color, strokeWidth: 2))
                : Text(value,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937))),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickNav() {
    final items = _navItems.skip(1).toList(); // Show all tabs in the dashboard grid
    return GridView.count(
      crossAxisCount: 4,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.0,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: items.map((item) {
        return GestureDetector(
          onTap: () => setState(() => _selectedIndex = item.index),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon,
                      color: AppTheme.primaryGreen, size: 22),
                ),
                const SizedBox(height: 6),
                Text(item.label,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937)),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget? _buildAppBar() {
    if (_selectedIndex == 0) return null;
    return AppBar(
      automaticallyImplyLeading: false,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
          ),
        ),
      ),
      title: Text(_navItems[_selectedIndex].label,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold)),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.white),
          onPressed: _signOut,
        ),
      ],
    );
  }

  // ── Bottom navigation ─────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    // Only show the first 5 tabs in bottom nav; rest accessed via overview grid
    const bottomItems = [
      BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
      BottomNavigationBarItem(
          icon: Icon(Icons.people_alt_rounded), label: 'Users'),
      BottomNavigationBarItem(
          icon: Icon(Icons.restaurant_menu_rounded), label: 'Posts'),
      BottomNavigationBarItem(
          icon: Icon(Icons.inbox_rounded), label: 'Requests'),
      BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart_rounded), label: 'Reports'),
    ];
    // Map bottom index to actual tab index
    const bottomMap = [0, 1, 2, 3, 9];
    final currentBottomIdx = bottomMap.indexOf(_selectedIndex).clamp(0, 4);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -5))
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentBottomIdx,
        selectedItemColor: AppTheme.primaryGreen,
        unselectedItemColor: Colors.grey.shade400,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        onTap: (i) {
          setState(() => _selectedIndex = bottomMap[i]);
          if (bottomMap[i] == 0) _loadStats();
        },
        items: bottomItems,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: _buildTab(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final int index;
  const _NavItem(this.icon, this.label, this.index);
}
