import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'map_service.dart';

class NavigationService extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  MapService? _mapService;
  List<Map<String, dynamic>> _alternativeRoutes = [];
  List<Map<String, dynamic>> _trafficData = [];
  List<Map<String, dynamic>> _roadWorkAlerts = [];
  List<Map<String, dynamic>> _speedCameras = [];
  List<Map<String, dynamic>> _schoolZones = [];
  Map<String, dynamic>? _currentLaneGuidance;
  String? _currentRouteId;
  bool _isNavigating = false;
  DateTime? _navigationStartTime;
  double _distanceTraveled = 0.0;
  List<LatLng> _routeHistory = [];

  NavigationService();

  void setMapService(MapService mapService) {
    _mapService = mapService;
  }

  // Getters for navigation data
  List<Map<String, dynamic>> get alternativeRoutes => _alternativeRoutes;
  List<Map<String, dynamic>> get trafficData => _trafficData;
  List<Map<String, dynamic>> get roadWorkAlerts => _roadWorkAlerts;
  List<Map<String, dynamic>> get speedCameras => _speedCameras;
  List<Map<String, dynamic>> get schoolZones => _schoolZones;
  Map<String, dynamic>? get currentLaneGuidance => _currentLaneGuidance;
  String? get currentRouteId => _currentRouteId;
  bool get isNavigating => _isNavigating;
  DateTime? get navigationStartTime => _navigationStartTime;
  double get distanceTraveled => _distanceTraveled;
  List<LatLng> get routeHistory => _routeHistory;

  // Start navigation on a route
  Future<void> startNavigation(String routeId) async {
    try {
      final response = await _supabase
          .from('routes')
          .select()
          .eq('id', routeId)
          .single();

      _currentRouteId = routeId;
      _isNavigating = true;
      _navigationStartTime = DateTime.now();
      _distanceTraveled = 0.0;
      _routeHistory = [];

      // Update driver's current route
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await _supabase
            .from('drivers')
            .update({'current_route_id': routeId})
            .eq('id', userId);
      }

      notifyListeners();
    } catch (e) {
      print('Error starting navigation: $e');
      rethrow;
    }
  }

  // Stop navigation
  Future<void> stopNavigation() async {
    if (!_isNavigating) return;

    try {
      // Update driver's current route
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await _supabase
            .from('drivers')
            .update({'current_route_id': null})
            .eq('id', userId);

        // Save navigation history
        if (_currentRouteId != null && _routeHistory.isNotEmpty) {
          await _supabase.from('navigation_history').insert({
            'route_id': _currentRouteId,
            'driver_id': userId,
            'start_time': _navigationStartTime?.toIso8601String(),
            'end_time': DateTime.now().toIso8601String(),
            'distance_traveled': _distanceTraveled,
            'route_points': _routeHistory.map((point) => {
                  'lat': point.latitude,
                  'lng': point.longitude,
                }).toList(),
          });
        }
      }

      _currentRouteId = null;
      _isNavigating = false;
      _navigationStartTime = null;
      _distanceTraveled = 0.0;
      _routeHistory = [];
      clearNavigationData();

      notifyListeners();
    } catch (e) {
      print('Error stopping navigation: $e');
      rethrow;
    }
  }

  // Update current location during navigation
  void updateLocation(LatLng currentLocation) {
    if (!_isNavigating) return;

    _routeHistory.add(currentLocation);
    if (_routeHistory.length > 1) {
      final lastPoint = _routeHistory[_routeHistory.length - 2];
      final distance = const Distance().distance(lastPoint, currentLocation);
      _distanceTraveled += distance;
    }

    notifyListeners();
  }

  // Fetch alternative routes for a given start and destination
  Future<void> fetchAlternativeRoutes(LatLng start, LatLng destination) async {
    try {
      final response = await _supabase
          .from('alternative_routes')
          .select()
          .eq('start_lat', start.latitude)
          .eq('start_lng', start.longitude)
          .eq('dest_lat', destination.latitude)
          .eq('dest_lng', destination.longitude);

      _alternativeRoutes = List<Map<String, dynamic>>.from(response);
      notifyListeners();
    } catch (e) {
      print('Error fetching alternative routes: $e');
    }
  }

  // Fetch traffic data for a given location
  Future<void> fetchTrafficData(LatLng location, double radius) async {
    try {
      final response = await _supabase
          .from('traffic_data')
          .select()
          .filter('location', 'dwithin', {
            'point': [location.longitude, location.latitude],
            'radius': radius,
          });

      _trafficData = List<Map<String, dynamic>>.from(response);
      notifyListeners();
    } catch (e) {
      print('Error fetching traffic data: $e');
    }
  }

  // Fetch road work alerts for a given location
  Future<void> fetchRoadWorkAlerts(LatLng location, double radius) async {
    try {
      final response = await _supabase
          .from('road_work_alerts')
          .select()
          .filter('location', 'dwithin', {
            'point': [location.longitude, location.latitude],
            'radius': radius,
          });

      _roadWorkAlerts = List<Map<String, dynamic>>.from(response);
      notifyListeners();
    } catch (e) {
      print('Error fetching road work alerts: $e');
    }
  }

  // Fetch speed cameras for a given location
  Future<void> fetchSpeedCameras(LatLng location, double radius) async {
    try {
      final response = await _supabase
          .from('speed_cameras')
          .select()
          .filter('location', 'dwithin', {
            'point': [location.longitude, location.latitude],
            'radius': radius,
          });

      _speedCameras = List<Map<String, dynamic>>.from(response);
      notifyListeners();
    } catch (e) {
      print('Error fetching speed cameras: $e');
    }
  }

  // Fetch school zones for a given location
  Future<void> fetchSchoolZones(LatLng location, double radius) async {
    try {
      final response = await _supabase
          .from('school_zones')
          .select()
          .filter('location', 'dwithin', {
            'point': [location.longitude, location.latitude],
            'radius': radius,
          });

      _schoolZones = List<Map<String, dynamic>>.from(response);
      notifyListeners();
    } catch (e) {
      print('Error fetching school zones: $e');
    }
  }

  // Update lane guidance
  void updateLaneGuidance(Map<String, dynamic> guidance) {
    _currentLaneGuidance = guidance;
    notifyListeners();
  }

  // Clear all navigation data
  void clearNavigationData() {
    _alternativeRoutes = [];
    _trafficData = [];
    _roadWorkAlerts = [];
    _speedCameras = [];
    _schoolZones = [];
    _currentLaneGuidance = null;
    notifyListeners();
  }
}
