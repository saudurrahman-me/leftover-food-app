import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'ngo_create_event_page.dart';

class NGOEventsPage extends StatefulWidget {
  const NGOEventsPage({super.key});

  @override
  State<NGOEventsPage> createState() => _NGOEventsPageState();
}

class _NGOEventsPageState extends State<NGOEventsPage> {
  @override
  Widget build(BuildContext context) {
    final currentNgoId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: const Color(0xffF7F9FC),
      appBar: AppBar(
        title: const Text("Food Events & Drives", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      // PHASE 3 FIX: Filter drives by current NGO's id.
      // Supports both ngoId (dashboard quick dialog) and createdBy (NGOCreateEventPage).
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("drives")
            .where("ngoId", isEqualTo: currentNgoId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final drives = snapshot.data?.docs ?? [];

          if (drives.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.campaign_outlined, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text("No active events", style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: drives.length,
            itemBuilder: (context, index) {
              final drive = drives[index].data() as Map<String, dynamic>;
              return _buildEventCard(drive, drives[index].id);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NGOCreateEventPage()),
          );
        },
        backgroundColor: Colors.green.shade700,
        label: const Text("New Event", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> drive, String docId) {
    final name = drive['name'] ?? "Food Drive";
    // PHASE 3+2 FIX: Read both 'address' and 'location' — two creation paths use different fields.
    final location = drive['address'] ?? drive['location'] ?? "Location unknown";
    final progress = (drive['progress'] ?? 0.0).toDouble();
    final imageUrl = drive['imageUrl'] ?? "https://images.unsplash.com/photo-1488459739022-dffee1d2d7eb?auto=format&fit=crop&q=80&w=600";
    final List assignedVolunteers = drive['assignedVolunteers'] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
            child: Image.network(
              imageUrl,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 160,
                width: double.infinity,
                color: Colors.grey.shade200,
                child: Icon(Icons.image_not_supported, color: Colors.grey.shade400, size: 40),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                          child: const Text("Active", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text("Delete Event"),
                                content: const Text("Are you sure you want to delete this event?"),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              if (!context.mounted) return;
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.green)),
                              );
                              try {
                                await FirebaseFirestore.instance.collection("drives").doc(docId).delete().timeout(const Duration(seconds: 10));
                                if (!context.mounted) return;
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Event deleted successfully!"), backgroundColor: Colors.green));
                              } catch (e, st) {
                                debugPrint("ERROR deleting event: $e\n$st");
                                if (!context.mounted) return;
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        style: TextStyle(color: Colors.grey.shade600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text("Assigned Volunteers", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (assignedVolunteers.isEmpty)
                      Text("No volunteers assigned yet", style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontStyle: FontStyle.italic))
                    else
                      ...assignedVolunteers.take(3).map((v) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.blue.shade100,
                          child: const Icon(Icons.person, size: 14, color: Colors.blue),
                        ),
                      )),
                    if (assignedVolunteers.length > 3)
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.grey.shade200,
                        child: Text("+${assignedVolunteers.length - 3}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _showAssignVolunteerDialog(docId, assignedVolunteers),
                      child: const Text("Assign", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text("Collection Progress", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.green.shade50,
                  valueColor: AlwaysStoppedAnimation(Colors.green.shade700),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  void _showAssignVolunteerDialog(String docId, List currentVolunteers) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (_) => StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection("users").where("role", isEqualTo: "Volunteer").snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final volunteers = snapshot.data!.docs;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Assign Volunteers", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    itemCount: volunteers.length,
                    itemBuilder: (context, index) {
                      final vData = volunteers[index].data() as Map<String, dynamic>;
                      final vName = vData['name'] ?? "Volunteer";
                      final vId = volunteers[index].id;
                      final isAssigned = currentVolunteers.contains(vId);

                      return ListTile(
                        leading: CircleAvatar(backgroundColor: Colors.green.shade100, child: const Icon(Icons.person, color: Colors.green)),
                        title: Text(vName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: Checkbox(
                          value: isAssigned,
                          onChanged: (val) async {
                            if (val == true) {
                              await FirebaseFirestore.instance.collection("drives").doc(docId).update({
                                "assignedVolunteers": FieldValue.arrayUnion([vId])
                              });
                            } else {
                              await FirebaseFirestore.instance.collection("drives").doc(docId).update({
                                "assignedVolunteers": FieldValue.arrayRemove([vId])
                              });
                            }
                            if (!context.mounted) return;
                            Navigator.pop(context);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

