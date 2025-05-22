import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show MaplibreMapController, LatLng, LatLngBounds, CameraUpdate, CameraPosition;
import 'package:latlong2/latlong.dart' as latlong2;
import '../../../core/services/trip_service.dart';
import '../../../core/services/map_service.dart';
import '../../../core/widgets/buttons/primary_button.dart';
import '../../../core/utils/location_utils.dart';
import '../../../core/widgets/platform_safe_map.dart';
import '../../../core/constants/map_constants.dart';
import '../../../core/widgets/village_notification.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
import '../../../core/widgets/crossed_villages_log.dart';

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
  double _completion = 0.0;
  Timer? _updateTimer;
  late LocationService _locationService;
  final String userId = 'someUserId';
  final String role = 'driver';
  Position? _currentPosition;
  DateTime? _lastMarkerUpdate;
  latlong2.LatLng? _destinationPosition;
  MapService? _mapService;
  Timer? _locationUpdateTimer;
  latlong2.LatLng? _selectedLocation;
  bool _isInitialZoom = true;
  List<Map<String, String>> _villageNotifications = [];
  OverlayEntry? _notificationOverlay;
  Set<String> _crossedVillages = {};
  Timer? _zoomTimer;
  bool _isZoomingToDestination = false;
  bool _hasReachedDestination = false;
  Map<String, DateTime> _villageCrossingTimes = {};

  @override
  void initState() {
    super.initState();
    _locationService = Provider.of<LocationService>(context, listen: false);
    _checkLocationPermissions();
    _loadRouteData();
    _setupLocationUpdates();
  }

  void _setupLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(
      MapConstants.locationUpdateInterval,
      (_) => _updateLocation(),
    );
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    _zoomTimer?.cancel();
    _notificationOverlay?.remove();
    _crossedVillages.clear();
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
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRouteData() async {
    final tripService = Provider.of<TripService>(context, listen: false);
    try {
      final routeData = await tripService.fetchRouteInfo(widget.routeId);
      final points = (routeData?['stops'] as List)
          .map((point) => latlong2.LatLng(point['latitude'] as double, point['longitude'] as double))
          .toList();
      setState(() {
        _routePoints = points;
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
      position: latlong2.LatLng(_routePoints.first.latitude, _routePoints.first.longitude),
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

  Future<void> _updateDriverMarker() async {
    if (_currentPosition == null || _mapController == null || _mapService == null) return;
    
    final currentPoint = latlong2.LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    
    await _mapService!.updateMarker(
      'driver',
      currentPoint,
      data: {
        'id': 'driver',
        'type': 'bus',
        'heading': _currentPosition!.heading,
      },
    );
  }
  
  Future<void> _updateRouteLine() async {
    if (_currentPosition == null || _destinationPosition == null) return;
    
    try {
      final tripService = Provider.of<TripService>(context, listen: false);
      final routePoints = await tripService.calculateRoute(
        latlong2.LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        _destinationPosition!,
      );
      
      if (routePoints.isNotEmpty && _mapService != null) {
        await _mapService!.addRoute(
          points: routePoints,
          data: {
            'id': 'current_route',
            'type': 'navigation',
          },
        );
      }
    } catch (e) {
      print('Error updating route line: $e');
    }
  }
  
  Future<void> _updateLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 10),
      );
      
      if (mounted) {
        setState(() => _currentPosition = position);
        
        if (_lastMarkerUpdate == null || 
            DateTime.now().difference(_lastMarkerUpdate!) > const Duration(milliseconds: 500)) {
          await _updateDriverMarker();
          _lastMarkerUpdate = DateTime.now();
        }
        
        if (_isInitialZoom) {
          await _zoomToLiveLocation();
          _isInitialZoom = false;
        }
        
        if (_destinationPosition != null) {
          await _updateRouteLine();
          
          if (!_hasReachedDestination) {
            final distance = _calculateDistance(
              latlong2.LatLng(position.latitude, position.longitude),
              _destinationPosition!,
            );
            
            if (distance <= MapConstants.villageDetectionRadius) {
              setState(() {
                _hasReachedDestination = true;
              });
            }
          }
        }

        await _checkForVillageCrossing(position);
      }
    } catch (e) {
      print('Error updating location: $e');
    }
  }

  Future<void> _zoomToLiveLocation() async {
    if (_currentPosition == null || _mapController == null) return;
    
    try {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          latlong2.LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ).toMaplibreLatLng(),
          MapConstants.liveLocationZoom,
        ),
        duration: MapConstants.cameraAnimationDuration,
      );
    } catch (e) {
      print('Error zooming to live location: $e');
    }
  }

  Future<void> _checkForVillageCrossing(Position position) async {
    if (_destinationPosition == null) return;

    try {
      final tripService = Provider.of<TripService>(context, listen: false);
      final currentPoint = latlong2.LatLng(position.latitude, position.longitude);
      
      final villageName = await tripService.getVillageName(currentPoint);
      
      if (villageName != null) {
        final villageCenter = await tripService.getVillageCenter(villageName);
        if (villageCenter != null) {
          final distance = _calculateDistance(currentPoint, villageCenter);
          
          if (distance <= MapConstants.villageDetectionRadius && 
              !_crossedVillages.contains(villageName) &&
              position.speed > 0) {
            
            _crossedVillages.add(villageName);
            _villageCrossingTimes[villageName] = DateTime.now();
            
            _showVillageNotification(villageName);
            
            await tripService.storeCrossedVillage(
              villageName,
              _villageCrossingTimes[villageName]!,
            );
          }
        }
      }
    } catch (e) {
      print('Error checking for village crossing: $e');
    }
  }

  void _showVillageNotification(String villageName) {
    final now = _villageCrossingTimes[villageName] ?? DateTime.now();
    final time = '${_formatHour(now.hour)}:${_formatMinute(now.minute)} ${now.hour >= 12 ? 'PM' : 'AM'}';
    
    setState(() {
      _villageNotifications.add({
        'village': villageName,
        'time': time,
      });
    });
    
    _showNotificationOverlay(villageName, time);
  }

  void _showNotificationOverlay(String villageName, String time) {
    _notificationOverlay?.remove();
    
    final overlay = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        child: VillageNotification(
          villageName: villageName,
          time: time,
          onDismiss: () {
            _notificationOverlay?.remove();
            _notificationOverlay = null;
          },
        ),
      ),
    );
    
    Overlay.of(context).insert(overlay);
    _notificationOverlay = overlay;
    
    Future.delayed(MapConstants.notificationDuration, () {
      overlay.remove();
      if (_notificationOverlay == overlay) {
        _notificationOverlay = null;
      }
    });
  }

  String _formatHour(int hour) {
    final h = hour > 12 ? hour - 12 : hour;
    return h.toString().padLeft(2, '0');
  }

  String _formatMinute(int minute) {
    return minute.toString().padLeft(2, '0');
  }

  void _onMapCreated(dynamic controller) {
    if (controller is MaplibreMapController) {
      _mapController = controller;
      _mapService = Provider.of<MapService>(context, listen: false);
      _mapService?.onMapCreated(controller);
      
      // Initial zoom to current location
      if (_currentPosition != null) {
        _zoomToLiveLocation();
      }
    }
  }

  void _onMapClick(latlong2.LatLng location) async {
    if (_mapController == null) return;

    setState(() {
      _selectedLocation = location;
      _destinationPosition = location;
      _isZoomingToDestination = true;
      _hasReachedDestination = false;
    });

    try {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          location.toMaplibreLatLng(),
          MapConstants.destinationZoom,
        ),
        duration: MapConstants.cameraAnimationDuration,
      );

      await _updateRouteLine();

      _zoomTimer?.cancel();
      _zoomTimer = Timer(const Duration(seconds: 2), () async {
        if (_currentPosition != null && mounted) {
          await _zoomToLiveLocation();
          setState(() {
            _isZoomingToDestination = false;
          });
        }
      });
    } catch (e) {
      print('Error handling map click: $e');
      setState(() {
        _isZoomingToDestination = false;
      });
    }
  }

  void _handleIdEntry() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Driver ID'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 40,
              child: Icon(Icons.person, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              'Driver ID: ${widget.busId}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Route: ${widget.routeId}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapService = Provider.of<MapService>(context);
    final locationService = Provider.of<LocationService>(context);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Campus Route'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: _handleIdEntry,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_error.isNotEmpty)
            Center(child: Text(_error, textAlign: TextAlign.center))
          else
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: PlatformSafeMap(
                onMapCreated: _onMapCreated,
                onMapClick: _onMapClick,
                initialCameraPosition: CameraPosition(
                  target: LatLng(
                    locationService.currentPosition?.latitude ?? 0,
                    locationService.currentPosition?.longitude ?? 0,
                  ),
                  zoom: MapConstants.defaultZoom,
                ),
                myLocationEnabled: true,
              ),
            ),
          
          Positioned(
            top: 16,
            right: 16,
            child: Column(
              children: [
                Container(
                  width: MapConstants.speedIndicatorSize,
                  height: MapConstants.speedIndicatorSize,
                  decoration: BoxDecoration(
                    color: MapConstants.speedIndicatorBackground,
                    borderRadius: BorderRadius.circular(MapConstants.defaultBorderRadius),
                  ),
                  child: Center(
                    child: Text(
                      '${_currentPosition?.speed?.round() ?? 0}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: MapConstants.locationSymbolSize,
                  height: MapConstants.locationSymbolSize,
                  decoration: BoxDecoration(
                    color: MapConstants.locationSymbolBackground,
                    borderRadius: BorderRadius.circular(MapConstants.defaultBorderRadius),
                  ),
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: MapConstants.bottomPanelHeight,
              padding: const EdgeInsets.all(16.0),
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
                  LinearProgressIndicator(
                    value: _completion,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Route ${(_completion * 100).toStringAsFixed(0)}% complete',
                    style: Theme.of(context).textTheme.titleMedium,
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
