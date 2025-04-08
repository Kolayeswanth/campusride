import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// MapService handles MapLibre integration and map-related operations.
class MapService extends ChangeNotifier {
  MaplibreMapController? _mapController;
  List<Symbol> _symbols = [];
  List<Line> _lines = [];
  LatLng _initialPosition = const LatLng(0, 0);
  bool _isMapLoaded = false;
  bool _isFollowingUser = true;
  LatLng? _currentLocation;
  bool _serviceEnabled = false;
  LocationPermission? _permissionGranted;
  String? _error;
  final _supabase = Supabase.instance.client;
  StreamSubscription? _locationSubscription;
  StreamSubscription? _busLocationSubscription;
  Map<String, LatLng> _busLocations = {};
  Map<String, StreamSubscription> _busSubscriptions = {};
  LatLng? _selectedLocation;
  double _zoom = 15.0;
  bool _isLoading = false;
  
  /// Map controller for direct map manipulation
  MaplibreMapController? get mapController => _mapController;
  
  /// Initial camera position
  LatLng get initialPosition => _initialPosition;
  
  /// Whether the map has been loaded
  bool get isMapLoaded => _isMapLoaded;
  
  /// Whether the map is following the user's location
  bool get isFollowingUser => _isFollowingUser;
  
  /// Set following user state
  set isFollowingUser(bool value) {
    _isFollowingUser = value;
    notifyListeners();
  }
  
  /// Current user location
  LatLng? get currentLocation => _currentLocation;
  
  /// Selected location on map
  LatLng? get selectedLocation => _selectedLocation;
  
  /// Current zoom level
  double get zoom => _zoom;
  
  /// Loading state
  bool get isLoading => _isLoading;
  
  /// Error message if any
  String? get error => _error;
  
