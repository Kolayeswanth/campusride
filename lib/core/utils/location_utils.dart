import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Utility class for handling location-related functionality.
class LocationUtils {
  /// Check if location services are enabled.
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Check and request location permissions.
  static Future<LocationPermission> checkPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  /// Get the current position of the device.
  static Future<Position> getCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int timeLimit = 10000,
    bool forceAndroidLocationManager = false,
  }) async {
    // Check if location service is enabled
    final isLocationEnabled = await isLocationServiceEnabled();
    if (!isLocationEnabled) {
      throw Exception('Location services are disabled. Please enable them to continue.');
    }

    // Check if permissions are granted
    final permission = await checkPermission();
    if (permission == LocationPermission.denied) {
      throw Exception('Location permission denied. Please grant permission to continue.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied. Please enable it in app settings.');
    }

    try {
      // Get position with the specified accuracy
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
        timeLimit: Duration(milliseconds: timeLimit),
        forceAndroidLocationManager: forceAndroidLocationManager,
      );
    } catch (e) {
      throw Exception('Failed to get location: $e');
    }
  }

  /// Convert Position to LatLng
  static LatLng positionToLatLng(Position position) {
    return LatLng(position.latitude, position.longitude);
  }

  /// Calculate distance between two points in meters
  static double calculateDistance(LatLng point1, LatLng point2) {
    return const Distance().as(LengthUnit.Meter, point1, point2);
  }

  /// Calculate bearing between two points in degrees
  static double calculateBearing(LatLng from, LatLng to) {
    return const Distance().bearing(from, to);
  }
} 