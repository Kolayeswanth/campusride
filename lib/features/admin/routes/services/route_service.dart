import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/route.dart';
import '../../../../core/utils/logger_util.dart';
import 'dart:math' as math;

class RouteService extends ChangeNotifier {
  final SupabaseClient _supabase;
  List<Route> _routes = [];
  bool _isLoading = false;
  String? _error;

  RouteService(this._supabase);

  List<Route> get routes => _routes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadRoutes() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('routes')
          .select()
          .order('created_at', ascending: false);

      _routes = (response as List).map((json) => Route.fromJson(json)).toList();
      _error = null;
    } catch (e) {
      _error = 'Failed to load routes: $e';
      _routes = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createRoute({
    required String busNumber,
    required String startLocation,
    required String endLocation,
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    String? collegeId, // This should actually be the college code
    String? driverId,
  }) async {
    try {
      // Create a JSONB start_location object for the new schema
      final startLocationJson = {
        'name': startLocation,
        'latitude': startLat,
        'longitude': startLng
      };
      
      // Create a JSONB end_location object for the new schema
      final endLocationJson = {
        'name': endLocation,
        'latitude': endLat,
        'longitude': endLng
      };
      
      // Create a random ID with the required format
      final id = 'route_${DateTime.now().millisecondsSinceEpoch}_${(1000 + math.Random().nextInt(9000))}';
      
      final response = await _supabase.from('routes').insert({
        'id': id,
        'name': busNumber,
        'start_location': startLocationJson,
        'end_location': endLocationJson,
        'is_active': true,
        'college_code': collegeId, // Use college_code instead of college_id
        'driver_id': driverId,
      }).select().single();

      final newRoute = Route.fromJson(response);
      _routes.insert(0, newRoute);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to create route: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateRoute({
    required String id,
    required String busNumber,
    required String startLocation,
    required String endLocation,
    required bool isActive,
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    String? collegeId,
    String? driverId,
  }) async {
    try {
      final response = await _supabase
          .from('routes')
          .update({
            'bus_number': busNumber,
            'start_location': startLocation,
            'end_location': endLocation,
            'active': isActive,
            'college_id': collegeId,
            'driver_id': driverId,
            'start_latitude': startLat,
            'start_longitude': startLng,
            'end_latitude': endLat,
            'end_longitude': endLng,
          })
          .eq('id', id)
          .select()
          .single();

      final updatedRoute = Route.fromJson(response);
      final index = _routes.indexWhere((r) => r.id == id);
      if (index != -1) {
        _routes[index] = updatedRoute;
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to update route: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteRoute(String id) async {
    try {
      await _supabase.from('routes').delete().eq('id', id);
      _routes.removeWhere((r) => r.id == id);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete route: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<List<Route>> getRoutesByCollege(String collegeCode) async {
    try {
      final response = await _supabase
          .from('routes')
          .select()
          .eq('college_code', collegeCode)
          .order('created_at', ascending: false);

      return (response as List).map((json) => Route.fromJson(json)).toList();
    } catch (e) {
      _error = 'Failed to get routes by college: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<List<Route>> getRoutesByDriver(String driverId) async {
    try {
      final response = await _supabase
          .from('routes')
          .select()
          .eq('driver_id', driverId)
          .order('created_at', ascending: false);

      return (response as List).map((json) => Route.fromJson(json)).toList();
    } catch (e) {
      _error = 'Failed to get routes by driver: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggleRouteStatus(String id, bool isActive) async {
    try {
      final response = await _supabase
          .from('routes')
          .update({'is_active': isActive})
          .eq('id', id)
          .select()
          .single();

      final updatedRoute = Route.fromJson(response);
      final index = _routes.indexWhere((route) => route.id == id);
      if (index != -1) {
        _routes[index] = updatedRoute;
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to toggle route status: $e';
      notifyListeners();
      rethrow;
    }
  }

  List<Route> getRoutesForCollege(String collegeCode) {
    return _routes.where((route) => route.collegeCode == collegeCode).toList();
  }
}
