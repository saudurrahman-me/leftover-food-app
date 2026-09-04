/// admin_service.dart
/// All Firestore streams and mutations used by the Admin Module.
/// Nothing here touches any existing service — it is purely additive.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminService {
  static final _db = FirebaseFirestore.instance;

  // ── Collections ───────────────────────────────────────────────────────────
  static CollectionReference get users => _db.collection('users');
  static CollectionReference get posts => _db.collection('posts');
  static CollectionReference get requests => _db.collection('requests');
  static CollectionReference get tasks => _db.collection('tasks');
  static CollectionReference get drives => _db.collection('drives');
  static CollectionReference get notifications => _db.collection('notifications');
  static CollectionReference get modQueue => _db.collection('moderationQueue');

  // ── Summary streams (live counters) ──────────────────────────────────────
  static Stream<int> streamCount(String collection, {String? field, dynamic equals}) {
    var q = _db.collection(collection) as Query;
    if (field != null) q = q.where(field, isEqualTo: equals);
    return q.snapshots().map((s) => s.size);
  }

  static Stream<int> streamCountWhere(String collection, String field, List<dynamic> inValues) {
    return _db
        .collection(collection)
        .where(field, whereIn: inValues)
        .snapshots()
        .map((s) => s.size);
  }

  // ── Users ─────────────────────────────────────────────────────────────────
  static Stream<QuerySnapshot> streamUsers({String? role}) {
    Query q = users.orderBy('name');
    if (role != null && role != 'All') q = users.where('role', isEqualTo: role);
    return q.snapshots();
  }

  static Future<void> updateUser(String uid, Map<String, dynamic> data) =>
      users.doc(uid).update(data);

  static Future<void> deleteUser(String uid) => users.doc(uid).delete();

  static Future<void> setUserStatus(String uid, bool enabled) =>
      users.doc(uid).update({'disabled': !enabled});

  static Future<void> changeUserRole(String uid, String newRole) =>
      users.doc(uid).update({'role': newRole});

  // ── Posts ─────────────────────────────────────────────────────────────────
  static Stream<QuerySnapshot> streamPosts({String? status}) {
    Query q = posts.orderBy('createdAt', descending: true);
    if (status != null && status != 'All') q = posts.where('status', isEqualTo: status).orderBy('createdAt', descending: true);
    return q.snapshots();
  }

  static Future<void> updatePostStatus(String postId, String status) =>
      posts.doc(postId).update({'status': status});

  static Future<void> deletePost(String postId) => posts.doc(postId).delete();

  // ── Requests ──────────────────────────────────────────────────────────────
  static Stream<QuerySnapshot> streamRequests({String? status}) {
    Query q = requests.orderBy('createdAt', descending: true);
    if (status != null && status != 'All') q = requests.where('status', isEqualTo: status).orderBy('createdAt', descending: true);
    return q.snapshots();
  }

  static Future<void> updateRequestStatus(String id, String status) =>
      requests.doc(id).update({'status': status});

  static Future<void> deleteRequest(String id) => requests.doc(id).delete();

  // ── Tasks ─────────────────────────────────────────────────────────────────
  static Stream<QuerySnapshot> streamTasks({String? status}) {
    Query q = tasks.orderBy('createdAt', descending: true);
    if (status != null && status != 'All') q = tasks.where('status', isEqualTo: status).orderBy('createdAt', descending: true);
    return q.snapshots();
  }

  static Future<void> updateTaskStatus(String id, String status) =>
      tasks.doc(id).update({'status': status});

  static Future<void> reassignVolunteer(String taskId, String volunteerId, String volunteerName) =>
      tasks.doc(taskId).update({'assignedTo': volunteerId, 'volunteerName': volunteerName, 'status': 'assigned'});

  static Future<void> deleteTask(String id) => tasks.doc(id).delete();

  // ── Drives ────────────────────────────────────────────────────────────────
  static Stream<QuerySnapshot> streamDrives({String? status}) {
    Query q = drives.orderBy('createdAt', descending: true);
    if (status != null && status != 'All') q = drives.where('status', isEqualTo: status).orderBy('createdAt', descending: true);
    return q.snapshots();
  }

  static Future<void> updateDrive(String id, Map<String, dynamic> data) =>
      drives.doc(id).update(data);

  static Future<void> deleteDrive(String id) => drives.doc(id).delete();

  // ── NGO helpers ───────────────────────────────────────────────────────────
  static Stream<QuerySnapshot> streamNGOs() =>
      users.where('role', isEqualTo: 'NGO').snapshots();

  static Stream<QuerySnapshot> streamVolunteers() =>
      users.where('role', isEqualTo: 'Volunteer').snapshots();

  static Stream<QuerySnapshot> streamReceivers() =>
      users.where('role', isEqualTo: 'Receiver').snapshots();

  // ── Notifications ─────────────────────────────────────────────────────────
  static Stream<QuerySnapshot> streamNotifications() =>
      notifications.orderBy('sentAt', descending: true).limit(50).snapshots();

  static Future<void> sendNotification({
    required String title,
    required String message,
    required String targetRole, // 'All' | role name | specific userId
    String? specificUserId,
  }) async {
    await notifications.add({
      'title': title,
      'message': message,
      'targetRole': targetRole,
      'recipientId': specificUserId ?? '',
      'sentAt': FieldValue.serverTimestamp(),
      'sentBy': FirebaseAuth.instance.currentUser?.uid ?? 'admin',
      'type': 'announcement',
      'isRead': false,
    });
  }

  static Future<void> deleteNotification(String id) =>
      notifications.doc(id).delete();

  // ── AI / Moderation ───────────────────────────────────────────────────────
  static Stream<QuerySnapshot> streamFlaggedPosts() =>
      modQueue.orderBy('createdAt', descending: true).snapshots();

  static Stream<QuerySnapshot> streamUnsafePosts() =>
      posts.where('aiModerationPassed', isEqualTo: false).snapshots();

  // ── Analytics helpers (one-shot futures) ─────────────────────────────────
  /// Returns count of posts per status.
  static Future<Map<String, int>> getPostStatusBreakdown() async {
    final snap = await posts.get();
    final Map<String, int> counts = {};
    for (final doc in snap.docs) {
      final status = (doc.data() as Map<String, dynamic>)['status'] as String? ?? 'unknown';
      counts[status] = (counts[status] ?? 0) + 1;
    }
    return counts;
  }

  /// Returns registrations per day for the last [days] days.
  static Future<Map<String, int>> getUserRegistrationsPerDay(int days) async {
    final since = Timestamp.fromDate(DateTime.now().subtract(Duration(days: days)));
    final snap = await users.where('createdAt', isGreaterThan: since).get();
    final Map<String, int> daily = {};
    for (final doc in snap.docs) {
      final ts = (doc.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
      if (ts != null) {
        final key = '${ts.toDate().day}/${ts.toDate().month}';
        daily[key] = (daily[key] ?? 0) + 1;
      }
    }
    return daily;
  }

  /// Returns donations (posts) per day for last [days] days.
  static Future<Map<String, int>> getDonationsPerDay(int days) async {
    final since = Timestamp.fromDate(DateTime.now().subtract(Duration(days: days)));
    final snap = await posts.where('createdAt', isGreaterThan: since).get();
    final Map<String, int> daily = {};
    for (final doc in snap.docs) {
      final ts = (doc.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
      if (ts != null) {
        final key = '${ts.toDate().day}/${ts.toDate().month}';
        daily[key] = (daily[key] ?? 0) + 1;
      }
    }
    return daily;
  }

  /// Returns food category distribution from posts.
  static Future<Map<String, int>> getFoodCategoryBreakdown() async {
    final snap = await posts.get();
    final Map<String, int> cats = {};
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final cat = data['aiFoodCategory'] as String?
          ?? data['category'] as String?
          ?? 'Other';
      cats[cat] = (cats[cat] ?? 0) + 1;
    }
    return cats;
  }

  // ── Maintenance / Settings ────────────────────────────────────────────────
  static DocumentReference get _settingsDoc =>
      _db.collection('adminSettings').doc('config');

  static Stream<DocumentSnapshot> streamSettings() => _settingsDoc.snapshots();

  static Future<void> updateSettings(Map<String, dynamic> data) =>
      _settingsDoc.set(data, SetOptions(merge: true));
}
