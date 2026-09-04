import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'task_service.dart';
import 'notification_service.dart';
import 'widgets/ai_urgency_badge.dart';

class NGODonationsPage extends StatefulWidget {
  const NGODonationsPage({super.key});

  @override
  State<NGODonationsPage> createState() => _NGODonationsPageState();
}

class _NGODonationsPageState extends State<NGODonationsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // _approveDonation() removed — was writing to non-existent 'donations' collection.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF7F9FC),
      appBar: AppBar(
        title: const Text("Donation Approvals", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.green,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.green,
              isScrollable: true,
              tabs: const [
                Tab(text: "Available"),
                Tab(text: "Claimed"),
                Tab(text: "Assigned"),
                Tab(text: "Completed"),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAvailableDonations(),
                _buildClaimedDonations(),
                _buildAssignedDonations(),
                _buildCompletedDonations(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableDonations() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("posts")
          .where("status", isEqualTo: "active")
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.green));

        final allDocs = snapshot.data!.docs;

        final now = DateTime.now();
        final nonExpiredDocs = allDocs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
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

          if (isExpired && d['status'] == 'active') {
            FirebaseFirestore.instance.collection('posts').doc(doc.id).update({'status': 'expired'}).catchError((_) {});
          }
          return !isExpired;
        }).toList();

        // Include posts with qty>=50 OR AI-urgent posts regardless of quantity
        final posts = nonExpiredDocs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final quantity = (d['quantity'] ?? 0) as num;
          final aiUrgency = d['aiUrgencyLevel'] as String? ?? 'normal';
          final isUrgent = aiUrgency == 'urgent' || aiUrgency == 'critical';
          return quantity >= 50 || isUrgent;
        }).toList();

        // Sort: critical first, then urgent, then by freshness score
        posts.sort((a, b) {
          final ad = a.data() as Map<String, dynamic>;
          final bd = b.data() as Map<String, dynamic>;
          int rank(String? u) => u == 'critical' ? 0 : u == 'urgent' ? 1 : 2;
          final uCmp = rank(ad['aiUrgencyLevel'] as String?)
              .compareTo(rank(bd['aiUrgencyLevel'] as String?));
          if (uCmp != 0) return uCmp;
          final aScore = (ad['aiFreshnessScore'] as num?)?.toInt() ?? 100;
          final bScore = (bd['aiFreshnessScore'] as num?)?.toInt() ?? 100;
          return aScore.compareTo(bScore);
        });

        if (posts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
                    child: Icon(Icons.fastfood_outlined, size: 64, color: Colors.orange.shade300),
                  ),
                  const SizedBox(height: 24),
                  const Text("No Active Food Posts", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 12),
                  Text(
                    "Donations from nearby donors (50+ people) will appear here. You can claim them for the NGO warehouse.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16, height: 1.5),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final doc = posts[index];
            final d = doc.data() as Map<String, dynamic>;
            final donorName = d['donorName'] ?? "Anonymous";
            final description = d['description'] ?? "No description";
            final title = d['title'] ?? "Food Item";
            final createdAt = (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            final imageUrl = d['imageUrl'] ?? "https://images.unsplash.com/photo-1593113598332-cd288d649433?auto=format&fit=crop&q=80&w=800";

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            Text("By $donorName \u2022 ${DateFormat('MMM dd, hh:mm a').format(createdAt)}", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                            const SizedBox(height: 4),
                            AiInfoRow(data: d, compact: true),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                            child: Text("Available", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                          if ((d['aiUrgencyLevel'] as String? ?? 'normal') != 'normal') ...[
                            const SizedBox(height: 4),
                            AiUrgencyBadge(urgency: d['aiUrgencyLevel'] as String?, compact: true),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(description, style: TextStyle(color: Colors.grey.shade700, fontSize: 15, height: 1.4)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            await FirebaseFirestore.instance.collection("posts").doc(doc.id).update({"status": "rejected"});
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Post marked as rejected."), backgroundColor: Colors.red));
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text("Reject", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
                            final donorId = d['userID'] ?? '';
                            final dName = d['donorName'] ?? 'Donor';
                            final postLocation = d['location'] ?? 'Donor Location';

                            await FirebaseFirestore.instance.collection("posts").doc(doc.id).update({
                              "status": "claimed",
                              "ngoId": currentUserId,
                            });

                            // Propagate AI fields from post to task
                            final ai = TaskService.aiFieldsFromPost(d);
                            await TaskService.createClaimTask(
                              ngoId: currentUserId,
                              postId: doc.id,
                              donorId: donorId,
                              donorName: dName,
                              title: title,
                              pickup: postLocation,
                              dropoff: 'NGO Warehouse',
                              taskPriority: ai.taskPriority,
                              aiFreshnessRisk: ai.aiFreshnessRisk,
                              aiUrgencyLevel: ai.aiUrgencyLevel,
                              estimatedRemainingHours: ai.estimatedRemainingHours,
                            );

                            if (donorId.isNotEmpty) {
                              await NotificationService.sendNotification(
                                recipientId: donorId,
                                title: 'Your Donation Was Claimed!',
                                message: 'An NGO has claimed your post "$title" and will coordinate delivery.',
                                type: 'approval',
                                relatedId: doc.id,
                                relatedType: 'post',
                              );
                            }

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Claimed! Task created for volunteers."),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: const Text("Claim", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildClaimedDonations() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("posts")
          .where("status", isEqualTo: "claimed")
          .where("ngoId", isEqualTo: currentUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.green));

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                    child: Icon(Icons.check_circle_outline, size: 64, color: Colors.blue.shade300),
                  ),
                  const SizedBox(height: 24),
                  const Text("No Claimed Donations", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 12),
                  Text(
                    "When you claim a donation, it will appear here. You can then assign it to a volunteer in the Team tab.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16, height: 1.5),
                  ),
                ],
              ),
            ),
          );
        }

        final posts = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final doc = posts[index];
            final d = doc.data() as Map<String, dynamic>;
            final donorName = d['donorName'] ?? "Anonymous";
            final title = d['title'] ?? "Food Item";
            final createdAt = (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            final imageUrl = d['imageUrl'] ?? "https://images.unsplash.com/photo-1593113598332-cd288d649433?auto=format&fit=crop&q=80&w=800";

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 4),
                        Text("By $donorName • ${DateFormat('MMM dd, hh:mm a').format(createdAt)}", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Text("Claimed", style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAssignedDonations() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("posts")
          .where("status", isEqualTo: "assigned")
          .where("ngoId", isEqualTo: currentUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.green));

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
                    child: Icon(Icons.delivery_dining, size: 64, color: Colors.orange.shade300),
                  ),
                  const SizedBox(height: 24),
                  const Text("No Assigned Donations", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 12),
                  Text(
                    "Donations assigned to volunteers will appear here.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16, height: 1.5),
                  ),
                ],
              ),
            ),
          );
        }

        final posts = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final doc = posts[index];
            final d = doc.data() as Map<String, dynamic>;
            final donorName = d['donorName'] ?? "Anonymous";
            final title = d['title'] ?? "Food Item";
            final createdAt = (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            final imageUrl = d['imageUrl'] ?? "https://images.unsplash.com/photo-1593113598332-cd288d649433?auto=format&fit=crop&q=80&w=800";

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 4),
                        Text("By $donorName • ${DateFormat('MMM dd, hh:mm a').format(createdAt)}", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Text("Assigned", style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCompletedDonations() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("posts")
          .where("status", isEqualTo: "completed")
          .where("ngoId", isEqualTo: currentUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.green));

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                    child: Icon(Icons.check_circle, size: 64, color: Colors.green.shade300),
                  ),
                  const SizedBox(height: 24),
                  const Text("No Completed Donations", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 12),
                  Text(
                    "Delivered donations will appear here.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16, height: 1.5),
                  ),
                ],
              ),
            ),
          );
        }

        final posts = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final doc = posts[index];
            final d = doc.data() as Map<String, dynamic>;
            final donorName = d['donorName'] ?? "Anonymous";
            final title = d['title'] ?? "Food Item";
            final createdAt = (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            final imageUrl = d['imageUrl'] ?? "https://images.unsplash.com/photo-1593113598332-cd288d649433?auto=format&fit=crop&q=80&w=800";

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 4),
                        Text("By $donorName • ${DateFormat('MMM dd, hh:mm a').format(createdAt)}", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Text("Completed", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

