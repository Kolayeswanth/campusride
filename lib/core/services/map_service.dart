import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'offline_service.dart';
import 'navigation_service.dart';

const double kAutoFollowZoom = 17.0; // Consistent zoom level for auto-follow

/// MapService handles MapLibre integration and map-related operations.
class MapService extends ChangeNotifier {
  MapLibreMapController? _mapController;
  final List<String> _markerIds = [];
  final List<String> _routeIds = [];
  final List<Symbol> _symbols = [];
  final List<Line> _lines = [];
  bool _isMapLoaded = false;
  bool _isFollowingUser = true;
  LatLng? _currentLocation;
  bool _serviceEnabled = false;
  LocationPermission? _permissionGranted;
  String? _error;
  final _supabase = Supabase.instance.client;
  StreamSubscription? _locationSubscription;
  StreamSubscription? _busLocationSubscription; // Removed <Map<String, dynamic>>
  Map<String, LatLng> _busLocations = {}; // Use LatLng from MapLibre
  Map<String, StreamSubscription> _busSubscriptions = {};
  LatLng? _selectedLocation;
  double _zoom = 15.0;
  bool _isLoading = false;
  bool _isOfflineMode = false;
  Map<String, dynamic>? _offlineMapData;
  NavigationService? _navigationService;
  DateTime? _lastMarkerUpdate;

  /// Map controller for direct map manipulation
  MapLibreMapController? get mapController => _mapController;

  /// Initial camera position
  CameraPosition get initialCameraPosition => CameraPosition(
        target: _currentLocation ?? const LatLng(33.7756, -84.3963),
        zoom: _zoom,
      );

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

  bool get isOfflineMode => _isOfflineMode;

  MapService();
  
  void setNavigationService(NavigationService navigationService) {
    _navigationService = navigationService;
  }

