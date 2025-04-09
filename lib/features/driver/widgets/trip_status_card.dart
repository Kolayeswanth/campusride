import 'package:flutter/material.dart';

class TripStatusCard extends StatelessWidget {
  final bool isTracking;
  final bool isTripActive;
  final String? driverId;
  final VoidCallback onStartTrip;
  final VoidCallback onToggleTracking;
  final VoidCallback onEndTrip;

  const TripStatusCard({
    Key? key,
    required this.isTracking,
    required this.isTripActive,
    this.driverId,
    required this.onStartTrip,
    required this.onToggleTracking,
    required this.onEndTrip,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Trip Status',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isTripActive ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isTripActive ? 'Active' : 'Inactive',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (driverId != null) ...[
              const SizedBox(height: 8),
              Text(
                'Driver ID: $driverId',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (!isTripActive)
                  ElevatedButton.icon(
                    onPressed: onStartTrip,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Trip'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  )
                else ...[
                  ElevatedButton.icon(
                    onPressed: onToggleTracking,
                    icon: Icon(
                      isTracking ? Icons.pause : Icons.play_arrow,
                    ),
                    label: Text(isTracking ? 'Pause' : 'Resume'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isTracking ? Colors.orange : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: onEndTrip,
                    icon: const Icon(Icons.stop),
                    label: const Text('End Trip'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
} 