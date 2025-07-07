import 'package:flutter/material.dart';

class TripStatusCard extends StatelessWidget {
  final String? driverId;
  final String? estimatedDistance;
  final String? estimatedTime;
  final DateTime? estimatedArrivalTime;
  final bool isEditingDriverId;
  final TextEditingController driverIdController;
  final Function() onEditDriverId;
  final Function(String) onDriverIdChanged;

  const TripStatusCard({
    Key? key,
    required this.driverId,
    required this.estimatedDistance,
    required this.estimatedTime,
    required this.estimatedArrivalTime,
    required this.isEditingDriverId,
    required this.driverIdController,
    required this.onEditDriverId,
    required this.onDriverIdChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDriverIdField(),
            if (estimatedDistance != null || estimatedTime != null) ...[
              const Divider(height: 16),
              _buildRouteInfo(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDriverIdField() {
    return Row(
      children: [
        const Icon(Icons.person, size: 20),
        const SizedBox(width: 8),
        if (isEditingDriverId)
          Expanded(
            child: TextField(
              controller: driverIdController,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onSubmitted: onDriverIdChanged,
            ),
          )
        else
          Expanded(
            child: Text(
              'Driver ID: ${driverId ?? 'Not Set'}',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        IconButton(
          icon: Icon(isEditingDriverId ? Icons.check : Icons.edit),
          onPressed: onEditDriverId,
          iconSize: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _buildRouteInfo() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (estimatedDistance != null)
              Row(
                children: [
                  const Icon(Icons.directions_car, size: 16),
                  const SizedBox(width: 4),
                  Text(estimatedDistance!),
                ],
              ),
            if (estimatedTime != null)
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16),
                  const SizedBox(width: 4),
                  Text(estimatedTime!),
                ],
              ),
          ],
        ),
        if (estimatedArrivalTime != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                const Icon(Icons.schedule, size: 16),
                const SizedBox(width: 4),
                Text(
                  'ETA: ${estimatedArrivalTime!.hour.toString().padLeft(2, '0')}:${estimatedArrivalTime!.minute.toString().padLeft(2, '0')}',
                ),
              ],
            ),
          ),
      ],
    );
  }
}
