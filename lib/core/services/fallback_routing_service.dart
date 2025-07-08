import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'dart:math' as math;

class FallbackRoutingService {
  /// Generates a simple direct route between waypoints when external routing services fail
  /// This creates a straight line route with basic distance and duration estimates
  static Map<String, dynamic> generateDirectRoute({
    required List<LatLng> waypoints,
  }) {
    if (waypoints.length < 2) {
      throw Exception('At least 2 waypoints are required');
    }

    final Distance distance = Distance();
    
    // Create route points (we'll add some intermediate points for a more natural look)
    final List<LatLng> routePoints = [];
    final List<String> segmentDistances = [];
    double totalDistance = 0.0;
    double totalDuration = 0.0;
    
    for (int i = 0; i < waypoints.length - 1; i++) {
      final start = waypoints[i];
      final end = waypoints[i + 1];
      
      // Calculate distance for this segment
      final segmentDistance = distance.as(LengthUnit.Kilometer, start, end);
      totalDistance += segmentDistance;
      
      // Estimate duration (assuming average speed of 40 km/h for mixed driving conditions)
      final segmentDuration = (segmentDistance / 40.0) * 3600; // seconds
      totalDuration += segmentDuration;
      
      segmentDistances.add('${segmentDistance.toStringAsFixed(1)} km');
      
      // Add start point if it's the first segment
      if (i == 0) {
        routePoints.add(start);
      }
      
      // Add intermediate points to make the route look more natural
      final numIntermediatePoints = math.max(2, (segmentDistance * 10).round().clamp(2, 20));
      
      for (int j = 1; j <= numIntermediatePoints; j++) {
        final ratio = j / (numIntermediatePoints + 1);
        final intermediateLat = start.latitude + (end.latitude - start.latitude) * ratio;
        final intermediateLng = start.longitude + (end.longitude - start.longitude) * ratio;
        
        // Add some minor randomness to make it look less perfectly straight
        final randomOffset = 0.0001; // Very small offset
        final latOffset = (math.Random().nextDouble() - 0.5) * randomOffset;
        final lngOffset = (math.Random().nextDouble() - 0.5) * randomOffset;
        
        routePoints.add(LatLng(
          intermediateLat + latOffset,
          intermediateLng + lngOffset,
        ));
      }
      
      // Add end point
      routePoints.add(end);
    }
    
    // Create polyline data (coordinates in [lng, lat] format for consistency with ORS)
    final polylineCoordinates = routePoints.map((point) => [point.longitude, point.latitude]).toList();
    
    return {
      'route_points': routePoints,
      'total_distance': totalDistance,
      'total_duration': totalDuration,
      'polyline_data': jsonEncode(polylineCoordinates),
      'segment_distances': segmentDistances,
      'is_fallback': true, // Flag to indicate this is a fallback route
    };
  }
  
  /// Validates that coordinates are reasonable for routing
  static bool areCoordinatesValid(List<LatLng> waypoints) {
    if (waypoints.length < 2) return false;
    
    for (final point in waypoints) {
      // Check if coordinates are within valid ranges
      if (point.latitude < -90 || point.latitude > 90 || 
          point.longitude < -180 || point.longitude > 180) {
        return false;
      }
      
      // Check if coordinates are not at exactly 0,0 (likely an error)
      if (point.latitude == 0.0 && point.longitude == 0.0) {
        return false;
      }
    }
    
    // Check if all points are not the same
    final firstPoint = waypoints.first;
    for (final point in waypoints.skip(1)) {
      if ((point.latitude - firstPoint.latitude).abs() > 0.0001 ||
          (point.longitude - firstPoint.longitude).abs() > 0.0001) {
        return true; // Found at least one different point
      }
    }
    
    return false; // All points are essentially the same
  }
  
  /// Estimates if waypoints are in a reasonable geographical area (e.g., India)
  static bool areCoordinatesInIndia(List<LatLng> waypoints) {
    // Rough bounds for India
    const double minLat = 6.0;
    const double maxLat = 37.0;
    const double minLng = 68.0;
    const double maxLng = 98.0;
    
    for (final point in waypoints) {
      if (point.latitude < minLat || point.latitude > maxLat ||
          point.longitude < minLng || point.longitude > maxLng) {
        return false;
      }
    }
    return true;
  }
}
