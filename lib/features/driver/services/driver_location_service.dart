import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DriverLocationService {
  final Function(Position) onLocationUpdate;
  final Function(double) onSpeedUpdate;
  final Function(List<latlong2.LatLng>) onRouteUpdate;

  DriverLocationService({
    required this.onLocationUpdate,
    required this.onSpeedUpdate,
    required this.onRouteUpdate,
  });

  Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  void updateSpeed(Position newPosition, Position? lastPosition, DateTime? lastPositionTime) {
    if (lastPosition != null && lastPositionTime != null) {
      final distance = Geolocator.distanceBetween(
        lastPosition.latitude,
        lastPosition.longitude,
        newPosition.latitude,
        newPosition.longitude,
      );
      
      final timeDiff = DateTime.now().difference(lastPositionTime).inSeconds;
      if (timeDiff > 0) {
        final speedInMetersPerSecond = distance / timeDiff;
        final speedInKmPerHour = (speedInMetersPerSecond * 3.6);
        onSpeedUpdate(speedInKmPerHour);
      }
    }
  }

  Future<List<latlong2.LatLng>> calculateRoute(
    latlong2.LatLng start,
    latlong2.LatLng end,
  ) async {
    try {
      final requestBody = {
        'coordinates': [
          [start.longitude, start.latitude],
          [end.longitude, end.latitude]
        ],
        'preference': 'shortest',
        'instructions': false,
        'units': 'km',
        'geometry_simplify': false,
        'continue_straight': true
      };

      final orsApiKey = dotenv.env['ORS_API_KEY'] ?? '5b3ce3597851110001cf6248a0ac0e4cb1ac489fa0857d1c6fc7203e';
      
      final response = await http.post(
        Uri.parse('https://api.openrouteservice.org/v2/directions/driving-car/geojson'),
        headers: {
          'Authorization': orsApiKey,
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json, application/geo+json'
        },
        body: json.encode(requestBody)
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['features'] != null && 
            data['features'].isNotEmpty && 
            data['features'][0]['geometry'] != null) {
          
          final coordinates = data['features'][0]['geometry']['coordinates'] as List;
          final routePoints = coordinates.map((coord) {
            return latlong2.LatLng(coord[1] as double, coord[0] as double);
          }).toList();

          onRouteUpdate(routePoints);
          return routePoints;
        }
      }
      return [];
    } catch (e) {
      print('Error calculating route: $e');
      return [];
    }
  }

  bool hasDeviatedFromRoute(Position currentPosition, List<latlong2.LatLng> routePoints) {
    if (routePoints.isEmpty) return false;
    
    const deviationThreshold = 50.0; // meters
    double minDistance = double.infinity;
    
    for (final point in routePoints) {
      final distance = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        point.latitude,
        point.longitude,
      );
      minDistance = min(minDistance, distance);
    }
    
    return minDistance > deviationThreshold;
  }

  double calculateDistanceToDestination(
    Position currentPosition,
    latlong2.LatLng destination,
  ) {
    return Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      destination.latitude,
      destination.longitude,
    );
  }
} 