import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../services/navigation_service.dart';
import '../services/map_service.dart';

class NavigationOverlay extends StatelessWidget {
  const NavigationOverlay({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final navigationService = Provider.of<NavigationService>(context);
    final mapService = Provider.of<MapService>(context);

    return Stack(
      children: [
        // Traffic density visualization
        ...navigationService.trafficData.map((traffic) {
          final position = LatLng(
            traffic['location']['lat'],
            traffic['location']['lng'],
          );
          final density = traffic['density'] as double;
          final color = _getTrafficColor(density);

          return Positioned(
            left: position.longitude,
            top: position.latitude,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: color.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
            ),
          );
        }).toList(),

        // Road work alerts
        ...navigationService.roadWorkAlerts.map((alert) {
          final position = LatLng(
            alert['location']['lat'],
            alert['location']['lng'],
          );

          return Positioned(
            left: position.longitude,
            top: position.latitude,
            child: const Icon(
              Icons.construction,
              color: Colors.orange,
              size: 24,
            ),
          );
        }).toList(),

        // Speed cameras
        ...navigationService.speedCameras.map((camera) {
          final position = LatLng(
            camera['location']['lat'],
            camera['location']['lng'],
          );

          return Positioned(
            left: position.longitude,
            top: position.latitude,
            child: const Icon(
              Icons.speed,
              color: Colors.red,
              size: 24,
            ),
          );
        }).toList(),

        // School zones
        ...navigationService.schoolZones.map((zone) {
          final position = LatLng(
            zone['location']['lat'],
            zone['location']['lng'],
          );

          return Positioned(
            left: position.longitude,
            top: position.latitude,
            child: const Icon(
              Icons.school,
              color: Colors.yellow,
              size: 24,
            ),
          );
        }).toList(),

        // Lane guidance
        if (navigationService.currentLaneGuidance != null)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Icon(
                      _getLaneGuidanceIcon(
                          navigationService.currentLaneGuidance!['direction']),
                      size: 32,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        navigationService.currentLaneGuidance!['instruction'],
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Color _getTrafficColor(double density) {
    if (density < 0.3) return Colors.green;
    if (density < 0.6) return Colors.yellow;
    if (density < 0.8) return Colors.orange;
    return Colors.red;
  }

  IconData _getLaneGuidanceIcon(String direction) {
    switch (direction.toLowerCase()) {
      case 'left':
        return Icons.turn_left;
      case 'right':
        return Icons.turn_right;
      case 'straight':
        return Icons.straight;
      case 'merge':
        return Icons.merge;
      default:
        return Icons.directions;
    }
  }
}
