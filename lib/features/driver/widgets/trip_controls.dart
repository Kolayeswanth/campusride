import 'package:flutter/material.dart';

class TripControls extends StatelessWidget {
  final bool isTripStarted;
  final bool isTracking;
  final Function() onStartTrip;
  final Function() onStopTrip;
  final Function() onToggleTracking;

  const TripControls({
    Key? key,
    required this.isTripStarted,
    required this.isTracking,
    required this.onStartTrip,
    required this.onStopTrip,
    required this.onToggleTracking,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (isTripStarted) ...[
          ElevatedButton.icon(
            onPressed: onToggleTracking,
            icon: Icon(isTracking ? Icons.pause : Icons.play_arrow),
            label: Text(isTracking ? 'Pause' : 'Resume'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isTracking ? Colors.orange : Colors.green,
            ),
          ),
          ElevatedButton.icon(
            onPressed: onStopTrip,
            icon: const Icon(Icons.stop),
            label: const Text('End Trip'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
          ),
        ] else
          ElevatedButton.icon(
            onPressed: onStartTrip,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Trip'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
            ),
          ),
      ],
    );
  }
} 