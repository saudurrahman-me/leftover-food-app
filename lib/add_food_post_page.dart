import 'dart:typed_data';
import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'notification_service.dart';
import 'models/food_analysis_model.dart';
import 'services/ai_food_service.dart';
import 'services/ai_moderation_service.dart';
import 'services/ai_priority_engine.dart';
import 'services/ai_dataset_service.dart';
import 'widgets/food_analysis_card.dart';
import 'core/app_config.dart';

class AddFoodPostPage extends StatefulWidget {
  final String userId;

  const AddFoodPostPage({super.key, required this.userId});

  @override
  State<AddFoodPostPage> createState() => _AddFoodPostPageState();
}

class _AddFoodPostPageState extends State<AddFoodPostPage> {
  final ImagePicker _picker = ImagePicker();

  final TextEditingController titleCtrl = TextEditingController();
  final TextEditingController descCtrl = TextEditingController();
  final TextEditingController qtyCtrl = TextEditingController();
  final TextEditingController locationCtrl = TextEditingController();
  final TextEditingController pickupCtrl = TextEditingController();
  final TextEditingController expiryCtrl = TextEditingController();
  final TextEditingController startTimeCtrl = TextEditingController();
  final TextEditingController endTimeCtrl = TextEditingController();

  File? selectedImage;
  Uint8List? webImage;
  bool isUploading = false;

  // ─── AI scan state ──────────────────────────────────────────────────────
  bool _isAiScanning = false;
  FoodAnalysisResult? _aiResult;
  // Structured expiry timestamp computed from time picker
  DateTime? _expiryDateTime;

  String get cloudName => AppConfig.cloudinaryCloudName;
  String get uploadPreset => AppConfig.cloudinaryUploadPreset;

  // PHASE 2 FIX: Category field so ReceiverHomePage filter chips work
  String selectedCategory = "Meals";
  final List<String> categories = [
    "Meals",
    "Vegetables",
    "Bakery",
    "Dairy",
    "Other",
  ];

