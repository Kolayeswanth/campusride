import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class RouteManagementService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _routes = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get routes => _routes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Get all routes for a specific college
  Future<void> loadCollegeRoutes(String collegeId) async {
    _setLoading(true);
    try {
      final response = await _supabase
          .from('routes')
          .select('*')
          .eq('college_id', collegeId)
          .eq('active', true)
          .order('bus_number');

      _routes = List<Map<String, dynamic>>.from(response);
      _error = null;
    } catch (e) {
      _error = 'Failed to load routes: $e';
      print('Error loading routes: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Create a new route
  Future<bool> createRoute({
    required String collegeId,
    required String busNumber,
    required String routeName,
    required String startLocation,
    required String endLocation,
    String? polylineData,
    List<Map<String, dynamic>>? waypoints,
    double? distanceKm,
    int? estimatedDurationMinutes,
  }) async {
    _setLoading(true);
    try {
      await _supabase.from('routes').insert({
        'college_id': collegeId,
        'bus_number': busNumber,
        'route_name': routeName,
        'start_location': startLocation,
        'end_location': endLocation,
        'polyline_data': polylineData,
        'waypoints': waypoints ?? [],
        'distance_km': distanceKm,
        'estimated_duration_minutes': estimatedDurationMinutes,
        'active': true,
      });

      _error = null;
      // Reload routes after creation
      await loadCollegeRoutes(collegeId);
      return true;
    } catch (e) {
      _error = 'Failed to create route: $e';
      print('Error creating route: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Update an existing route
  Future<bool> updateRoute(Map<String, dynamic> routeData) async {
    try {
      final routeId = routeData['id'];
      if (routeId == null) {
        throw 'Route ID cannot be null.';
      }
      
      // Create a new map without the 'id' key for the update payload
      final updatePayload = Map<String, dynamic>.from(routeData);
      updatePayload.remove('id');

      await _supabase.from('routes').update(updatePayload).eq('id', routeId);

      // Update local cache
      final index = _routes.indexWhere((route) => route['id'] == routeId);
      if (index != -1) {
        _routes[index].addAll(routeData);
        notifyListeners();
      }
      
      return true;
    } catch (e) {
      _error = 'Failed to update route: $e';
      print('Error updating route: $e');
      return false;
    }
  }

  /// Update route with polyline data
  Future<bool> updateRoutePolyline({
    required String routeId,
    required String polylineData,
    List<Map<String, dynamic>>? waypoints,
    double? distanceKm,
    int? estimatedDurationMinutes,
  }) async {
    try {
      await _supabase.from('routes').update({
        'polyline_data': polylineData,
        'waypoints': waypoints ?? [],
        'distance_km': distanceKm,
        'estimated_duration_minutes': estimatedDurationMinutes,
      }).eq('id', routeId);

      _error = null;
      
      // Update local route data
      final index = _routes.indexWhere((route) => route['id'] == routeId);
      if (index != -1) {
        _routes[index]['polyline_data'] = polylineData;
        _routes[index]['waypoints'] = waypoints ?? [];
        _routes[index]['distance_km'] = distanceKm;
        _routes[index]['estimated_duration_minutes'] = estimatedDurationMinutes;
        notifyListeners();
      }
      
      return true;
    } catch (e) {
      _error = 'Failed to update route: $e';
      print('Error updating route: $e');
      return false;
    }
  }

  /// Delete a route
  Future<bool> deleteRoute(String routeId, String collegeId) async {
    _setLoading(true);
    try {
      await _supabase.from('routes').delete().eq('id', routeId);

      _error = null;
      // Reload routes after deletion
      await loadCollegeRoutes(collegeId);
      return true;
    } catch (e) {
      _error = 'Failed to delete route: $e';
      print('Error deleting route: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Toggle route active status
  Future<bool> toggleRouteStatus(String routeId, bool active, String collegeId) async {
    try {
      await _supabase.from('routes').update({
        'active': active,
      }).eq('id', routeId);

      _error = null;
      // Reload routes after status change
      await loadCollegeRoutes(collegeId);
      return true;
    } catch (e) {
      _error = 'Failed to update route status: $e';
      print('Error updating route status: $e');
      return false;
    }
  }

  /// Get route by ID
  Future<Map<String, dynamic>?> getRoute(String routeId) async {
    try {
      final response = await _supabase
          .from('routes')
          .select('*')
          .eq('id', routeId)
          .single();

      return response;
    } catch (e) {
      print('Error getting route: $e');
      return null;
    }
  }

  /// Check if bus number is unique for college
  Future<bool> isBusNumberUnique(String busNumber, String collegeId, [String? excludeRouteId]) async {
    try {
      var query = _supabase
          .from('routes')
          .select('id')
          .eq('college_id', collegeId)
          .eq('bus_number', busNumber);

      if (excludeRouteId != null) {
        query = query.neq('id', excludeRouteId);
      }

      final response = await query;
      return response.isEmpty;
    } catch (e) {
      print('Error checking bus number uniqueness: $e');
      return false;
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
