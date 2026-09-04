import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/ai_urgency_badge.dart';
import 'notification_service.dart';

class VolunteerAvailableTasksPage extends StatefulWidget {
  final String userId;
  final Function(int) onTabSwitch;
  const VolunteerAvailableTasksPage({super.key, required this.userId, required this.onTabSwitch});

  @override
  State<VolunteerAvailableTasksPage> createState() => _VolunteerAvailableTasksPageState();
}

class _VolunteerAvailableTasksPageState extends State<VolunteerAvailableTasksPage> {
  String selectedFilter = "All";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: CircleAvatar(
            backgroundColor: Colors.green.shade100,
            child: const Icon(Icons.person, color: Colors.green),
          ),
        ),
        title: const Text(
          "Volunteer",
          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.grey),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Available Tasks",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              "Help your community today by completing a delivery.",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
            const SizedBox(height: 24),
            
            // Filter Chips
            Row(
              children: [
                _buildFilterChip("All"),
                const SizedBox(width: 12),
                _buildFilterChip("Closest"),
                const SizedBox(width: 12),
                _buildFilterChip("Urgent"),
              ],
            ),
            const SizedBox(height: 32),

            // My Assignments (Drives/Events assigned by NGO)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("drives")
                  .where("assignedVolunteers", arrayContains: widget.userId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
                final drives = snapshot.data!.docs;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("My Assignments", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 16),
                    ...drives.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      // PHASE 2+3 FIX: Read both 'address' and 'location' from drives
            // since two creation paths write different field names.
            return _buildTaskCard(
                        data['name'] ?? "Food Drive",
                        data['address'] ?? data['location'] ?? "NGO Location",
                        "Distribution Point",
                        "Event",
                        data['imageUrl'] ?? "https://images.unsplash.com/photo-1593113598332-cd288d649433?auto=format&fit=crop&q=80&w=800",
                        isUrgent: true,
                        isDrive: true,
                        taskId: doc.id,
                      );
                    }),
                    const Divider(height: 40),
                  ],
                );
              },
            ),

            const Text("Upcoming Food Drives", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("drives")
                  .where("status", isEqualTo: "active")
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
                final drives = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final vols = List<String>.from(data['assignedVolunteers'] ?? []);
                  return !vols.contains(widget.userId);
                }).toList();
                
                if (drives.isEmpty) return const SizedBox.shrink();

                return Column(
                  children: [
                    ...drives.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return _buildTaskCard(
                        data['name'] ?? "Food Drive",
                        data['location'] ?? "NGO Location",
                        "Distribution Point",
                        "Event",
                        data['imageUrl'] ?? "https://images.unsplash.com/photo-1593113598332-cd288d649433?auto=format&fit=crop&q=80&w=800",
                        isUrgent: false,
                        isDrive: true,
                        isJoinable: true,
                        taskId: doc.id,
                      );
                    }),
                    const Divider(height: 40),
                  ],
                );
              },
            ),

            // My Active Deliveries
            const Text("My Active Deliveries", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("tasks")
                  .where("assignedTo", isEqualTo: widget.userId)
                  .where("status", isEqualTo: "assigned")
                  .snapshots(),
              builder: (context, snapshot) {
                final tasks = snapshot.data?.docs ?? [];
                if (tasks.isEmpty) {
                  return const Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: Text("No active deliveries assigned.", style: TextStyle(color: Colors.grey)),
                );
                }

                return Column(
                  children: tasks.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildTaskCard(
                      data['title'] ?? "Delivery Task",
                      data['pickup'] ?? "Unknown",
                      data['dropoff'] ?? "Unknown",
                      "${data['estimatedMinutes'] ?? 30}min est.",
                      data['imageUrl'] ?? "https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&q=80&w=600",
                      taskId: doc.id,
                      isUrgent: (data['aiUrgencyLevel'] == 'critical' || data['aiUrgencyLevel'] == 'urgent'),
                      aiData: data,
                      isAccepted: true,
                    );
                  }).toList(),
                );
              },
            ),
            const Divider(height: 40),

            const Text("Available for Pickup", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("tasks")
                  .where("assignedTo", isEqualTo: "")
                  .where("status", isEqualTo: "pending")
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.green));
                }
                
                final tasks = snapshot.data?.docs ?? [];
                
                if (tasks.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assignment_late_outlined, size: 60, color: Colors.green.shade200),
                          const SizedBox(height: 16),
                          const Text("No New Tasks", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                          const SizedBox(height: 8),
                          Text(
                            "Check back later for new tasks!",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // AI-priority sort
                int urgencyRank(String? u) =>
                    u == 'critical' ? 0 : u == 'urgent' ? 1 : 2;

                List<QueryDocumentSnapshot> filteredTasks = List.from(tasks);
                // ... sorting logic ...
                filteredTasks.sort((a, b) {
                  final au = (a.data() as Map)['aiUrgencyLevel'] as String? ?? 'normal';
                  final bu = (b.data() as Map)['aiUrgencyLevel'] as String? ?? 'normal';
                  return urgencyRank(au).compareTo(urgencyRank(bu));
                });

                return Column(
                  children: filteredTasks.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final estMins = data['estimatedMinutes'] as int? ?? 30;
                    final aiUrgency = data['aiUrgencyLevel'] as String? ?? 'normal';
                    final isUrgentTask = aiUrgency == 'critical' || aiUrgency == 'urgent';
                    return _buildTaskCard(
                      data['title'] ?? "Delivery Task",
                      data['pickup'] ?? "Unknown",
                      data['dropoff'] ?? "Unknown",
                      "${estMins}min est.",
                      data['imageUrl'] ?? "https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&q=80&w=600",
                      taskId: doc.id,
                      isUrgent: isUrgentTask,
                      aiData: data,
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    bool isSelected = selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => selectedFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF006D3E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildTaskCard(String title, String pickup, String dropoff, String distance, String imageUrl, {bool isUrgent = false, bool isDrive = false, bool isJoinable = false, bool isAccepted = false, String? taskId, Map<String, dynamic>? aiData}) {
    // Pulsing border color for urgent/critical AI tasks
    final borderColor = isUrgent ? const Color(0xFFE67E22) : Colors.transparent;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 700),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: isUrgent ? 2 : 0),
        boxShadow: [
          if (isUrgent)
            BoxShadow(
              color: const Color(0xFFE67E22).withOpacity(0.25),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 6),
            )
          else
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                child: Builder(
                  builder: (context) {
                    Widget buildImg(String url) => Image.network(
                          url,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 180,
                            width: double.infinity,
                            color: Colors.grey.shade200,
                            child: Icon(Icons.image_not_supported, color: Colors.grey.shade400, size: 40),
                          ),
                        );
                    
                    if (aiData != null) {
                      final taskImage = aiData['itemImage'] ?? aiData['imageUrl'];
                      if (taskImage != null && taskImage.toString().isNotEmpty && !taskImage.toString().contains('unsplash')) {
                        return buildImg(taskImage);
                      }
                    }

                    if (aiData != null && aiData['postId'] != null && imageUrl.contains('unsplash')) {
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('posts').doc(aiData['postId']).get(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data!.exists) {
                            final postData = snapshot.data!.data() as Map<String, dynamic>;
                            final postImageUrl = postData['itemImage'] ?? postData['imageUrl'];
                            if (postImageUrl != null && postImageUrl.toString().isNotEmpty) {
                              return buildImg(postImageUrl);
                            }
                          }
                          return buildImg(imageUrl);
                        },
                      );
                    }
                    return buildImg(imageUrl);
                  }
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: [
                      const Icon(Icons.near_me, size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(distance, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    if (isUrgent)
                      AiUrgencyBadge(
                        urgency: aiData?['aiUrgencyLevel'] as String? ?? 'urgent',
                      ),
                  ],
                ),
                if (aiData != null) ...[ 
                  const SizedBox(height: 6),
                  AiInfoRow(data: aiData, compact: true),
                ],
                const SizedBox(height: 16),
                _buildLocationRow(Icons.radio_button_off, "PICKUP", pickup),
                const SizedBox(height: 12),
                _buildLocationRow(Icons.location_on, "DROP-OFF", dropoff),
                const SizedBox(height: 24),
                if (isDrive) 
                  Row(
                    children: [
                      if (!isJoinable)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              await FirebaseFirestore.instance.collection("drives").doc(taskId).update({
                                "assignedVolunteers": FieldValue.arrayRemove([widget.userId])
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text("Reject", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      if (!isJoinable) const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (isJoinable) {
                              await FirebaseFirestore.instance.collection("drives").doc(taskId).update({
                                "assignedVolunteers": FieldValue.arrayUnion([widget.userId])
                              });
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Joined drive!"), backgroundColor: Colors.green),
                                );
                              }
                            } else {
                              widget.onTabSwitch(2);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF006D3E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: Text(isJoinable ? "Join Drive" : "Navigate", style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                if (!isDrive && !isAccepted)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _acceptTask(taskId, isDrive),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF006D3E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text("Accept Delivery", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  )
                else if (isAccepted)
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                // Contact logic placeholder
                              },
                              icon: const Icon(Icons.chat_bubble_outline, size: 18),
                              label: const Text("Contact"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF006D3E),
                                side: const BorderSide(color: Color(0xFF006D3E)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _markTaskCompleted(taskId),
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text("Complete"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => widget.onTabSwitch(2),
                          icon: const Icon(Icons.map_outlined, size: 18),
                          label: const Text("View on Map"),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF006D3E)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, String label, String address) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.green),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
              Text(address, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis, maxLines: 2),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _markTaskCompleted(String? taskId) async {
    if (taskId == null) return;
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
      debugPrint("Error marking task completed: \$e");
    }
  }

  Future<void> _acceptTask(String? taskId, bool isDrive) async {
    if (taskId == null) return;
    if (isDrive) {
      widget.onTabSwitch(2);
      return;
    }
    try {
      await FirebaseFirestore.instance.collection("tasks").doc(taskId).update({
        "assignedTo": widget.userId,
        "status": "assigned",
      });
      
      final taskDoc = await FirebaseFirestore.instance.collection("tasks").doc(taskId).get();
      if (taskDoc.exists) {
        final data = taskDoc.data();
        if (data != null && data.containsKey("postId") && data["postId"] != null) {
          await FirebaseFirestore.instance.collection("posts").doc(data["postId"]).update({
            "status": "assigned",
            "volunteerId": widget.userId,
          });
        }
        // Notify Donor
        if (data != null && data["donorId"] != null) {
          await FirebaseFirestore.instance.collection("notifications").add({
            'recipientId': data["donorId"],
            'title': 'Rider Assigned! 🛵',
            'message': 'A rider has accepted the task for "${data['title']}".',
            'type': 'task',
            'relatedId': taskId,
            'isRead': false,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Task accepted! Starting navigation..."), backgroundColor: Colors.green),
        );
      }
      // Automatically switch to Map tab (index 2)
      widget.onTabSwitch(2);
    } catch (e) {
      debugPrint("Error accepting task: $e");
    }
  }
}

