import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/bus.dart';
import '../models/route.dart';

/// Trip model to represent a driver's trip
class Trip {
  final String id;
  final String busId;
  final String routeName;
  final DateTime startTime;
  final DateTime? endTime;
  final bool isActive;
  
  Trip({
    required this.id,
    required this.busId,
    required this.routeName,
    required this.startTime,
    this.endTime,
    required this.isActive,
  });
  
  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] as String,
      busId: json['bus_id'] as String,
      routeName: json['route_name'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null 
          ? DateTime.parse(json['end_time'] as String) 
          : null,
      isActive: json['is_active'] as bool,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bus_id': busId,
      'route_name': routeName,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'is_active': isActive,
    };
  }
  
  /// Get the duration of the trip as a formatted string
  String get duration {
    final endDateTime = endTime ?? DateTime.now();
    final difference = endDateTime.difference(startTime);
    
    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60);
    final seconds = difference.inSeconds.remainder(60);
    
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  /// Get a formatted start time (e.g. "10:30 AM")
  String get formattedStartTime {
    return DateFormat('h:mm a').format(startTime);
  }
  
  /// Get a formatted date (e.g. "Jun 15, 2023")
  String get formattedDate {
    return DateFormat('MMM d, yyyy').format(startTime);
  }
}

/// TripService handles trip management for drivers
class TripService extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  
  Trip? _currentTrip;
  List<Trip> _tripHistory = [];
  String? _error;
  bool _isLoading = false;
  Timer? _tripTimer;
  String _tripDuration = '00:00:00';
  
  List<Bus> _activeBuses = [];
  List<BusRoute> _routes = [];
  
  /// Current active trip if any
  Trip? get currentTrip => _currentTrip;
  
  /// List of past trips
  List<Trip> get tripHistory => _tripHistory;
  
  /// Error message if any
  String? get error => _error;
  
  /// Loading state
  bool get isLoading => _isLoading;
  
  /// Current trip duration as formatted string
  String get tripDuration => _tripDuration;
  
  /// Check if there's an active trip
  bool get hasActiveTrip => _currentTrip != null && _currentTrip!.isActive;
  
  List<Bus> get activeBuses => _activeBuses;
  List<BusRoute> get routes => _routes;
  
  /// Load driver's bus information and active trip
  Future<void> initialize(String driverId) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // First, check if driver has an active trip
      final tripResponse = await _supabase
          .from('driver_trips')
          .select()
          .eq('driver_id', driverId)
          .eq('is_active', true)
          .limit(1)
          .maybeSingle();
      
      if (tripResponse != null) {
        _currentTrip = Trip.fromJson(tripResponse);
        _startTripTimer();
      }
      
      // Load trip history
      await _loadTripHistory(driverId);
      
      _error = null;
    } catch (e) {
      _error = 'Failed to load trip data: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Start a new trip
  Future<bool> startTrip({
    required String driverId, 
    required String busId, 
    required String routeName
  }) async {
    if (hasActiveTrip) {
      _error = 'You already have an active trip';
      notifyListeners();
      return false;
    }
    
    _isLoading = true;
    notifyListeners();
    
    try {
      // Create a new trip entry
      final tripId = 'trip_${DateTime.now().millisecondsSinceEpoch}';
      final startTime = DateTime.now();
      
      final newTrip = Trip(
        id: tripId,
        busId: busId,
        routeName: routeName,
        startTime: startTime,
        isActive: true,
      );
      
      // Insert into database
      await _supabase.from('driver_trips').insert({
        'id': tripId,
        'driver_id': driverId,
        'bus_id': busId,
        'route_name': routeName,
        'start_time': startTime.toIso8601String(),
        'is_active': true,
      });
      
      _currentTrip = newTrip;
      _startTripTimer();
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to start trip: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  /// End the current trip
  Future<bool> endTrip() async {
    if (!hasActiveTrip) {
      _error = 'No active trip to end';
      notifyListeners();
      return false;
    }
    
    _isLoading = true;
    notifyListeners();
    
    try {
      final endTime = DateTime.now();
      
      // Update trip in database
      await _supabase
          .from('driver_trips')
          .update({
            'end_time': endTime.toIso8601String(),
            'is_active': false,
          })
          .eq('id', _currentTrip!.id);
      
      // Update local trip
      final updatedTrip = Trip(
        id: _currentTrip!.id,
        busId: _currentTrip!.busId,
        routeName: _currentTrip!.routeName,
        startTime: _currentTrip!.startTime,
        endTime: endTime,
        isActive: false,
      );
      
      _currentTrip = null;
      _tripHistory.insert(0, updatedTrip);
      _stopTripTimer();
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to end trip: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  /// Load trip history for a driver
  Future<void> _loadTripHistory(String driverId) async {
    try {
      final response = await _supabase
          .from('driver_trips')
          .select()
          .eq('driver_id', driverId)
          .eq('is_active', false)
          .order('start_time', ascending: false)
          .limit(30);
      
      _tripHistory = response.map<Trip>((trip) => Trip.fromJson(trip)).toList();
      notifyListeners();
    } catch (e) {
      print('Error loading trip history: $e');
      // We don't want to interrupt the entire flow if history fails to load
    }
  }
  
  /// Start timer to update trip duration
  void _startTripTimer() {
    _stopTripTimer();
    
    _updateTripDuration();
    _tripTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTripDuration();
    });
  }
  
  /// Stop trip duration timer
  void _stopTripTimer() {
    _tripTimer?.cancel();
    _tripTimer = null;
    _tripDuration = '00:00:00';
  }
  
  /// Update the trip duration string
  void _updateTripDuration() {
    if (_currentTrip == null) return;
    
    final now = DateTime.now();
    final difference = now.difference(_currentTrip!.startTime);
    
    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60);
    final seconds = difference.inSeconds.remainder(60);
    
    _tripDuration = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    notifyListeners();
  }
  
  /// Clear all data, typically called at logout
  void clear() {
    _currentTrip = null;
    _tripHistory.clear();
    _stopTripTimer();
    _error = null;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _stopTripTimer();
    super.dispose();
  }
  
  /// Initialize real-time subscriptions
  void initSubscriptions() {
    // Subscribe to bus location updates
    _supabase
        .from('bus_locations')
        .stream(primaryKey: ['id'])
        .order('timestamp', ascending: false)
        .limit(100)
        .listen((data) {
          _updateBusLocations(data);
        });
  }
  
  /// Update bus locations from real-time data
  void _updateBusLocations(List<Map<String, dynamic>> data) {
    final updatedBuses = data.map((json) {
      final busId = json['bus_id'] as String;
      final existingBus = _activeBuses.firstWhere(
        (bus) => bus.id == busId,
        orElse: () => Bus(
          id: busId,
          name: 'Bus $busId',
          routeId: json['route_id'] as String? ?? '',
          latitude: (json['latitude'] as num).toDouble(),
          longitude: (json['longitude'] as num).toDouble(),
          capacity: 40, // Default capacity
          currentPassengers: 0,
          isActive: true,
          lastUpdated: DateTime.parse(json['timestamp'] as String),
        ),
      );
      
      return existingBus.copyWith(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        lastUpdated: DateTime.parse(json['timestamp'] as String),
      );
    }).toList();
    
    _activeBuses = updatedBuses;
    notifyListeners();
  }
  
  /// Get route details by ID
  Future<BusRoute> getRouteDetails(String routeId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _supabase
          .from('routes')
          .select()
          .eq('id', routeId)
          .single();
      
      final route = BusRoute.fromJson(response);
      _error = null;
      _isLoading = false;
      notifyListeners();
      return route;
    } catch (e) {
      _error = 'Failed to load route details: $e';
      _isLoading = false;
      notifyListeners();
      throw Exception(_error);
    }
  }
  
  /// Get all active buses for a specific route
  Future<List<Bus>> getActiveBusesForRoute(String routeId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Get the latest location for each active bus on this route
      final response = await _supabase
          .from('bus_locations')
          .select('''
            bus_id,
            latitude,
            longitude,
            timestamp,
            buses (
              id,
              name,
              capacity,
              status
            )
          ''')
          .eq('route_id', routeId)
          .eq('buses.status', 'active')
          .order('timestamp', ascending: false)
          .limit(1, referencedTable: 'buses');
      
      final buses = response.map<Bus>((json) {
        final bus = json['buses'] as Map<String, dynamic>;
        return Bus(
          id: bus['id'] as String,
          name: bus['name'] as String,
          routeId: routeId,
          latitude: (json['latitude'] as num).toDouble(),
          longitude: (json['longitude'] as num).toDouble(),
          capacity: bus['capacity'] as int,
          currentPassengers: 0, // TODO: Implement passenger counting
          isActive: bus['status'] == 'active',
          lastUpdated: DateTime.parse(json['timestamp'] as String),
        );
      }).toList();
      
      _activeBuses = buses;
      _error = null;
      _isLoading = false;
      notifyListeners();
      return buses;
    } catch (e) {
      _error = 'Failed to load active buses: $e';
      _isLoading = false;
      notifyListeners();
      throw Exception(_error);
    }
  }
  
  /// Get all available routes
  Future<List<BusRoute>> loadRoutes() async {
    // Don't call notifyListeners() at the beginning to avoid setState during build
    _isLoading = true;
    _error = null;
    
    try {
      final response = await _supabase
          .from('routes')
          .select()
          .order('name');
      
      _routes = response.map<BusRoute>((json) => BusRoute.fromJson(json)).toList();
      _error = null;
      _isLoading = false;
      // Only notify listeners after the async operation is complete
      notifyListeners();
      return _routes;
    } catch (e) {
      _error = 'Failed to load routes: $e';
      _isLoading = false;
      // Only notify listeners after the async operation is complete
      notifyListeners();
      return [];
    }
  }
  
  /// Get favorite routes for the current user
  Future<List<BusRoute>> getFavoriteRoutes() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];
    
    try {
      final response = await _supabase
          .from('favorite_routes')
          .select('''
            route_id,
            routes (*)
          ''')
          .eq('user_id', userId);
      
      return response.map<BusRoute>((json) {
        return BusRoute.fromJson(json['routes'] as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      _error = 'Failed to load favorite routes: $e';
      notifyListeners();
      return [];
    }
  }
  
  /// Add a route to favorites
  Future<void> addToFavorites(String routeId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    
    try {
      await _supabase
          .from('favorite_routes')
          .upsert({
            'user_id': userId,
            'route_id': routeId,
            'created_at': DateTime.now().toIso8601String(),
          });
      
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to add route to favorites: $e';
      notifyListeners();
    }
  }
  
  /// Remove a route from favorites
  Future<void> removeFromFavorites(String routeId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    
    try {
      await _supabase
          .from('favorite_routes')
          .delete()
          .match({
            'user_id': userId,
            'route_id': routeId,
          });
      
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to remove route from favorites: $e';
      notifyListeners();
    }
  }
  
  /// Check if a route is in favorites
  Future<bool> isFavorite(String routeId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;
    
    try {
      final response = await _supabase
          .from('favorite_routes')
          .select()
          .match({
            'user_id': userId,
            'route_id': routeId,
          })
          .maybeSingle();
      
      return response != null;
    } catch (e) {
      return false;
    }
  }
  
  /// Search for buses by number or route name
  Future<List<Map<String, dynamic>>> searchBuses(String query) async {
    try {
      final response = await _supabase
          .from('driver_trips')
          .select('''
            id,
            bus_id,
            route_name,
            route_id,
            is_active,
            start_time
          ''')
          .or('bus_id.ilike.%$query%,route_name.ilike.%$query%')
          .order('start_time', ascending: false)
          .limit(10);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _error = 'Failed to search buses: $e';
      notifyListeners();
      rethrow;
    }
  }
  
  /// Get route data including stops and path points
  Future<Map<String, dynamic>> getRouteData(String routeId) async {
    try {
      final response = await _supabase
          .from('bus_routes')
          .select('''
            id,
            name,
            stops (
              id,
              name,
              latitude,
              longitude
            ),
            path_points (
              latitude,
              longitude
            )
          ''')
          .eq('id', routeId)
          .single();

      return {
        'stops': response['stops'],
        'points': response['path_points'],
      };
    } catch (e) {
      _error = 'Failed to get route data: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Get the current location of a bus on a specific route
  Future<Map<String, dynamic>?> getBusLocation(String routeId) async {
    try {
      final response = await _supabase
          .from('bus_locations')
          .select('''
            bus_id,
            latitude,
            longitude,
            timestamp
          ''')
          .eq('route_id', routeId)
          .order('timestamp', ascending: false)
          .limit(1)
          .maybeSingle();

      return response;
    } catch (e) {
      _error = 'Failed to get bus location: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<List<BusRoute>> getPreviousRoutes(String driverId) async {
    try {
      final response = await _supabase
          .from('driver_trips')
          .select('route_id, route_name, bus_id, start_time')
          .eq('driver_id', driverId)
          .order('start_time', ascending: false)
          .limit(10);

      final routes = <BusRoute>[];
      for (final trip in response) {
        final routeData = await _supabase
            .from('bus_routes')
            .select()
            .eq('id', trip['route_id'])
            .single();
        
        routes.add(BusRoute.fromJson(routeData));
      }

      return routes;
    } catch (e) {
      _error = 'Failed to load previous routes: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> saveTripHistory({
    required String driverId,
    required String busId,
    required String routeId,
    required String routeName,
    required LatLng destination,
  }) async {
    try {
      await _supabase.from('trip_history').insert({
        'driver_id': driverId,
        'bus_id': busId,
        'route_id': routeId,
        'route_name': routeName,
        'destination_lat': destination.latitude,
        'destination_lng': destination.longitude,
        'start_time': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _error = 'Failed to save trip history: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getTripHistory(String driverId) async {
    try {
      final response = await _supabase
          .from('trip_history')
          .select()
          .eq('driver_id', driverId)
          .order('start_time', ascending: false)
          .limit(10);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _error = 'Failed to load trip history: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Update bus location in the database
  Future<void> updateBusLocation(
    String busId,
    double latitude,
    double longitude,
    double heading,
    double speed,
  ) async {
    try {
      final response = await _supabase
          .from('bus_locations')
          .upsert({
            'bus_id': busId,
            'latitude': latitude,
            'longitude': longitude,
            'heading': heading,
            'speed': speed,
            'timestamp': DateTime.now().toIso8601String(),
          })
          .select();
      
      if (response.isEmpty) {
        _error = 'Failed to update bus location';
        notifyListeners();
      }
    } catch (e) {
      _error = 'Error updating bus location: $e';
      notifyListeners();
      rethrow;
    }
  }
} 
  }
} 