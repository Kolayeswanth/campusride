import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/services/trip_service.dart';
import '../../../core/services/map_service.dart';
import '../../../core/widgets/buttons/primary_button.dart';
import '../../../core/utils/location_utils.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show MaplibreMapController;
import 'package:latlong2/latlong.dart' as latlong2;
import '../../../core/widgets/platform_safe_map.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase

/// LocationService handles real-time location tracking and updates
class LocationService extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  StreamSubscription? _locationSubscription;
  bool _isTracking = false;
  String? _error;

  /// Current position
  Position? get currentPosition => _currentPosition;

  /// Whether location tracking is active
  bool get isTracking => _isTracking;

  /// Error message if any
  String? get error => _error;

  /// Start location tracking
  Future<void> startTracking(String userId, String role) async {
    if (_isTracking) return;

    try {
      // Check location permissions
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied) {
          throw Exception('Location permissions are required');
        }
      }

      // Start position updates
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      ).listen((Position position) async {
        _currentPosition = position;

        // Update location in Supabase
        await _updateLocation(userId, role, position);

        notifyListeners();
      });

      _isTracking = true;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to start location tracking: ${e.toString()}';
      _isTracking = false;
      notifyListeners();
    }
  }

  /// Stop location tracking
  Future<void> stopTracking() async {
    await _positionStream?.cancel();
    await _locationSubscription?.cancel();
    _isTracking = false;
    _currentPosition = null;
    notifyListeners();
  }

  /// Update location in Supabase
  Future<void> _updateLocation(String userId, String role, Position position) async {
    try {
      await _supabase.from('user_locations').upsert({
        'user_id': userId,
        'role': role,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'heading': position.heading,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _error = 'Failed to update location: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Subscribe to location updates for a specific role
  void subscribeToLocationUpdates(String role, Function(List<Map<String, dynamic>>) onUpdate) {
    _locationSubscription?.cancel();

    _locationSubscription = _supabase
        .from('user_locations')
        .stream(primaryKey: ['user_id'])
        .eq('role', role)
        .listen((data) {
      onUpdate(data);
    });
  }

  /// Calculate distance between two points
  double calculateDistance(latlong2.LatLng point1, latlong2.LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  /// Calculate bearing between two points
  double calculateBearing(latlong2.LatLng point1, latlong2.LatLng point2) {
    return Geolocator.bearingBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}

class DriverMapScreen extends StatefulWidget {
  final String routeId;
  final String busId;

  const DriverMapScreen({
    Key? key,
    required this.routeId,
    required this.busId,
  }) : super(key: key);

  @override
  State<DriverMapScreen> createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends State<DriverMapScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  MaplibreMapController? _mapController;
  bool _isLoading = true;
  String _error = '';
  List<latlong2.LatLng> _routePoints = <latlong2.LatLng>[];
  List<latlong2.LatLng> _completedPoints = <latlong2.LatLng>[];
  double _completion = 0.0; // 0 to 1
  Timer? _updateTimer;
  late LocationService _locationService; // Add LocationService
  // Define userId and role.  These should come from your authentication system
  final String userId = 'someUserId';
  final String role = 'driver';

  @override
  void initState() {
    super.initState();
    _locationService = Provider.of<LocationService>(context, listen: false); // Initialize LocationService
    _checkLocationPermissions();
    _loadRouteData();
  }

  @override
  void dispose() {
    _stopPeriodicUpdates();
    super.dispose();
  }

  Future<void> _checkLocationPermissions() async {
    try {
      final position = await LocationUtils.getCurrentPosition();
      setState(() {
        //_currentPosition = position; // No longer directly setting _currentPosition
        _isLoading = false;
      });
    } catch (e) {
      setState(() {z
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRouteData() async {
    final tripService = Provider.of<TripService>(context, listen: false);

    try {
      final routeData = await tripService.getRouteData(widget.routeId);
      final points = routeData['points'] as List;

      setState(() {
        _routePoints = points
            .map((point) => latlong2.LatLng(point['latitude'] as double, point['longitude'] as double))
            .toList();
        _isLoading = false;
      });

      _updateRouteDisplay();
    } catch (e) {
      setState(() {
        _error = 'Failed to load route data: $e';
        _isLoading = false;
      });
    }
  }

  void _startLocationUpdates() {
    if (_locationService.isTracking) return;

    _locationService.startTracking(userId, role); // Use LocationService to start tracking

    // Start periodic updates to server (if needed, otherwise Supabase updates are sufficient)
    _updateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _updateBusLocation();
    });
  }

  void _stopLocationUpdates() {
    _locationService.stopTracking(); // Use LocationService to stop tracking
    _stopPeriodicUpdates();
  }

  void _stopPeriodicUpdates() {
    _updateTimer?.cancel();
  }

  void _onLocationUpdate() {
    // Get the latest position from the LocationService
    final position = _locationService.currentPosition;

    if (position != null) {
      // Update map if controller exists
      if (_mapController != null) {
        final mapService = Provider.of<MapService>(context, listen: false);
        final currentPosition = latlong2.LatLng(position.latitude, position.longitude);

        mapService.updateUserLocation(position);

        // Update route completion
        _updateRouteCompletion(currentPosition);
      }
    }
    // No longer setting state directly, LocationService handles it
  }

  void _updateRouteCompletion(latlong2.LatLng currentPosition) {
    if (_routePoints.isEmpty) return;

    // Find closest point on route
    int closestPointIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < _routePoints.length; i++) {
      final point = _routePoints[i];
      final distance = _calculateDistance(currentPosition, point);

      if (distance < minDistance) {
        minDistance = distance;
        closestPointIndex = i;
      }
    }

    // Update completed points
    setState(() {
      _completedPoints = _routePoints.sublist(0, closestPointIndex + 1);
      _completion = closestPointIndex / _routePoints.length;
    });

    _updateRouteDisplay();
  }

  double _calculateDistance(latlong2.LatLng point1, latlong2.LatLng point2) {
    return LocationUtils.calculateDistance(point1, point2);
  }

  void _updateRouteDisplay() {
    if (_routePoints.isEmpty) return;

    final mapService = Provider.of<MapService>(context, listen: false);

    // Add full route polyline
    mapService.addRoute(
      points: _routePoints,
      data: {'id': 'full_route', 'color': Colors.grey.withOpacity(0.7)},
      width: 5.0,
      color: Colors.grey.withOpacity(0.7),
    );

    // Add completed route polyline
    if (_completedPoints.isNotEmpty) {
      mapService.addRoute(
        points: _completedPoints,
        data: {'id': 'completed_route', 'color': Colors.green},
        width: 5.0,
        color: Colors.green,
      );
    }

    // Add markers for route start and end
    mapService.addMarker(
      position: LatLng(_routePoints.first.latitude, _routePoints.first.longitude),
      data: {'id': 'route_start', 'color': Colors.green},
      title: 'Start',
      iconColor: Colors.green,
    );

    mapService.addMarker(
      position: _routePoints.last,
      data: {'id': 'route_end', 'color': Colors.red},
      title: 'End',
      iconColor: Colors.red,
    );
  }

  Future<void> _updateBusLocation() async {
    if (!_locationService.isTracking || _locationService.currentPosition == null) return;

    final tripService = Provider.of<TripService>(context, listen: false);
    final position = _locationService.currentPosition!;

    try {
      await tripService.updateBusLocation(
        widget.busId,
        position.latitude,
        position.longitude,
        position.heading,
        position.speed,
      );
    } catch (e) {
      print('Failed to update bus location: $e');
      // We don't want to show errors to the driver for every update failure
    }
  }

  void _toggleTracking() {
    if (_locationService.isTracking) {
      _stopLocationUpdates();
    } else {
      _startLocationUpdates();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapService = Provider.of<MapService>(context);
    final locationService = Provider.of<LocationService>(context); // Get the LocationService

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Campus Route'),
        actions: [
          IconButton(
            icon: const Icon(Icons.layers),
            onPressed: () {
              // Show map options
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_error.isNotEmpty)
            Center(child: Text(_error, textAlign: TextAlign.center))
          else
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: PlatformSafeMap(
                initialCameraPosition: latlong2.CameraPosition(
                  target: latlong2.LatLng(
                    locationService.currentPosition?.latitude ?? 0.0, // Use LocationService's position
                    locationService.currentPosition?.longitude ?? 0.0,
                  ),
                  zoom: 15.0,
                ),
                myLocationEnabled: true,
                onMapCreated: (controller) {
                  setState(() {
                    _mapController = controller;
                  });

                  if (locationService.currentPosition != null) {
                    final lat = locationService.currentPosition!.latitude;
                    final lng = locationService.currentPosition!.longitude;
                    final position = LatLng(lat, lng);
                    mapService.moveCameraToPosition(latlong2.LatLng(lat, lng));
                  }

                  if (_routePoints.isNotEmpty) {
                    // Calculate bounds manually since fromLatLngs is not available
                    double minLat = _routePoints[0].latitude;
                    double maxLat = _routePoints[0].latitude;
                    double minLng = _routePoints[0].longitude;
                    double maxLng = _routePoints[0].longitude;

                    for (final point in _routePoints) {
                      minLat = minLat < point.latitude ? minLat : point.latitude;
                      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
                      minLng = minLng < point.longitude ? minLng : point.longitude;
                      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
                    }

                    final latlong2Bounds = latlong2.LatLngBounds(
                      latlong2.LatLng(minLat, minLng),
                      latlong2.LatLng(maxLat, maxLng),
                    );

                    controller.animateCamera(
                      CameraUpdate.newLatLngBounds(latlong2Bounds, top: 50.0, right: 50.0, bottom: 50.0, left: 50.0),
                    );
                  }
                },
              ),
            ),
          // Bottom panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Route completion indicator
                  LinearProgressIndicator(
                    value: _completion,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Route ${(_completion * 100).toStringAsFixed(0)}% complete',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      PrimaryButton(
                        text: locationService.isTracking ? 'Stop Tracking' : 'Start Tracking',
                        icon: locationService.isTracking ? Icons.stop : Icons.play_arrow,
                        onPressed: _toggleTracking,
                        backgroundColor: locationService.isTracking
                            ? Colors.red
                            : Theme.of(context).colorScheme.primary,
                        minWidth: 180,
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
