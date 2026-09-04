import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'core/app_config.dart';

class NGOCreateEventPage extends StatefulWidget {
  const NGOCreateEventPage({super.key});

  @override
  State<NGOCreateEventPage> createState() => _NGOCreateEventPageState();
}

class _NGOCreateEventPageState extends State<NGOCreateEventPage> {
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _goalController = TextEditingController();
  final _descController = TextEditingController();

  List<String> selectedVolunteers = [];
  bool _isLaunching = false;

  // Image state — supports mobile (File) and web (Uint8List)
  File? _selectedImageFile;
  Uint8List? _selectedImageBytes;

  String get _cloudName => AppConfig.cloudinaryCloudName;
  String get _uploadPreset => AppConfig.cloudinaryUploadPreset;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _goalController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      if (kIsWeb) {
        _selectedImageBytes = await pickedFile.readAsBytes();
      } else {
        _selectedImageFile = File(pickedFile.path);
        _selectedImageBytes = await _selectedImageFile!.readAsBytes();
      }
      setState(() {});
    }
  }

  /// PHASE 3 FIX: Upload event image to Cloudinary instead of keeping local File.
  Future<String?> _uploadToCloudinary() async {
    if (_selectedImageBytes == null) return null;
    try {
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
      final request = http.MultipartRequest('POST', uri);
      request.fields['upload_preset'] = _uploadPreset;
      request.files.add(http.MultipartFile.fromBytes('file', _selectedImageBytes!, filename: 'event.jpg'));
      final response = await http.Response.fromStream(await request.send());
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['secure_url'] as String?;
      }
    } catch (e) {
      debugPrint('Cloudinary upload error: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: const Text("Vitality Food",
            style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
              icon: const Icon(Icons.notifications_none, color: Colors.grey), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Create Food Drive",
                style: TextStyle(
                    fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 8),
            Text("Fill in the details to launch your community impact event.",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
            const SizedBox(height: 24),

            // Image picker — shows preview
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                  image: _selectedImageBytes != null
                      ? DecorationImage(
                          image: MemoryImage(_selectedImageBytes!), fit: BoxFit.cover)
                      : null,
                ),
                child: _selectedImageBytes == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: Colors.green.shade50, shape: BoxShape.circle),
                            child: const Icon(Icons.add_photo_alternate_outlined,
                                color: Colors.green, size: 32),
                          ),
                          const SizedBox(height: 12),
                          const Text("Upload Event Banner",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, color: Colors.green)),
                          const Text("16:9 ratio recommended",
                              style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      )
                    : null,
              ),
            ),

            const SizedBox(height: 24),

            _buildFieldLabel("Event Name"),
            _buildTextField(_nameController, "e.g. Harvest Hope Community Drive"),

            _buildFieldLabel("Location"),
            _buildTextField(_locationController, "Venue or street address",
                icon: Icons.location_on_outlined),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel("Date"),
                      _buildTextField(_dateController, "mm/dd/yy",
                          icon: Icons.calendar_today_outlined),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel("Start Time"),
                      _buildTextField(_timeController, "--:-- --",
                          icon: Icons.access_time),
                    ],
                  ),
                ),
              ],
            ),

            _buildFieldLabel("Volunteer Goal"),
            _buildTextField(_goalController, "Number of volunteers needed",
                icon: Icons.people_outline),

            _buildFieldLabel("Event Description"),
            _buildTextField(
                _descController, "Tell volunteers about the impact...",
                maxLines: 4),

            const SizedBox(height: 24),

            const Text("Assign Initial Volunteers",
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 12),
            _buildVolunteerSelector(),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLaunching ? null : _launchEvent,
                icon: _isLaunching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.rocket_launch_outlined, color: Colors.white),
                label: const Text("Launch Event",
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006D3E),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),

            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, color: Colors.green, size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Pro-tip for Success",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(
                          "Events with clear descriptions and high-quality banners attract 40% more volunteers.",
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 16),
      child: Text(label,
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14)),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint,
      {IconData? icon, int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: icon != null ? Icon(icon, color: Colors.grey.shade400, size: 20) : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildVolunteerSelector() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("users")
          .where("role", isEqualTo: "Volunteer")
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final volunteers = snapshot.data!.docs;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: volunteers.map((vDoc) {
            final name = vDoc['name'] ?? "Volunteer";
            final isSelected = selectedVolunteers.contains(vDoc.id);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    selectedVolunteers.remove(vDoc.id);
                  } else {
                    selectedVolunteers.add(vDoc.id);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.green.shade700 : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isSelected ? Colors.transparent : Colors.grey.shade300),
                ),
                child: Text(
                  name,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _launchEvent() async {
    if (_nameController.text.isEmpty) return;
    setState(() => _isLaunching = true);
    try {
      final currentNgoId = FirebaseAuth.instance.currentUser?.uid ?? '';

      // PHASE 3 FIX: Upload image to Cloudinary before saving to Firestore.
      String imageUrl = 'https://images.unsplash.com/photo-1593113598332-cd288d649433?auto=format&fit=crop&q=80&w=800';
      if (_selectedImageBytes != null) {
        final uploaded = await _uploadToCloudinary();
        if (uploaded != null) imageUrl = uploaded;
      }

      // PHASE 2 FIX: Standardized schema — write BOTH 'address' and 'location'
      // so both NGOEventsPage and VolunteerAvailableTasksPage can read it.
      // Also write 'ngoId' (not just 'createdBy') for proper scoping.
      await FirebaseFirestore.instance.collection("drives").add({
        "ngoId": currentNgoId,          // STANDARDIZED: used for filtering
        "createdBy": currentNgoId,      // kept for backward compat
        "name": _nameController.text,
        "address": _locationController.text,  // for NGOEventsPage
        "location": _locationController.text, // for VolunteerAvailableTasksPage
        "date": _dateController.text,
        "time": _timeController.text,
        "goal": int.tryParse(_goalController.text) ?? 500,
        "description": _descController.text,
        "assignedVolunteers": selectedVolunteers,
        "progress": 0.0,
        "status": "active",
        "imageUrl": imageUrl,
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Error launching event: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to create event: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLaunching = false);
    }
  }
}

