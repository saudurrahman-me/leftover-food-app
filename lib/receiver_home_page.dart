
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'my_pickup_page.dart';
import 'receiver_profile_page.dart';
import 'receiver_map_page.dart';
import 'notification_service.dart';
import 'notifications_page.dart';
import 'widgets/ai_urgency_badge.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';

class ReceiverHomePage extends StatefulWidget {
  final String userId;
  const ReceiverHomePage({super.key, required this.userId});

  @override
  State<ReceiverHomePage> createState() => _HomePageState();
}

class _HomePageState extends State<ReceiverHomePage> {
  // 'All' means no filter; others match posts' 'category' field
  String selectedCategory = "All";
  final List<Map<String, dynamic>> categories = [
    {"name": "All", "icon": Icons.grid_view},
    {"name": "Vegetables", "icon": Icons.eco},
    {"name": "Meals", "icon": Icons.restaurant},
    {"name": "Bakery", "icon": Icons.bakery_dining},
    {"name": "Dairy", "icon": Icons.local_drink},
  ];
  String userName = "User";
  bool isLoading = true;
  int selectedIndex = 0;
  String searchQuery = "";
  
  late Stream<QuerySnapshot> _drivesStream;
  late Stream<QuerySnapshot> _notificationsStream;
  StreamSubscription<QuerySnapshot>? _postsSubscription;
  List<FoodItem> _cachedItems = [];
  bool _isPostsLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserName();
    
    _postsSubscription = FirebaseFirestore.instance
        .collection('posts')
        .where('status', whereIn: ['active', 'claimed'])
        .limit(200)
        .snapshots()
        .listen((snapshot) {
      _processPosts(snapshot);
    });
        
    _drivesStream = FirebaseFirestore.instance
        .collection("drives")
        .where("status", isEqualTo: "active")
        .limit(10)
        .snapshots();
        