  @override
  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
    qtyCtrl.dispose();
    locationCtrl.dispose();
    pickupCtrl.dispose();
    expiryCtrl.dispose();
    startTimeCtrl.dispose();
    endTimeCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Image pick + AI trigger
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1080,
      maxHeight: 1080,
    );
    if (file == null) return;

    Uint8List? bytes;
    File? fileRef;

    if (kIsWeb) {
      bytes = await file.readAsBytes();
      webImage = bytes;
    } else {
      fileRef = File(file.path);
      selectedImage = fileRef;
    }

    // Reset previous AI result
    setState(() {
      _aiResult = null;
      _isAiScanning = true;
    });

    // Trigger AI scan — always pass bytes (v3 API is bytes-only)
    Uint8List? scanBytes = bytes;
    if (scanBytes == null && fileRef != null) {
      scanBytes = await fileRef.readAsBytes();
    }
    if (scanBytes != null) _runAiScan(imageBytes: scanBytes);
  }

  Future<void> _runAiScan({required Uint8List imageBytes}) async {
    bool isAiEnabled = true;
    try {
      final settingsSnap = await FirebaseFirestore.instance
          .collection('adminSettings')
          .doc('config')
          .get();
      isAiEnabled = settingsSnap.data()?['aiEnabled'] ?? true;
    } catch (_) {}

    if (!isAiEnabled) {
      if (!mounted) return;
      setState(() => _isAiScanning = false);
      return;
    }

    if (!AppConfig.hasGeminiKey) {
      if (!mounted) return;
      setState(() => _isAiScanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'AI scan unavailable: set GEMINI_API_KEY when building the app.',
          ),
        ),
      );
      return;
    }
    try {
      final result = await AiFoodService.analyze(imageBytes: imageBytes);

      if (!mounted) return;

      setState(() {
        _aiResult = result;
        _isAiScanning = false;
      });

      // Auto-sync category from AI detection
      _syncCategoryFromAi(result.foodCategory);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAiScanning = false;
        // Leave _aiResult = null → scan failed gracefully
      });
      _snack('AI scan failed: please check your image and try again.');
    }
  }

  /// Optionally align the dropdown category with AI's food category detection
  void _syncCategoryFromAi(FoodCategory aiCategory) {
    const map = {
      FoodCategory.vegetables: 'Vegetables',
      FoodCategory.fruits: 'Vegetables', // closest match
      FoodCategory.bakery: 'Bakery',
      FoodCategory.dairy: 'Dairy',
      FoodCategory.cookedMeals: 'Meals',
      FoodCategory.meat: 'Meals',
      FoodCategory.beverages: 'Other',
      FoodCategory.other: 'Other',
    };
    final mapped = map[aiCategory];
    if (mapped != null && categories.contains(mapped)) {
      setState(() => selectedCategory = mapped);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Time pickers
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _pickTime({required bool isStart}) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null && mounted) {
      final formatted = picked.format(context);
      setState(() {
        if (isStart) {
          startTimeCtrl.text = formatted;
        } else {
          endTimeCtrl.text = formatted;
        }
      });
    }
  }

  Future<void> _pickExpiryRangeToday() async {
    await _pickTime(isStart: true);
    await _pickTime(isStart: false);
    if (startTimeCtrl.text.isNotEmpty && endTimeCtrl.text.isNotEmpty) {
      expiryCtrl.text =
          "Today from ${startTimeCtrl.text} to ${endTimeCtrl.text}";
      // Build an absolute DateTime for the expiry (end time = when post should be deleted)
      try {
        final endParsed = TimeOfDay.fromDateTime(
          DateTime.parse('2000-01-01 ${_parseTime12(endTimeCtrl.text)}'),
        );
        final now = DateTime.now();
        setState(() {
          _expiryDateTime = DateTime(
            now.year,
            now.month,
            now.day,
            endParsed.hour,
            endParsed.minute,
          );
        });
      } catch (_) {
        // If parsing fails, we'll just skip the structured timestamp
        _expiryDateTime = null;
      }
    }
  }

  /// Converts "9:30 AM" / "11:00 PM" to "09:30:00" for DateTime.parse
  static String _parseTime12(String t) {
    try {
      final parts = t.trim().split(' ');
      final hm = parts[0].split(':');
      int h = int.parse(hm[0]);
      final m = int.parse(hm[1]);
      final isPm = parts.length > 1 && parts[1].toUpperCase() == 'PM';
      if (isPm && h != 12) h += 12;
      if (!isPm && h == 12) h = 0;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:00';
    } catch (_) {
      return '00:00:00';
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Validation
  // ─────────────────────────────────────────────────────────────────────────

  String? _validate() {
    if (titleCtrl.text.trim().isEmpty) return "Please enter food title.";
    if (descCtrl.text.trim().isEmpty) return "Please enter description.";
    if (qtyCtrl.text.trim().isEmpty) return "Please enter quantity.";
    if (locationCtrl.text.trim().isEmpty)
      return "Please enter pickup location.";
    final q = int.tryParse(qtyCtrl.text.trim());
    if (q == null || q <= 0) return "Quantity must be a valid number (> 0).";
    if (expiryCtrl.text.trim().isEmpty) return "Please select expiry time.";
    if (selectedImage == null && webImage == null)
      return "Please select an image.";
    if (_isAiScanning) return "Please wait for AI scan to complete.";
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Blocking / warning logic before submit
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns false if submission should be blocked.
  /// In production (hardBlockUnsafe=true), unsafe food CANNOT be submitted.
  Future<bool> _checkAiBeforeSubmit() async {
    if (_aiResult == null) return true; // No scan → allow (graceful fallback)

    // ── HARD BLOCK: unsafe food or moderation failure ──────────────────────
    if (_aiResult!.isUnsafe) {
      // Production mode: permanent block, no bypass
      await _showHardBlockDialog();
      return false;
    }

    // ── NON-BLOCKING WARNING: expiring soon / low confidence ───────────────
    if (_aiResult!.requiresWarning && !_aiResult!.isUnsafe) {
      await _showWarningDialog();
    }

    return true;
  }

  Future<void> _showHardBlockDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(
          Icons.block_rounded,
          color: Color(0xFFE74C3C),
          size: 52,
        ),
        title: const Text(
          'Upload Blocked',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF991B1B),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _aiResult!.safetyRecommendation,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Our AI system has flagged this food as unsafe for donation. '
                'Donating spoiled or unsafe food endangers recipients. '
                'This upload has been blocked to protect the community.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF991B1B),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE74C3C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Understood',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showWarningDialog() async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Color(0xFFF39C12),
          size: 40,
        ),
        title: const Text(
          'Food Quality Notice',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          '${_aiResult!.safetyRecommendation}\n\nPlease ensure the food meets safety standards before donating.',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Understood',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Cloudinary upload
  // ─────────────────────────────────────────────────────────────────────────

  Future<String?> _uploadImageToCloudinary() async {
    if (selectedImage == null && webImage == null) return null;

    try {
      late Uint8List imageBytes;

      if (kIsWeb && webImage != null) {
        imageBytes = webImage!;
      } else if (selectedImage != null) {
        imageBytes = await selectedImage!.readAsBytes();
      }

      final uri = Uri.parse(
        "https://api.cloudinary.com/v1_1/$cloudName/image/upload",
      );
      var request = http.MultipartRequest('POST', uri);
      request.fields['upload_preset'] = uploadPreset;
      request.files.add(
        http.MultipartFile.fromBytes('file', imageBytes, filename: 'image.jpg'),
      );

      var responseStream = await request.send();
      var response = await http.Response.fromStream(responseStream);

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        final errorMessage = errorData['error']?['message'] ?? 'Unknown error';
        throw Exception("Cloudinary: $errorMessage");
      }

      final data = json.decode(response.body);
      return data['secure_url'];
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Image upload failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Phase 2: Background moderation check
  // ─────────────────────────────────────────────────────────────────────────

  /// Runs moderation in the background — does not block the UX.
  /// Writes results (fraudRiskScore, moderationFlags) back to the post.
  void _runModerationCheck(
    String postId, {
    required Uint8List? imageBytes,
  }) async {
    if (imageBytes == null) return;
    bool isAutoMod = true;
    try {
      final settingsSnap = await FirebaseFirestore.instance
          .collection('adminSettings')
          .doc('config')
          .get();
      isAutoMod = settingsSnap.data()?['autoModeration'] ?? true;
    } catch (_) {}
    if (!isAutoMod) return;

    AiModerationService.checkPost(
          imageBytes: imageBytes,
          donorId: widget.userId,
          title: titleCtrl.text.trim(),
        )
        .then((result) {
          AiModerationService.persistModerationResult(
            postId: postId,
            result: result,
          );
        })
        .catchError((_) {});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Submit
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final String? err = _validate();
    if (err != null) {
      _snack(err);
      return;
    }

    // ── Enforce Donation Limit ──
    double limit = 50.0;
    try {
      final settingsSnap = await FirebaseFirestore.instance
          .collection('adminSettings')
          .doc('config')
          .get();
      limit = ((settingsSnap.data()?['donationLimit'] ?? 50) as num).toDouble();
    } catch (_) {}

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    try {
      final userPostsSnap = await FirebaseFirestore.instance
          .collection('posts')
          .where('userID', isEqualTo: widget.userId)
          .get();

      final todayPostCount = userPostsSnap.docs.where((doc) {
        final data = doc.data();
        if (data['createdAt'] == null) return false;
        final timestamp = data['createdAt'] as Timestamp;
        return timestamp.toDate().isAfter(startOfDay);
      }).length;

      if (todayPostCount >= limit) {
        _snack(
          "You have reached the daily donation limit of ${limit.round()} posts. Please try again tomorrow.",
        );
        return;
      }
    } catch (e) {
      debugPrint("Could not check donation limit: $e");
      // If we fail to check, we let them proceed or we could block.
      // Letting them proceed prevents soft-locking the app.
    }

    // AI blocking / warning gate
    final bool proceed = await _checkAiBeforeSubmit();
    if (!proceed) return;

    setState(() => isUploading = true);

    try {
      final String? imageUrl = await _uploadImageToCloudinary();
      if (imageUrl == null) {
        setState(() => isUploading = false);
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(widget.userId)
          .get();
      final String dName = userDoc.data()?['name'] ?? "Donor";
      final String dAvatar = userDoc.data()?['avatarUrl'] ?? "";

      // Build base post data
      final Map<String, dynamic> postData = {
        "userID": widget.userId,
        "donorName": dName,
        "donorAvatar": dAvatar,
        "title": titleCtrl.text.trim(),
        "description": descCtrl.text.trim(),
        "quantity": int.parse(qtyCtrl.text.trim()),
        "location": locationCtrl.text.trim(),
        "pickupInstructions": pickupCtrl.text.trim(),
        "expiryDate": expiryCtrl.text.trim(),
        // Store structured Timestamp for server-side / client-side expiry cleanup
        if (_expiryDateTime != null)
          "expiryTimestamp": Timestamp.fromDate(_expiryDateTime!),
        "imageUrl": imageUrl,
        "status": "active",
        // PHASE 2 FIX: Write category so receivers can filter by it
        "category": selectedCategory,
        "createdAt": FieldValue.serverTimestamp(),
      };

      // Merge AI analysis fields if scan was performed
      if (_aiResult != null) {
        postData.addAll(_aiResult!.toFirestore());

        // ── Phase 2: Food quality score ──────────────────────────────────
        postData['foodQualityScore'] = AiPriorityEngine.computeFoodQualityScore(
          postData,
        );

        // ── Phase 2: Delivery time prediction ───────────────────────────
        final deliveryPrediction = AiPriorityEngine.predictDelivery(
          remainingHours: _aiResult!.estimatedRemainingHours,
          urgencyLevel: _aiResult!.urgencyLevel.name,
        );
        postData.addAll(deliveryPrediction);
      }

      final postRef = await FirebaseFirestore.instance
          .collection("posts")
          .add(postData);

      // ── Phase 2: Moderation check (async, post-upload) ─────────────────
      final bytesForPost = webImage ?? await selectedImage?.readAsBytes();
      _runModerationCheck(postRef.id, imageBytes: bytesForPost);

      // ── Phase 3: AI Dataset Archival ─────────────────
      AiDatasetService.uploadToDataset(
        imageUrl: imageUrl,
        postId: postRef.id,
        uploadedByUserId: widget.userId,
        donorName: dName,
        foodName: titleCtrl.text.trim(),
        category: selectedCategory,
        quantity: qtyCtrl.text.trim(),
        location: locationCtrl.text.trim(),
        expiryDate:
            _expiryDateTime ?? DateTime.now().add(const Duration(days: 1)),
        devicePlatform: kIsWeb ? 'web' : Platform.operatingSystem,
      );

      final int quantity = int.parse(qtyCtrl.text.trim());
      final bool isAiUrgent =
          _aiResult != null &&
          (_aiResult!.urgencyLevel.name == 'urgent' ||
              _aiResult!.urgencyLevel.name == 'critical');

      // Notify Receivers always
      List<String> rolesToNotify = ["Receiver"];

      // NGO auto-escalation:
      //  • large donation (qty ≥ 50)  OR
      //  • AI marks it as urgent/critical regardless of quantity
      if (quantity >= 50 || isAiUrgent) {
        rolesToNotify.add("NGO");
      }

      final String notifTitle = isAiUrgent
          ? '⚡ Urgent Food Donation!'
          : 'New Food Available!';
      final String notifMessage = isAiUrgent
          ? "URGENT: '${titleCtrl.text.trim()}' needs pickup soon — AI flagged it as expiring."
          : "A new donation '${titleCtrl.text.trim()}' is available near you.";

      final usersSnap = await FirebaseFirestore.instance
          .collection("users")
          .where("role", whereIn: rolesToNotify)
          .get();
      for (var doc in usersSnap.docs) {
        if (doc.id != widget.userId) {
          await NotificationService.sendNotification(
            recipientId: doc.id,
            title: notifTitle,
            message: notifMessage,
            type: isAiUrgent ? "urgent_post" : "post",
            relatedId: postRef.id,
          );
        }
      }

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          icon: const Icon(
            Icons.check_circle_rounded,
            color: Colors.green,
            size: 48,
          ),
          title: const Text(
            "Posted!",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text("Your food post has been created successfully."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      _snack("Upload failed: $e");
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 10),
      ),
    );
  }

  Widget _field({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    bool readOnly = false,
    VoidCallback? onTap,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xffF4F6FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xff7D8FAB)),
          prefixIcon: Icon(icon, color: Colors.green),
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (!kIsWeb && selectedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          selectedImage!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: 170,
        ),
      );
    } else if (kIsWeb && webImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          webImage!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: 170,
        ),
      );
    } else {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.photo_camera, color: Colors.green, size: 34),
          SizedBox(height: 8),
          Text("Upload Photo", style: TextStyle(fontWeight: FontWeight.bold)),
          Text(
            "Tap to choose from gallery",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // AI section widget
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildAiSection() {
    // Nothing selected yet → hide
    if (selectedImage == null && webImage == null)
      return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Row(
          children: const [
            Icon(Icons.auto_awesome, color: Colors.green, size: 18),
            SizedBox(width: 6),
            Text(
              "AI Freshness Analysis",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_isAiScanning) const FoodAnalysisLoadingCard(),
        if (!_isAiScanning && _aiResult != null)
          FoodAnalysisCard(result: _aiResult!),
        if (!_isAiScanning && _aiResult == null) ...[
          // Scan failed or not yet run
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFD54F)),
            ),
            child: Row(
              children: const [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFF57F17),
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'AI scan unavailable. Please verify food freshness manually before posting.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF5D4037),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool isUnsafe = _aiResult != null && _aiResult!.isUnsafe;
    final bool submitEnabled = !isUploading && !_isAiScanning && !isUnsafe;

    return Scaffold(
      backgroundColor: const Color(0xffF5F7F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Add New Food Post",
          style: TextStyle(color: Colors.black),
        ),
        leading: const BackButton(color: Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Photo picker ──────────────────────────────────────────
              const Text(
                "Add Photos",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 170,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: _buildImagePreview(),
                ),
              ),

              // ── AI Analysis Card (auto-appears after image pick) ──────
              _buildAiSection(),

              const SizedBox(height: 18),

              // ── Food Item Name ────────────────────────────────────────
              const Text(
                "Food Item Name",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              _field(
                label: "e.g., Vegetable soup",
                icon: Icons.fastfood,
                controller: titleCtrl,
              ),
              const SizedBox(height: 18),

              // ── Description ───────────────────────────────────────────
              const Text(
                "Description",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              _field(
                label: "Ingredients / allergens (if any)",
                icon: Icons.notes,
                controller: descCtrl,
                maxLines: 4,
              ),
              const SizedBox(height: 18),

              // ── Quantity + Expiry ─────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Quantity",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        _field(
                          label: "e.g., 5",
                          icon: Icons.format_list_numbered,
                          controller: qtyCtrl,
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Expiry Time (Today)",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        _field(
                          label: "Select time range",
                          icon: Icons.access_time,
                          controller: expiryCtrl,
                          readOnly: true,
                          onTap: _pickExpiryRangeToday,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ── Category ──────────────────────────────────────────────
              const Text(
                "Category",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              // PHASE 2 FIX: Category dropdown to enable receiver filtering
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xffF4F6FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedCategory,
                    isExpanded: true,
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.green,
                    ),
                    items: categories.map((cat) {
                      return DropdownMenuItem(value: cat, child: Text(cat));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedCategory = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // ── Location ──────────────────────────────────────────────
              const Text(
                "Pickup Location",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              _field(
                label: "Enter address / area",
                icon: Icons.location_on,
                controller: locationCtrl,
              ),
              const SizedBox(height: 18),

              // ── Pickup Instructions ───────────────────────────────────
              const Text(
                "Pickup Instructions (Optional)",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              _field(
                label: "e.g., ring bell; leave at gate",
                icon: Icons.tips_and_updates,
                controller: pickupCtrl,
                maxLines: 3,
              ),
              const SizedBox(height: 26),

              // ── Unsafe Block Warning ────────────────────────────────
              if (isUnsafe) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.block,
                        color: Color(0xFFEF4444),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "This food is not safe for donation.\n${_aiResult!.safetyRecommendation}",
                          style: const TextStyle(
                            color: Color(0xFFB91C1C),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Submit button ─────────────────────────────────────────
              Tooltip(
                message: isUnsafe
                    ? "Blocked: Food is not safe for donation"
                    : "",
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: submitEnabled
                          ? Colors.green
                          : Colors.grey.shade400,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: submitEnabled ? _submit : null,
                    child: isUploading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : _isAiScanning
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                "AI Scanning…",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            "Post Food",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
