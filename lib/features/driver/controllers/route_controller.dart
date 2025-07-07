import 'dart:convert';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class RouteController {
  LatLng? destinationPosition;
  List<latlong2.LatLng> routePoints = [];
  List<latlong2.LatLng> completedPoints = [];
  double completion = 0.0;
  String? estimatedDistance;
  String? estimatedTime;
  DateTime? estimatedArrivalTime;
  String timeToDestination = '--:--';
  String distanceRemaining = '-- km';

  // Deviation tracking
  double lastDeviationCheckDistance = 0.0;
  static const double deviationThreshold = 50.0; // meters
  static const double deviationCheckInterval = 100.0; // meters

  // Callback for when route is updated
  final Function(List<LatLng>) onRouteUpdated;
  final Function(List<LatLng>) onCompletedRouteUpdated;

  RouteController({
    required this.onRouteUpdated,
    required this.onCompletedRouteUpdated,
  });

  // Calculate route between two points
  Future<void> calculateRoute(
      Position currentPosition, LatLng destination) async {
    try {
      final requestBody = {
        'coordinates': [
          [currentPosition.longitude, currentPosition.latitude],
          [destination.longitude, destination.latitude]
        ],
        'preference': 'shortest',
        'instructions': false,
        'units': 'km',
        'geometry_simplify': false,
        'continue_straight': true
      };

      final orsApiKey = dotenv.env['ORS_API_KEY'] ??
          '5b3ce3597851110001cf6248a0ac0e4cb1ac489fa0857d1c6fc7203e';

      final response = await http.post(
          Uri.parse(
              'https://api.openrouteservice.org/v2/directions/driving-car/geojson'),
          headers: {
            'Authorization': orsApiKey,
            'Content-Type': 'application/json; charset=utf-8',
            'Accept': 'application/json, application/geo+json'
          },
          body: json.encode(requestBody));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['features'] != null &&
            data['features'].isNotEmpty &&
            data['features'][0]['geometry'] != null) {
          final coordinates =
              data['features'][0]['geometry']['coordinates'] as List;
          final List<LatLng> routePoints = coordinates.map((coord) {
            return LatLng(coord[1] as double, coord[0] as double);
          }).toList();

          this.routePoints = routePoints
              .map((point) => latlong2.LatLng(point.latitude, point.longitude))
              .toList();

          // Extract distance and duration from the response
          if (data['features'][0]['properties'] != null &&
              data['features'][0]['properties']['summary'] != null) {
            final summary = data['features'][0]['properties']['summary'];
            final distanceInMeters = summary['distance'] as double;
            final durationInSeconds = summary['duration'] as double;

            estimatedDistance =
                '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
            estimatedTime = _formatDuration(durationInSeconds);
            estimatedArrivalTime = DateTime.now()
                .add(Duration(seconds: durationInSeconds.toInt()));

            timeToDestination = _formatTime(estimatedArrivalTime!);
            distanceRemaining = estimatedDistance!;
          }

          // Notify listeners
          onRouteUpdated(routePoints);

          return;
        }
      }

      throw Exception('Failed to calculate route: ${response.statusCode}');
    } catch (e) {
      print('Error calculating route: $e');
      rethrow;
    }
  }

  // Recalculate route from current position
  Future<void> recalculateRouteFromCurrentPosition(
      Position currentPosition) async {
    if (destinationPosition == null) return;

    await calculateRoute(currentPosition, destinationPosition!);
  }

  // Update route completion based on current position
  void updateRouteCompletion(Position currentPosition) {
    if (routePoints.isEmpty) return;

    // Find the closest point on the route
    int closestPointIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < routePoints.length; i++) {
      final point = routePoints[i];
      final distance = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        point.latitude,
        point.longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        closestPointIndex = i;
      }
    }

    // Update completed points
    completedPoints = routePoints.sublist(0, closestPointIndex + 1);

    // Calculate completion percentage
    completion = completedPoints.length / routePoints.length;

    // Update distance remaining
    if (destinationPosition != null) {
      final distance = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        destinationPosition!.latitude,
        destinationPosition!.longitude,
      );

      distanceRemaining = '${(distance / 1000).toStringAsFixed(1)} km';
    }

    // Notify listeners
    final completedLatLngs = completedPoints
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();
    onCompletedRouteUpdated(completedLatLngs);
  }

  // Check if driver has deviated from route
  bool hasDeviatedFromRoute(Position currentPosition) {
    if (routePoints.isEmpty) return false;

    // Find the closest point on the route
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

  // Check if driver has reached destination
  bool hasReachedDestination(Position currentPosition) {
    if (destinationPosition == null) return false;

    final distance = Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      destinationPosition!.latitude,
      destinationPosition!.longitude,
    );

    return distance < 50.0; // 50 meters threshold
  }

  // Clear route
  void clearRoute() {
    destinationPosition = null;
    routePoints.clear();
    completedPoints.clear();
    completion = 0.0;
    estimatedDistance = null;
    estimatedTime = null;
    estimatedArrivalTime = null;
    timeToDestination = '--:--';
    distanceRemaining = '-- km';

    // Notify listeners
    onRouteUpdated([]);
    onCompletedRouteUpdated([]);
  }

  // Format duration in seconds to human-readable format
  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.toInt());
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '$hours h $minutes min';
    } else {
      return '$minutes min';
    }
  }

  // Format time to human-readable format
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  // Update ETA and distance
  void updateETAAndDistance(Position currentPosition) {
    if (destinationPosition == null || routePoints.isEmpty) return;

    // Calculate remaining distance
    final distance = Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      destinationPosition!.latitude,
      destinationPosition!.longitude,
    );

    distanceRemaining = '${(distance / 1000).toStringAsFixed(1)} km';

    // Update ETA based on average speed (if available)
    // This would be implemented with actual speed data
  }
}
