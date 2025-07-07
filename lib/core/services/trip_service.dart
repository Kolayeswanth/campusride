import 'dart:async';
import 'dart:math' show Random, sin, cos, pi;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, ChangeNotifier;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'geocoding_service.dart';
import '../constants/map_constants.dart';

class BusRoute {
  String id;
  String name;
  latlong2.LatLng startLocation;
  latlong2.LatLng endLocation;

  BusRoute({
    required this.id,
    required this.name,
    required this.startLocation,
    required this.endLocation,
  });

  factory BusRoute.fromJson(Map<String, dynamic> json) {
    return BusRoute(
      id: json['id'],
      name: json['name'],
      startLocation: latlong2.LatLng(
        json['start_latitude'],
        json['start_longitude'],
      ),
      endLocation: latlong2.LatLng(
        json['end_latitude'],
        json['end_longitude'],
      ),
    );
  }
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
  double _routeDistance = 0.0;
  double _routeDuration = 0.0;
  String? _lastCrossedVillage;
  bool _showVillageNotification = false;
  String? _villageNotificationMessage;
  Timer? _notificationTimer;
  final Set<String> _crossedVillages = {}; // Track crossed villages to prevent duplicates

  List<BusRoute> get routes => _routes;
  BusRoute? get selectedRoute => _selectedRoute;
  latlong2.LatLng? get currentLocation => _currentLocation;
  bool get isTracking => _isTracking;
  String? get error => _error;
  Map<String, String> get crossedVillages => _geocodingService.crossedVillages;
  bool get showVillageNotification => _showVillageNotification;
  String? get villageNotificationMessage => _villageNotificationMessage;

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
        _currentLocation = latlong2.LatLng(position.latitude, position.longitude);
        
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
        if (villageCenter == null) return;
        
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
      print('Error checking for crossed village: $e');
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
            
        // Store route metadata
        final summary = data['features'][0]['properties']['summary'];
        final distance = summary['distance'] as double;
        final duration = summary['duration'] as double;
        
        // Notify listeners about the route details
        _routeDistance = distance;
        _routeDuration = duration;
        notifyListeners();
        
        return routePoints;
      } else {
        print('Failed to calculate route: ${response.statusCode} - ${response.body}');
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
      
      if (routeResponse == null) {
        throw Exception('Route not found');
      }
      
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
      print('Failed to store crossed village: $e');
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
        if (villageCenter == null) return null;
        
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
      print('Error getting village name: $e');
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
      print('Failed to get crossed villages: $e');
      return [];
    }
  }

  /// Get the village center coordinates
  Future<latlong2.LatLng?> getVillageCenter(String villageName) async {
    try {
      return await _geocodingService.getVillageCenter(villageName);
    } catch (e) {
      print('Error getting village center: $e');
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
      print('Failed to store crossed village: $e');
    }
  }

  @override
  void dispose() {
    _crossedVillages.clear();
    _notificationTimer?.cancel();
    super.dispose();
  }

  Future<List<BusRoute>> fetchDriverRoutes() async {
    try {
      final response = await _supabase.from('routes').select('*');
      _routes = response.map((e) => BusRoute.fromJson(e)).toList();
      notifyListeners();
      return _routes;
    } catch (e) {
      _error = 'Failed to fetch driver routes: $e';
      notifyListeners();
      return [];
    }
  }
}
