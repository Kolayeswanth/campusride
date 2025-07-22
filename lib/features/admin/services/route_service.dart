import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Admin route service for managing routes
class RouteService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _routes = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get routes => _routes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Get all routes for a specific college
  Future<void> loadCollegeRoutes(String collegeCode) async {
    _setLoading(true);
    try {
      final response = await _supabase
          .from('routes')
          .select('*')
          .eq('college_code', collegeCode)
          .order('name');

      _routes = List<Map<String, dynamic>>.from(response);
      _error = null;
    } catch (e) {
      _error = 'Failed to load routes: $e';
      print('Error loading routes: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Get all routes
  Future<List<Map<String, dynamic>>> getAllRoutes() async {
    try {
      final response = await _supabase
          .from('routes')
          .select('*')
          .order('name');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error loading all routes: $e');
      return [];
    }
  }

  /// Get routes by college code
  Future<List<Map<String, dynamic>>> getRoutesByCollege(String collegeCode) async {
    try {
      final response = await _supabase
          .from('routes')
          .select('*')
          .eq('college_code', collegeCode)
          .order('name');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error loading routes for college: $e');
      return [];
    }
  }

  /// Create a new route
  Future<bool> createRoute({
    required String collegeCode,
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
      // Generate a unique text ID for the route
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final routeId = 'route_${collegeCode}_${timestamp}';

      final routeData = {
        'id': routeId,
        'college_code': collegeCode,
        'bus_number': busNumber,
        'name': routeName,
        'start_location': startLocation,
        'end_location': endLocation,
        'polyline_data': polylineData,
        'waypoints': waypoints,
        'distance_km': distanceKm,
        'estimated_duration_minutes': estimatedDurationMinutes,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from('routes').insert(routeData);
      
      // Reload routes
      await loadCollegeRoutes(collegeCode);
      
      _error = null;
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
  Future<bool> updateRoute({
    required String routeId,
    required String collegeCode,
    String? busNumber,
    String? routeName,
    String? startLocation,
    String? endLocation,
    String? polylineData,
    List<Map<String, dynamic>>? waypoints,
    double? distanceKm,
    int? estimatedDurationMinutes,
  }) async {
    _setLoading(true);
    try {
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (busNumber != null) updateData['bus_number'] = busNumber;
      if (routeName != null) updateData['name'] = routeName;
      if (startLocation != null) updateData['start_location'] = startLocation;
      if (endLocation != null) updateData['end_location'] = endLocation;
      if (polylineData != null) updateData['polyline_data'] = polylineData;
      if (waypoints != null) updateData['waypoints'] = waypoints;
      if (distanceKm != null) updateData['distance_km'] = distanceKm;
      if (estimatedDurationMinutes != null) {
        updateData['estimated_duration_minutes'] = estimatedDurationMinutes;
      }

      await _supabase
          .from('routes')
          .update(updateData)
          .eq('id', routeId);

      // Reload routes
      await loadCollegeRoutes(collegeCode);
      
      _error = null;
      return true;
    } catch (e) {
      _error = 'Failed to update route: $e';
      print('Error updating route: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Delete a route
  Future<bool> deleteRoute(String routeId, String collegeCode) async {
    _setLoading(true);
    try {
      await _supabase
          .from('routes')
          .delete()
          .eq('id', routeId);

      // Reload routes
      await loadCollegeRoutes(collegeCode);
      
      _error = null;
      return true;
    } catch (e) {
      _error = 'Failed to delete route: $e';
      print('Error deleting route: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Get route by ID
  Future<Map<String, dynamic>?> getRouteById(String routeId) async {
    try {
      final response = await _supabase
          .from('routes')
          .select('*')
          .eq('id', routeId)
          .single();

      return response;
    } catch (e) {
      print('Error loading route by ID: $e');
      return null;
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
