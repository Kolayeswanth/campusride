import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../utils/logger_util.dart';

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
          throw Exception(
              'Location permissions are permanently denied. Please enable them from the app settings.');
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

  Future<void> _updateLocation(
      String userId, String role, Position position) async {
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
      LoggerUtil.error('Error updating location', e);
      _error = 'Failed to update location';
      notifyListeners();
    }
  }

  void subscribeToLocationUpdates(
      String role, Function(List<Map<String, dynamic>>) onUpdate) {
    _locationSubscription?.cancel();

    _locationSubscription = _supabase
        .from('user_locations')
        .stream(primaryKey: ['user_id'])
        .eq('role', role)
        .listen((data) {
          onUpdate(data);
        }, onError: (error) {
          LoggerUtil.error('Error subscribing to location updates', error);
        });
  }

  double calculateDistance(LatLng point1, LatLng point2) {
    // Calculate distance using the Haversine formula
    const double earthRadius = 6371000; // in meters
    final lat1 = point1.latitude * (math.pi / 180);
    final lat2 = point2.latitude * (math.pi / 180);
    final dLat = (point2.latitude - point1.latitude) * (math.pi / 180);
    final dLon = (point2.longitude - point1.longitude) * (math.pi / 180);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c; // distance in meters
  }

  double calculateBearing(LatLng point1, LatLng point2) {
    final dLon = (point2.longitude - point1.longitude) * (math.pi / 180);
    final lat1 = point1.latitude * (math.pi / 180);
    final lat2 = point2.latitude * (math.pi / 180);
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return math.atan2(y, x);
  }

  /// Get the current position once
  Future<Position> getCurrentPosition() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied) {
          throw Exception('Location permissions are required');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }
      
      final position = await Geolocator.getCurrentPosition();
      _currentPosition = position;
      return position;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      throw Exception('Could not get current location: $e');
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }
}
