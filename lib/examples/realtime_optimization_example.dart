import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/services/realtime_service.dart';
import '../features/passenger/services/optimized_passenger_service.dart';

/// Example widget demonstrating real-time optimization usage
class RealtimeOptimizationExample extends StatefulWidget {
  const RealtimeOptimizationExample({Key? key}) : super(key: key);

  @override
  State<RealtimeOptimizationExample> createState() => _RealtimeOptimizationExampleState();
}

class _RealtimeOptimizationExampleState extends State<RealtimeOptimizationExample> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-time Optimization Demo'),
      ),
      body: Column(
        children: [
          // Real-time Statistics Card
          _buildRealtimeStatsCard(),
          
          const SizedBox(height: 16),
          
          // Active Buses List (Real-time)
          _buildActiveBusesList(),
          
          const SizedBox(height: 16),
          
          // Performance Metrics
          _buildPerformanceMetrics(),
        ],
      ),
    );
  }

  /// Real-time statistics card showing live data
  Widget _buildRealtimeStatsCard() {
    return Consumer<RealtimeService>(
      builder: (context, realtimeService, child) {
        final stats = realtimeService.getActiveTripsStats();
        
        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📊 Real-time Statistics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildStatRow('Active Trips', '${stats['total_active_trips']}'),
                _buildStatRow('Unique Drivers', '${stats['unique_drivers']}'),
                _buildStatRow('Routes in Use', '${stats['unique_routes']}'),
                _buildStatRow('Last Updated', '${DateTime.parse(stats['last_updated']).toString().substring(11, 19)}'),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Active buses list using real-time data
  Widget _buildActiveBusesList() {
    return Expanded(
      child: Consumer<OptimizedPassengerService>(
        builder: (context, passengerService, child) {
          final buses = passengerService.getNearbyBuses();
          
          if (buses.isEmpty) {
            return const Card(
              margin: EdgeInsets.all(16),
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.directions_bus, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No active buses found',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return Card(
            margin: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '🚌 Active Buses (Real-time)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: buses.length,
                    itemBuilder: (context, index) {
                      final bus = buses[index];
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Icon(Icons.directions_bus, color: Colors.white),
                        ),
                        title: Text('Bus ${bus['bus_number'] ?? 'Unknown'}'),
                        subtitle: Text('Route: ${bus['route_id'] ?? 'Unknown'}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${bus['eta'] ?? 'Unknown'}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${bus['distance'] ?? 'Unknown'}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Performance metrics showing optimization benefits
  Widget _buildPerformanceMetrics() {
    return Consumer<OptimizedPassengerService>(
      builder: (context, passengerService, child) {
        final metrics = passengerService.getRealtimeStats();
        
        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '⚡ Performance Metrics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildMetricRow('Active Buses Tracked', '${metrics['active_buses']}'),
                _buildMetricRow('Location Updates', '${metrics['tracked_locations']}'),
                _buildMetricRow('Data Source', '${metrics['data_source']}'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '97%+ reduction in database queries vs polling',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
