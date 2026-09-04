import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';
import 'services/ai_recommendation_service.dart';

class NGOVolunteersPage extends StatefulWidget {
  const NGOVolunteersPage({super.key});

  @override
  State<NGOVolunteersPage> createState() => _NGOVolunteersPageState();
}

class _NGOVolunteersPageState extends State<NGOVolunteersPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF7F9FC),
      appBar: AppBar(
        title: const Text('Manage Volunteers',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'Volunteer')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Text('Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red)));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.green));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                          color: Colors.green.shade50, shape: BoxShape.circle),
                      child: Icon(Icons.people_outline,
                          size: 64, color: Colors.green.shade300),
                    ),
                    const SizedBox(height: 24),
                    const Text('No Volunteers Yet',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                    const SizedBox(height: 12),
                    Text(
                      'When users sign up as volunteers, they will appear here.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 16, height: 1.5),
                    ),
                  ],
                ),
              ),
            );
          }

          final volunteers = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: volunteers.length,
            itemBuilder: (context, index) {
              final doc = volunteers[index];
              final v = doc.data() as Map<String, dynamic>;
              final name = v['name'] as String? ?? 'Volunteer';
              final email = v['email'] as String? ?? '';
              final status = v['status'] as String? ?? 'Available';

              final statusColor = status == 'Available'
                  ? Colors.green
                  : status == 'Busy'
                      ? Colors.orange
                      : Colors.grey;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
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
                      radius: 28,
                      backgroundColor: Colors.green.shade50,
                      child: Text(
                        name[0].toUpperCase(),
                        style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(email,
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 13)),
                          const SizedBox(height: 8),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('tasks')
                                .where('assignedTo', isEqualTo: doc.id)
                                .where('status', isEqualTo: 'delivered')
                                .snapshots(),
                            builder: (context, snap) {
                              final count =
                                  snap.hasData ? snap.data!.docs.length : 0;
                              return Text(
                                'Deliveries completed: $count',
                                style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10)),
                          child: Text(status,
                              style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () =>
                              _showAssignTaskDialog(doc.id, name),
                          icon: const Icon(Icons.assignment_ind, size: 16),
                          label: const Text('Assign'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // AI-enhanced task assignment dialog
  // ─────────────────────────────────────────────────────────────────────────

  void _showAssignTaskDialog(String volunteerId, String volunteerName) {
    final currentNgoId = FirebaseAuth.instance.currentUser?.uid ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('tasks')
              .where('ngoId', isEqualTo: currentNgoId)
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final tasks = snapshot.data!.docs;

            // Sort tasks by AI urgency for smarter assignment
            tasks.sort((a, b) {
              final ad = a.data() as Map<String, dynamic>;
              final bd = b.data() as Map<String, dynamic>;
              int urgencyRank(String? u) =>
                  u == 'critical' ? 0 : u == 'urgent' ? 1 : 2;
              return urgencyRank(ad['aiUrgencyLevel'] as String?)
                  .compareTo(urgencyRank(bd['aiUrgencyLevel'] as String?));
            });

            return ListView(
              controller: controller,
              padding: const EdgeInsets.all(24),
              children: [
                // Handle indicator
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Assign Task to $volunteerName',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'AI-sorted by urgency. Select a pending task below.',
                  style:
                      TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 20),

                if (tasks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.assignment_turned_in,
                              size: 60, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No pending deliveries available',
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  )
                else
                  ...tasks.map((taskDoc) {
                    final t = taskDoc.data() as Map<String, dynamic>;
                    final aiUrgency =
                        t['aiUrgencyLevel'] as String? ?? 'normal';
                    final spoilageRisk =
                        t['spoilageRiskDuringDelivery'] as String? ?? 'low';
                    final predictedMins =
                        (t['predictedDeliveryMinutes'] as num?)?.toInt() ?? 30;
                    final isUrgent =
                        aiUrgency == 'critical' || aiUrgency == 'urgent';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isUrgent
                              ? const Color(0xFFE67E22).withValues(alpha: 0.5)
                              : Colors.grey.shade200,
                          width: isUrgent ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        color: isUrgent
                            ? const Color(0xFFFFF8F2)
                            : Colors.white,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isUrgent
                                        ? Colors.orange.shade50
                                        : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.delivery_dining,
                                    color: isUrgent
                                        ? Colors.orange.shade700
                                        : Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t['title'] ?? 'Delivery',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15),
                                      ),
                                      Text(
                                        '${t['pickup']} → ${t['dropoff']}',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // AI metadata row
                            Wrap(
                              spacing: 8,
                              children: [
                                _taskChip('~${predictedMins}min',
                                    Icons.timer, Colors.blue.shade700),
                                if (aiUrgency != 'normal')
                                  _taskChip(
                                    aiUrgency.toUpperCase(),
                                    Icons.warning_amber,
                                    aiUrgency == 'critical'
                                        ? Colors.red
                                        : Colors.orange,
                                  ),
                                if (spoilageRisk == 'high' ||
                                    spoilageRisk == 'critical')
                                  _taskChip(
                                      'Spoilage Risk',
                                      Icons.thermostat,
                                      Colors.red.shade700),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () =>
                                    _assignTask(taskDoc.id, volunteerId, t,
                                        volunteerName),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isUrgent
                                      ? const Color(0xFFE67E22)
                                      : Colors.green,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                ),
                                child: Text(
                                  isUrgent ? 'Assign (Urgent)' : 'Assign',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _taskChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Future<void> _assignTask(
      String taskId, String volunteerId, Map<String, dynamic> taskData,
      String volunteerName) async {
    await FirebaseFirestore.instance.collection('tasks').doc(taskId).update({
      'assignedTo': volunteerId,
      'status': 'assigned',
      'assignedAt': FieldValue.serverTimestamp(),
    });

    if (taskData['postId'] != null) {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(taskData['postId'] as String)
          .update({'status': 'assigned', 'volunteerId': volunteerId});
    }

    await NotificationService.sendNotification(
      recipientId: volunteerId,
      title: (taskData['aiUrgencyLevel'] == 'critical' ||
              taskData['aiUrgencyLevel'] == 'urgent')
          ? '⚡ Urgent Task Assigned!'
          : 'New Task Assigned!',
      message:
          'You have been assigned: "${taskData['title'] ?? "a delivery task"}".',
      type: 'task',
      relatedId: taskId,
    );

    // Invalidate volunteer recommendation cache for this NGO
    AiRecommendationService.clearCache();

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task assigned to $volunteerName!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}

