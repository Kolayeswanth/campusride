import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// LocationService handles real-time location tracking and updates
class LocationService extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  StreamSubscription? _locationSubscription;
  bool _isTracking = false;
  String? _error;
  
  /// Current position
  Position? get currentPosition => _currentPosition;
  
  /// Whether location tracking is active
  bool get isTracking => _isTracking;
  
  /// Error message if any
  String? get error => _error;
  
  /// Start location tracking
  Future<void> startTracking(String userId, String role) async {
    if (_isTracking) return;
    
    try {
      // Check location permissions
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied) {
          throw Exception('Location permissions are required');
        }
      }
      
      // Start position updates
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      ).listen((Position position) async {
        _currentPosition = position;
        
        // Update location in Supabase
        await _updateLocation(userId, role, position);
        
        notifyListeners();
      });
      
      _isTracking = true;
      _error = null;
      notifyListeners();
      
    } catch (e) {
      _error = 'Failed to start location tracking: ${e.toString()}';
      _isTracking = false;
      notifyListeners();
    }
  }
  
  /// Stop location tracking
  Future<void> stopTracking() async {
    await _positionStream?.cancel();
    await _locationSubscription?.cancel();
    _isTracking = false;
    _currentPosition = null;
    notifyListeners();
  }
  
  /// Update location in Supabase
  Future<void> _updateLocation(String userId, String role, Position position) async {
    try {
      await _supabase.from('user_locations').upsert({
        'user_id': userId,
        'role': role,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'heading': position.heading,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      _error = 'Failed to update location: ${e.toString()}';
      notifyListeners();
    }
  }
  
  /// Subscribe to location updates for a specific role
  void subscribeToLocationUpdates(String role, Function(List<Map<String, dynamic>>) onUpdate) {
    _locationSubscription?.cancel();
    
    _locationSubscription = _supabase
      .from('user_locations')
      .stream(primaryKey: ['user_id'])
      .eq('role', role)
      .listen((data) {
        onUpdate(data);
      });
  }
  
  /// Calculate distance between two points
  double calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }
  
  /// Calculate bearing between two points
  double calculateBearing(LatLng point1, LatLng point2) {
    return Geolocator.bearingBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }
  
  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
} 