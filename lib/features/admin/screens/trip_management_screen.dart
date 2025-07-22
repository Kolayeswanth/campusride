import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:campusride/core/services/trip_service.dart';
import 'package:campusride/core/theme/app_colors.dart';

class TripManagementScreen extends StatefulWidget {
  const TripManagementScreen({Key? key}) : super(key: key);

  @override
  State<TripManagementScreen> createState() => _TripManagementScreenState();
}

class _TripManagementScreenState extends State<TripManagementScreen> {
  Map<String, dynamic>? _stats;
  bool _isLoading = false;
  String? _error;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tripService = context.read<TripService>();
      final stats = await tripService.getOngoingRidesStats();
      
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load stats: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _stopAllRides() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop All Ongoing Rides'),
        content: const Text(
          'Are you sure you want to stop ALL ongoing rides? This action cannot be undone.\n\n'
          'All active drivers will be notified and their trips will be marked as completed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Stop All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final tripService = context.read<TripService>();
      final result = await tripService.stopAllOngoingRides(
        reason: 'Admin emergency stop',
      );

      setState(() {
        _isLoading = false;
        if (result['success']) {
          _successMessage = result['message'];
        } else {
          _error = result['message'];
        }
      });

      // Reload stats after stopping rides
      await _loadStats();
    } catch (e) {
      setState(() {
        _error = 'Failed to stop rides: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _stopSpecificTrip(String tripId, String driverId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Specific Trip'),
        content: Text(
          'Are you sure you want to stop the trip for driver $driverId?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Stop Trip'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final tripService = context.read<TripService>();
      final result = await tripService.stopSpecificTrip(
        tripId,
        reason: 'Admin action',
      );

      setState(() {
        _isLoading = false;
        if (result['success']) {
          _successMessage = 'Trip stopped successfully';
        } else {
          _error = result['message'];
        }
      });

      // Reload stats after stopping trip
      await _loadStats();
    } catch (e) {
      setState(() {
        _error = 'Failed to stop trip: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Success/Error Messages
            if (_successMessage != null)
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: TextStyle(color: Colors.green.shade700),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _successMessage = null),
                      ),
                    ],
                  ),
                ),
              ),
            
            if (_error != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _error = null),
                      ),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 16),

            // Statistics Overview
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Current Statistics',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_isLoading)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    if (_stats != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatCard(
                            title: 'Active Trips',
                            value: _stats!['total_active_trips']?.toString() ?? '0',
                            icon: Icons.directions_bus,
                            color: AppColors.primary,
                          ),
                          _StatCard(
                            title: 'Active Drivers',
                            value: _stats!['unique_drivers']?.toString() ?? '0',
                            icon: Icons.person,
                            color: Colors.green,
                          ),
                          _StatCard(
                            title: 'Routes in Use',
                            value: _stats!['unique_routes']?.toString() ?? '0',
                            icon: Icons.route,
                            color: Colors.orange,
                          ),
                        ],
                      ),
                    ] else if (!_isLoading && _error == null) ...[
                      const Center(
                        child: Text('No statistics available'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),

            // Emergency Actions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Emergency Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _stopAllRides,
                        icon: const Icon(Icons.stop_circle),
                        label: const Text('Stop All Ongoing Rides'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    const Text(
                      '⚠️ This will immediately stop all active trips and mark them as completed.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),

            // Active Trips List
            if (_stats != null && _stats!['trip_details'] != null && _stats!['trip_details'].isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Active Trips Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      ..._stats!['trip_details'].map<Widget>((trip) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary,
                              child: Text(
                                trip['bus_number']?.toString().substring(0, 1) ?? 'B',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text('Bus: ${trip['bus_number'] ?? 'N/A'}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Driver: ${trip['driver_id']}'),
                                Text('Route: ${trip['route_id']}'),
                                Text('Duration: ${trip['duration_minutes']} minutes'),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.stop, color: Colors.red),
                              onPressed: _isLoading
                                  ? null
                                  : () => _stopSpecificTrip(
                                        trip['trip_id'],
                                        trip['driver_id'],
                                      ),
                              tooltip: 'Stop this trip',
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ] else if (_stats != null && (_stats!['trip_details'] == null || _stats!['trip_details'].isEmpty)) ...[
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 48,
                          color: Colors.green,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No Active Trips',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'All drivers are currently offline',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
