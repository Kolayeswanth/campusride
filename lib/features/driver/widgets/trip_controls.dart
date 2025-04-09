import 'package:flutter/material.dart';

class TripControls extends StatelessWidget {
  final bool isTripStarted;
  final bool isTracking;
  final VoidCallback onStartTrip;
  final VoidCallback onToggleTracking;
  final VoidCallback? onEndTrip;

  const TripControls({
    Key? key,
    required this.isTripStarted,
    required this.isTracking,
    required this.onStartTrip,
    required this.onToggleTracking,
    this.onEndTrip,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isTripStarted ? 'Trip Controls' : 'Start a New Trip',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!isTripStarted)
                  ElevatedButton.icon(
                    onPressed: onStartTrip,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Trip'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  )
                else ...[
                  ElevatedButton.icon(
                    onPressed: onToggleTracking,
                    icon: Icon(isTracking ? Icons.pause : Icons.play_arrow),
                    label: Text(
                      isTracking ? 'Pause Tracking' : 'Resume Tracking',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isTracking ? Colors.orange : Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                  if (onEndTrip != null) ...[
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: onEndTrip,
                      icon: const Icon(Icons.stop),
                      label: const Text('End Trip'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
} 