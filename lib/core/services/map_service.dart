import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// MapService handles MapLibre integration and map-related operations.
class MapService extends ChangeNotifier {
  MapController? _mapController;
  List<Marker> _markers = [];
  Map<String, Polyline> _routesMap = {}; // Using a Map to store routes with keys
  latlong.LatLng _initialPosition = const latlong.LatLng(0, 0);
  bool _isMapLoaded = false;
  bool _isFollowingUser = true;
  final Location _location = Location();
  LocationData? _currentLocation;
  bool _serviceEnabled = false;
  PermissionStatus? _permissionGranted;
  String? _error;
  final _supabase = Supabase.instance.client;
  StreamSubscription? _locationSubscription;
  StreamSubscription? _busLocationSubscription;
  Map<String, latlong.LatLng> _busLocations = {};
  Map<String, StreamSubscription> _busSubscriptions = {};
  
  /// Map controller
  MapController? get mapController => _mapController;
  
  /// List of map markers
  List<Marker> get markers => _markers;
  
  /// List of route polylines - converted from Map to List for flutter_map
  List<Polyline> get routes => _routesMap.values.toList();
  
  /// Initial camera position
  latlong.LatLng get initialPosition => _initialPosition;
  
  /// Whether the map has been loaded
  bool get isMapLoaded => _isMapLoaded;
  
  /// Whether the map is following the user's location
  bool get isFollowingUser => _isFollowingUser;
  
  /// Set following user state
  set isFollowingUser(bool value) {
    _isFollowingUser = value;
    notifyListeners();
  }
  
  /// Initialize the map with user's current position
  Future<void> initializeMap(Position? position) async {
    if (position != null) {
      _initialPosition = latlong.LatLng(position.latitude, position.longitude);
    }
    _isMapLoaded = true;
    _mapController = MapController();
    notifyListeners();
  }
  
  /// Set the Map controller
  void setMapController(MapController controller) {
    _mapController = controller;
    notifyListeners();
  }
  
  /// Update user location marker and camera position if following
  Future<void> updateUserLocation(Position position, {bool animate = true}) async {
    if (_mapController == null) return;
    
    // Update user marker
    final userMarker = Marker(
      point: latlong.LatLng(position.latitude, position.longitude),
      width: 30,
      height: 30,
      child: _buildUserMarker(position.heading),
    );
    
    // Replace the user marker if it exists, or add it
    _markers = [
      userMarker,
      ..._markers.where((m) => m.key != const ValueKey('user_location'))
    ];
    
    // Move camera if following is enabled
    if (_isFollowingUser && animate) {
      _mapController!.move(
        latlong.LatLng(position.latitude, position.longitude),
        15.0,
      );
    }
    
    notifyListeners();
  }
  
