import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// LocationService handles real-time location tracking and sharing.
class LocationService extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  Position? _currentPosition;
  bool _isTracking = false;
  String? _error;
  StreamSubscription<Position>? _positionStreamSubscription;

  /// Current user position
  Position? get currentPosition => _currentPosition;
  
  /// Whether location services are enabled
  bool get isTracking => _isTracking;
  
  /// Error message if any
  String? get error => _error;
  
  Future<Position> getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _currentPosition = position;
      notifyListeners();
      return position;
    } catch (e) {
      _error = 'Failed to get location: $e';
      notifyListeners();
      rethrow;
    }
  }
  
  /// Start continuous location tracking
  Future<void> startTracking({required String busId}) async {
    if (_isTracking) return;

    try {
      _isTracking = true;
      notifyListeners();

      // Start location updates
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      ).listen((Position position) async {
        _currentPosition = position;
        notifyListeners();

        // Update location in database
        await _supabase.from('bus_locations').upsert({
          'bus_id': busId,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'updated_at': DateTime.now().toIso8601String(),
        });
      });
    } catch (e) {
      _error = 'Failed to start tracking: $e';
      _isTracking = false;
      notifyListeners();
      rethrow;
    }
  }
  
  /// Stop location tracking
  Future<void> stopTracking() async {
    _isTracking = false;
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    notifyListeners();
  }
  
  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
} 