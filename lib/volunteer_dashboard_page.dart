import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notifications_page.dart';
import 'notification_service.dart';
import 'volunteer_available_tasks_page.dart';
import 'volunteer_profile_page.dart';
import 'map_page.dart';

class VolunteerDashboardPage extends StatefulWidget {
  final String userId;
  const VolunteerDashboardPage({super.key, required this.userId});

  @override
  State<VolunteerDashboardPage> createState() => _VolunteerDashboardPageState();
}

class _VolunteerDashboardPageState extends State<VolunteerDashboardPage> {
  int selectedIndex = 0;
  bool isLoading = true;
  String volunteerName = "";
  String volunteerEmail = "";
  int pendingTasks = 0;
  int completedTasks = 0;

  // Profile editing
  bool isEditingProfile = false;
  final nameEditCtrl = TextEditingController();
  bool isSavingProfile = false;
  
  StreamSubscription<QuerySnapshot>? _taskSubscription;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _taskSubscription?.cancel();
    nameEditCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    try {
      final userDoc = FirebaseFirestore.instance.collection("users").doc(widget.userId);
      final userSnap = await userDoc.get();
      if (userSnap.exists) {
        volunteerName = userSnap['name'] ?? "Volunteer";
        volunteerEmail = userSnap.data()?['email'] ?? "";
        nameEditCtrl.text = volunteerName;
      }

      // We'll set up listeners for real-time stats instead of one-time get
      _taskSubscription = FirebaseFirestore.instance
          .collection("tasks")
          .where("assignedTo", isEqualTo: widget.userId)
          .snapshots()
          .listen((snapshot) {
        int pending = 0;
        int completed = 0;
        for (var doc in snapshot.docs) {
          final status = doc.data()['status'] as String?;
          if (status == 'pending' || status == 'assigned' || status == 'in_progress') pending++;
          if (status == 'delivered') completed++;
        }
        if (mounted) {
          setState(() {
            pendingTasks = pending;
            completedTasks = completed;
            isLoading = false;
          });
        }
      });
    } catch (e) {
      debugPrint("Error loading dashboard data: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _markTaskCompleted(String taskId) async {
    try {
      final taskDoc = await FirebaseFirestore.instance.collection("tasks").doc(taskId).get();
      await taskDoc.reference.update({"status": "delivered"});

      if (taskDoc.exists) {
        final data = taskDoc.data();
        if (data != null) {
          if (data.containsKey("requestId") && data["requestId"] != null) {
            final reqId = data["requestId"];
            await FirebaseFirestore.instance.collection("requests").doc(reqId).update({"status": "completed"});
          }
          if (data.containsKey("postId") && data["postId"] != null) {
            final postId = data["postId"];
            await FirebaseFirestore.instance.collection("posts").doc(postId).update({"status": "completed"});
          }
          if (data.containsKey("donorId") && data["donorId"] != null) {
            await NotificationService.sendNotification(
              recipientId: data["donorId"],
              title: "Delivery Completed!",
              message: "Your food donation has been successfully delivered.",
              type: "delivery",
              relatedId: taskId,
            );
          }
          if (data.containsKey("receiverId") && data["receiverId"] != null) {
            await NotificationService.sendNotification(
              recipientId: data["receiverId"],
              title: "Food Delivered!",
              message: "Your requested food has arrived.",
              type: "delivery",
              relatedId: taskId,
            );
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Task marked as completed! Great job!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Error marking task completed: $e");
    }
  }

  // ---------------- UI COMPONENTS ----------------

  Widget _buildTaskCard(DocumentSnapshot task, {bool showComplete = true}) {
    final data = task.data() as Map<String, dynamic>?;
    final title = data?['title'] ?? "Delivery Task";
    final pickup = data?['pickup'] ?? "Unknown Pickup";
    final dropoff = data?['dropoff'] ?? "Unknown Drop-off";
    final estTime = data?['estTime'] ?? "N/A";
    final status = data?['status'] ?? "pending";
    final bool isDone = status == "delivered";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDone ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDone
                      ? [Colors.green.shade50, Colors.green.shade100]
                      : [Colors.orange.shade50, Colors.orange.shade100],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isDone ? Icons.check_circle : Icons.delivery_dining,
                      color: isDone ? Colors.green : Colors.orange,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isDone ? "Delivery Completed" : "NGO Assigned Task",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDone ? Colors.green.shade700 : Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildLocationRow(Icons.storefront, "Pickup", pickup),
                  Padding(
                    padding: const EdgeInsets.only(left: 11, top: 4, bottom: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(width: 2, height: 16, color: Colors.grey.shade300),
                    ),
                  ),
                  _buildLocationRow(Icons.location_on, "Drop-off", dropoff),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(estTime, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                        ],
                      ),
                      if (!isDone && showComplete)
                        Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                // Contact logic
                              },
                              icon: const Icon(Icons.chat_bubble_outline),
                              color: Colors.green,
                            ),
                            ElevatedButton(
                              onPressed: () => _markTaskCompleted(task.id),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              child: const Text("Complete", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, String label, String address) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(address, style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  // Pages ...

  // ---------------- PAGES ----------------

  Widget _dashboardPage() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Banner
          Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Welcome back,", style: TextStyle(color: Colors.white70, fontSize: 16)),
                          const SizedBox(height: 4),
                          isLoading
                              ? Container(width: 150, height: 28, color: Colors.white24)
                              : Text(volunteerName,
                                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    _buildNotificationBell(),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.white,
                        child: Text(
                          volunteerName.isNotEmpty ? volunteerName[0].toUpperCase() : "V",
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                // Glassmorphism Stats
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: SizedBox(
                    // filter removed for Web stability
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection("tasks").where("assignedTo", isEqualTo: widget.userId).where("status", whereIn: ["pending", "assigned", "in_progress"]).snapshots(),
                          builder: (context, snap) {
                            final count = snap.hasData ? snap.data!.docs.length : 0;
                            return _heroStat(count.toString(), "Pending");
                          },
                        ),
                        Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.3)),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection("tasks").where("assignedTo", isEqualTo: widget.userId).where("status", isEqualTo: "delivered").snapshots(),
                          builder: (context, snap) {
                            final count = snap.hasData ? snap.data!.docs.length : 0;
                            return _heroStat(count.toString(), "Completed");
                          },
                        ),
                        Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.3)),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection("tasks").where("assignedTo", isEqualTo: widget.userId).snapshots(),
                          builder: (context, snap) {
                            final count = snap.hasData ? snap.data!.docs.length : 0;
                            return _heroStat(count.toString(), "Total");
                          },
                        ),
                      ],
                    ),
                  ),
                  ),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Recent Activity", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("tasks")
                      .where("assignedTo", isEqualTo: widget.userId)
                      .limit(5)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(color: Colors.green));
                    }
                    if (snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text("No tasks yet", style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Text("The NGO will assign deliveries to you soon.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                      );
                    }
                    // Sort client-side to avoid composite index requirement
                    final docs = List.of(snapshot.data!.docs);
                    docs.sort((a, b) {
                      final aT = (a.data() as Map)['createdAt'] as Timestamp?;
                      final bT = (b.data() as Map)['createdAt'] as Timestamp?;
                      if (aT == null || bT == null) return 0;
                      return bT.compareTo(aT);
                    });
                    return Column(
                      children: docs.take(3).map((doc) => _buildTaskCard(doc)).toList(),
                    );
                  },
                ),
              ],
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

  Widget _heroStat(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500)),
      ],
    );
  }



  Widget _bottomIcon(IconData icon, bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.green.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon),
    );
  }

  Widget _modernBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: BottomNavigationBar(
        currentIndex: selectedIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey.shade400,
        showUnselectedLabels: true,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        onTap: (index) => setState(() => selectedIndex = index),
        items: [
          BottomNavigationBarItem(icon: _bottomIcon(Icons.home_outlined, selectedIndex == 0), label: "Home"),
          BottomNavigationBarItem(icon: _bottomIcon(Icons.assignment_outlined, selectedIndex == 1), label: "Tasks"),
          BottomNavigationBarItem(icon: _bottomIcon(Icons.map_outlined, selectedIndex == 2), label: "Map"),
          BottomNavigationBarItem(icon: _bottomIcon(Icons.person_outline, selectedIndex == 3), label: "Profile"),
        ],
      ),
    );
  }

  Widget _getPage(int index) {
    switch (index) {
      case 0: return _dashboardPage();
      case 1: return VolunteerAvailableTasksPage(
        userId: widget.userId,
        onTabSwitch: (newIndex) => setState(() => selectedIndex = newIndex),
      );
      case 2: return MapPage(userId: widget.userId);
      case 3: return VolunteerProfilePage(userId: widget.userId);
      default: return _dashboardPage();
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
}