    _notificationsStream = FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientId', isEqualTo: widget.userId)
        .where('isRead', isEqualTo: false)
        .limit(20)
        .snapshots();
  }

  // PHASE 6 FIX: Removed _startLocationTracking() and _handleLocationPermission().
  // Continuous geolocator writes to Firestore on every 10m movement caused
  // excessive Firestore write costs and battery drain without any real benefit.
  // Location is read by MapPage on demand instead.

  @override
  void dispose() {
    _postsSubscription?.cancel();
    super.dispose();
  }
  
  void _processPosts(QuerySnapshot snapshot) {
    final allItems = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      
      DateTime? parsedExpiry;
      bool isExpired = false;
      final now = DateTime.now();

      if (data['expiryTimestamp'] != null) {
        parsedExpiry = (data['expiryTimestamp'] as Timestamp).toDate();
        isExpired = parsedExpiry.isBefore(now);
      } else {
        try {
          parsedExpiry = DateFormat("yyyy-MM-dd hh:mm a").parse(data['expiryDate'] ?? '');
          isExpired = now.isAfter(parsedExpiry);
        } catch (_) {}
      }

      if (isExpired && data['status'] == 'active') {
        FirebaseFirestore.instance.collection('posts').doc(doc.id).update({'status': 'expired'}).catchError((_) {});
      }
      
      return FoodItem(
        id: doc.id,
        donorId: data['userID'] ?? '',
        donorName: data['donorName'] ?? 'Donor',
        donorImage: data['donorAvatar'] ?? '',
        ngoId: data['ngoId'],
        title: data['title'] ?? '',
        subtitle: data['description'] ?? '',
        imageUrl: data['imageUrl'] ?? '',
        distance: 0,
        serves: (data['quantity'] as num?)?.toInt() ?? 1,
        timeRange: data['expiryDate'] ?? '',
        status: data['status'] ?? 'active',
        category: data['category'] as String?,
        createdAt: data['createdAt'] as Timestamp?,
        aiFreshnessStatus: data['aiFreshnessStatus'] as String?,
        aiUrgencyLevel: data['aiUrgencyLevel'] as String?,
        aiFreshnessScore: (data['aiFreshnessScore'] as num?)?.toInt(),
        estimatedRemainingHours: (data['estimatedRemainingHours'] as num?)?.toDouble(),
        postPriority: data['postPriority'] as String?,
        aiScanEnabled: data['aiScanEnabled'] as bool? ?? false,
        isExpired: isExpired,
        parsedExpiryDate: parsedExpiry,
      );
    }).toList();

    int urgencyRank(String? u) {
      if (u == 'critical') return 0;
      if (u == 'urgent') return 1;
      return 2;
    }
    allItems.sort((a, b) {
      final uCmp = urgencyRank(a.aiUrgencyLevel).compareTo(urgencyRank(b.aiUrgencyLevel));
      if (uCmp != 0) return uCmp;
      final sCmp = (a.aiFreshnessScore ?? 100).compareTo(b.aiFreshnessScore ?? 100);
      if (sCmp != 0) return sCmp;
      final hCmp = (a.estimatedRemainingHours ?? 99).compareTo(b.estimatedRemainingHours ?? 99);
      if (hCmp != 0) return hCmp;
      if (a.createdAt == null || b.createdAt == null) return 0;
      return b.createdAt!.compareTo(a.createdAt!);
    });

    if (mounted) {
      setState(() {
        _cachedItems = allItems;
        _isPostsLoading = false;
      });
    }
  }

  // ================= FETCH USER =================
  Future<void> _fetchUserName() async {
    try {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(widget.userId);
      final docSnap = await userDoc.get();

      if (!mounted) return;

      if (docSnap.exists) {
        setState(() {
          userName = docSnap.data()?['name'] ?? "User";
          isLoading = false;
        });
      } else {
        // Recreate user document if it was deleted
        await userDoc.set({
          "name": "User",
          "email": "",
          "role": "Receiver",
          "createdAt": FieldValue.serverTimestamp(),
        });
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('ReceiverHomePage _fetchUserName error: $e');
      // Do NOT re-throw. Simply hide the loader so the page stays open.
      if (mounted) setState(() => isLoading = false);
    }
  }



  // ================= SEND REQUEST =================
  Future<void> _sendRequest(FoodItem item) async {
    try {
      await FirebaseFirestore.instance.collection("requests").add({
        "donorId": item.donorId,
        "ngoId": item.ngoId ?? '',  // populated if post is NGO-claimed
        "receiverId": widget.userId,
        "receiverName": userName,
        "donorName": item.donorName,
        "itemId": item.id,
        "itemTitle": item.title,
        "requestedItem": item.title,
        "itemImage": item.imageUrl,
        "status": "pending",
        "timestamp": FieldValue.serverTimestamp(),
      });

      // PHASE 1 FIX: Notify NGO if post is claimed, otherwise notify Donor.
      if (item.ngoId != null && item.ngoId!.isNotEmpty) {
        await NotificationService.sendNotification(
          recipientId: item.ngoId!,
          title: "New Receiver Request!",
          message: "$userName wants '${item.title}' from your managed donation.",
          type: "request",
          relatedId: item.id,
          relatedType: 'post',
        );
      } else {
        await NotificationService.sendNotification(
          recipientId: item.donorId,
          title: "New Food Request!",
          message: "$userName has requested your '${item.title}'.",
          type: "request",
          relatedId: item.id,
          relatedType: 'post',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Food request sent successfully! 🚀'),
            backgroundColor: Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error sending request: $e");
      if (mounted) {
        // PHASE 4 FIX: Error catch must show error message, not success message.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send request: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // ================= NAVIGATION =================
  void _onTabTapped(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  Widget _getPage() {
    switch (selectedIndex) {
      case 0:
        return _homePage();
      case 1:
        return MyPickupsPage(userId: widget.userId);
      case 2:
        return ReceiverMapPage(userId: widget.userId);
      case 3:
        return ReceiverProfilePage(userId: widget.userId);
      default:
        return _homePage();
    }
  }

  Widget _homePage() {
    if (_isPostsLoading) {
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator(color: Colors.green)),
          ),
        ],
      );
    }

    // Apply dynamic expiry guard + search + category filter
    final now = DateTime.now();
    final displayedItems = _cachedItems.where((item) {
      if (item.parsedExpiryDate != null && item.parsedExpiryDate!.isBefore(now)) {
        return false;
      }
      
      final matchesSearch = item.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
          item.subtitle.toLowerCase().contains(searchQuery.toLowerCase());
      final matchesCategory = selectedCategory == 'All' ||
          (item.category?.toLowerCase() == selectedCategory.toLowerCase());
      return matchesSearch && matchesCategory;
    }).toList();

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildCategoryList()),
            SliverToBoxAdapter(child: _buildUpcomingEvents()),
            if (displayedItems.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    "No food available matching your search.\nCheck back later!",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return FoodCardModern(
                        item: displayedItems[index],
                        onRequest: () => _sendRequest(displayedItems[index]),
                      );
                    },
                    childCount: displayedItems.length,
                  ),
                ),
              ),
          ],
        );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Hello, $userName 👋",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      "Find Food \nNear You",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  _buildNotificationBell(),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                        )
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.green.shade100,
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 25),
          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.4)),
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Search for food, bakery...",
                hintStyle: TextStyle(color: Colors.white70),
                border: InputBorder.none,
                icon: Icon(Icons.search, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              "Categories",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 55,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                final isSelected = selectedCategory == cat["name"];
                return GestureDetector(
                  onTap: () => setState(() => selectedCategory = cat["name"]),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.green : Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        else
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                      ],
                      border: Border.all(
                        color: isSelected ? Colors.green : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          cat["icon"],
                          color: isSelected ? Colors.white : Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          cat["name"],
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingEvents() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              "Upcoming Food Drives",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: StreamBuilder<QuerySnapshot>(
              stream: _drivesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(child: CircularProgressIndicator(color: Colors.green)),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Center(
                      child: Text(
                        "No upcoming events at the moment.",
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ),
                  );
                }
                final drives = snapshot.data!.docs;
                return Column(
                  children: drives.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name'] ?? "Food Drive";
                    final location = data['location'] ?? "NGO Location";
                    final imageUrl = data['imageUrl'] ?? "https://images.unsplash.com/photo-1593113598332-cd288d649433?auto=format&fit=crop&q=80&w=800";
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          )
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 70,
                                height: 70,
                                child: Image.network(
                                  imageUrl, 
                                  width: 70, 
                                  height: 70, 
                                  fit: BoxFit.cover, 
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      width: 70, height: 70, color: Colors.grey[200],
                                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: 70, height: 70, color: Colors.grey[200],
                                    child: const Icon(Icons.event, size: 30, color: Colors.grey),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          location,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () {
                                 ScaffoldMessenger.of(context).showSnackBar(
                                   const SnackBar(
                                     content: Text("Drive details coming soon!"),
                                     backgroundColor: Colors.green,
                                   ),
                                 );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade600,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  "View",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _modernBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: selectedIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey[400],
        showUnselectedLabels: true,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        onTap: _onTabTapped,
        items: [
          BottomNavigationBarItem(
            icon: _bottomIcon(Icons.home_outlined, selectedIndex == 0),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: _bottomIcon(Icons.shopping_bag_outlined, selectedIndex == 1),
            label: "Pickups",
          ),
          BottomNavigationBarItem(
            icon: _bottomIcon(Icons.map_outlined, selectedIndex == 2),
            label: "Map",
          ),
          BottomNavigationBarItem(
            icon: _bottomIcon(Icons.person_outline, selectedIndex == 3),
            label: "Profile",
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationBell() {
    return StreamBuilder<QuerySnapshot>(
      stream: _notificationsStream,
      builder: (context, snapshot) {
        bool hasUnread = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

        return Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 28),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => NotificationsPage(userId: widget.userId)),
                );
              },
            ),
            if (hasUnread)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _bottomIcon(IconData icon, bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isSelected
            ? const LinearGradient(colors: [Colors.green, Color(0xff66BB6A)])
            : null,
        color: isSelected ? null : Colors.transparent,
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Colors.green.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Icon(icon, color: isSelected ? Colors.white : Colors.grey[500]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC), // Modern off-white background
      body: _getPage(),
      bottomNavigationBar: _modernBottomNav(),
    );
  }
}

// ================= MODEL =================
class FoodItem {
  final String id;
  final String donorId;
  final String donorName;
  final String donorImage;
  final String? ngoId;
  final String title;
  final String subtitle;
  final String imageUrl;
  final double distance;
  final int serves;
  final String timeRange;
  final String status;
  final String? category;  // PHASE 2: category filtering
  final Timestamp? createdAt;
  // ── AI fields ────────────────────────────────────────────────────────────
  final String? aiFreshnessStatus;     // 'fresh'|'moderate'|'expiringSoon'|'unsafe'
  final String? aiUrgencyLevel;        // 'normal'|'urgent'|'critical'
  final int? aiFreshnessScore;         // 0–100 (lower = more urgent for sorting)
  final double? estimatedRemainingHours;
  final String? postPriority;          // 'normal'|'urgent'
  final bool aiScanEnabled;
  final bool isExpired;
  final DateTime? parsedExpiryDate;

  FoodItem({
    required this.id,
    required this.donorId,
    required this.donorName,
    required this.donorImage,
    this.ngoId,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.distance,
    required this.serves,
    required this.timeRange,
    required this.status,
    this.category,
    this.createdAt,
    this.aiFreshnessStatus,
    this.aiUrgencyLevel,
    this.aiFreshnessScore,
    this.estimatedRemainingHours,
    this.postPriority,
    this.aiScanEnabled = false,
    this.isExpired = false,
    this.parsedExpiryDate,
  });
}

// ================= CARD =================
class FoodCardModern extends StatelessWidget {
  final FoodItem item;
  final VoidCallback onRequest;

  const FoodCardModern({required this.item, required this.onRequest, super.key});

  @override
  Widget build(BuildContext context) {
    // Dynamic fallback for build-time expiration check
    final expired = item.parsedExpiryDate != null 
        ? DateTime.now().isAfter(item.parsedExpiryDate!) 
        : item.isExpired;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // IMAGE & BADGES
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: Image.network(
                    item.imageUrl,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 180,
                        width: double.infinity,
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator(color: Colors.green)),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 180,
                      width: double.infinity,
                      color: Colors.grey[200],
                      child: const Icon(Icons.fastfood, size: 50, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              // Serves badge
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Serves ${item.serves}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              // NGO Managed badge
              if (item.status == 'claimed' || (item.ngoId != null && item.ngoId!.isNotEmpty))
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade700,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.business, color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'NGO Managed',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // AI Urgency badge (top-left, below NGO badge when both present)
              if (item.aiScanEnabled && item.aiUrgencyLevel != null && item.aiUrgencyLevel != 'normal')
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: AiUrgencyBadge(urgency: item.aiUrgencyLevel),
                ),
              // Expired Badge overlay
              if (expired)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: const Center(
                      child: Text(
                        "EXPIRED",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          
          // CONTENT
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      expired ? "Expired" : "Active",
                      style: TextStyle(
                        color: expired ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                
                // DONOR INFO & TIME + AI Badges
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.green.shade100,
                      child: const Icon(Icons.person, size: 16, color: Colors.green),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.donorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.timeRange,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                // AI badges row
                if (item.aiScanEnabled) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (item.aiFreshnessStatus != null)
                        AiFreshnessBadge(status: item.aiFreshnessStatus, compact: true),
                      if (item.estimatedRemainingHours != null && item.estimatedRemainingHours! > 0)
                        AiCountdownBadge(remainingHours: item.estimatedRemainingHours, compact: true),
                    ],
                  ),
                ],
                
                const SizedBox(height: 20),
                
                // BUTTON
                GestureDetector(
                  onTap: expired ? null : onRequest,
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: expired ? Colors.grey.shade400 : (item.status == 'claimed' ? Colors.blue.shade700 : Colors.green),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: expired ? [] : [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.5),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      expired
                          ? 'Not Available'
                          : item.status == 'claimed'
                              ? 'Request (NGO Managed)'
                              : 'Request Pickup',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