  /// Initialize map with current location
  Future<void> initializeMap() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15), // Add proper timeout
      );
      _currentLocation = LatLng(position.latitude, position.longitude);
      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_currentLocation!, _zoom),
        );
      }
    } catch (e) {
      _error = 'Failed to initialize map: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update user location
  void updateUserLocation(Position position) {
    _currentLocation = LatLng(position.latitude, position.longitude);
    updateUserLocationMarker(position);
    notifyListeners();
  }

  /// Move camera to a specific position
  Future<void> moveCameraToPosition(LatLng position) async {
    if (_mapController == null) return;
    await _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(position, _zoom),
    );
  }

  /// Set the Map controller when map is created
  void onMapCreated(MapLibreMapController controller) {
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
      CameraUpdate.newLatLngZoom(location, zoom ?? _zoom),
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
  Future<void> addMarker({
    required LatLng position,
    required Map<String, dynamic> data,
    String? title,
    Color? iconColor,
  }) async {
    if (_mapController == null) return;

    final markerId = data['id'] as String;
    if (_markerIds.contains(markerId)) {
      await removeMarkerById(markerId);
    }

    final symbol = await _mapController!.addSymbol(
      SymbolOptions(
        geometry: position,
        iconImage: data['type'] == 'bus' ? 'bus-icon' : 'marker-icon',
        iconSize: data['type'] == 'bus' ? 1.5 : 1.0,
        iconRotate: data['heading']?.toDouble() ?? 0.0,
        textField: title,
        textColor: '#000000',
        textSize: 12.0,
        textOffset: const Offset(0, 2),
      ),
      data,
    );

    _symbols.add(symbol);
    _markerIds.add(markerId);
    notifyListeners();
  }

  /// Update user location marker
  Future<void> updateUserLocationMarker(Position position) async {
    if (_mapController == null) return;

    try {
      // First, check if we already have a user location marker
      Symbol? existingUserMarker;
      for (final symbol in _symbols) {
        if (symbol.data?['id'] == 'user_location') {
          existingUserMarker = symbol;
          break;
        }
      }

      if (existingUserMarker != null) {
        // Update the existing marker instead of creating a new one
        await _mapController!.updateSymbol(
          existingUserMarker,
          SymbolOptions(
            geometry: LatLng(position.latitude, position.longitude),
            iconImage: 'user-location',
            iconSize: 1.0,
            iconRotate: position.heading,
            iconColor: Colors.blue.toHexStringRGB(),
          ),
        );
      } else {
        // Create a new marker if one doesn't exist
        final userMarker = await _mapController!.addSymbol(
          SymbolOptions(
            geometry: LatLng(position.latitude, position.longitude),
            iconImage: 'user-location',
            iconSize: 1.0,
            iconRotate: position.heading,
            iconColor: Colors.blue.toHexStringRGB(),
          ),
          {'id': 'user_location'},
        );
        _symbols.add(userMarker);
      }

      // Move camera if following is enabled
      if (_isFollowingUser) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude),
            kAutoFollowZoom,
          ),
        );
        _zoom = kAutoFollowZoom; // Keep internal zoom state in sync
      }

      notifyListeners();
    } catch (e) {
      _error = 'Failed to update user location: $e';
      notifyListeners();
    }
  }

  /// Update an existing marker
  Future<void> updateMarker(
    String markerId,
    LatLng position, {
    Map<String, dynamic>? data,
    double? heading,
  }) async {
    if (_mapController == null || !_markerIds.contains(markerId)) return;

    final symbol = _symbols.firstWhere(
      (s) => s.data?['id'] == markerId,
      orElse: () => throw Exception('Marker not found'),
    );

    final currentData = symbol.data ?? {};
    final updatedData = {
      ...currentData,
      ...?data,
      'heading': heading ?? currentData['heading'],
    };

    await _mapController!.updateSymbol(
      symbol,
      SymbolOptions(
        geometry: position,
        iconImage: updatedData['type'] == 'bus' ? 'bus-icon' : 'marker-icon',
        iconSize: updatedData['type'] == 'bus' ? 1.5 : 1.0,
        iconRotate: updatedData['heading']?.toDouble() ?? 0.0,
      ),
    );

    notifyListeners();
  }

  /// Remove a marker by ID
  Future<void> removeMarkerById(String markerId) async {
    if (_mapController == null) return;

    final symbol = _symbols.firstWhere(
      (s) => s.data?['id'] == markerId,
      orElse: () => throw Exception('Marker not found'),
    );

    await _mapController!.removeSymbol(symbol);
    _symbols.remove(symbol);
    _markerIds.remove(markerId);
    notifyListeners();
  }

  /// Clear all markers
  Future<void> clearMarkers() async {
    if (_mapController == null) return;

    for (final symbol in List.from(_symbols)) {
      await _mapController!.removeSymbol(symbol);
    }
    _symbols.clear();
    _markerIds.clear();
    notifyListeners();
  }

  /// Add a route to the map
  Future<void> addRoute({
    required List<LatLng> points,
    required Map<String, dynamic> data,
    double width = 5.0,
    Color color = Colors.blue,
  }) async {
    if (_mapController == null) return;

    final routeId = data['id'] as String;
    if (_routeIds.contains(routeId)) {
      await removeRouteById(routeId);
    }

    final coordinates = points.map((point) => point).toList();

    final line = await _mapController!.addLine(
      LineOptions(
        geometry: coordinates,
        lineColor: color.value.toRadixString(16).padLeft(8, '0'),
        lineWidth: width,
        lineJoin: 'round',
      ),
      data,
    );

    _lines.add(line);
    _routeIds.add(routeId);
    notifyListeners();
  }

  /// Remove a route by ID
  Future<void> removeRouteById(String routeId) async {
    if (_mapController == null) return;

    final line = _lines.firstWhere(
      (l) => l.data?['id'] == routeId,
      orElse: () => throw Exception('Route not found'),
    );

    await _mapController!.removeLine(line);
    _lines.remove(line);
    _routeIds.remove(routeId);
    notifyListeners();
  }

  /// Clear all routes
  Future<void> clearRoutes() async {
    if (_mapController == null) return;

    for (final line in List.from(_lines)) {
      await _mapController!.removeLine(line);
    }
    _lines.clear();
    _routeIds.clear();
    notifyListeners();
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
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10, // Update every 10 meters instead of 5
        timeLimit: Duration(seconds: 15), // Increased timeout
      ),
    ).listen(
      (Position position) {
      _currentLocation = LatLng(position.latitude, position.longitude);
        // Debounce marker updates to reduce UI work
        if (_lastMarkerUpdate == null || 
            DateTime.now().difference(_lastMarkerUpdate!) > const Duration(milliseconds: 500)) {
      updateUserLocationMarker(position);
          _lastMarkerUpdate = DateTime.now();
        }
        notifyListeners();
      },
      onError: (error) {
        _error = 'Location update error: $error';
      notifyListeners();
      },
    );
  }

  /// Stop listening to location updates
  void _stopLocationUpdates() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  /// Get current location
  Future<LatLng> getCurrentLocation() async {
    try {
      // Handle web platform specifically to avoid Platform._operatingSystem error
      if (kIsWeb) {
        try {
          // First check if location services are enabled for web
          bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (!serviceEnabled) {
            _error = 'Location services are disabled. Please enable them in your browser settings.';
            notifyListeners();
            return const LatLng(33.7756, -84.3963); // Default location
          }

          // Check permission status for web
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
            if (permission == LocationPermission.denied) {
              _error = 'Location permission denied in browser';
              notifyListeners();
              return const LatLng(33.7756, -84.3963); // Default location
            }
          }

          if (permission == LocationPermission.deniedForever) {
            _error = 'Location permissions are permanently denied in browser settings';
            notifyListeners();
            return const LatLng(33.7756, -84.3963); // Default location
          }

          // Get current position for web with highest accuracy
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.bestForNavigation,
            timeLimit: const Duration(seconds: 15),
            forceAndroidLocationManager: false, // Use Google Play Services when available
          );
          _currentLocation = LatLng(position.latitude, position.longitude);
          _error = null;
          notifyListeners();
          return _currentLocation!;
        } catch (webError) {
          _error = 'Failed to get location in browser: $webError';
          notifyListeners();
          return const LatLng(33.7756, -84.3963); // Default location
        }
      } else {
        // Mobile platform handling
        // First check if location services are enabled
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          _error = 'Location services are disabled. Please enable them in your device settings.';
          notifyListeners();
          return const LatLng(33.7756, -84.3963); // Default location
        }

        // Check permission status
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            _error = 'Location permission denied';
            notifyListeners();
            return const LatLng(33.7756, -84.3963); // Default location
          }
        }

        if (permission == LocationPermission.deniedForever) {
          _error = 'Location permissions are permanently denied, we cannot request permissions.';
          notifyListeners();
          return const LatLng(33.7756, -84.3963); // Default location
        }

        // Get current position with highest accuracy for navigation
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
          timeLimit: const Duration(seconds: 15),
          forceAndroidLocationManager: false, // Use Google Play Services when available
        );
        
        // Update current location
        _currentLocation = LatLng(position.latitude, position.longitude);
        _error = null;
        notifyListeners();
        return _currentLocation!;
      }
    } catch (e) {
      _error = 'Failed to get current location: $e';
      notifyListeners();
      // Return a default location
      return const LatLng(33.7756, -84.3963); // Default location (can be customized)
    }
  }

  /// Update user location on map
  Future<void> updateUserLocationOnMap(Position position) async {
    if (position.accuracy <= 20) { // Only update if accuracy is within 20 meters
      _currentLocation = LatLng(position.latitude, position.longitude);
      
      // Check if marker exists
      bool markerExists = _markerIds.contains('user_location');
      
      if (markerExists) {
        // Update existing marker
        await updateMarker(
          'user_location',
          _currentLocation!,
          data: {'id': 'user_location'},
        );
      } else {
        // Create new marker
        await addMarker(
          position: _currentLocation!,
          data: {'id': 'user_location'},
          title: 'Your Location',
          iconColor: Colors.blue,
        );
      }
      
      notifyListeners();
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
        final accuracy = location['accuracy'] as double? ?? 0.0;
        if (accuracy <= 20) { // Only update if accuracy is within 20 meters
          _busLocations[busId] = LatLng(lat, lng);
          // Update marker
          await removeMarkerById('bus_$busId');
          await addMarker(
            position: LatLng(lat, lng),
            data: {'id': 'bus_$busId'},
            title: 'Bus $busId',
            iconColor: Colors.green,
          );
          notifyListeners();
        }
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

    // Create a new subscription (assuming 'active_buses' contains bus_ids as strings)
    _busLocationSubscription = _supabase
        .from('active_buses')
        .stream(primaryKey: ['route_id'])
        .eq('route_id', routeId)
        .listen((data) {
      if (data.isNotEmpty) {
        final buses = data.first['bus_ids'] as List<dynamic>; // Adjust this line based on your data structure
        buses.forEach((busId) {
          if (busId is String) {
            subscribeToBusLocation(busId);
          }
        });
      }
    });
  }


  /// Stop listening to bus location updates
  void _stopBusLocationUpdates() {
    _busLocationSubscription?.cancel();
    _busLocationSubscription = null;
    _busSubscriptions.forEach((key, value) {
      value.cancel();
    });
    _busSubscriptions.clear();
    _busLocations.clear();
  }

  Future<void> initializeOfflineMode() async {
    try {
      final offlineService = OfflineService();
      _offlineMapData = await offlineService.getOfflineMapRegion();
      
      if (_offlineMapData != null) {
        _isOfflineMode = true;
        notifyListeners();
      }
    } catch (e) {
      print('Error initializing offline mode: $e');
    }
  }

  /// Get the current map style string based on mode
  String get mapStyleString {
    if (_isOfflineMode) {
      return 'asset://assets/offline_map.json';
    } else {
      return '''
      {
        "version": 8,
        "sources": {
          "ola-raster": {
            "type": "raster",
            "tiles": [
              "https://api.olamaps.io/tiles/raster/v1/styles/default/{z}/{x}/{y}?api_key=u8bxvlb9ubgP2wKgJyxEY2ya1hYNcvyxFDCpA85y"
            ],
            "tileSize": 256,
            "maxzoom": 19,
            "attribution": "© Ola Maps"
          }
        },
        "layers": [
          {
            "id": "ola-raster-layer",
            "type": "raster",
            "source": "ola-raster"
          }
        ]
      }
      ''';
    }
  }

  Future<void> switchToOfflineMode() async {
    if (_offlineMapData == null) {
      throw Exception('No offline map data available');
    }

    _isOfflineMode = true;
    notifyListeners();
  }

  Future<void> switchToOnlineMode() async {
    _isOfflineMode = false;
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> getOfflineRoutes() async {
    try {
      final offlineService = OfflineService();
      return await offlineService.getCachedRoutes();
    } catch (e) {
      print('Error getting offline routes: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getOfflineEmergencyContacts() async {
    try {
      final offlineService = OfflineService();
      return await offlineService.getEmergencyContacts();
    } catch (e) {
      print('Error getting offline emergency contacts: $e');
      return [];
    }
  }

  Future<void> updateNavigationFeatures(LatLng currentLocation) async {
    if (_mapController == null || _navigationService == null) return;

    // TODO: Convert navigation service to use MapLibre LatLng
    // const double searchRadius = 1000.0; // 1km radius for navigation features
    // await _navigationService?.fetchTrafficData(currentLocation, searchRadius);
    // await _navigationService?.fetchRoadWorkAlerts(currentLocation, searchRadius);
    // await _navigationService?.fetchSpeedCameras(currentLocation, searchRadius);
    // await _navigationService?.fetchSchoolZones(currentLocation, searchRadius);

    // Update the map with the new navigation features
    notifyListeners();
  }

  void updateLaneGuidance(Map<String, dynamic> guidance) {
    _navigationService?.updateLaneGuidance(guidance);
    notifyListeners();
  }

  void clearNavigationData() {
    _navigationService?.clearNavigationData();
    notifyListeners();
  }
}


