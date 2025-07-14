import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Real-time service to replace polling with efficient Supabase subscriptions
class RealtimeService with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  
  // User college information for filtering
  String? _userCollegeId;
  
  // Subscriptions
  StreamSubscription<List<Map<String, dynamic>>>? _activeTripsSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _driverLocationsSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _routeStatusSubscription;
  
  // Cached data
  final Map<String, Map<String, dynamic>> _activeTrips = {};
  final Map<String, Map<String, dynamic>> _driverLocations = {};
  final Set<String> _routesInUse = {};
  
  // Getters
  Map<String, Map<String, dynamic>> get activeTrips => _activeTrips;
  Map<String, Map<String, dynamic>> get driverLocations => _driverLocations;
  Set<String> get routesInUse => _routesInUse;
  
  /// Initialize real-time subscriptions for active trips with college filtering
  void subscribeToActiveTrips() {
    _activeTripsSubscription?.cancel();
    _activeTripsSubscription = _supabase
        .from('driver_trips')
        .stream(primaryKey: ['id'])
        .eq('status', 'active')
        .listen(
          (List<Map<String, dynamic>> data) {
            _updateActiveTripsWithCollegeFilter(data);
          },
          onError: (error) {
            // Try to get data directly from database for debugging
            
            
            // Start fallback polling if real-time fails
            
          },
        );
  }
  
  /// Initialize real-time subscriptions for driver locations
  void subscribeToDriverLocations() {
    _driverLocationsSubscription?.cancel();
    _driverLocationsSubscription = _supabase
        .from('driver_trip_locations')
        .stream(primaryKey: ['id'])
        .order('timestamp', ascending: false)
        .listen(
          (List<Map<String, dynamic>> data) {
            _updateDriverLocations(data);
          },
          onError: (error) {
            // Handle error silently
          },
        );
  }
  
  /// Subscribe to route status changes for a specific college
  void subscribeToRouteStatus({String? collegeCode}) {
    _routeStatusSubscription?.cancel();
    
    // Subscribe to driver_trips to track route usage
    _routeStatusSubscription = _supabase
        .from('driver_trips')
        .stream(primaryKey: ['id'])
        .eq('status', 'active')
        .listen(
          (List<Map<String, dynamic>> data) {
            _updateRouteStatus(data);
          },
          onError: (error) {
            
          },
        );
  }
  
  /// Update active trips cache with college filtering
  Future<void> _updateActiveTripsWithCollegeFilter(List<Map<String, dynamic>> trips) async {
    
    
    // Clear existing cache
    _activeTrips.clear();
    
    // Get current user's college for filtering
    final userCollegeId = await _getCurrentUserCollegeId();
    
    if (userCollegeId == null) {
      // If no college is set, show all trips for now (fallback behavior)
      _updateActiveTrips(trips);
      return;
    }
    
    // Filter trips by user's college
    final filteredTrips = <Map<String, dynamic>>[];
    
    for (final trip in trips) {
      final routeId = trip['route_id'] as String?;
      if (routeId != null) {
        // Get the college for this route
        final routeCollegeId = await _getRouteCollegeId(routeId);
        if (routeCollegeId == userCollegeId) {
          filteredTrips.add(trip);
          
        } else {
          
        }
      }
    }
    
    
    _updateActiveTrips(filteredTrips);
  }
  
  /// Get current user's college ID
  Future<String?> _getCurrentUserCollegeId() async {
    try {
      if (_userCollegeId != null) {
        return _userCollegeId;
      }
      
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return null;
      
      final profileResponse = await _supabase
          .from('profiles')
          .select('college_id')
          .eq('id', currentUser.id)
          .maybeSingle();
      
      _userCollegeId = profileResponse?['college_id'] as String?;
      
      return _userCollegeId;
    } catch (e) {
      
      return null;
    }
  }
  
  /// Get college ID for a specific route
  Future<String?> _getRouteCollegeId(String routeId) async {
    try {
      // First try to get route by ID
      final routeResponse = await _supabase
          .from('routes')
          .select('college_code')
          .eq('id', routeId)
          .maybeSingle();
      
      if (routeResponse?['college_code'] != null) {
        final collegeCode = routeResponse!['college_code'] as String;
        
        // Get college ID from college code
        final collegeResponse = await _supabase
            .from('colleges')
            .select('id')
            .eq('code', collegeCode)
            .maybeSingle();
        
        return collegeResponse?['id'] as String?;
      }
      
      return null;
    } catch (e) {
      
      return null;
    }
  }

  /// Update active trips cache (enhanced with route information)
  Future<void> _updateActiveTrips(List<Map<String, dynamic>> trips) async {
    
    
    // Clear existing cache
    _activeTrips.clear();
    
    // Update cache with enhanced data
    for (final trip in trips) {
      final tripId = trip['id'] as String;
      final enhancedTrip = await _enhanceTripWithRouteInfo(Map<String, dynamic>.from(trip));
      _activeTrips[tripId] = enhancedTrip;
      
    }
    
    // Notify listeners about the update safely
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (hasListeners) {
        notifyListeners();
      }
    });
  }

  /// Enhance trip data with route information (from/to destinations, route name)
  Future<Map<String, dynamic>> _enhanceTripWithRouteInfo(Map<String, dynamic> trip) async {
    final routeId = trip['route_id'] as String?;
    if (routeId != null) {
      try {
        final routeResponse = await _supabase
            .from('routes')
            .select('name, start_location, end_location')
            .eq('id', routeId)
            .single();
        
        // Extract route information
        final routeName = routeResponse['name'] as String? ?? '';
        final startLocation = routeResponse['start_location'] as Map<String, dynamic>?;
        final endLocation = routeResponse['end_location'] as Map<String, dynamic>?;
        
        // Add route information to trip
        trip['route_name'] = routeName;
        trip['from_destination'] = startLocation?['name'] as String? ?? '';
        trip['to_destination'] = endLocation?['name'] as String? ?? '';
        
        
      } catch (e) {
        
        // Set fallback values
        trip['route_name'] = 'Route ${trip['bus_number'] ?? ''}';
        trip['from_destination'] = 'Unknown';
        trip['to_destination'] = 'Unknown';
      }
    } else {
      // Set fallback values if no route ID
      trip['route_name'] = 'Route ${trip['bus_number'] ?? ''}';
      trip['from_destination'] = 'Unknown';
      trip['to_destination'] = 'Unknown';
    }
    
    return trip;
  }
  
  /// Update driver locations cache
  void _updateDriverLocations(List<Map<String, dynamic>> locations) {
    
    
    // Group locations by trip_id and keep only the latest
    final latestLocations = <String, Map<String, dynamic>>{};
    
    for (final location in locations) {
      final tripId = location['trip_id'] as String?;
      if (tripId != null) {
        final timestamp = DateTime.parse(location['timestamp'] as String);
        
        if (!latestLocations.containsKey(tripId) ||
            timestamp.isAfter(DateTime.parse(latestLocations[tripId]!['timestamp'] as String))) {
          latestLocations[tripId] = location;
        }
      }
    }
    
    // Update cache
    _driverLocations.clear();
    _driverLocations.addAll(latestLocations);
    
    // Notify listeners safely
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (hasListeners) {
        notifyListeners();
      }
    });
  }
  
  /// Update route status based on active trips
  void _updateRouteStatus(List<Map<String, dynamic>> activeTrips) {
    
    
    // Clear existing routes in use
    _routesInUse.clear();
    
    // Mark routes as in use
    for (final trip in activeTrips) {
      final routeId = trip['route_id'] as String?;
      if (routeId != null) {
        _routesInUse.add(routeId);
      }
    }
    
    
    
    // Notify listeners safely
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (hasListeners) {
        notifyListeners();
      }
    });
  }
  
  /// Get active trips count
  int getActiveTripsCount() {
    return _activeTrips.length;
  }
  
  /// Check if a route is currently in use
  bool isRouteInUse(String routeId) {
    return _routesInUse.contains(routeId);
  }
  
  /// Get driver location for a specific trip
  Map<String, dynamic>? getDriverLocation(String tripId) {
    return _driverLocations[tripId];
  }
  
  /// Get latest driver location with better error handling
  Map<String, dynamic>? getLatestDriverLocation(String tripId) {
    final location = _driverLocations[tripId];
    if (location == null) return null;
    
    // Check if location is recent (within last 5 minutes)
    try {
      final timestamp = DateTime.parse(location['timestamp'] as String);
      final age = DateTime.now().difference(timestamp);
      
      if (age.inMinutes < 5) {
        return {
          ...location,
          'age_seconds': age.inSeconds,
          'is_recent': true,
        };
      } else {
        return {
          ...location,
          'age_seconds': age.inSeconds,
          'is_recent': false,
        };
      }
    } catch (e) {
      
      return null;
    }
  }
  
  /// Check if driver location is available and recent for a trip
  bool isDriverLocationAvailable(String tripId) {
    final location = getLatestDriverLocation(tripId);
    return location != null && (location['is_recent'] as bool? ?? false);
  }
  
  /// Get all active trips for a specific driver
  List<Map<String, dynamic>> getActiveTripsForDriver(String driverId) {
    return _activeTrips.values
        .where((trip) => trip['driver_id'] == driverId)
        .toList();
  }
  
  /// Get active trips statistics
  Map<String, dynamic> getActiveTripsStats() {
    final uniqueDrivers = <String>{};
    final uniqueRoutes = <String>{};
    
    for (final trip in _activeTrips.values) {
      final driverId = trip['driver_id'] as String?;
      final routeId = trip['route_id'] as String?;
      
      if (driverId != null) uniqueDrivers.add(driverId);
      if (routeId != null) uniqueRoutes.add(routeId);
    }
    
    return {
      'total_active_trips': _activeTrips.length,
      'unique_drivers': uniqueDrivers.length,
      'unique_routes': uniqueRoutes.length,
      'last_updated': DateTime.now().toIso8601String(),
    };
  }
  
  /// Initialize all subscriptions with college-based filtering
  void initializeSubscriptions({String? collegeCode}) {
    
    
    // Stop any fallback polling since we're setting up real-time
    
    
    // Clear user college cache to refresh on next query
    _userCollegeId = null;
    
    subscribeToActiveTrips();
    subscribeToDriverLocations();
    subscribeToRouteStatus(collegeCode: collegeCode);
    
    // Immediately query database to get current state
    Future.delayed(const Duration(seconds: 2), () {
      
      
    });
  }
  
  /// Refresh college filtering when user updates their college selection
  void refreshCollegeFilter() {
    
    _userCollegeId = null; // Clear cache
    
    // Re-subscribe to get filtered data
    subscribeToActiveTrips();
  }
  
  /// Clean up all subscriptions
  void dispose() {
    
    _activeTripsSubscription?.cancel();
    _driverLocationsSubscription?.cancel();
    _routeStatusSubscription?.cancel();
    
    super.dispose();
  }
}
