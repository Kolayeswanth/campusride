import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import '../lib/core/services/fallback_routing_service.dart';

void main() {
  group('FallbackRoutingService Tests', () {
    test('should generate valid direct route', () {
      final waypoints = [
        LatLng(28.7041, 77.1025), // Delhi
        LatLng(28.5355, 77.3910), // Noida
      ];

      final result = FallbackRoutingService.generateDirectRoute(waypoints: waypoints);

      expect(result['route_points'], isA<List<LatLng>>());
      expect(result['total_distance'], isA<double>());
      expect(result['total_duration'], isA<double>());
      expect(result['polyline_data'], isA<String>());
      expect(result['segment_distances'], isA<List<String>>());
      expect(result['is_fallback'], true);

      final routePoints = result['route_points'] as List<LatLng>;
      expect(routePoints.length, greaterThan(2));
      expect(routePoints.first.latitude, equals(waypoints.first.latitude));
      expect(routePoints.last.latitude, equals(waypoints.last.latitude));
    });

    test('should validate coordinates correctly', () {
      // Valid coordinates in India
      final validWaypoints = [
        LatLng(28.7041, 77.1025), // Delhi
        LatLng(19.0760, 72.8777), // Mumbai
      ];
      expect(FallbackRoutingService.areCoordinatesValid(validWaypoints), true);
      expect(FallbackRoutingService.areCoordinatesInIndia(validWaypoints), true);

      // Invalid coordinates (out of bounds)
      final invalidWaypoints = [
        LatLng(100.0, 200.0), // Invalid lat/lng
        LatLng(0.0, 0.0), // Null island
      ];
      expect(FallbackRoutingService.areCoordinatesValid(invalidWaypoints), false);

      // Same coordinates
      final sameWaypoints = [
        LatLng(28.7041, 77.1025),
        LatLng(28.7041, 77.1025),
      ];
      expect(FallbackRoutingService.areCoordinatesValid(sameWaypoints), false);
    });
  });
}
