import 'package:flutter/material.dart';

class SpeedTracker extends StatelessWidget {
  final double currentSpeed;
  final String timeToDestination;
  final String distanceRemaining;
  final bool isTracking;

  const SpeedTracker({
    Key? key,
    required this.currentSpeed,
    required this.timeToDestination,
    required this.distanceRemaining,
    required this.isTracking,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      bottom: 16,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Speed display
            Text(
              currentSpeed.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const Text(
              'km/h',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            // Time and distance info
            Text(
              timeToDestination,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            Text(
              distanceRemaining,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            // Tracking indicator
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isTracking ? Colors.green : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 