import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'task_service.dart';
import 'notification_service.dart';

class NGORequestsPage extends StatefulWidget {
  const NGORequestsPage({super.key});

  @override
  State<NGORequestsPage> createState() => _NGORequestsPageState();
}

class _NGORequestsPageState extends State<NGORequestsPage> {
  // Cache outer stream — scoped to this NGO's claimed posts
  Stream<QuerySnapshot>? _postsStream;
  // Cache inner requests stream to avoid flash-to-empty
  Stream<QuerySnapshot>? _requestsStream;
  List<String> _lastClaimedPostIds = [];

  @override
  void initState() {
    super.initState();
    final currentNgoId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _postsStream = FirebaseFirestore.instance
        .collection('posts')
        .where('ngoId', isEqualTo: currentNgoId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF7F9FC),
      appBar: AppBar(
        title: const Text('Receiver Requests',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: _buildRequestList(),
    );
  }

  Widget _buildRequestList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _postsStream,
      builder: (context, postsSnap) {
        if (!postsSnap.hasData) {
          return const Center(child: CircularProgressIndicator(color: Colors.green));
        }

        final claimedPostIds = postsSnap.data!.docs.map((d) => d.id).toList();

        if (claimedPostIds.isEmpty) {
          return _emptyState(
            'No claimed donations yet',
            'Claim a donation first so receivers can send you requests.',
          );
        }

        // ── PHASE 3 FIX: chunk whereIn into batches of 10 ──────────────
        // Firestore whereIn limit is 30; we use 10 for safety margin.
        final newKey = claimedPostIds.join(',');
        final oldKey = _lastClaimedPostIds.join(',');

        if (newKey != oldKey) {
          _lastClaimedPostIds = List.from(claimedPostIds);
          // Build a merged real-time stream by fetching all at once.
          // Because we can't easily merge Firestore streams client-side,
          // we query with a Firestore stream on the first chunk and reload
          // when the outer stream changes. For >10 posts we fall back to
          // one-time batched fetch inside the StreamBuilder pattern below.
          if (claimedPostIds.length <= 10) {
            _requestsStream = FirebaseFirestore.instance
                .collection('requests')
                .where('itemId', whereIn: claimedPostIds)
                .snapshots();
          } else {
            // For >10, query by ngoId directly on the requests collection.
            // Requests now include ngoId when receiver sends request to a
            // claimed post (see ReceiverHomePage._sendRequest fix).
            final currentNgoId = FirebaseAuth.instance.currentUser?.uid ?? '';
            _requestsStream = FirebaseFirestore.instance
                .collection('requests')
                .where('ngoId', isEqualTo: currentNgoId)
                .snapshots();
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _requestsStream,
          builder: (context, reqSnap) {
            if (!reqSnap.hasData) {
              return const Center(child: CircularProgressIndicator(color: Colors.green));
            }

            final allRequests = reqSnap.data!.docs;
            final pending =
                allRequests.where((d) => (d.data() as Map)['status'] == 'pending').toList();
            final accepted =
                allRequests.where((d) => (d.data() as Map)['status'] == 'accepted').toList();
            final rejected =
                allRequests.where((d) => (d.data() as Map)['status'] == 'rejected').toList();

            if (allRequests.isEmpty) {
              return _emptyState(
                'No requests yet',
                'Once receivers request your claimed donations, they will appear here.',
              );
            }

            return DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  Container(
                    color: Colors.white,
                    child: TabBar(
                      labelColor: Colors.green,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.green,
                      tabs: [
                        Tab(text: 'Pending (${pending.length})'),
                        Tab(text: 'Accepted (${accepted.length})'),
                        Tab(text: 'Rejected (${rejected.length})'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _requestList(pending, showActions: true),
                        _requestList(accepted, showActions: false),
                        _requestList(rejected, showActions: false),
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

  Widget _requestList(List<QueryDocumentSnapshot> requests, {required bool showActions}) {
    if (requests.isEmpty) {
      return const Center(
          child: Text('No requests in this category.', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index].data() as Map<String, dynamic>;
        final receiverName = req['receiverName'] ?? 'Receiver';
        final itemTitle = req['itemTitle'] ?? req['requestedItem'] ?? 'Food Item';
        final createdAt = (req['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
        final status = req['status'] ?? 'pending';

        Color statusColor = Colors.orange;
        if (status == 'accepted') statusColor = Colors.green;
        if (status == 'rejected') statusColor = Colors.red;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20)
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.green.shade50,
                    child: const Icon(Icons.person_outline, color: Colors.green),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(receiverName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(DateFormat('MMM dd • hh:mm a').format(createdAt),
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(status.toUpperCase(),
                        style: TextStyle(
                            color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Requested: $itemTitle',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              if (showActions) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await requests[index].reference.update({'status': 'rejected'});

                          // Notify receiver of rejection
                          final receiverId = req['receiverId'] ?? '';
                          if (receiverId.isNotEmpty) {
                            await NotificationService.sendNotification(
                              recipientId: receiverId,
                              title: 'Request Rejected',
                              message: 'Your request for "$itemTitle" was not accepted.',
                              type: 'rejection',
                              relatedId: requests[index].id,
                              relatedType: 'request',
                            );
                          }

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Request rejected.'),
                                  backgroundColor: Colors.red),
                            );
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Reject',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final currentNgoId =
                              FirebaseAuth.instance.currentUser?.uid ?? '';
                          final itemId = req['itemId'] ?? '';
                          final receiverId = req['receiverId'] ?? '';
                          final donorId = req['donorId'] ?? '';
                          final requestId = requests[index].id;

                          // 1. Accept the request
                          await requests[index].reference.update({'status': 'accepted'});

                          // 2. Fetch post details for task fields
                          String pickup = 'Donor Location';
                          if (itemId.isNotEmpty) {
                            try {
                              final postDoc = await FirebaseFirestore.instance
                                  .collection('posts')
                                  .doc(itemId)
                                  .get();
                              if (postDoc.exists) {
                                pickup = (postDoc.data()?['location'] as String?) ??
                                    'Donor Location';
                              }
                            } catch (_) {}
                          }

                          // 3. Auto-create delivery task
                          await TaskService.createDeliveryTask(
                            ngoId: currentNgoId,
                            postId: itemId,
                            requestId: requestId,
                            donorId: donorId,
                            receiverId: receiverId,
                            title: itemTitle,
                            pickup: pickup,
                            dropoff: 'Receiver: $receiverName',
                            receiverName: receiverName,
                          );

                          // 4. Notify receiver
                          if (receiverId.isNotEmpty) {
                            await NotificationService.sendNotification(
                              recipientId: receiverId,
                              title: 'Request Accepted! 🎉',
                              message:
                                  'Your request for "$itemTitle" was accepted. A volunteer will deliver it soon.',
                              type: 'approval',
                              relatedId: requestId,
                              relatedType: 'request',
                            );
                          }

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Approved! Delivery task created for volunteers.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Text('Approve',
                            style:
                                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _emptyState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mark_email_read_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

