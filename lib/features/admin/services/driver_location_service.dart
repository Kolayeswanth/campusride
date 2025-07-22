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
      // In a real-world app, we'd check permissions for location access
      // For the simulation mode, we'll skip this and just create simulated data
      // Request location permissions
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            debugPrint('Location permissions are denied, using simulation mode');
          }
        }

        if (permission == LocationPermission.deniedForever) {
          debugPrint('Location permissions are permanently denied, using simulation mode');
        }
      } catch (e) {
        debugPrint('Error checking location permissions: $e. Using simulation mode.');
      }

      // Start location tracking for each driver
      debugPrint('Starting tracking for ${driverIds.length} drivers');
      for (final driverId in driverIds) {
        _routeHistory[driverId] = [];
        _startDriverTracking(driverId);
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error in startTracking: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startDriverTracking(String driverId) {
    // In a real app, this would connect to the driver's device
    // For now, we'll simulate the driver's location with some randomness
    
    // Starting with a position in central Hyderabad (or modify for your campus)
    double baseLat = 17.385044;
    double baseLng = 78.486671;
    
    // Add some randomness for each driver
    baseLat += (driverId.hashCode % 100) / 10000.0;
    baseLng += (driverId.hashCode % 100) / 10000.0;
    
    // Small increments to simulate movement
    double latIncrement = (driverId.hashCode % 10 - 5) / 10000.0; // Random drift
    double lngIncrement = (driverId.hashCode % 10 - 5) / 10000.0; // Random drift
    
    // Track current position for this driver
    double currentLat = baseLat;
    double currentLng = baseLng;
    double currentSpeed = 0.0;
    double currentHeading = 0.0;
    
    _locationTimers[driverId] = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        // In production, we would get the driver's actual position
        // For simulation, we'll use our simulated position
        
        // Update position with small random changes
        currentLat += latIncrement;
        currentLng += lngIncrement;
        
        // Simulate some speed variation (0-60 km/h)
        currentSpeed = 20 + (DateTime.now().millisecondsSinceEpoch % 400) / 10;
        
        // Calculate heading based on movement direction
        if (latIncrement != 0 || lngIncrement != 0) {
          currentHeading = (180 / 3.14159) * 
              (latIncrement.abs() > lngIncrement.abs() 
                ? (latIncrement > 0 ? 0 : 180) 
                : (lngIncrement > 0 ? 90 : 270));
        }

        // Create location point
        final locationPoint = LocationPoint(
          latitude: currentLat,
          longitude: currentLng,
          timestamp: DateTime.now(),
        );

        // Update route history
        _routeHistory[driverId] ??= [];
        _routeHistory[driverId]!.add(locationPoint);
        if (_routeHistory[driverId]!.length > 100) {
          _routeHistory[driverId]!.removeAt(0);
        }

        // Update driver location
        _locations[driverId] = DriverLocation(
          driverId: driverId,
          latitude: currentLat,
          longitude: currentLng,
          timestamp: DateTime.now(),
          speed: currentSpeed,
          heading: currentHeading,
          routePoints: _routeHistory[driverId] ?? [],
        );

        notifyListeners();
        
        // Add some randomness to the increments occasionally to create more natural paths
        if (DateTime.now().second % 10 == 0) {
          latIncrement = (driverId.hashCode % 10 - 5) / 10000.0;
          lngIncrement = (driverId.hashCode % 10 - 5) / 10000.0;
        }
      } catch (e) {
        debugPrint('Error updating driver location: $e');
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