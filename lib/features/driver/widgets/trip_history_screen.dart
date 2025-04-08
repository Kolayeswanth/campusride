import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/theme.dart';
import '../../../core/services/trip_service.dart';
import '../../../shared/widgets/widgets.dart';

/// TripHistoryScreen shows a list of past trips for drivers
class TripHistoryScreen extends StatelessWidget {
  const TripHistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<TripService>(
      builder: (context, tripService, _) {
        final tripHistory = tripService.tripHistory;
        
        if (tripHistory.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 64,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Trip History',
                  style: AppTypography.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your completed trips will appear here',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trip History',
                  style: AppTypography.titleLarge,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: tripHistory.length,
                    itemBuilder: (context, index) {
                      final trip = tripHistory[index];
                      return _buildTripHistoryItem(trip);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  /// Build a trip history item card
  Widget _buildTripHistoryItem(Trip trip) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  trip.routeName,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  trip.formattedDate,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            _buildInfoRow(
              icon: Icons.access_time,
              label: 'Start Time',
              value: trip.formattedStartTime,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              icon: Icons.timer,
              label: 'Duration',
              value: trip.duration,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              icon: Icons.directions_bus,
              label: 'Bus ID',
              value: trip.busId,
            ),
          ],
        ),
      ),
    );
  }
  
  /// Build an info row for trip details
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: AppTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
} 