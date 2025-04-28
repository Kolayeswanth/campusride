import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  StreamSubscription? _locationSubscription;
  bool _isTracking = false;
  String? _error;
  
  Position? get currentPosition => _currentPosition;
  bool get isTracking => _isTracking;
  String? get error => _error;
  
  Future<void> startTracking(String userId, String role) async {
    if (_isTracking) return;
    
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied) {
          throw Exception('Location permissions are required');
        } else if (requested == LocationPermission.deniedForever) {
          throw Exception('Location permissions are permanently denied. Please enable them from the app settings.');
        }
      }
      
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((Position position) async {
        _currentPosition = position;
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
  
  Future<void> stopTracking() async {
    _positionStream?.cancel();
    _locationSubscription?.cancel();
    _isTracking = false;
    _currentPosition = null;
    notifyListeners();
  }
  
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
      print('Error updating location: $e');
      _error = 'Failed to update location';
      notifyListeners();
    }
  }
  
  void subscribeToLocationUpdates(String role, Function(List<Map<String, dynamic>>) onUpdate) {
    _locationSubscription?.cancel();
    
    _locationSubscription = _supabase
      .from('user_locations')
      .stream(primaryKey: ['user_id'])
      .eq('role', role)
      .listen((data) {
        onUpdate(data);
      }, onError: (error) {
        print('Error subscribing to location updates: $error');
      });
  }
  
  double calculateDistance(LatLng point1, LatLng point2) {
    return point1.distanceTo(point2);
  }
  
  double calculateBearing(LatLng point1, LatLng point2) {
    final dLon = point2.longitude - point1.longitude;
    final y = sin(dLon) * cos(point2.latitude);
    final x = cos(point1.latitude) * sin(point2.latitude) -
        sin(point1.latitude) * cos(point2.latitude) * cos(dLon);
    return atan2(y, x);
  }
  
  @override
  void dispose() {
    _positionStream?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }
}
