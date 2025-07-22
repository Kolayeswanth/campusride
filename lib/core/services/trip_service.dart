import 'dart:async';
import 'dart:convert';
import 'dart:math' show sin, cos, pi, atan2;
import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:http/http.dart' as http;
import 'geocoding_service.dart';
import '../constants/map_constants.dart';

class DriverTrip {
  String id;
  String driverId;
  String routeId;
  String? busNumber;
  DateTime startTime;
  DateTime? endTime;
  String status; // 'active', 'completed', 'cancelled'
  Map<String, dynamic>? startLocation;
  Map<String, dynamic>? endLocation;
  double? actualDistanceKm;
  int? actualDurationMinutes;

  DriverTrip({
    required this.id,
    required this.driverId,
    required this.routeId,
    this.busNumber,
    required this.startTime,
    this.endTime,
    this.status = 'active',
    this.startLocation,
    this.endLocation,
    this.actualDistanceKm,
    this.actualDurationMinutes,
  });

  factory DriverTrip.fromJson(Map<String, dynamic> json) {
    return DriverTrip(
      id: json['id'] as String,
      driverId: json['driver_id'] as String,
      routeId: json['route_id'] as String,
      busNumber: json['bus_number'] as String?,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time'] as String) : null,
      status: json['status'] as String? ?? 'active',
      startLocation: json['start_location'] as Map<String, dynamic>?,
      endLocation: json['end_location'] as Map<String, dynamic>?,
      actualDistanceKm: (json['actual_distance_km'] as num?)?.toDouble(),
      actualDurationMinutes: json['actual_duration_minutes'] as int?,
    );
  }
}

class BusRoute {
  String id;
  String name;
  String? busNumber;
  String? description;
  latlong2.LatLng startLocation;
  latlong2.LatLng endLocation;
  String startLocationName;
  String endLocationName;
  double? distanceKm;
  int? estimatedDurationMinutes;
  String? collegeId;
  bool isActive;
  bool isInUseByOther;

  BusRoute({
    required this.id,
    required this.name,
    this.busNumber,
    this.description,
    required this.startLocation,
    required this.endLocation,
    required this.startLocationName,
    required this.endLocationName,
    this.distanceKm,
    this.estimatedDurationMinutes,
    this.collegeId,
    this.isActive = true,
    this.isInUseByOther = false,
  });

  factory BusRoute.fromJson(Map<String, dynamic> json) {
    // Handle different location field formats
    double startLat = 0.0;
    double startLng = 0.0;
    double endLat = 0.0;
    double endLng = 0.0;
    String startName = '';
    String endName = '';

    // Handle start_location
    if (json['start_location'] is Map) {
      final startLoc = json['start_location'] as Map<String, dynamic>;
      startLat = (startLoc['latitude'] as num?)?.toDouble() ?? 0.0;
      startLng = (startLoc['longitude'] as num?)?.toDouble() ?? 0.0;
      startName = startLoc['name'] as String? ?? '';
    } else {
      startLat = (json['start_latitude'] as num?)?.toDouble() ?? 0.0;
      startLng = (json['start_longitude'] as num?)?.toDouble() ?? 0.0;
      startName = json['start_location'] as String? ?? '';
    }

    // Handle end_location
    if (json['end_location'] is Map) {
      final endLoc = json['end_location'] as Map<String, dynamic>;
      endLat = (endLoc['latitude'] as num?)?.toDouble() ?? 0.0;
      endLng = (endLoc['longitude'] as num?)?.toDouble() ?? 0.0;
      endName = endLoc['name'] as String? ?? '';
    } else {
      endLat = (json['end_latitude'] as num?)?.toDouble() ?? 0.0;
      endLng = (json['end_longitude'] as num?)?.toDouble() ?? 0.0;
      endName = json['end_location'] as String? ?? '';
    }

    return BusRoute(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? json['bus_number'] as String? ?? '',
      busNumber: json['bus_number'] as String? ?? json['name'] as String?,
      description: json['description'] as String?,
      startLocation: latlong2.LatLng(startLat, startLng),
      endLocation: latlong2.LatLng(endLat, endLng),
      startLocationName: startName,
      endLocationName: endName,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      estimatedDurationMinutes: json['estimated_duration_minutes'] as int?,
      collegeId: json['college_id'] as String? ?? json['college_code'] as String?,
      isActive: json['is_active'] as bool? ?? json['active'] as bool? ?? true,
    );
  }

  String get displayName => busNumber ?? name;
  
  String get formattedDistance => distanceKm != null 
      ? '${distanceKm!.toStringAsFixed(1)} km' 
      : 'Distance not set';
  
  String get formattedDuration => estimatedDurationMinutes != null 
      ? '${estimatedDurationMinutes} min' 
      : 'Time not set';
}