  /// Build the user marker with heading
  Widget _buildUserMarker(double heading) {
    return Transform.rotate(
      angle: heading * (pi / 180),
      child: Container(
        key: const ValueKey('user_location'),
        decoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: const Icon(
          Icons.navigation,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
  
  /// Add or update a marker on the map
  void addMarker({
    required String id,
    required latlong.LatLng position,
    String? title,
    String? snippet,
    Color color = Colors.red,
    VoidCallback? onTap,
  }) {
    final marker = Marker(
      key: ValueKey(id),
      point: position,
      width: 30,
      height: 30,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              width: 20,
              height: 20,
            ),
            if (title != null)
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 2,
                    ),
                  ],
                ),
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 10),
                ),
              ),
          ],
        ),
      ),
    );
    
    // Replace marker if it exists with same id, or add it
    _markers = [
      marker,
      ..._markers.where((m) => m.key != ValueKey(id))
    ];
    notifyListeners();
  }
  
  /// Remove a marker from the map
  void removeMarker(String id) {
    _markers = _markers.where((m) => m.key != ValueKey(id)).toList();
    notifyListeners();
  }
  
  /// Clear all markers except user location
  void clearMarkers({bool keepUserLocation = true}) {
    if (keepUserLocation) {
      _markers = _markers.where((m) => m.key == const ValueKey('user_location')).toList();
    } else {
      _markers = [];
    }
    notifyListeners();
  }
  
  /// Add a route polyline to the map
  void addRoute({
    required String id,
    required List<latlong.LatLng> points,
    Color color = Colors.blue,
    double width = 4.0,
    bool isDotted = false,
  }) {
    // Create polyline
    final polyline = Polyline(
      points: points,
      color: color,
      strokeWidth: width,
      isDotted: isDotted,
    );
    
    // Add or replace route in the Map
    _routesMap[id] = polyline;
    notifyListeners();
  }
  
  /// Remove a route from the map
  void removeRoute(String id) {
    _routesMap.remove(id);
    notifyListeners();
  }
  
  /// Clear all routes
  void clearRoutes() {
    _routesMap.clear();
    notifyListeners();
  }
  
  /// Move camera to a specific position
  Future<void> moveCameraToPosition(latlong.LatLng position, {double zoom = 15.0}) async {
    if (_mapController == null) return;
    _mapController!.move(position, zoom);
  }
  
  /// Move camera to show all provided markers
  Future<void> fitMapToMarkers(List<Marker> markers, {double padding = 50.0}) async {
    if (_mapController == null || markers.isEmpty) return;
    
    final bounds = boundsFromPoints(
      markers.map((m) => m.point).toList()
    );
    
    final centerZoom = _mapController!.centerZoomFitBounds(bounds, options: FitBoundsOptions(
      padding: EdgeInsets.all(padding),
    ));
    
    _mapController!.move(centerZoom.center, centerZoom.zoom);
  }
  
  /// Calculate bounds from a list of LatLng points
  LatLngBounds boundsFromPoints(List<latlong.LatLng> points) {
    if (points.isEmpty) {
      return LatLngBounds(latlong.LatLng(0, 0), latlong.LatLng(0, 0));
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    
    for (final point in points) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }
    
    return LatLngBounds(
      latlong.LatLng(minLat, minLng),
      latlong.LatLng(maxLat, maxLng),
    );
  }
  
  /// Dispose of resources
  @override
  void dispose() {
    _stopLocationUpdates();
    _stopBusLocationUpdates();
    super.dispose();
  }
  
  LocationData? get currentLocation => _currentLocation;
  bool get serviceEnabled => _serviceEnabled;
  PermissionStatus? get permissionGranted => _permissionGranted;
  String? get error => _error;
  
  MapService() {
    _initLocationService();
  }
  
  /// Initialize location service
  Future<void> _initLocationService() async {
    try {
      // Check if location service is enabled
      _serviceEnabled = await _location.serviceEnabled();
      if (!_serviceEnabled) {
        _serviceEnabled = await _location.requestService();
        if (!_serviceEnabled) {
          _error = 'Location service is disabled';
          notifyListeners();
          return;
        }
      }
      
      // Check location permission
      _permissionGranted = await _location.hasPermission();
      if (_permissionGranted == PermissionStatus.denied) {
        _permissionGranted = await _location.requestPermission();
        if (_permissionGranted != PermissionStatus.granted) {
          _error = 'Location permission denied';
          notifyListeners();
          return;
        }
      }
      
      // Get current location
      _currentLocation = await _location.getLocation();
      _error = null;
      notifyListeners();
      
      // Start listening to location changes
      _startLocationUpdates();
    } catch (e) {
      _error = 'Failed to initialize location service: $e';
      notifyListeners();
    }
  }
  
  /// Start listening to location updates
  void _startLocationUpdates() {
    _locationSubscription?.cancel();
    _locationSubscription = _location.onLocationChanged.listen((LocationData locationData) {
      _currentLocation = locationData;
      notifyListeners();
    });
  }
  
  /// Stop listening to location updates
  void _stopLocationUpdates() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
  }
  
  /// Get current location
  Future<latlong.LatLng> getCurrentLocation() async {
    try {
      final locationData = await _location.getLocation();
      _currentLocation = locationData;
      _error = null;
      notifyListeners();
      return latlong.LatLng(locationData.latitude!, locationData.longitude!);
    } catch (e) {
      _error = 'Failed to get current location: $e';
      notifyListeners();
      // Return default location (campus center) if current location is not available
      return const latlong.LatLng(33.7756, -84.3963);
    }
  }
  
  /// Subscribe to real-time bus location updates
  void subscribeToBusLocation(String busId) {
    // Cancel existing subscription if any
    _busSubscriptions[busId]?.cancel();
    
    // Create new subscription
    _busSubscriptions[busId] = _supabase
        .from('bus_locations')
        .stream(primaryKey: ['id'])
        .eq('bus_id', busId)
        .order('timestamp', ascending: false)
        .limit(1)
        .listen((data) {
          if (data.isNotEmpty) {
            final location = data.first;
            final lat = location['latitude'] as double;
            final lng = location['longitude'] as double;
            
            _busLocations[busId] = latlong.LatLng(lat, lng);
            
            // Update marker
            addMarker(
              id: 'bus_$busId',
              position: latlong.LatLng(lat, lng),
              title: 'Bus $busId',
              color: Colors.green,
            );
            
            notifyListeners();
          }
        });
  }
  
  /// Unsubscribe from bus location updates
  void unsubscribeFromBusLocation(String busId) {
    _busSubscriptions[busId]?.cancel();
    _busSubscriptions.remove(busId);
    _busLocations.remove(busId);
    removeMarker('bus_$busId');
    notifyListeners();
  }
  
  /// Subscribe to all active buses for a route
  void subscribeToRouteBuses(String routeId) {
    // Cancel existing subscription if any
    _busLocationSubscription?.cancel();
    
    // Create new subscription
    _busLocationSubscription = _supabase
        .from('bus_locations')
        .stream(primaryKey: ['id'])
        .eq('route_id', routeId)
        .order('timestamp', ascending: false)
        .limit(10)
        .listen((data) {
          // Clear existing bus markers
          _markers = _markers.where((m) => m.key == const ValueKey('user_location')).toList();
          _busLocations.clear();
          
          // Add new markers for each bus
          for (final location in data) {
            final busId = location['bus_id'] as String;
            final lat = location['latitude'] as double;
            final lng = location['longitude'] as double;
            
            _busLocations[busId] = latlong.LatLng(lat, lng);
            
            addMarker(
              id: 'bus_$busId',
              position: latlong.LatLng(lat, lng),
              title: 'Bus $busId',
              color: Colors.green,
            );
          }
          
          notifyListeners();
        });
  }
  
  /// Stop listening to bus location updates
  void _stopBusLocationUpdates() {
    _busLocationSubscription?.cancel();
    _busLocationSubscription = null;
    
    // Cancel all bus subscriptions
    for (final subscription in _busSubscriptions.values) {
      subscription.cancel();
    }
    _busSubscriptions.clear();
  }
  
  /// Calculate distance between two points in meters
  double calculateDistance(latlong.LatLng point1, latlong.LatLng point2) {
    final distance = const latlong.Distance().distance(point1, point2);
    return distance;
  }
  
  /// Format distance in a human-readable format
  String formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()} m';
    } else {
      final kilometers = distanceInMeters / 1000;
      return '${kilometers.toStringAsFixed(1)} km';
    }
  }
  
  /// Calculate estimated time of arrival (ETA)
  String calculateETA(double distanceInMeters, {double speedInKmh = 30}) {
    // Convert speed to meters per second
    final speedInMps = speedInKmh * (1000 / 3600);
    
    // Calculate time in seconds
    final timeInSeconds = distanceInMeters / speedInMps;
    
    // Convert to minutes
    final minutes = (timeInSeconds / 60).round();
    
    if (minutes < 1) {
      return 'Less than a minute';
    } else if (minutes == 1) {
      return '1 minute';
    } else if (minutes < 60) {
      return '$minutes minutes';
    } else {
      final hours = (minutes / 60).floor();
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '$hours ${hours == 1 ? 'hour' : 'hours'}';
      } else {
        return '$hours ${hours == 1 ? 'hour' : 'hours'} $remainingMinutes minutes';
      }
    }
  }
  
  /// Get map style URLs for MapTiler
  String getMapTileUrl({bool darkMode = false}) {
    // You can use OpenStreetMap tiles (free)
    return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    
    // Or if you have a MapTiler key
    // final mapTilerKey = 'YOUR_MAPTILER_KEY';
    // return darkMode
    //     ? 'https://api.maptiler.com/maps/streets-dark/256/{z}/{x}/{y}.png?key=$mapTilerKey'
    //     : 'https://api.maptiler.com/maps/streets/256/{z}/{x}/{y}.png?key=$mapTilerKey';
  }
  
  // Add MapTiler key if using their service
  String? mapTilerKey;
} 