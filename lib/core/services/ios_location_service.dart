import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class IOSLocationService {
  static const MethodChannel _channel = MethodChannel('campusride/location');
  
  /// Check if running on iOS
  static bool get isIOS {
    try {
      return Platform.isIOS;
    } catch (e) {
      // Fallback for web or unsupported platforms
      return false;
    }
  }
  
  /// Request location permission with iOS-specific handling
  static Future<bool> requestLocationPermission({bool background = false}) async {
    try {
      if (!isIOS) {
        // Fallback to regular permission for non-iOS
        return await _requestRegularPermission();
      }
      
      // Check if location services are enabled first
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (kDebugMode) {
          print('Location services are disabled');
        }
        return false;
      }
      
      // Check current permission status
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.deniedForever) {
        if (kDebugMode) {
          print('Location permission denied forever');
        }
        return false;
      }
      
      // For iOS, background location handling
      if (background && permission == LocationPermission.whileInUse) {
        // On iOS, we can't directly upgrade to "always" permission
        // The user must do this in Settings
        if (kDebugMode) {
          print('Background location requires "Always" permission in Settings');
        }
      }
      
      return permission == LocationPermission.always || 
             permission == LocationPermission.whileInUse;
             
    } catch (e) {
      if (kDebugMode) {
        print('Error requesting iOS location permission: $e');
      }
      return await _requestRegularPermission();
    }
  }
  
  /// Request regular location permission
  static Future<bool> _requestRegularPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      return permission == LocationPermission.always || 
             permission == LocationPermission.whileInUse;
             
    } catch (e) {
      print('Error requesting location permission: $e');
      return false;
    }
  }
  
  /// Show explanation for background location (iOS requirement)
  static Future<void> _showBackgroundLocationExplanation() async {
    // This should be called from the UI layer to show a dialog
    // explaining why background location is needed
  }
  
  /// Get current location with iOS-specific settings
  static Future<LatLng?> getCurrentLocation() async {
    try {
      // Check permission first
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        if (kDebugMode) {
          print('Location permission not granted');
        }
        return null;
      }
      
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (kDebugMode) {
          print('Location services are disabled');
        }
        return null;
      }
      
      // Get location with iOS-optimized settings
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: isIOS 
            ? LocationAccuracy.bestForNavigation 
            : LocationAccuracy.high,
        timeLimit: Duration(seconds: isIOS ? 30 : 15), // Longer timeout for iOS
      );
      
      return LatLng(position.latitude, position.longitude);
      
    } catch (e) {
      if (kDebugMode) {
        print('Error getting current location: $e');
      }
      return null;
    }
  }
  
  /// Get location stream with iOS-specific settings
  static Stream<LatLng> getLocationStream({bool background = false}) {
    try {
      return Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: isIOS 
              ? LocationAccuracy.bestForNavigation 
              : LocationAccuracy.high,
          distanceFilter: isIOS ? 3 : 5, // More sensitive on iOS
          timeLimit: Duration(seconds: isIOS ? 30 : 15), // Longer timeout for iOS
        ),
      ).handleError((error) {
        if (kDebugMode) {
          print('Location stream error: $error');
        }
      }).map((position) => LatLng(position.latitude, position.longitude));
    } catch (e) {
      if (kDebugMode) {
        print('Error creating location stream: $e');
      }
      // Return empty stream on error
      return Stream.empty();
    }
  }
  
  /// Check if location services are enabled
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }
  
  /// Open location settings
  static Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }
  
  /// Get permission status
  static Future<LocationPermission> getPermissionStatus() async {
    return await Geolocator.checkPermission();
  }
  
  /// Check if background location is available
  static Future<bool> hasBackgroundLocationPermission() async {
    final permission = await getPermissionStatus();
    return permission == LocationPermission.always;
  }
}