class TripService with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final GeocodingService _geocodingService = GeocodingService();
  List<BusRoute> _routes = [];
  BusRoute? _selectedRoute;
  latlong2.LatLng? _currentLocation;
  bool _isTracking = false;
  String? _error;
  StreamSubscription<Position>? _positionSubscription;
  String? _lastCrossedVillage;
  bool _showVillageNotification = false;
  String? _villageNotificationMessage;
  Timer? _notificationTimer;
  final Set<String> _crossedVillages = {}; // Track crossed villages to prevent duplicates
  
  // Real-time subscription for trip updates
  StreamSubscription? _tripUpdatesSubscription;

  // List to store trip history
  final List<dynamic> _tripHistory = [];
  
  // Location tracking for navigation
  final List<latlong2.LatLng> _locationHistory = [];
  int _maxLocationHistorySize = 20; // Keep last 20 locations for path analysis
  latlong2.LatLng? _previousLocation;
  double? _currentHeading;
  bool _isOffRoute = false;
  
  // Cache management
  bool _routesLoaded = false;
  String? _lastCollegeId;
  DateTime? _lastRoutesFetchTime;
  
  // Constructor to set up real-time listeners
  TripService() {
    _setupTripUpdatesListener();
  }
  
  /// Set up real-time listener for trip updates
  void _setupTripUpdatesListener() {
    _tripUpdatesSubscription = _supabase
        .from('driver_trips')
        .stream(primaryKey: ['id'])
        .eq('status', 'completed')
        .listen((data) {
          _handleTripUpdate(data);
        });
  }
  
  /// Handle real-time trip updates
  void _handleTripUpdate(List<Map<String, dynamic>> updates) {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null || _currentTrip == null) return;
    
    for (final update in updates) {
      final tripId = update['id'] as String?;
      final driverId = update['driver_id'] as String?;
      final status = update['status'] as String?;
      
      // If current user's trip was completed externally
      if (tripId == _currentTrip!.id && 
          driverId == currentUser.id && 
          status == 'completed') {
        
        _handleExternalTripStop();
        break;
      }
    }
  }
  
  /// Handle when trip is stopped externally (e.g., by admin)
  Future<void> _handleExternalTripStop() async {
    try {
      
      
      // Stop location sharing
      await _stopLiveLocationSharing();
      
      // Clear local state
      _currentTrip = null;
      _currentTripPolyline.clear();
      _plannedRoutePolyline.clear();
      _isLiveLocationSharing = false;
      
      // Notify listeners
      notifyListeners();
      
      
    } catch (e) {
      
    }
  }
  
  List<BusRoute> get routes => _routes;
  BusRoute? get selectedRoute => _selectedRoute;
  latlong2.LatLng? get currentLocation => _currentLocation;
  latlong2.LatLng? get previousLocation => _previousLocation;
  bool get isTracking => _isTracking;
  String? get error => _error;
  Map<String, String> get crossedVillages => _geocodingService.crossedVillages;
  bool get showVillageNotification => _showVillageNotification;
  String? get villageNotificationMessage => _villageNotificationMessage;
  List<latlong2.LatLng> get locationHistory => _locationHistory;
  double? get currentHeading => _currentHeading;
  bool get isOffRoute => _isOffRoute;

  // Getter for trip history
  List<dynamic> get tripHistory => _tripHistory;

  Future<void> loadRoutes() async {
    try {
      final response = await _supabase.from('routes').select('*');
      _routes = response.map((e) => BusRoute.fromJson(e)).toList();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load routes: $e';
      notifyListeners();
    }
  }

  void selectRoute(BusRoute route) {
    _selectedRoute = route;
    notifyListeners();
  }

  Future<void> startTripTracking() async {
    if (_isTracking) return;

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied) {
          throw Exception('Location permissions are required');
        }
      }

      // Clear previous crossed villages when starting a new trip
      _geocodingService.clearCrossedVillages();
      _lastCrossedVillage = null;
      _showVillageNotification = false;
      _villageNotificationMessage = null;

      _isTracking = true;
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((Position position) async {
        // Store previous location before updating current
        if (_currentLocation != null) {
          _previousLocation = _currentLocation;
        }
        
        _currentLocation = latlong2.LatLng(position.latitude, position.longitude);
        
        // Add to location history for path tracking
        if (_currentLocation != null) {
          _locationHistory.add(_currentLocation!);
          
          // Limit the history size to avoid memory issues
          if (_locationHistory.length > _maxLocationHistorySize) {
            _locationHistory.removeAt(0);
          }
          
          // Calculate heading from movement direction if we have previous location
          if (_previousLocation != null) {
            _currentHeading = _calculateHeading(_previousLocation!, _currentLocation!);
          } else {
            // Try to use device compass heading if available
            try {
              _currentHeading = position.heading;
            } catch (e) {
              // Default heading if all else fails
              _currentHeading = 0.0;
            }
          }
          
          // Add to current trip polyline for route tracking
          if (_isTracking && _currentTrip != null) {
            _currentTripPolyline.add(_currentLocation!);
          }
        }
        
        // Update location in database
        await _updateLocationInSupabase();
        
        // Check if we've crossed a new village
        await _checkForCrossedVillage();
        
        notifyListeners();
      });
    } catch (e) {
      _error = 'Failed to start trip tracking: $e';
      _isTracking = false;
      notifyListeners();
    }
  }
  
  /// Check if we've crossed a new village and show notification
  Future<void> _checkForCrossedVillage() async {
    if (_currentLocation == null) return;
    
    try {
    final villageName = await _geocodingService.checkCrossedVillage(
      latlong2.LatLng(_currentLocation!.latitude, _currentLocation!.longitude)
    );
    
      if (villageName != null && 
          villageName != _lastCrossedVillage && 
          !_crossedVillages.contains(villageName)) {
        
        // Get the village center
        final villageCenter = await _geocodingService.getVillageCenter(villageName);
        
        // Calculate distance to village center
        final distance = const latlong2.Distance().distance(
          _currentLocation!,
          villageCenter,
        );
        
        // Only show notification if we're actually crossing the village
        // (i.e., we're within the detection radius)
        if (distance <= MapConstants.villageDetectionRadius) {
      _lastCrossedVillage = villageName;
          _crossedVillages.add(villageName);
      
      // Get the current time for the notification
      final now = DateTime.now();
      final formattedTime = '${_formatHour(now.hour)}:${_formatMinute(now.minute)} ${now.hour >= 12 ? 'PM' : 'AM'}';
      
      // Show notification
      _showVillageNotification = true;
      _villageNotificationMessage = '🏁 You crossed $villageName at $formattedTime.';
          
          // Store the crossed village in the database
          await _storeCrossedVillage(villageName, now);
      
      // Auto-hide notification after 5 seconds
      _notificationTimer?.cancel();
          _notificationTimer = Timer(MapConstants.notificationDuration, () {
        _showVillageNotification = false;
        notifyListeners();
      });
      
      notifyListeners();
        }
      }
    } catch (e) {
      
    }
  }
  
  /// Format hour to ensure 12-hour format
  String _formatHour(int hour) {
    final h = hour > 12 ? hour - 12 : hour;
    return h.toString().padLeft(2, '0');
  }
  
  /// Format minute to ensure two digits
  String _formatMinute(int minute) {
    return minute.toString().padLeft(2, '0');
  }

  Future<void> _updateLocationInSupabase() async {
    try {
      await _supabase.from('trip_locations').upsert({
        'trip_id': 'your_trip_id',
        'latitude': _currentLocation!.latitude,
        'longitude': _currentLocation!.longitude,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _error = 'Failed to update location: $e';
      notifyListeners();
    }
  }

  Future<void> stopTripTracking() async {
    _isTracking = false;
    await _positionSubscription?.cancel();
    _notificationTimer?.cancel();
    _showVillageNotification = false;
    notifyListeners();
  }
  
  /// Dismiss the village notification manually
  void dismissVillageNotification() {
    _showVillageNotification = false;
    _notificationTimer?.cancel();
    notifyListeners();
  }

  Future<List<latlong2.LatLng>> calculateRoute(
      latlong2.LatLng start, latlong2.LatLng end) async {
    try {
      final orsApiKey = dotenv.env['ORS_API_KEY'] ?? '5b3ce3597851110001cf6248a0ac0e4cb1ac489fa0857d1c6fc7203e';
      
      const url = 'https://api.openrouteservice.org/v2/directions/driving-car';
      final body = {
        'coordinates': [
          [start.longitude, start.latitude],
          [end.longitude, end.latitude]
        ],
        'preference': 'recommended',
        'instructions': true,
        'geometry_simplify': false,
        'format': 'geojson',
        'elevation': false,
        'maneuvers': true,
        'radiuses': [5000, 5000],
        'continue_straight': false,
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': orsApiKey,
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coordinates = data['features'][0]['geometry']['coordinates'];
        
        // Convert coordinates to LatLng objects
        final routePoints = coordinates
            .map<latlong2.LatLng>((coord) => latlong2.LatLng(coord[1], coord[0]))
            .toList();
            
        // Route calculated successfully
        notifyListeners();
        
        return routePoints;
      } else {
        
        return _addIntermediatePoints(start, end);
      }
    } catch (e) {
      _error = 'Failed to calculate route: $e';
      notifyListeners();
      return _addIntermediatePoints(start, end);
    }
  }
  
  /// Add intermediate points between start and end to create a more natural-looking route
  /// This is a fallback method when the routing API fails
  List<latlong2.LatLng> _addIntermediatePoints(latlong2.LatLng start, latlong2.LatLng end) {
    final points = <latlong2.LatLng>[];
    points.add(start);
    
    // Calculate distance between points
    final distance = const latlong2.Distance().distance(start, end);
    
    // Add more points for longer distances
    final numPoints = (distance / 500).ceil(); // One point every 500 meters
    
    if (numPoints > 1) {
      for (int i = 1; i < numPoints; i++) {
        // Calculate intermediate point with slight randomness to simulate road curves
        final ratio = i / numPoints;
        final lat = start.latitude + (end.latitude - start.latitude) * ratio;
        final lng = start.longitude + (end.longitude - start.longitude) * ratio;
        
        // Add some randomness to simulate roads (not straight lines)
        final randomFactor = 0.0005 * sin(i * pi / numPoints); // Small random offset
        final offsetLat = lat + randomFactor * cos(i.toDouble());
        final offsetLng = lng + randomFactor * sin(i.toDouble());
        
        points.add(latlong2.LatLng(offsetLat, offsetLng));
      }
    }
    
    points.add(end);
    return points;
  }
  
  /// Fetch route information including stops
  Future<Map<String, dynamic>?> fetchRouteInfo(String routeId) async {
    try {
      // Fetch route details from Supabase
      final routeResponse = await _supabase
          .from('routes')
          .select('*')
          .eq('id', routeId)
          .single();
      
      // Fetch stops for this route
      final stopsResponse = await _supabase
          .from('route_stops')
          .select('*')
          .eq('route_id', routeId)
          .order('sequence_number');
      
      // Combine the data
      final routeInfo = {
        ...routeResponse,
        'stops': stopsResponse,
      };
      
      return routeInfo;
    } catch (e) {
      _error = 'Failed to fetch route info: $e';
      notifyListeners();
      return null;
    }
  }
  
  /// Search for buses by route name or bus ID
  Future<List<Map<String, dynamic>>> searchBuses(String query) async {
    try {
      // Search in active_trips table
      final response = await _supabase
          .from('active_trips')
          .select('*, routes!inner(*)')
          .or('bus_id.ilike.%$query%, routes.name.ilike.%$query%');
      
      // Format the results
      return response.map<Map<String, dynamic>>((trip) {
        return {
          'bus_id': trip['bus_id'],
          'route_id': trip['route_id'],
          'route_name': trip['routes']['name'],
          'is_active': trip['is_active'] ?? true,
          'last_updated': trip['last_updated'],
        };
      }).toList();
    } catch (e) {
      _error = 'Failed to search buses: $e';
      notifyListeners();
      return [];
    }
  }

  /// Update bus location in the database
  Future<void> updateBusLocation(
    String busId,
    double latitude,
    double longitude,
    double? heading,
    double? speed,
  ) async {
    try {
      await _supabase.from('trip_locations').insert({
        'trip_id': busId,
        'latitude': latitude,
        'longitude': longitude,
        'heading': heading,
        'speed': speed,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _error = 'Failed to update bus location: $e';
      notifyListeners();
    }
  }

  Future<void> _storeCrossedVillage(String villageName, DateTime timestamp) async {
    try {
      await _supabase.from('crossed_villages').insert({
        'trip_id': 'your_trip_id', // Replace with actual trip ID
        'village_name': villageName,
        'timestamp': timestamp.toIso8601String(),
        'latitude': _currentLocation!.latitude,
        'longitude': _currentLocation!.longitude,
      });
    } catch (e) {
      
    }
  }

  /// Get the village name for a given location
  Future<String?> getVillageName(latlong2.LatLng location) async {
    try {
      // Use the GeocodingService to get the village name
      final villageName = await _geocodingService.getVillageName(location);
      
      if (villageName != null) {
        // Get the village center
        final villageCenter = await _geocodingService.getVillageCenter(villageName);
        
        // Calculate distance to village center
        final distance = const latlong2.Distance().distance(
          location,
          villageCenter,
        );
        
        // Only return village name if we're within the detection radius
        if (distance <= MapConstants.villageDetectionRadius) {
          return villageName;
        }
      }
      
      return null;
    } catch (e) {
      
      return null;
    }
  }

  /// Get all crossed villages for a trip
  Future<List<Map<String, dynamic>>> getCrossedVillages(String tripId) async {
    try {
      final response = await _supabase
          .from('crossed_villages')
          .select('*')
          .eq('trip_id', tripId)
          .order('timestamp', ascending: false);
      
      return response.map<Map<String, dynamic>>((village) {
        return {
          'village_name': village['village_name'],
          'timestamp': DateTime.parse(village['timestamp']),
          'latitude': village['latitude'],
          'longitude': village['longitude'],
        };
      }).toList();
    } catch (e) {
      
      return [];
    }
  }

  /// Get the village center coordinates
  Future<latlong2.LatLng?> getVillageCenter(String villageName) async {
    try {
      return await _geocodingService.getVillageCenter(villageName);
    } catch (e) {
      
      return null;
    }
  }

  /// Store crossed village information
  Future<void> storeCrossedVillage(String villageName, DateTime timestamp) async {
    try {
      await _supabase.from('crossed_villages').insert({
        'trip_id': 'your_trip_id', // Replace with actual trip ID
        'village_name': villageName,
        'timestamp': timestamp.toIso8601String(),
        'latitude': _currentLocation!.latitude,
        'longitude': _currentLocation!.longitude,
      });
    } catch (e) {
      
    }
  }

  @override
  void dispose() {
    _crossedVillages.clear();
    _notificationTimer?.cancel();
    _tripUpdatesSubscription?.cancel();
    super.dispose();
  }

  /// Mark routes that are currently in use by other drivers
  Future<List<BusRoute>> _markRoutesInUse(List<BusRoute> allRoutes) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return allRoutes;

      // Get all active trips
      final activeTripsResponse = await _supabase
          .from('driver_trips')
          .select('route_id, driver_id')
          .eq('status', 'active');

      final Set<String> routesInUseByOthers = {};
      final Set<String> routesInUseByCurrentDriver = {};
      
      for (final trip in activeTripsResponse) {
        final routeId = trip['route_id'] as String?;
        final driverId = trip['driver_id'] as String?;
        
        if (routeId != null && driverId != null) {
          if (driverId == currentUser.id) {
            // Current driver has an active trip on this route
            routesInUseByCurrentDriver.add(routeId);
          } else {
            // Another driver is using this route
            routesInUseByOthers.add(routeId);
          }
        }
      }

      // Mark routes as in use by others (but not if current driver is using it)
      for (final route in allRoutes) {
        route.isInUseByOther = routesInUseByOthers.contains(route.id);
        
        // If current driver has an active trip on this route, check if we need to resume it
        if (routesInUseByCurrentDriver.contains(route.id) && _currentTrip == null) {
          // Driver has an active trip but it's not loaded in memory
          
        }
      }

      if (routesInUseByOthers.isNotEmpty) {
        
      }
      if (routesInUseByCurrentDriver.isNotEmpty) {
        
      }
      return allRoutes;
      
    } catch (e) {
      
      // If checking fails, return all routes as available to avoid blocking the driver
      for (final route in allRoutes) {
        route.isInUseByOther = false;
      }
      return allRoutes;
    }
  }

  Future<List<BusRoute>> fetchDriverRoutes({bool forceRefresh = false}) async {
    try {
      // Get the current user's profile to find their college
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Check if we have cached routes and don't need to refresh
      if (!forceRefresh && !shouldRefreshRoutes() && _routes.isNotEmpty) {
        // Only refresh route usage status, not the entire route list
        _refreshRouteUsageStatusFromRealtime();
        
        notifyListeners();
        return _routes;
      }

      // Get the user's profile and college information only if needed
      String? currentCollegeId;
      if (_lastCollegeId == null || forceRefresh) {
        final profileResponse = await _supabase
            .from('profiles')
            .select('college_id')
            .eq('id', currentUser.id)
            .maybeSingle();
        
        currentCollegeId = profileResponse?['college_id'] as String?;
        _lastCollegeId = currentCollegeId;
      } else {
        currentCollegeId = _lastCollegeId;
      }

      List<BusRoute> allRoutes = [];

      if (currentCollegeId == null) {
        
        final response = await _supabase.from('routes').select('*').order('name');
        allRoutes = response.map((e) => BusRoute.fromJson(e)).toList();
      } else {
        try {
          // First get the college code from the college ID
          final collegeResponse = await _supabase
              .from('colleges')
              .select('code')
              .eq('id', currentCollegeId)
              .maybeSingle();
          
          if (collegeResponse != null && collegeResponse['code'] != null) {
            final collegeCode = collegeResponse['code'] as String;
            
            // Now fetch routes using the college code
            var response = await _supabase
                .from('routes')
                .select('*')
                .eq('college_code', collegeCode)
                .order('name');
            
            allRoutes = response.map((e) => BusRoute.fromJson(e)).toList();
            
          } else {
            
            final response = await _supabase.from('routes').select('*').order('name');
            allRoutes = response.map((e) => BusRoute.fromJson(e)).toList();
          }
        } catch (e) {
          
          final response = await _supabase.from('routes').select('*').order('name');
          allRoutes = response.map((e) => BusRoute.fromJson(e)).toList();
        }
      }
      
      // Mark routes that are currently in use by other drivers
      _routes = await _markRoutesInUse(allRoutes);
      _routesLoaded = true;
      _lastRoutesFetchTime = DateTime.now();
      
      
      notifyListeners();
      return _routes;
    } catch (e) {
      _error = 'Failed to fetch driver routes: $e';
      
      notifyListeners();
      return [];
    }
  }

  /// Refresh route usage status using real-time data (no database polling)
  void _refreshRouteUsageStatusFromRealtime() {
    if (_routes.isEmpty) return;
    
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;

      // Get real-time data from RealtimeService instead of database polling
      final realtimeService = _getRealtimeService();
      if (realtimeService == null) {
        
        return;
      }

      final routesInUseByOthers = <String>{};
      
      // Use cached real-time data instead of database query
      for (final trip in realtimeService.activeTrips.values) {
        final routeId = trip['route_id'] as String?;
        final driverId = trip['driver_id'] as String?;
        
        // If route is being used by another driver, mark it as in use
        if (routeId != null && driverId != null && driverId != currentUser.id) {
          routesInUseByOthers.add(routeId);
        }
      }

      // Update existing routes usage status
      for (final route in _routes) {
        route.isInUseByOther = routesInUseByOthers.contains(route.id);
      }

      if (routesInUseByOthers.isNotEmpty) {
        
      }
    } catch (e) {
      
    }
  }

  /// Get RealtimeService instance (implement this based on your dependency injection)
  dynamic _getRealtimeService() {
    // You'll need to inject this service or access it through your service locator
    // This is a placeholder - implement based on your architecture
    return null;
  }

  // Driver trip management
  DriverTrip? _currentTrip;
  List<DriverTrip> _driverTripHistory = [];
  List<latlong2.LatLng> _currentTripPolyline = [];
  List<latlong2.LatLng> _plannedRoutePolyline = [];
  bool _isLiveLocationSharing = false;

  DriverTrip? get currentTrip => _currentTrip;
  List<DriverTrip> get driverTripHistory => _driverTripHistory;
  List<latlong2.LatLng> get currentTripPolyline => _currentTripPolyline;
  bool get isLiveLocationSharing => _isLiveLocationSharing;

  /// Validate and convert route ID to proper format for database
  String _validateRouteId(String routeId) {
    // Check if it's already a valid UUID
    final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
    
    if (uuidRegex.hasMatch(routeId)) {
      // Already a valid UUID
      
      return routeId;
    }
    
    // If it's an invalid string ID, allow it for now but log a warning
    
    return routeId;
  }

  /// Check if a route is currently being used by another driver
  Future<bool> _isRouteCurrentlyInUse(String routeId) async {
    try {
      final response = await _supabase
          .from('driver_trips')
          .select('id, driver_id')
          .eq('route_id', routeId)
          .eq('status', 'active');
      
      if (response.isEmpty) return false;
      
      // Check if the active trip belongs to current user
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return true;
      
      final activeTrip = response.first;
      return activeTrip['driver_id'] != currentUser.id;
    } catch (e) {
      
      return false; // If check fails, allow the trip to proceed
    }
  }

  /// Start a new driver trip or resume existing one
  Future<DriverTrip?> startDriverTrip({
    required String routeId,
    String? busNumber, // Made optional
    required BusRoute route,
  }) async {
    try {
      
      
      
      
      
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // First check if this driver already has an active trip on this route
      final existingTrip = await getDriverActiveTrip(routeId);
      if (existingTrip != null) {
        
        // Resume the existing trip instead of creating a new one
        final resumed = await resumeActiveTrip(existingTrip, route);
        if (resumed) {
          return existingTrip;
        } else {
          throw Exception('Failed to resume existing trip. Please try again.');
        }
      }

      // Check if route is already in use by another driver
      final isRouteInUse = await _isRouteCurrentlyInUse(routeId);
      if (isRouteInUse) {
        throw Exception('This route is currently being used by another driver. Please select a different route.');
      }

      // Get current location with proper timeout
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 15), // Proper timeout for GPS
      );
      final startLocation = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'name': 'Trip Start',
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Generate bus number if not provided
      final finalBusNumber = busNumber ?? 'AUTO-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      // For backward compatibility with string route IDs, use routeId as-is
      // The database column should be TEXT type to accept both UUIDs and strings
      final response = await _supabase.from('driver_trips').insert({
        'driver_id': currentUser.id,
        'route_id': routeId, // Use original routeId for backward compatibility
        'bus_number': finalBusNumber,
        'start_location': startLocation,
        'status': 'active',
      }).select().single();

      _currentTrip = DriverTrip.fromJson(response);
      
      // Calculate planned route polyline
      _plannedRoutePolyline = await calculateRoute(route.startLocation, route.endLocation);
      
      // Start live location sharing
      await _startLiveLocationSharing();
      
      
      notifyListeners();
      return _currentTrip;
    } catch (e) {
      _error = 'Failed to start trip: $e';
      
      notifyListeners();
      return null;
    }
  }

  /// End the current driver trip
  Future<bool> endDriverTrip() async {
    if (_currentTrip == null) return false;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 15), // Proper timeout for GPS
      );
      final endLocation = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'name': 'Trip End',
        'timestamp': DateTime.now().toIso8601String(),
      };

      final duration = DateTime.now().difference(_currentTrip!.startTime).inMinutes;
      final distance = _calculateTotalDistance();

      // Update trip record
      await _supabase.from('driver_trips').update({
        'end_location': endLocation,
        'end_time': DateTime.now().toIso8601String(),
        'status': 'completed',
        'actual_distance_km': distance,
        'actual_duration_minutes': duration,
      }).eq('id', _currentTrip!.id);

      // Store trip polyline
      await _storeTripPolyline();

      // Stop live location sharing
      await _stopLiveLocationSharing();

      // Add to history
      _driverTripHistory.insert(0, _currentTrip!);
      _currentTrip = null;
      _currentTripPolyline.clear();
      _plannedRoutePolyline.clear();

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to end trip: $e';
      
      notifyListeners();
      return false;
    }
  }

  /// Start sharing live location
  Future<void> _startLiveLocationSharing() async {
    if (_isLiveLocationSharing) {
      
      return;
    }

    try {
      // Check location permissions
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied) {
          throw Exception('Location permissions are denied and are required for live tracking');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied. Please enable them in settings.');
      }

      _isLiveLocationSharing = true;
      _currentTripPolyline.clear();
      
      
      // Start location tracking with more frequent updates for live sharing
      _positionSubscription?.cancel();
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5, // Update every 5 meters
        ),
      ).listen(
        (Position position) async {
          if (_currentTrip != null && _isLiveLocationSharing) {
            _currentLocation = latlong2.LatLng(position.latitude, position.longitude);
            
            // Add to current trip polyline
            _currentTripPolyline.add(_currentLocation!);
            
            // Store location in database
            await _storeTripLocation(position);
            
            // Check if driver is on route
            await _checkRouteDeviation();
            
            notifyListeners();
          }
        },
        onError: (error) {
          
          _error = 'Error tracking location: $error';
          notifyListeners();
        },
        cancelOnError: false,
      );
    } catch (e) {
      _isLiveLocationSharing = false;
      _error = 'Failed to start live location sharing: $e';
      
      notifyListeners();
      throw e;
    }
  }

  /// Stop sharing live location
  Future<void> _stopLiveLocationSharing() async {
    if (!_isLiveLocationSharing) {
      
      return;
    }

    try {
      
      
      _isLiveLocationSharing = false;
      await _positionSubscription?.cancel();
      _positionSubscription = null;
      _currentLocation = null;
      
      
      notifyListeners();
    } catch (e) {
      
      _error = 'Error stopping live location sharing: $e';
      notifyListeners();
    }
  }

  /// Store trip location in database
  Future<void> _storeTripLocation(Position position) async {
    if (_currentTrip == null) return;

    try {
      
      
      await _supabase.from('driver_trip_locations').insert({
        'trip_id': _currentTrip!.id,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'heading': position.heading,
        'speed': position.speed * 3.6, // Convert m/s to km/h
        'accuracy': position.accuracy,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      
    } catch (e) {
      
    }
  }

  /// Check if driver deviated from planned route
  Future<void> _checkRouteDeviation() async {
    if (_currentLocation == null || _plannedRoutePolyline.isEmpty) return;

    // Find the closest point on planned route
    double minDistance = double.infinity;
    for (final point in _plannedRoutePolyline) {
      final distance = const latlong2.Distance().distance(_currentLocation!, point);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    // If driver is more than 100 meters from planned route, create deviation polyline
    const deviationThreshold = 100.0; // meters
    if (minDistance > deviationThreshold) {
      await _handleRouteDeviation();
    }
  }

  /// Handle route deviation by merging with nearest point
  Future<void> _handleRouteDeviation() async {
    if (_currentLocation == null || _plannedRoutePolyline.isEmpty) return;

    try {
      // Find the nearest point on the planned route
      latlong2.LatLng? nearestPoint;
      double minDistance = double.infinity;
      
      for (final point in _plannedRoutePolyline) {
        final distance = const latlong2.Distance().distance(_currentLocation!, point);
        if (distance < minDistance) {
          minDistance = distance;
          nearestPoint = point;
        }
      }

      if (nearestPoint != null) {
        // Calculate route from current location to nearest point on planned route
        final deviationRoute = await calculateRoute(_currentLocation!, nearestPoint);
        
        // Store deviation polyline
        await _supabase.from('driver_trip_polylines').insert({
          'trip_id': _currentTrip!.id,
          'polyline_data': deviationRoute.map((point) => {
            'latitude': point.latitude,
            'longitude': point.longitude,
            'timestamp': DateTime.now().toIso8601String(),
          }).toList(),
          'is_deviation': true,
          'merged_with_planned_route': true,
        });
      }
    } catch (e) {
      
    }
  }

  /// Store trip polyline data
  Future<void> _storeTripPolyline() async {
    if (_currentTrip == null || _currentTripPolyline.isEmpty) return;

    try {
      await _supabase.from('driver_trip_polylines').insert({
        'trip_id': _currentTrip!.id,
        'polyline_data': _currentTripPolyline.map((point) => {
          'latitude': point.latitude,
          'longitude': point.longitude,
          'timestamp': DateTime.now().toIso8601String(),
        }).toList(),
        'is_deviation': false,
      });
    } catch (e) {
      
    }
  }

  /// Calculate total distance of current trip
  double _calculateTotalDistance() {
    if (_currentTripPolyline.length < 2) return 0.0;

    double totalDistance = 0.0;
    for (int i = 1; i < _currentTripPolyline.length; i++) {
      final distance = const latlong2.Distance().distance(
        _currentTripPolyline[i - 1],
        _currentTripPolyline[i],
      );
      totalDistance += distance;
    }
    
    return totalDistance / 1000; // Convert to kilometers
  }

  /// Fetch driver trip history
  Future<void> fetchDriverTripHistory() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;

      final response = await _supabase
          .from('driver_trips')
          .select('*')
          .eq('driver_id', currentUser.id)
          .order('start_time', ascending: false)
          .limit(50);

      _driverTripHistory = response.map((e) => DriverTrip.fromJson(e)).toList();
      notifyListeners();
    } catch (e) {
      
    }
  }

  /// Get trip details with polyline data
  Future<Map<String, dynamic>?> getTripDetails(String tripId) async {
    try {
      final tripResponse = await _supabase
          .from('driver_trips')
          .select('*')
          .eq('id', tripId)
          .single();

      final polylineResponse = await _supabase
          .from('driver_trip_polylines')
          .select('*')
          .eq('trip_id', tripId);

      final locationsResponse = await _supabase
          .from('driver_trip_locations')
          .select('*')
          .eq('trip_id', tripId)
          .order('timestamp');

      return {
        'trip': tripResponse,
        'polylines': polylineResponse,
        'locations': locationsResponse,
      };
    } catch (e) {
      
      return null;
    }
  }

  /// Get driver trip history (fetches fresh data)
  Future<List<DriverTrip>> getTripHistory() async {
    await fetchDriverTripHistory();
    return driverTripHistory;
  }

  /// Get a specific route by ID from cached routes
  BusRoute? getRouteById(String routeId) {
    try {
      return _routes.firstWhere((route) => route.id == routeId);
    } catch (e) {
      
      return null;
    }
  }

  /// Force refresh routes (for pull-to-refresh scenarios)
  Future<List<BusRoute>> refreshRoutes() async {
    _routesLoaded = false;
    return await fetchDriverRoutes(forceRefresh: true);
  }

  /// Clear cache when user logs out or switches context
  void clearRouteCache() {
    _routes.clear();
    _routesLoaded = false;
    _lastCollegeId = null;
    _lastRoutesFetchTime = null;
    
  }

  /// Check if routes need to be refreshed due to user change or cache expiration
  bool shouldRefreshRoutes() {
    // Always refresh if not loaded yet
    if (!_routesLoaded) return true;
    
    // Check if user changed
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return true;
    
    // Check cache age (refresh after 5 minutes)
    if (_lastRoutesFetchTime != null) {
      final cacheAge = DateTime.now().difference(_lastRoutesFetchTime!);
      if (cacheAge.inMinutes > 5) {
        
        return true;
      }
    }
    
    return false;
  }

  /// Stop all ongoing rides in the system (admin function)
  Future<Map<String, dynamic>> stopAllOngoingRides({String reason = 'System maintenance'}) async {
    try {
      final endTime = DateTime.now();
      
      // Get all active trips
      final activeTripsResponse = await _supabase
          .from('driver_trips')
          .select('id, driver_id, route_id, start_time, bus_number')
          .eq('status', 'active');

      if (activeTripsResponse.isEmpty) {
        return {
          'success': true,
          'message': 'No active trips found',
          'stopped_trips': 0,
          'details': [],
        };
      }

      List<Map<String, dynamic>> stoppedTrips = [];
      int successCount = 0;
      int errorCount = 0;
      List<String> errors = [];

      for (final trip in activeTripsResponse) {
        try {
          final tripId = trip['id'] as String;
          final driverId = trip['driver_id'] as String;
          final routeId = trip['route_id'] as String;
          final busNumber = trip['bus_number'] as String?;
          final startTime = DateTime.parse(trip['start_time'] as String);
          
          // Calculate duration
          final duration = endTime.difference(startTime).inMinutes;

          // Create end location (use a default location or try to get last known location)
          Map<String, dynamic> endLocation = {
            'latitude': 0.0,
            'longitude': 0.0,
            'name': 'System Stop - $reason',
            'timestamp': endTime.toIso8601String(),
          };

          // Try to get the last known location for this trip
          try {
            final lastLocationResponse = await _supabase
                .from('driver_trip_locations')
                .select('latitude, longitude')
                .eq('trip_id', tripId)
                .order('timestamp', ascending: false)
                .limit(1)
                .maybeSingle();

            if (lastLocationResponse != null) {
              endLocation = {
                'latitude': lastLocationResponse['latitude'],
                'longitude': lastLocationResponse['longitude'],
                'name': 'Last Known Location - System Stop',
                'timestamp': endTime.toIso8601String(),
              };
            }
          } catch (e) {
            
            // Continue with default location
          }

          // Update trip to completed status
          await _supabase.from('driver_trips').update({
            'end_location': endLocation,
            'end_time': endTime.toIso8601String(),
            'status': 'completed',
            'actual_duration_minutes': duration,
          }).eq('id', tripId);

          // Add to stopped trips list
          stoppedTrips.add({
            'trip_id': tripId,
            'driver_id': driverId,
            'route_id': routeId,
            'bus_number': busNumber,
            'duration_minutes': duration,
            'stopped_at': endTime.toIso8601String(),
          });

          successCount++;
          

        } catch (e) {
          errorCount++;
          errors.add('Failed to stop trip ${trip['id']}: $e');
          
        }
      }

      // If current user has an active trip, update the local state
      final currentUser = _supabase.auth.currentUser;
      if (currentUser != null && _currentTrip != null) {
        final userTripStopped = stoppedTrips.any((trip) => 
          trip['driver_id'] == currentUser.id && trip['trip_id'] == _currentTrip!.id);
        
        if (userTripStopped) {
          // Stop local tracking
          await _stopLiveLocationSharing();
          
          // Update local state
          _currentTrip = null;
          _currentTripPolyline.clear();
          _plannedRoutePolyline.clear();
          _isLiveLocationSharing = false;
          
          notifyListeners();
        }
      }

      return {
        'success': true,
        'message': 'Stopped $successCount trips successfully${errorCount > 0 ? ' with $errorCount errors' : ''}',
        'stopped_trips': successCount,
        'errors': errorCount,
        'error_details': errors,
        'details': stoppedTrips,
      };

    } catch (e) {
      
      return {
        'success': false,
        'message': 'Failed to stop ongoing rides: $e',
        'stopped_trips': 0,
        'errors': 1,
        'error_details': [e.toString()],
        'details': [],
      };
    }
  }

  /// Get statistics about ongoing rides
  Future<Map<String, dynamic>> getOngoingRidesStats() async {
    try {
      final activeTripsResponse = await _supabase
          .from('driver_trips')
          .select('id, driver_id, route_id, start_time, bus_number')
          .eq('status', 'active');

      final uniqueDrivers = <String>{};
      final uniqueRoutes = <String>{};
      final tripDetails = <Map<String, dynamic>>[];

      for (final trip in activeTripsResponse) {
        uniqueDrivers.add(trip['driver_id'] as String);
        uniqueRoutes.add(trip['route_id'] as String);
        
        final startTime = DateTime.parse(trip['start_time'] as String);
        final duration = DateTime.now().difference(startTime);
        
        tripDetails.add({
          'trip_id': trip['id'],
          'driver_id': trip['driver_id'],
          'route_id': trip['route_id'],
          'bus_number': trip['bus_number'],
          'start_time': trip['start_time'],
          'duration_minutes': duration.inMinutes,
          'duration_hours': duration.inHours,
        });
      }

      return {
        'total_active_trips': activeTripsResponse.length,
        'unique_drivers': uniqueDrivers.length,
        'unique_routes': uniqueRoutes.length,
        'trip_details': tripDetails,
      };
    } catch (e) {
      
      return {
        'total_active_trips': 0,
        'unique_drivers': 0,
        'unique_routes': 0,
        'trip_details': [],
        'error': e.toString(),
      };
    }
  }

  /// Stop a specific trip by trip ID (admin function)
  Future<Map<String, dynamic>> stopSpecificTrip(String tripId, {String reason = 'Admin action'}) async {
    try {
      // Get trip details
      final tripResponse = await _supabase
          .from('driver_trips')
          .select('*')
          .eq('id', tripId)
          .eq('status', 'active')
          .maybeSingle();

      if (tripResponse == null) {
        return {
          'success': false,
          'message': 'Trip not found or already completed',
        };
      }

      final startTime = DateTime.parse(tripResponse['start_time'] as String);
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime).inMinutes;

      // Create end location
      Map<String, dynamic> endLocation = {
        'latitude': 0.0,
        'longitude': 0.0,
        'name': 'Admin Stop - $reason',
        'timestamp': endTime.toIso8601String(),
      };

      // Try to get last known location
      try {
        final lastLocationResponse = await _supabase
            .from('driver_trip_locations')
            .select('latitude, longitude')
            .eq('trip_id', tripId)
            .order('timestamp', ascending: false)
            .limit(1)
            .maybeSingle();

        if (lastLocationResponse != null) {
          endLocation = {
            'latitude': lastLocationResponse['latitude'],
            'longitude': lastLocationResponse['longitude'],
            'name': 'Last Known Location - Admin Stop',
            'timestamp': endTime.toIso8601String(),
          };
        }
      } catch (e) {
        
      }

      // Update trip status
      await _supabase.from('driver_trips').update({
        'end_location': endLocation,
        'end_time': endTime.toIso8601String(),
        'status': 'completed',
        'actual_duration_minutes': duration,
      }).eq('id', tripId);

      // If this is the current user's trip, update local state
      final currentUser = _supabase.auth.currentUser;
      if (currentUser != null && 
          _currentTrip != null && 
          _currentTrip!.id == tripId &&
          tripResponse['driver_id'] == currentUser.id) {
        
        await _stopLiveLocationSharing();
        _currentTrip = null;
        _currentTripPolyline.clear();
        _plannedRoutePolyline.clear();
        _isLiveLocationSharing = false;
        notifyListeners();
      }

      return {
        'success': true,
        'message': 'Trip stopped successfully',
        'trip_id': tripId,
        'driver_id': tripResponse['driver_id'],
        'duration_minutes': duration,
        'stopped_at': endTime.toIso8601String(),
      };

    } catch (e) {
      
      return {
        'success': false,
        'message': 'Failed to stop trip: $e',
      };
    }
  }

  /// Check if the current driver has an active trip on any route
  Future<DriverTrip?> getCurrentDriverActiveTrip() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return null;

      final response = await _supabase
          .from('driver_trips')
          .select('*')
          .eq('driver_id', currentUser.id)
          .eq('status', 'active')
          .maybeSingle();

      if (response != null) {
        final trip = DriverTrip.fromJson(response);
        
        return trip;
      }
      
      return null;
    } catch (e) {
      
      return null;
    }
  }

  /// Resume an existing active trip (when driver comes back to the app)
  Future<bool> resumeActiveTrip(DriverTrip trip, BusRoute route) async {
    try {
      
      
      // Set the current trip
      _currentTrip = trip;
      
      // Calculate planned route polyline if not already set
      if (_plannedRoutePolyline.isEmpty) {
        _plannedRoutePolyline = await calculateRoute(route.startLocation, route.endLocation);
      }
      
      // Start live location sharing if not already active
      if (!_isLiveLocationSharing) {
        await _startLiveLocationSharing();
      }
      
      
      notifyListeners();
      return true;
    } catch (e) {
      
      _error = 'Failed to resume trip: $e';
      notifyListeners();
      return false;
    }
  }

  /// Check if current driver has an active trip on a specific route
  Future<DriverTrip?> getDriverActiveTrip(String routeId) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return null;

      final response = await _supabase
          .from('driver_trips')
          .select('*')
          .eq('driver_id', currentUser.id)
          .eq('route_id', routeId)
          .eq('status', 'active')
          .maybeSingle();

      if (response != null) {
        return DriverTrip.fromJson(response);
      }
      
      return null;
    } catch (e) {
      
      return null;
    }
  }

  /// Initialize trip service - check for any existing active trips
  Future<void> initializeTripService() async {
    try {
      // Check if driver has any active trip
      final activeTrip = await getCurrentDriverActiveTrip();
      
      if (activeTrip != null) {
        
        
        // Try to get the route for this trip
        final route = getRouteById(activeTrip.routeId);
        if (route != null) {
          // Resume the active trip
          await resumeActiveTrip(activeTrip, route);
        } else {
          
          // Store the active trip info to resume after routes are loaded
          _currentTrip = activeTrip;
        }
      } else {
        
      }
    } catch (e) {
      
    }
  }

  /// Get current trip status for UI display
  Map<String, dynamic> getCurrentTripStatus() {
    if (_currentTrip == null) {
      return {
        'hasActiveTrip': false,
        'trip': null,
        'message': 'No active trip',
      };
    }

    final now = DateTime.now();
    final duration = now.difference(_currentTrip!.startTime);
    
    return {
      'hasActiveTrip': true,
      'trip': _currentTrip,
      'duration': duration,
      'formattedDuration': _formatDuration(duration),
      'busNumber': _currentTrip!.busNumber,
      'routeId': _currentTrip!.routeId,
      'isLiveLocationSharing': _isLiveLocationSharing,
      'message': 'Trip in progress',
    };
  }

  /// Format duration for display
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  /// Check if current driver can start a trip on a route
  Future<Map<String, dynamic>> canStartTripOnRoute(String routeId) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        return {
          'canStart': false,
          'reason': 'User not authenticated',
          'hasExistingTrip': false,
        };
      }

      // Check if driver already has an active trip on this route
      final existingTrip = await getDriverActiveTrip(routeId);
      if (existingTrip != null) {
        return {
          'canStart': true,
          'reason': 'Resume existing trip',
          'hasExistingTrip': true,
          'existingTrip': existingTrip,
          'action': 'resume',
        };
      }

      // Check if another driver is using this route
      final isRouteInUse = await _isRouteCurrentlyInUse(routeId);
      if (isRouteInUse) {
        return {
          'canStart': false,
          'reason': 'Route is currently being used by another driver',
          'hasExistingTrip': false,
          'action': 'blocked',
        };
      }

      return {
        'canStart': true,
        'reason': 'Route is available',
        'hasExistingTrip': false,
        'action': 'start_new',
      };
    } catch (e) {
      
      return {
        'canStart': false,
        'reason': 'Error checking route availability: $e',
        'hasExistingTrip': false,
      };
    }
  }

  /// Calculate heading in degrees (0-360) from one point to another
  double _calculateHeading(latlong2.LatLng from, latlong2.LatLng to) {
    // Convert from degrees to radians
    final startLat = from.latitude * pi / 180;
    final startLng = from.longitude * pi / 180;
    final destLat = to.latitude * pi / 180;
    final destLng = to.longitude * pi / 180;

    // Calculate heading
    final y = sin(destLng - startLng) * cos(destLat);
    final x = cos(startLat) * sin(destLat) -
              sin(startLat) * cos(destLat) * cos(destLng - startLng);
    
    var heading = atan2(y, x) * 180 / pi;
    
    // Normalize to 0-360
    heading = (heading + 360) % 360;
    return heading;
  }
}
