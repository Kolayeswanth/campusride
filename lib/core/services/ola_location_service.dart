import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class OlaLocationService {
  static const String _baseUrl = 'https://api.olamaps.io';
  static const String _apiKey = 'u8bxvlb9ubgP2wKgJyxEY2ya1hYNcvyxFDCpA85y';
  
  /// Get current location using device GPS
  static Future<LatLng?> getCurrentLocation() async {
    try {
      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied');
        return null;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      );

      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  /// Get location stream for real-time tracking
  static Stream<LatLng> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters
        timeLimit: Duration(seconds: 15),
      ),
    ).map((position) => LatLng(position.latitude, position.longitude));
  }

  /// Reverse geocode using Ola Maps API
  static Future<String?> reverseGeocode(LatLng location) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/places/v1/reverse-geocode?latlng=${location.latitude},${location.longitude}&api_key=$_apiKey'
      );

      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          return data['results'][0]['formatted_address'];
        }
      }
      
      return null;
    } catch (e) {
      print('Error in reverse geocoding: $e');
      return null;
    }
  }

  /// Calculate route using Ola Maps Directions API
  static Future<Map<String, dynamic>?> getDirections({
    required LatLng origin,
    required LatLng destination,
    String mode = 'DRIVING',
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/routing/v1/directions');
      
      final body = json.encode({
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'mode': mode,
        'alternatives': false,
        'steps': true,
        'language': 'en',
      });

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Request-Id': DateTime.now().millisecondsSinceEpoch.toString(),
        },
        body: body,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      
      return null;
    } catch (e) {
      print('Error getting directions: $e');
      return null;
    }
  }

  /// Calculate distance and ETA between two points
  static Future<Map<String, dynamic>?> getDistanceMatrix({
    required List<LatLng> origins,
    required List<LatLng> destinations,
    String mode = 'DRIVING',
  }) async {
    try {
      final originsStr = origins.map((e) => '${e.latitude},${e.longitude}').join('|');
      final destinationsStr = destinations.map((e) => '${e.latitude},${e.longitude}').join('|');
      
      final url = Uri.parse(
        '$_baseUrl/routing/v1/distanceMatrix?origins=$originsStr&destinations=$destinationsStr&mode=$mode&api_key=$_apiKey'
      );

      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      
      return null;
    } catch (e) {
      print('Error getting distance matrix: $e');
      return null;
    }
  }

  /// Snap coordinates to nearest road using Ola Maps Roads API
  static Future<List<LatLng>?> snapToRoad(List<LatLng> coordinates) async {
    try {
      final pathStr = coordinates.map((e) => '${e.latitude},${e.longitude}').join('|');
      
      final url = Uri.parse(
        '$_baseUrl/routing/v1/snapToRoad?path=$pathStr&interpolate=true&api_key=$_apiKey'
      );

      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['snappedPoints'] != null) {
          return (data['snappedPoints'] as List).map((point) {
            final location = point['location'];
            return LatLng(location['latitude'], location['longitude']);
          }).toList();
        }
      }
      
      return null;
    } catch (e) {
      print('Error snapping to road: $e');
      return null;
    }
  }

  /// Get nearby places using Ola Maps Places API
  static Future<List<Map<String, dynamic>>?> getNearbyPlaces({
    required LatLng location,
    int radius = 1000,
    String type = 'bus_station',
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/places/v1/nearbysearch?location=${location.latitude},${location.longitude}&radius=$radius&types=$type&api_key=$_apiKey'
      );

      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['predictions'] != null) {
          return List<Map<String, dynamic>>.from(data['predictions']);
        }
      }
      
      return null;
    } catch (e) {
      print('Error getting nearby places: $e');
      return null;
    }
  }

  /// Enhanced ETA calculation using real traffic data
  static Future<String> calculateETAWithTraffic({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      final distanceMatrix = await getDistanceMatrix(
        origins: [origin],
        destinations: [destination],
        mode: 'DRIVING',
      );

      if (distanceMatrix != null && 
          distanceMatrix['rows'] != null && 
          distanceMatrix['rows'].isNotEmpty) {
        
        final element = distanceMatrix['rows'][0]['elements'][0];
        if (element['status'] == 'OK') {
          final duration = element['duration_in_traffic'] ?? element['duration'];
          return _formatDuration(duration['value']);
        }
      }
      
      // Fallback to simple calculation
      final distance = Geolocator.distanceBetween(
        origin.latitude, origin.longitude,
        destination.latitude, destination.longitude,
      );
      
      final timeMinutes = (distance / 1000 / 25 * 60).round(); // 25 km/h average
      return _formatDuration(timeMinutes * 60);
      
    } catch (e) {
      print('Error calculating ETA: $e');
      return 'Unknown';
    }
  }

  static String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    if (minutes < 1) {
      return 'Arriving now';
    } else if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '${hours}h ${mins}m';
    }
  }
}
