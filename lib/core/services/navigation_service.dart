import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
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

  // Fetch real-time traffic data
  Future<void> fetchTrafficData(LatLng center, double radius) async {
    try {
      final response = await _supabase
          .from('traffic_data')
          .select()
          .filter('location', 'st_dwithin', {
            'point': [center.latitude, center.longitude],
            'distance': radius,
          });

      _trafficData = List<Map<String, dynamic>>.from(response);
      notifyListeners();
    } catch (e) {
      print('Error fetching traffic data: $e');
    }
  }

  // Fetch road work alerts
  Future<void> fetchRoadWorkAlerts(LatLng center, double radius) async {
    try {
      final response = await _supabase
          .from('road_work_alerts')
          .select()
          .filter('location', 'st_dwithin', {
            'point': [center.latitude, center.longitude],
            'distance': radius,
          });

      _roadWorkAlerts = List<Map<String, dynamic>>.from(response);
      notifyListeners();
    } catch (e) {
      print('Error fetching road work alerts: $e');
    }
  }

  // Fetch speed cameras
  Future<void> fetchSpeedCameras(LatLng center, double radius) async {
    try {
      final response = await _supabase
          .from('speed_cameras')
          .select()
          .filter('location', 'st_dwithin', {
            'point': [center.latitude, center.longitude],
            'distance': radius,
          });

      _speedCameras = List<Map<String, dynamic>>.from(response);
      notifyListeners();
    } catch (e) {
      print('Error fetching speed cameras: $e');
    }
  }

  // Fetch school zones
  Future<void> fetchSchoolZones(LatLng center, double radius) async {
    try {
      final response = await _supabase
          .from('school_zones')
          .select()
          .filter('location', 'st_dwithin', {
            'point': [center.latitude, center.longitude],
            'distance': radius,
          });

      _schoolZones = List<Map<String, dynamic>>.from(response);
      notifyListeners();
    } catch (e) {
      print('Error fetching school zones: $e');
    }
  }

  // Update lane guidance based on current route
  void updateLaneGuidance(Map<String, dynamic>? guidance) {
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