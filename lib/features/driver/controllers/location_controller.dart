import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlong2;

class LocationController {
  Position? currentPosition;
  bool isLoading = true;
  String? error;
  Timer? locationUpdateTimer;

  // Callback for when location is updated
  final Function(Position) onLocationUpdated;

  LocationController({required this.onLocationUpdated});

  // Initialize location services
  Future<void> initializeLocation() async {
    isLoading = true;
    error = null;

    try {
      // Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        error =
            'Location services are disabled. Please enable location services.';
        isLoading = false;
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          error =
              'Location permissions are denied. Please enable them in settings.';
          isLoading = false;
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        error =
            'Location permissions are permanently denied. Please enable them in settings.';
        isLoading = false;
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );

      currentPosition = position;
      isLoading = false;

      // Notify listeners
      onLocationUpdated(position);
    } catch (e) {
      error = 'Error getting location: $e';
      isLoading = false;
    }
  }

  // Start location updates
  void startLocationUpdates() {
    locationUpdateTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => updateLocation(),
    );
  }

  // Stop location updates
  void stopLocationUpdates() {
    locationUpdateTimer?.cancel();
    locationUpdateTimer = null;
  }

  // Update current location
  Future<void> updateLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );

      currentPosition = position;

      // Notify listeners
      onLocationUpdated(position);
    } catch (e) {
      print('Error updating location: $e');
    }
  }

  // Calculate distance between two points
  double calculateDistance(latlong2.LatLng point1, latlong2.LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  // Check if location services are enabled
  Future<bool> checkLocationServices() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  // Request location permission
  Future<LocationPermission> requestLocationPermission() async {
    return await Geolocator.requestPermission();
  }

  // Open location settings
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  // Open app settings
  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  // Dispose resources
  void dispose() {
    stopLocationUpdates();
  }
}
