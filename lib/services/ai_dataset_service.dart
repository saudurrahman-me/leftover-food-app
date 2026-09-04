import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class AiDatasetService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const Uuid _uuid = Uuid();

  /// Saves dataset metadata using the existing Cloudinary URL.
  /// Runs asynchronously.
  static Future<void> uploadToDataset({
    required String imageUrl,
    required String postId,
    required String uploadedByUserId,
    required String donorName,
    required String foodName,
    required String category,
    required String quantity,
    required String location,
    required DateTime expiryDate,
    required String devicePlatform,
    double? latitude,
    double? longitude,
  }) async {
    final datasetId = _uuid.v4();
    final now = DateTime.now();

    // Generate strict storage path: food_ai_dataset/raw/YYYY/MM/DD/<timestamp>_<uuid>.jpg
    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final timestamp = now.millisecondsSinceEpoch;
    final shortUuid = datasetId.substring(0, 8);
    final fileName = '${timestamp}_$shortUuid.jpg';
    final storagePath = 'cloudinary_hosted';

    try {
      // 1. Create Firestore dataset document
      final docData = {
        'datasetId': datasetId,
        'postId': postId,
        'uploadedByUserId': uploadedByUserId,
        'donorName': donorName,
        'foodName': foodName,
        'category': category,
        'quantity': quantity,
        'location': location,
        'expiryDate': expiryDate,
        'uploadTime': now,
        'storagePath': storagePath,
        'downloadUrl': imageUrl,
        'fileName': fileName,
        'fileSize': 0, // Not stored in Firebase Storage
        'imageWidth': 0,
        'imageHeight': 0,
        'imageFormat': 'jpg',
        'devicePlatform': devicePlatform,
        'latitude': latitude,
        'longitude': longitude,
        'status': 'active',
        'isVerified': false,
        
        // AI Training Fields (Future compatibility)
        'foodType': null,
        'freshnessLabel': null,
        'qualityScore': null,
        'ripeness': null,
        'condition': null,
        'lightingCondition': null,
        'isBlurry': null,
        'packagingType': null,
        'detectedObjects': null,
        'boundingBoxes': null,
        'classificationModel': null,
        'predictionConfidence': null,
        'verifiedByHuman': null,
        'verifiedAt': null,
        'datasetVersion': null,
        'notes': null,
      };

      await _db.collection('ai_dataset').doc(datasetId).set(docData);

      // 3. Log success
      await _logAction(
        datasetId: datasetId,
        userId: uploadedByUserId,
        action: 'upload',
        result: 'success',
        errorMessage: null,
      );

    } catch (e) {
      // Log failure
      await _logAction(
        datasetId: datasetId,
        userId: uploadedByUserId,
        action: 'upload',
        result: 'failure',
        errorMessage: e.toString(),
      );
    }
  }

  static Future<void> _logAction({
    required String datasetId,
    required String userId,
    required String action,
    required String result,
    String? errorMessage,
  }) async {
    try {
      await _db.collection('dataset_logs').add({
        'datasetId': datasetId,
        'userId': userId,
        'timestamp': FieldValue.serverTimestamp(),
        'action': action,
        'result': result,
        if (errorMessage != null) 'errorMessage': errorMessage,
      });
    } catch (_) {
      // Ignore logging errors to prevent crashing the main flow
    }
  }
}
