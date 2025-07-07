import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/driver_location.dart';
import '../models/location_point.dart';

class DriverLocationService extends ChangeNotifier {
  final Map<String, DriverLocation> _locations = {};
  final Map<String, Timer> _locationTimers = {};
  final Map<String, List<LocationPoint>> _routeHistory = {};
  bool _isLoading = false;
  String? _error;

  Map<String, DriverLocation> get locations => _locations;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> startTracking(List<String> driverIds) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Request location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      // Start location tracking for each driver
      for (final driverId in driverIds) {
        _routeHistory[driverId] = [];
        _startDriverTracking(driverId);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startDriverTracking(String driverId) {
    // In a real app, this would connect to the driver's device
    // For now, we'll simulate the driver's location
    _locationTimers[driverId] = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        // Get current position
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        // Calculate speed and heading
        final speed = position.speed * 3.6; // Convert m/s to km/h
        final heading = position.heading;

        // Create location point
        final locationPoint = LocationPoint(
          latitude: position.latitude,
          longitude: position.longitude,
          timestamp: DateTime.now(),
        );

        // Update route history
        _routeHistory[driverId]?.add(locationPoint);
        if (_routeHistory[driverId]!.length > 100) {
          _routeHistory[driverId]!.removeAt(0);
        }

        // Update driver location
        _locations[driverId] = DriverLocation(
          driverId: driverId,
          latitude: position.latitude,
          longitude: position.longitude,
          timestamp: DateTime.now(),
          speed: speed,
          heading: heading,
          routePoints: _routeHistory[driverId] ?? [],
        );

        notifyListeners();
      } catch (e) {
        print('Error updating driver location: $e');
      }
    });
  }

  void stopTracking() {
    for (final timer in _locationTimers.values) {
      timer.cancel();
    }
    _locationTimers.clear();
    _locations.clear();
    _routeHistory.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
} 