import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../models/route.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/route_model.dart';

class RouteService extends ChangeNotifier {
  final SupabaseClient _supabase;
  final String _openRouteApiKey;
  static const String _openRouteBaseUrl = 'https://api.openrouteservice.org/v2';
  List<RouteModel> _routes = [];
  bool _isLoading = false;
  String? _error;

  RouteService(this._supabase, this._openRouteApiKey);

  List<RouteModel> get routes => _routes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<List<RouteModel>> getRoutesByCollege(String collegeId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from('bus_routes')
          .select('name, start_location, end_location, active, created_at')
          .order('created_at', ascending: false);

      _routes = (response as List)
          .map((json) => RouteModel.fromJson(json))
          .toList();
      _isLoading = false;
      notifyListeners();
      return _routes;
    } catch (e) {
      _error = 'Failed to load routes: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<RouteModel> createRoute(RouteModel route) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase.from('routes').insert({
        'college_id': route.collegeId,
        'driver_id': route.driverId,
        'start_location': route.startLocation,
        'end_location': route.endLocation,
        'start_coordinates': {
          'lat': route.startCoordinates?.latitude,
          'lng': route.startCoordinates?.longitude,
        },
        'end_coordinates': {
          'lat': route.endCoordinates?.latitude,
          'lng': route.endCoordinates?.longitude,
        },
        'route_polyline': route.routePolyline,
        'is_active': route.isActive,
      }).select().single();

      final newRoute = RouteModel.fromJson(response);
      _routes.add(newRoute);
      _isLoading = false;
      notifyListeners();
      return newRoute;
    } catch (e) {
      _error = 'Failed to create route: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getRouteDirections(
      double startLat, double startLng, double endLat, double endLng) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$_openRouteBaseUrl/directions/driving-car?start=$startLng,$startLat&end=$endLng,$endLat'),
        headers: {
          'Authorization': _openRouteApiKey,
          'Accept': 'application/json, application/geo+json, application/gpx+xml, img/png; charset=utf-8',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to fetch route directions: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch route directions: $e');
    }
  }

  Future<void> updateRoute(RouteModel route) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _supabase
          .from('bus_routes')
          .update({
        'start_location': route.startLocation,
        'end_location': route.endLocation,
        'start_coordinates': {
          'lat': route.startCoordinates?.latitude,
          'lng': route.startCoordinates?.longitude,
        },
        'end_coordinates': {
          'lat': route.endCoordinates?.latitude,
          'lng': route.endCoordinates?.longitude,
        },
        'route_polyline': route.routePolyline,
        'is_active': route.isActive,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', route.id!);

      final index = _routes.indexWhere((r) => r.id == route.id);
      if (index != -1) {
        _routes[index] = route;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update route: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteRoute(String routeId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _supabase.from('routes').delete().eq('id', routeId);
      _routes.removeWhere((r) => r.id == routeId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete route: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> addRoute(RouteModel route) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // TODO: Replace with actual API call
      await Future.delayed(const Duration(seconds: 1));
      _routes.add(route);
    } catch (e) {
      _error = 'Failed to add route: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
} 