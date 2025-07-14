import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Optimized passenger service using real-time subscriptions instead of polling
class OptimizedPassengerService with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  
  // Real-time subscriptions
  StreamSubscription<List<Map<String, dynamic>>>? _activeBusesSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _driverLocationsSubscription;
  
  // Cache for real-time data
  final Map<String, Map<String, dynamic>> _activeBuses = {};
  final Map<String, Map<String, dynamic>> _busLocations = {};
  
  // Getters
  List<Map<String, dynamic>> get activeBuses => _activeBuses.values.toList();
  Map<String, Map<String, dynamic>> get busLocations => _busLocations;
  
  /// Initialize real-time subscriptions for passenger app
  void initializePassengerSubscriptions() {
    
    
    _subscribeToActiveBuses();
    _subscribeToBusLocations();
  }
  
  /// Subscribe to active buses instead of polling
  void _subscribeToActiveBuses() {
    
    
    _activeBusesSubscription?.cancel();
    _activeBusesSubscription = _supabase
        .from('driver_trips')
        .stream(primaryKey: ['id'])
        .eq('status', 'active')
        .listen(
          (List<Map<String, dynamic>> data) {
            _updateActiveBuses(data);
          },
          onError: (error) {
            
          },
        );
  }
  
  /// Subscribe to bus locations for real-time tracking
  void _subscribeToBusLocations() {
    
    
    _driverLocationsSubscription?.cancel();
    _driverLocationsSubscription = _supabase
        .from('driver_trip_locations')
        .stream(primaryKey: ['id'])
        .order('timestamp', ascending: false)
        .listen(
          (List<Map<String, dynamic>> data) {
            _updateBusLocations(data);
          },
          onError: (error) {
            
          },
        );
  }
  
  /// Update active buses cache from real-time data
  void _updateActiveBuses(List<Map<String, dynamic>> trips) {
    
    
    // Clear and update cache
    _activeBuses.clear();
    
    for (final trip in trips) {
      final tripId = trip['id'] as String;
      final busNumber = trip['bus_number'] as String?;
      final routeId = trip['route_id'] as String?;
      
      _activeBuses[tripId] = {
        ...trip,
        'busId': busNumber ?? tripId,
        'routeNumber': routeId ?? 'Unknown',
        'eta': _calculateETA(trip),
        'distance': _calculateDistance(trip),
        'isActive': true,
      };
    }
    
    
    notifyListeners();
  }
  
  /// Update bus locations cache from real-time data
  void _updateBusLocations(List<Map<String, dynamic>> locations) {
    
    
    // Group by trip_id and keep only the latest location
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
    _busLocations.clear();
    _busLocations.addAll(latestLocations);
    
    
    notifyListeners();
  }
  
  /// Calculate ETA based on trip data
  String _calculateETA(Map<String, dynamic> trip) {
    try {
      // Get the start time and calculate elapsed time
      final startTime = DateTime.parse(trip['start_time'] as String);
      final elapsed = DateTime.now().difference(startTime).inMinutes;
      
      // Simple ETA calculation (you can enhance this with route data)
      final estimatedDuration = 30; // minutes (replace with actual route duration)
      final remaining = estimatedDuration - elapsed;
      
      if (remaining <= 0) return 'Arriving';
      if (remaining < 60) return '${remaining} min';
      
      final hours = remaining ~/ 60;
      final minutes = remaining % 60;
      return '${hours}h ${minutes}m';
    } catch (e) {
      return 'Unknown';
    }
  }
  
  /// Calculate distance based on location data
  String _calculateDistance(Map<String, dynamic> trip) {
    try {
      // This is a placeholder - implement actual distance calculation
      // based on user location and bus location
      return '0.5 km'; // Replace with actual calculation
    } catch (e) {
      return 'Unknown';
    }
  }
  
  /// Get nearby buses (replaces the old polling method)
  List<Map<String, dynamic>> getNearbyBuses() {
    // Return cached real-time data instead of making database calls
    return activeBuses;
  }
  
  /// Search buses using cached real-time data
  List<Map<String, dynamic>> searchBuses(String query) {
    if (query.isEmpty) return [];
    
    final queryLower = query.toLowerCase();
    return activeBuses.where((bus) {
      final busNumber = (bus['bus_number'] ?? '').toString().toLowerCase();
      final routeId = (bus['route_id'] ?? '').toString().toLowerCase();
      return busNumber.contains(queryLower) || routeId.contains(queryLower);
    }).toList();
  }
  
  /// Get bus location by trip ID
  Map<String, dynamic>? getBusLocation(String tripId) {
    return _busLocations[tripId];
  }
  
  /// Get real-time statistics
  Map<String, dynamic> getRealtimeStats() {
    return {
      'active_buses': _activeBuses.length,
      'tracked_locations': _busLocations.length,
      'last_updated': DateTime.now().toIso8601String(),
      'data_source': 'realtime_subscription',
    };
  }
  
  /// Clean up subscriptions
  @override
  void dispose() {
    
    _activeBusesSubscription?.cancel();
    _driverLocationsSubscription?.cancel();
    super.dispose();
  }
}
