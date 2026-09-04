import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class MyFoodPostsPage extends StatefulWidget {
  const MyFoodPostsPage({super.key, required String userId});

  @override
  State<MyFoodPostsPage> createState() => _MyFoodPostsPageState();
}

class _MyFoodPostsPageState extends State<MyFoodPostsPage> {
  final user = FirebaseAuth.instance.currentUser;

  bool _isExpired(String expiryText) {
    try {
      final parts = expiryText.split("to");
      if (parts.length != 2) return false;

      final endTimeStr = parts[1].trim();
      final now = DateTime.now();
      final format = DateFormat.jm(); // 12-hour format
      final endTime = format.parse(endTimeStr);

      final expiryDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        endTime.hour,
        endTime.minute,
      );

      return now.isAfter(expiryDateTime);
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xffF5F7F6),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            "My Food Posts",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          automaticallyImplyLeading: false,
          bottom: const TabBar(
            labelColor: Colors.green,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.green,
            tabs: [
              Tab(text: "Active"),
              Tab(text: "History"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildPostList(["active", "accepted", "claimed", "assigned"]),
            _buildPostList(["completed", "delivered", "expired", "rejected"]),
          ],
        ),
      ),
    );
  }

  Widget _buildPostList(List<String> statuses) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("posts")
          .where("userID", isEqualTo: user!.uid)
          .where("status", whereIn: statuses)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.green));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.post_add, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  "No ${statuses.contains("completed") ? "historical" : "active"} posts yet!",
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          );
        }

        final posts = List.of(snapshot.data!.docs);
        posts.sort((a, b) {
          final aT = (a.data() as Map)['createdAt'] as Timestamp?;
          final bT = (b.data() as Map)['createdAt'] as Timestamp?;
          if (aT == null || bT == null) return 0;
          return bT.compareTo(aT);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: posts.length,
          itemBuilder: (context, index) {
              final post = posts[index];
              final imageUrl = post["imageUrl"] ?? "";
              final title = post["title"] ?? "";
              final description = post["description"] ?? "";
              final quantity = post["quantity"] ?? "";
              final location = post["location"] ?? "";
              final expiry = post["expiryDate"] ?? "";
              final status = post["status"] ?? "active";
              final aiScore = post["aiFreshnessScore"];

              final expired = _isExpired(expiry);
              if (expired && status == "active") {
                // Lazily update status to 'expired' in backend
                FirebaseFirestore.instance.collection("posts").doc(post.id).update({"status": "expired"});
              }

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image
                    if (imageUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        child: Image.network(
                          imageUrl,
                          height: 220,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 220,
                            width: double.infinity,
                            color: Colors.grey[200],
                            child: const Icon(Icons.fastfood, size: 50, color: Colors.grey),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title & Status
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: expired
                                      ? Colors.red
                                      : (status == "active" ? Colors.green : ((status == "accepted" || status == "claimed" || status == "assigned" || status == "completed" || status == "delivered") ? Colors.blue : Colors.grey)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  expired ? "EXPIRED" : status.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text("Delete Post"),
                                      content: const Text("Are you sure you want to delete this food post?"),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
                                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
                                      ],
                                    ),
                                  );
                                    if (confirm == true) {
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.green)),
                                      );
                                      try {
                                        await Future(() async {
                                          final relatedReqs = await FirebaseFirestore.instance
                                              .collection("requests")
                                              .where("itemId", isEqualTo: post.id)
                                              .get();
                                          
                                          final batch = FirebaseFirestore.instance.batch();
                                          for (var reqDoc in relatedReqs.docs) {
                                            batch.delete(reqDoc.reference);
                                          }
                                          await batch.commit();

                                          await FirebaseFirestore.instance.collection("posts").doc(post.id).delete();
                                        }).timeout(const Duration(seconds: 10));

                                        if (context.mounted) {
                                          Navigator.pop(context); // Close loading
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Post deleted successfully"), backgroundColor: Colors.green));
                                        }
                                      } catch (e, st) {
                                        debugPrint("ERROR deleting post: $e\n$st");
                                        if (context.mounted) {
                                          Navigator.pop(context); // Close loading
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                                        }
                                      }
                                    }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            description,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 18, color: Colors.green),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  location,
                                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.format_list_numbered, size: 18, color: Colors.green),
                              const SizedBox(width: 6),
                              Text(
                                "Quantity: $quantity",
                                style: const TextStyle(fontSize: 14, color: Colors.black87),
                              ),
                              const SizedBox(width: 12),
                              const Icon(Icons.access_time, size: 18, color: Colors.orange),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  expiry,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: expired ? Colors.red : Colors.black87,
                                  ),
                                ),
                              ),
                              if (aiScore != null) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.psychology, size: 18, color: Colors.purple),
                                const SizedBox(width: 4),
                                Text(
                                  "$aiScore% Fresh",
                                  style: const TextStyle(fontSize: 14, color: Colors.purple, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ],
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

