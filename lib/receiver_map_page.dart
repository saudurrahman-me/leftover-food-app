import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class ReceiverMapPage extends StatefulWidget {
  final String userId;
  const ReceiverMapPage({super.key, required this.userId});

  @override
  State<ReceiverMapPage> createState() => _ReceiverMapPageState();
}

class _ReceiverMapPageState extends State<ReceiverMapPage> {
  Position? _currentPosition;
  bool _isLoading = true;
  final MapController _mapController = MapController();
  List<LatLng> _routePoints = [];
  LatLng? _volunteerPos;
  String? _volunteerName;
  String _deliveryStatus = "assigned"; // "assigned" or "picked_up"
  double _distanceRemaining = 0.0;
  double _volunteerHeading = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _listenToActiveDelivery();
  }

  Future<void> _initializeLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(timeLimit: Duration(seconds: 5)),
      );
      if (mounted) setState(() { _currentPosition = position; _isLoading = false; });
    } catch (e) { 
      debugPrint("Location Error: $e");
      if (mounted) setState(() => _isLoading = false); 
    }
  }

  void _listenToActiveDelivery() {
    // 1. Listen for NGO/Volunteer Delivery Tasks
    FirebaseFirestore.instance
        .collection("tasks")
        .where("receiverId", isEqualTo: widget.userId)
        .where("status", isEqualTo: "pending")
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final taskData = snapshot.docs.first.data();
        final volunteerId = taskData['assignedTo'] as String?;
        final currentStatus = taskData['deliveryStatus'] ?? "assigned";
        
        if (mounted) setState(() => _deliveryStatus = currentStatus);

        if (volunteerId != null && volunteerId.isNotEmpty) {
          _listenToPersonLocation(volunteerId, "Rider");
        }
      }
    });

    // 2. Listen for Direct Donor-Receiver Accepted Requests
    FirebaseFirestore.instance
        .collection("requests")
        .where("receiverId", isEqualTo: widget.userId)
        .where("status", isEqualTo: "accepted")
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final reqData = snapshot.docs.first.data();
        final donorId = reqData['donorId'] as String?;
        
        if (mounted) setState(() => _deliveryStatus = "donor_pickup");

        if (donorId != null && donorId.isNotEmpty) {
          _listenToPersonLocation(donorId, reqData['donorName'] ?? "Donor");
        }
      } else if (_deliveryStatus == "donor_pickup") {
        // If it was a donor pickup and now there are no accepted requests, clear it
        if (mounted) setState(() { _volunteerPos = null; _routePoints = []; });
      }
    });
  }

  void _listenToPersonLocation(String personId, String defaultName) {
    FirebaseFirestore.instance.collection("users").doc(personId).snapshots().listen((userSnap) {
      if (userSnap.exists && mounted) {
        final geo = userSnap.data()?['lastLocation'] as GeoPoint?;
        if (geo != null) {
          setState(() {
            _volunteerPos = LatLng(geo.latitude, geo.longitude);
            _volunteerName = userSnap.data()?['name'] ?? defaultName;
            _volunteerHeading = (userSnap.data()?['heading'] ?? 0.0).toDouble();
          });
          
          if (_currentPosition != null) {
            _fetchRoute(_volunteerPos!, LatLng(_currentPosition!.latitude, _currentPosition!.longitude));
            double dist = Geolocator.distanceBetween(_volunteerPos!.latitude, _volunteerPos!.longitude, _currentPosition!.latitude, _currentPosition!.longitude);
            setState(() => _distanceRemaining = dist / 1000);
          }
        }
      }
    });
  }

  Future<void> _fetchRoute(LatLng start, LatLng end) async {
    try {
      final url = 'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final List coords = data['routes'][0]['geometry']['coordinates'];
        if (mounted) setState(() => _routePoints = coords.map((c) => LatLng(c[1], c[0])).toList());
      }
    } catch (e) { debugPrint("Route error: $e"); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _isLoading ? const Center(child: CircularProgressIndicator()) : FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition != null ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude) : const LatLng(30.3753, 69.3451),
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                retinaMode: RetinaMode.isHighDensity(context),
              ),
              if (_routePoints.isNotEmpty) PolylineLayer(polylines: [
                Polyline(points: _routePoints, strokeWidth: 10.0, color: Colors.blue.withValues(alpha: 0.5)), // Thick Blue Glow
                Polyline(points: _routePoints, strokeWidth: 4.0, color: Colors.blueAccent), // Core Blue Line
              ]),
              MarkerLayer(markers: [
                if (_currentPosition != null) Marker(point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude), width: 60, height: 60, child: const Icon(Icons.home_work, color: Colors.green, size: 40)),
                if (_volunteerPos != null) Marker(
                  point: _volunteerPos!,
                  width: 70, height: 70,
                  child: GestureDetector(
                    onTap: () {
                      _mapController.move(_volunteerPos!, 16.0);
                    },
                    child: Transform.rotate(
                      angle: _volunteerHeading * (3.14159 / 180),
                      child: const Icon(Icons.navigation, color: Color(0xFFD70F64), size: 35),
                    ),
                  ),
                ),
              ]),
            ],
          ),

          // Receiver Status Banner
          if (_volunteerPos != null) Positioned(
            top: 50, left: 20, right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32), 
                borderRadius: BorderRadius.circular(16), 
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)]
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions_run, color: Colors.white, size: 30),
                  const SizedBox(width: 16),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Pickup Mode Active", 
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                      ),
                      Text("You are ${_distanceRemaining.toStringAsFixed(1)} km away from the Donor", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  )),
                ],
              ),
            ),
          ),

          // Bottom Info Card
          if (_volunteerPos != null) Positioned(
            bottom: 20, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)]),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 25, 
                        backgroundColor: Colors.green.shade50, 
                        child: const Icon(Icons.person, color: Colors.green)
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_volunteerName ?? "Donor", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        const Text("Destination: Food Pickup Location", style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ])),
                      IconButton(onPressed: () {}, icon: const Icon(Icons.phone, color: Colors.green)),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _mapController.move(_volunteerPos!, 17.0);
                          },
                          icon: const Icon(Icons.my_location),
                          label: const Text("Locate Donor"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[200],
                            foregroundColor: Colors.black87,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                             // Center on user
                             if (_currentPosition != null) {
                               _mapController.move(LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 16.0);
                             }
                          },
                          icon: const Icon(Icons.navigation),
                          label: const Text("My Location"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

