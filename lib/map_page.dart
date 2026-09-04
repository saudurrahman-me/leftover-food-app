import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class MapPage extends StatefulWidget {
  final String userId;
  const MapPage({super.key, required this.userId});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  Position? _currentPosition;
  bool _isLoading = true;
  bool _showRoute = false;
  final MapController _mapController = MapController();
  List<LatLng> _routePoints = [];
  LatLng? _currentTarget;
  String? _currentAddress;
  double _distanceRemaining = 0.0;
  double _heading = 0.0;
  StreamSubscription<Position>? _posSub;
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  final TextEditingController _searchController = TextEditingController();
  
  // Map Layer
  String _currentTileLayer = 'google_streets'; // 'google_streets', 'google_satellite', 'google_terrain'
  
  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      bool hasPermission = await _handlePermission();
      if (hasPermission) {
        _startLiveTracking();
        try {
          Position pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 5)),
          );
          if (mounted) setState(() => _currentPosition = pos);
        } catch (e) {
          debugPrint("GPS Timeout: $e");
        }
      }
    } catch (e) {
      debugPrint("Map Init Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startLiveTracking() {
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((pos) {
      if (mounted) {
        setState(() { 
          _currentPosition = pos; 
          _heading = pos.heading; 
        });
        
        if (_showRoute && _currentTarget != null) {
          _fetchRoute(LatLng(pos.latitude, pos.longitude), _currentTarget!);
          double dist = Geolocator.distanceBetween(pos.latitude, pos.longitude, _currentTarget!.latitude, _currentTarget!.longitude);
          setState(() => _distanceRemaining = dist / 1000);
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

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;
    try {
      final res = await http.get(Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data.isNotEmpty) {
          final target = LatLng(double.parse(data[0]['lat']), double.parse(data[0]['lon']));
          _selectLocation(target, query);
        }
      }
    } catch (e) { debugPrint("Search error: $e"); }
  }

  void _selectLocation(LatLng target, String address) {
    setState(() {
      _currentTarget = target;
      _currentAddress = address;
      _showRoute = true;
    });
    _mapController.move(target, 15.0);
    if (_currentPosition != null) _fetchRoute(LatLng(_currentPosition!.latitude, _currentPosition!.longitude), target);
    _sheetController.animateTo(0.35, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
  }

  Future<bool> _handlePermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;
    LocationPermission p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Colors.green))
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentPosition != null 
                        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude) 
                        : const LatLng(33.6844, 73.0479), // Default to Islamabad
                    initialZoom: 15.0,
                    onLongPress: (tapPos, point) => _selectLocation(point, "Marked Location"),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _getTileUrl(),
                      userAgentPackageName: 'com.example.leftover_food_app',
                    ),
                    if (_routePoints.isNotEmpty && _showRoute) PolylineLayer(polylines: [
                      Polyline(
                        points: _routePoints, 
                        strokeWidth: 8.0, 
                        color: Colors.blue.withValues(alpha: 0.3),
                      ),
                      Polyline(
                        points: _routePoints, 
                        strokeWidth: 4.0, 
                        color: const Color(0xFF1A73E8), // Google Maps Blue
                      ),
                    ]),
                    MarkerLayer(markers: [
                      if (_currentTarget != null) Marker(
                        point: _currentTarget!,
                        width: 100, height: 100,
                        child: _buildCustomMarker(Icons.location_on, Colors.redAccent),
                      ),
                      if (_currentPosition != null) Marker(
                        point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                        width: 120, height: 120,
                        child: _buildUserLocationMarker(),
                      ),
                    ]),
                  ],
                ),
          
          _buildTopSearchInterface(),
          _buildRightSideControls(),
          _buildBottomActionSheet(),
        ],
      ),
    );
  }

  String _getTileUrl() {
    switch (_currentTileLayer) {
      case 'google_satellite':
        return 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}';
      case 'google_terrain':
        return 'https://mt1.google.com/vt/lyrs=p&x={x}&y={y}&z={z}';
      default:
        return 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';
    }
  }

  Widget _buildUserLocationMarker() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10)]
          ),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Color(0xFF1A73E8), shape: BoxShape.circle),
            child: Transform.rotate(
              angle: _heading * (3.14159 / 180),
              child: const Icon(Icons.navigation, color: Colors.white, size: 20),
            ),
          ),
        ),
        Container(
          width: 20, height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF1A73E8).withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF1A73E8), width: 1),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomMarker(IconData icon, Color color) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.location_on, color: color, size: 50),
        Positioned(
          top: 10,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(Icons.restaurant, color: color, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildTopSearchInterface() {
    return Positioned(
      top: 60, left: 16, right: 16,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            height: 55,
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(30), 
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 8))]
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.blueGrey),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: _searchLocation,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    decoration: const InputDecoration(hintText: "Search here...", border: InputBorder.none),
                  ),
                ),
                const VerticalDivider(width: 20, indent: 15, endIndent: 15),
                IconButton(
                  onPressed: () => _searchLocation(_searchController.text), 
                  icon: const Icon(Icons.mic_none, color: Colors.blueGrey)
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _searchChip(Icons.restaurant, "Food Banks"),
                _searchChip(Icons.volunteer_activism, "NGOs"),
                _searchChip(Icons.home, "Shelters"),
                _searchChip(Icons.local_hospital, "Clinics"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightSideControls() {
    return Positioned(
      right: 16, bottom: 280,
      child: Column(
        children: [
          _mapControlBtn(Icons.layers, () => _showLayerDialog()),
          const SizedBox(height: 12),
          _mapControlBtn(Icons.my_location, () {
            if (_currentPosition != null) {
              _mapController.move(LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 16.0);
            }
          }),
        ],
      ),
    );
  }

  Widget _mapControlBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50, height: 50,
        decoration: BoxDecoration(
          color: Colors.white, 
          shape: BoxShape.circle, 
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)]
        ),
        child: Icon(icon, color: const Color(0xFF1A73E8), size: 24),
      ),
    );
  }

  Widget _searchChip(IconData icon, String label) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1A73E8)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildBottomActionSheet() {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.1,
      minChildSize: 0.1,
      maxChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)), 
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 30)]
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 24),
              if (_currentTarget == null)
                const Column(
                  children: [
                    Icon(Icons.explore_outlined, size: 50, color: Colors.grey),
                    SizedBox(height: 12),
                    Text("Select a donor or location to start", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                  ],
                )
              else ...[
                Text(_currentAddress ?? "Selected Location", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Colors.black)),
                const SizedBox(height: 4),
                const Text("Near Abbottabad • Open 24/7", style: TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _sheetActionBtn(Icons.directions, "Go", const Color(0xFF1A73E8)),
                    _sheetActionBtn(Icons.call, "Call", Colors.green),
                    _sheetActionBtn(Icons.share, "Share", Colors.orange),
                    _sheetActionBtn(Icons.bookmark_border, "Save", Colors.pink),
                  ],
                ),
                if (_showRoute) ...[
                  const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider()),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFF1A73E8).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        const Icon(Icons.drive_eta, color: Color(0xFF1A73E8)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Fastest Route", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text("${_distanceRemaining.toStringAsFixed(1)} km • 15 min drive"),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _sheetActionBtn(IconData icon, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 10),
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
      ],
    );
  }

  void _showLayerDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Map Type", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _layerOpt("Streets", Icons.map, 'google_streets'),
                _layerOpt("Satellite", Icons.satellite, 'google_satellite'),
                _layerOpt("Terrain", Icons.terrain, 'google_terrain'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _layerOpt(String label, IconData icon, String type) {
    bool isSelected = _currentTileLayer == type;
    return GestureDetector(
      onTap: () {
        setState(() => _currentTileLayer = type);
        Navigator.pop(context);
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF1A73E8).withValues(alpha: 0.1) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isSelected ? const Color(0xFF1A73E8) : Colors.transparent, width: 2),
            ),
            child: Icon(icon, color: isSelected ? const Color(0xFF1A73E8) : Colors.grey, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}