  /// Initialize map with current location
  Future<void> initializeMap() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      _currentLocation = LatLng(position.latitude, position.longitude);
      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_currentLocation!, _zoom)
        );
      }
      
    } catch (e) {
      _error = 'Failed to initialize map: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Set the Map controller when map is created
  void onMapCreated(MaplibreMapController controller) {
    _mapController = controller;
    _isMapLoaded = true;
    notifyListeners();
    
    // Initialize map after controller is set
    initializeMap();
  }
  
  /// Move map to location
  Future<void> moveToLocation(LatLng location, {double? zoom}) async {
    if (_mapController == null) return;
    
    await _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(location, zoom ?? _zoom)
    );
  }
  
  /// Update current location
  void updateCurrentLocation(LatLng location) {
    _currentLocation = location;
    notifyListeners();
  }
  
  /// Set selected location
  void setSelectedLocation(LatLng? location) {
    _selectedLocation = location;
    notifyListeners();
  }
  
  /// Update zoom level
  void setZoom(double zoom) {
    _zoom = zoom;
    notifyListeners();
  }
  
  /// Add a marker to the map
  Future<Symbol?> addMarker({
    required LatLng position,
    String? title,
    String? snippet,
    String iconImage = 'marker',
    double iconSize = 1.0,
    Color iconColor = Colors.red,
  }) async {
    if (_mapController == null) return null;
    
    try {
      final symbol = await _mapController!.addSymbol(
        SymbolOptions(
          geometry: position,
          iconImage: iconImage,
          iconSize: iconSize,
          textField: title,
          textOffset: const Offset(0, 1.5),
          iconColor: iconColor.toHexStringRGB(),
        ),
      );
      
      _symbols.add(symbol);
      notifyListeners();
      return symbol;
    } catch (e) {
      _error = 'Failed to add marker: $e';
      notifyListeners();
      return null;
    }
  }
  
  /// Update user location marker
  Future<void> updateUserLocationMarker(Position position) async {
    if (_mapController == null) return;
    
    try {
      // Remove old user marker if exists
      for (final symbol in List.from(_symbols)) {
        if (symbol.data != null && symbol.data['id'] == 'user_location') {
          await _mapController!.removeSymbol(symbol);
          _symbols.remove(symbol);
        }
      }
      
      // Add new user marker
      final userMarker = await _mapController!.addSymbol(
        SymbolOptions(
          geometry: LatLng(position.latitude, position.longitude),
          iconImage: 'user-location',
          iconSize: 1.0,
          iconRotate: position.heading,
          iconColor: Colors.blue.toHexStringRGB(),
        ),
        {
          'id': 'user_location',
        },
      );
      
      _symbols.add(userMarker);
      
      // Move camera if following is enabled
      if (_isFollowingUser) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude),
            _zoom,
          ),
        );
      }
      
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update user location: $e';
      notifyListeners();
    }
  }
  
  /// Remove a marker from the map
  Future<void> removeMarker(Symbol symbol) async {
    if (_mapController == null) return;
    
    try {
      await _mapController!.removeSymbol(symbol);
      _symbols.remove(symbol);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to remove marker: $e';
      notifyListeners();
    }
  }
  
  /// Remove a marker by ID from the data property
  Future<void> removeMarkerById(String id) async {
    if (_mapController == null) return;
    
    try {
      for (final symbol in List.from(_symbols)) {
        if (symbol.data != null && symbol.data['id'] == id) {
          await _mapController!.removeSymbol(symbol);
          _symbols.remove(symbol);
        }
      }
      notifyListeners();
    } catch (e) {
      _error = 'Failed to remove marker: $e';
      notifyListeners();
    }
  }
  
  /// Clear all markers
  Future<void> clearMarkers({bool keepUserLocation = true}) async {
    if (_mapController == null) return;
    
    try {
      for (final symbol in List.from(_symbols)) {
        if (keepUserLocation && symbol.data != null && symbol.data['id'] == 'user_location') {
          continue;
        }
        await _mapController!.removeSymbol(symbol);
        _symbols.remove(symbol);
      }
      notifyListeners();
    } catch (e) {
      _error = 'Failed to clear markers: $e';
      notifyListeners();
    }
  }
  
  /// Add a route line to the map
  Future<Line?> addRoute({
    required List<LatLng> points,
    String id = 'route',
    Color color = Colors.blue,
    double width = 4.0,
  }) async {
    if (_mapController == null) return null;
    
    try {
      // Remove existing route with same ID
      await removeRouteById(id);
      
      // Add new route
      final line = await _mapController!.addLine(
        LineOptions(
          geometry: points,
          lineColor: color.toHexStringRGB(),
          lineWidth: width,
          lineOpacity: 0.7,
        ),
        {
          'id': id,
        },
      );
      
      _lines.add(line);
      notifyListeners();
      return line;
    } catch (e) {
      _error = 'Failed to add route: $e';
      notifyListeners();
      return null;
    }
  }
  
  /// Remove a route from the map
  Future<void> removeRoute(Line line) async {
    if (_mapController == null) return;
    
    try {
      await _mapController!.removeLine(line);
      _lines.remove(line);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to remove route: $e';
      notifyListeners();
    }
  }
  
  /// Remove a route by ID from the data property
  Future<void> removeRouteById(String id) async {
    if (_mapController == null) return;
    
    try {
      for (final line in List.from(_lines)) {
        if (line.data != null && line.data['id'] == id) {
          await _mapController!.removeLine(line);
          _lines.remove(line);
        }
      }
      notifyListeners();
    } catch (e) {
      _error = 'Failed to remove route: $e';
      notifyListeners();
    }
  }
  
  /// Clear all routes
  Future<void> clearRoutes() async {
    if (_mapController == null) return;
    
    try {
      for (final line in List.from(_lines)) {
        await _mapController!.removeLine(line);
      }
      _lines.clear();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to clear routes: $e';
      notifyListeners();
    }
  }
  
  /// Move camera to fit all points
  Future<void> fitBounds(List<LatLng> points, {double padding = 50.0}) async {
    if (_mapController == null || points.isEmpty) return;
    
    try {
      // Calculate bounds manually since fromLatLngs is not available
      double minLat = points[0].latitude;
      double maxLat = points[0].latitude;
      double minLng = points[0].longitude;
      double maxLng = points[0].longitude;
      
      for (final point in points) {
        minLat = minLat < point.latitude ? minLat : point.latitude;
        maxLat = maxLat > point.latitude ? maxLat : point.latitude;
        minLng = minLng < point.longitude ? minLng : point.longitude;
        maxLng = maxLng > point.longitude ? maxLng : point.longitude;
      }
      
      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );
      
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          bounds,
          top: padding,
          right: padding,
          bottom: padding,
          left: padding,
        ),
      );
    } catch (e) {
      _error = 'Failed to fit bounds: $e';
      notifyListeners();
    }
  }
  
  /// Dispose of resources
  @override
  void dispose() {
    _stopLocationUpdates();
    _stopBusLocationUpdates();
    super.dispose();
  }
  
  MapService() {
    _checkLocationPermission();
  }
  
  /// Check location permission
  Future<void> _checkLocationPermission() async {
    try {
      // Check if location service is enabled
      _serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!_serviceEnabled) {
        _error = 'Location service is disabled';
        notifyListeners();
        return;
      }
      
      // Check location permission
      _permissionGranted = await Geolocator.checkPermission();
      if (_permissionGranted == LocationPermission.denied) {
        _permissionGranted = await Geolocator.requestPermission();
        if (_permissionGranted == LocationPermission.denied) {
          _error = 'Location permission denied';
          notifyListeners();
          return;
        }
      }
      
      if (_permissionGranted == LocationPermission.deniedForever) {
        _error = 'Location permission permanently denied';
        notifyListeners();
        return;
      }
      
      // Get current location
      final position = await Geolocator.getCurrentPosition();
      _currentLocation = LatLng(position.latitude, position.longitude);
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
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      _currentLocation = LatLng(position.latitude, position.longitude);
      updateUserLocationMarker(position);
      notifyListeners();
    });
  }
  
  /// Stop listening to location updates
  void _stopLocationUpdates() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
  }
  
  /// Get current location
  Future<LatLng> getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      _currentLocation = LatLng(position.latitude, position.longitude);
      _error = null;
      notifyListeners();
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      _error = 'Failed to get current location: $e';
      notifyListeners();
      // Return default location (campus center) if current location is not available
      return const LatLng(33.7756, -84.3963);
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
        .listen((data) async {
          if (data.isNotEmpty) {
            final location = data.first;
            final lat = location['latitude'] as double;
            final lng = location['longitude'] as double;
            
            _busLocations[busId] = LatLng(lat, lng);
            
            // Update marker
            await removeMarkerById('bus_$busId');
            await addMarker(
              position: LatLng(lat, lng),
              title: 'Bus $busId',
              iconColor: Colors.green,
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
    removeMarkerById('bus_$busId');
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
        .listen((data) async {
          // Clear existing bus markers
          await clearMarkers(keepUserLocation: true);
          _busLocations.clear();
          
          // Add new markers for each bus
          for (final location in data) {
            final busId = location['bus_id'] as String;
            final lat = location['latitude'] as double;
            final lng = location['longitude'] as double;
            
            _busLocations[busId] = LatLng(lat, lng);
            
            await addMarker(
              position: LatLng(lat, lng),
              title: 'Bus $busId',
              iconColor: Colors.green,
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
  
  /// Calculate distance between two points
  double calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }
  
  /// Calculate bearing between two points
  double calculateBearing(LatLng point1, LatLng point2) {
    return Geolocator.bearingBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
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
} 