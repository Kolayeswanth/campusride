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
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: onStartTrip,
          icon: const Icon(Icons.person),
          label: const Text('Enter ID'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
          ),
        ),
      ],
    );
  }
} 