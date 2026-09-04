import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'notification_service.dart';

class IncomingRequestsPage extends StatefulWidget {
  final String userId;
  const IncomingRequestsPage({super.key, required this.userId});

  @override
  State<IncomingRequestsPage> createState() => _IncomingRequestsPageState();
}

class _IncomingRequestsPageState extends State<IncomingRequestsPage> {
  final requestsRef = FirebaseFirestore.instance.collection('requests');

  String _formatTimeAgo(dynamic timestamp) {
    if (timestamp == null) return '';
    if (timestamp is! Timestamp) return '';

    final DateTime dateTime = timestamp.toDate();
    final Duration diff = DateTime.now().difference(dateTime);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, yyyy').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xffF5F7F6),
        appBar: AppBar(
          title: const Text('Incoming Requests'),
          backgroundColor: Colors.green,
          elevation: 2,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: requestsRef
              .where('donorId', isEqualTo: widget.userId)
              .snapshots(), // Single where clause - rules can validate this
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'If this persists, check Firestore rules and indexes.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text(
                  'No requests yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              );
            }

            // Filter pending and sort by timestamp client-side
            final allDocs = snapshot.data!.docs;
            final pendingRequests = allDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['status'] == 'pending';
            }).toList();

            // Sort by timestamp descending
            pendingRequests.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aTime = aData['timestamp'] as Timestamp?;
              final bTime = bData['timestamp'] as Timestamp?;
              if (aTime == null || bTime == null) return 0;
              return bTime.compareTo(aTime);
            });

            if (pendingRequests.isEmpty) {
              return const Center(
                child: Text(
                  'No pending requests',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: pendingRequests.length,
              itemBuilder: (context, index) {
                final data =
                pendingRequests[index].data() as Map<String, dynamic>;
                final status = data['status'] ?? 'pending';
                final docId = pendingRequests[index].id;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: status == 'accepted'
                          ? [Colors.green.shade300, Colors.green.shade100]
                          : status == 'rejected'
                          ? [Colors.red.shade300, Colors.red.shade100]
                          : [Colors.white, Colors.white],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildAvatar(data['receiverId'], data['receiverName']),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['receiverName'] ?? "Unknown",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Requested: ${data['requestedItem'] ?? data['itemTitle'] ?? 'Item'}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatTimeAgo(data['timestamp']),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _updateRequest(docId, 'rejected'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: BorderSide(color: Colors.red.shade300),
                                padding:
                                const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Reject',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _updateRequest(docId, 'accepted'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding:
                                const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Accept',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
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
        ),
      ),
    );
  }

  Widget _buildAvatar(String? id, String? name) {
    return CircleAvatar(
      radius: 28,
      backgroundColor: Colors.green.shade100,
      child: Text(
        name != null && name.isNotEmpty ? name[0].toUpperCase() : "U",
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.green,
        ),
      ),
    );
  }

  Future<void> _updateRequest(String id, String status) async {
    try {
      // PHASE 1 FIX: Do NOT set post.status = 'accepted'.
      // Only update the per-request status. Post stays 'active' until
      // the receiver physically picks it up (marks it completed in MyPickupsPage).
      await requestsRef.doc(id).update({'status': status});

      // Fetch request doc to get receiver info for notification
      final doc = await requestsRef.doc(id).get();
      final data = doc.data() as Map<String, dynamic>;

      await NotificationService.sendNotification(
        recipientId: data['receiverId'] ?? '',
        title: status == 'accepted' ? "Request Accepted! 🎉" : "Request Rejected",
        message: status == 'accepted'
            ? "Your request for '${data['requestedItem'] ?? data['itemTitle']}' was accepted."
            : "Unfortunately, your request for '${data['requestedItem'] ?? data['itemTitle']}' was not accepted.",
        type: status == 'accepted' ? "approval" : "rejection",
        relatedId: id,
        relatedType: 'request',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'accepted' ? 'Request Accepted! 🎉' : 'Request Rejected'),
            backgroundColor: status == 'accepted' ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error updating request: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update: $e")),
        );
      }
    }
  }
}

