import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notifications_page.dart';
import 'add_food_post_page.dart';
import 'my_food_posts_page.dart';
import 'incoming_requests_page.dart';
import 'donor_profile_page.dart';
import 'package:geolocator/geolocator.dart';

class DonorDashboardPage extends StatefulWidget {
  final String userId;
  const DonorDashboardPage({super.key, required this.userId});

  @override
  State<DonorDashboardPage> createState() => _DonorDashboardPageState();
}

class _DonorDashboardPageState extends State<DonorDashboardPage> {
  bool isLoading = true;
  String userName = "User";
  int familiesHelped = 0;
  List<QueryDocumentSnapshot> recentActivity = [];
  int selectedIndex = 0;
  StreamSubscription<Position>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    loadDashboardData();
    _startLocationTracking();
  }

  void _startLocationTracking() async {
    bool hasPermission = await _handleLocationPermission();
    if (hasPermission) {
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((Position position) {
        FirebaseFirestore.instance.collection("users").doc(widget.userId).update({
          "lastLocation": GeoPoint(position.latitude, position.longitude),
          "heading": position.heading,
        });
      });
    }
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> loadDashboardData() async {
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final userDoc = FirebaseFirestore.instance.collection("users").doc(widget.userId);
      final userSnap = await userDoc.get();

      if (userSnap.exists) {
        final data = userSnap.data();
        if (mounted) {
          setState(() {
            userName = data?["name"] ?? "User";
            familiesHelped = data?["familiesHelped"] ?? 0;
          });
        }
      } else {
        await userDoc.set({
          "name": "User",
          "email": currentUser.email ?? "",
          "role": "Donor",
          "familiesHelped": 0,
          "createdAt": FieldValue.serverTimestamp(),
        });
      }

      final recentSnap = await FirebaseFirestore.instance
          .collection("posts")
          .where("userID", isEqualTo: widget.userId)
          .limit(10)
          .get();

      final recentDocs = recentSnap.docs..sort((a, b) {
        final aTime = (a.data() as Map)['createdAt'] as Timestamp?;
        final bTime = (b.data() as Map)['createdAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      final now = DateTime.now();
      for (var doc in recentDocs) {
        final d = doc.data();
        if (d['status'] == 'active') {
          DateTime? parsedExpiry;
          bool isExpired = false;
          if (d['expiryTimestamp'] != null) {
            parsedExpiry = (d['expiryTimestamp'] as Timestamp).toDate();
            isExpired = parsedExpiry.isBefore(now);
          } else {
            try {
              parsedExpiry = DateFormat("yyyy-MM-dd hh:mm a").parse(d['expiryDate'] ?? '');
              isExpired = now.isAfter(parsedExpiry);
            } catch (_) {}
          }
          if (isExpired) {
            FirebaseFirestore.instance.collection('posts').doc(doc.id).update({'status': 'expired'}).catchError((_) {});
          }
        }
      }

      if (mounted) {
        final startOfDay = DateTime(now.year, now.month, now.day);
        final todayActivity = recentDocs.where((doc) {
          final data = doc.data();
          final timestamp = data['createdAt'] as Timestamp?;
          if (timestamp == null) return false;
          return timestamp.toDate().isAfter(startOfDay);
        }).toList();

        setState(() {
          recentActivity = todayActivity.take(3).toList();
        });
      }
    } catch (e) {
      debugPrint("❌ Dashboard load error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Widget _getPage(int index) {
    switch (index) {
      case 0: return _dashboardBody();
      case 1: return MyFoodPostsPage(userId: widget.userId);
      case 2: return IncomingRequestsPage(userId: widget.userId);
      case 3: return DonorProfilePage(userId: widget.userId);
      default: return _dashboardBody();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      body: _getPage(selectedIndex),
      bottomNavigationBar: _modernBottomNav(),
    );
  }

  Widget _dashboardBody() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildHeroActionCard(),
              const SizedBox(height: 30),
              _buildStatsRow(),
              const SizedBox(height: 35),
              const Text(
                "Today's Activity",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
              ),
              const SizedBox(height: 16),
              _buildRecentActivityList(),
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
        ),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Hello, $userName 👋", style: const TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 8),
                const Text("Ready to share\nfood today?", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, height: 1.2)),
              ],
            ),
          ),
          _buildNotificationBell(),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: CircleAvatar(
              radius: 27,
              backgroundColor: Colors.green.shade100,
              child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : '?', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
            ),
          ),
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
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsPage(userId: widget.userId))),
            ),
            if (hasUnread)
              Positioned(right: 8, top: 8, child: Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))),
          ],
        );
      },
    );
  }

  Widget _buildHeroActionCard() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddFoodPostPage(userId: widget.userId))).then((_) => loadDashboardData()),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF388E3C), Color(0xFF81C784)]),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            const Icon(Icons.add_business_rounded, color: Colors.white, size: 36),
            const SizedBox(width: 20),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Donate Food", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  Text("Post your leftover food and help someone in need.", style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStreamStatCard("Active Posts", "posts", "userID", "status", ["active", "accepted", "claimed", "assigned"], Colors.orange, Icons.inventory_2_rounded),
        const SizedBox(width: 12),
        _statCard("Impact", familiesHelped, Colors.green, Icons.volunteer_activism),
      ],
    );
  }

  Widget _buildStreamStatCard(String title, String collection, String userField, String statusField, List<String> statusValues, Color color, IconData icon) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where(userField, isEqualTo: widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        int count = 0;
        if (snapshot.hasData) {
          count = snapshot.data!.docs.where((doc) => statusValues.contains((doc.data() as Map<String, dynamic>)[statusField])).length;
        }
        return _statCard(title, count, color, icon);
      },
    );
  }

  Widget _statCard(String title, int count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(count.toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(title, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityList() {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (recentActivity.isEmpty) return const Center(child: Text("No activity today."));

    return Column(
      children: recentActivity.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data["status"] ?? "active";
        final isDone = status == "completed" || status == "delivered";
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: isDone ? Colors.blue.shade50 : Colors.green.shade50,
                  child: Icon(
                    isDone ? Icons.check_circle : Icons.restaurant,
                    color: isDone ? Colors.blue : Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data["title"] ?? "No title", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(
                        isDone ? "Completed Delivery" : "Expires: ${data['expiryDate'] ?? 'Unknown'}${data['aiFreshnessScore'] != null ? ' • ${data['aiFreshnessScore']}% Fresh' : ''}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDone ? Colors.blue.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: isDone ? Colors.blue : Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _modernBottomNav() {
    return BottomNavigationBar(
      currentIndex: selectedIndex,
      selectedItemColor: Colors.green,
      unselectedItemColor: Colors.grey,
      onTap: (index) {
        setState(() => selectedIndex = index);
        if (index == 0) loadDashboardData();
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Dashboard"),
        BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: "My Posts"),
        BottomNavigationBarItem(icon: Icon(Icons.mail), label: "Requests"),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
      ],
    );
  }
}
