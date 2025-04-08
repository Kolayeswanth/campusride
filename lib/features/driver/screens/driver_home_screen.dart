import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/trip_service.dart';
import '../../../core/services/location_service.dart';
import '../widgets/route_selection_dialog.dart';
import 'driver_map_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  List<Map<String, dynamic>> _previousTrips = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPreviousTrips();
  }

  Future<void> _loadPreviousTrips() async {
    final authService = context.read<AuthService>();
    final tripService = context.read<TripService>();
    final driverId = authService.currentUser?.id;

    if (driverId == null) {
      setState(() {
        _error = 'Driver ID not found';
        _isLoading = false;
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final trips = await tripService.getTripHistory(driverId);
      setState(() {
        _previousTrips = trips;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load previous trips: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _startTrip() async {
    final authService = context.read<AuthService>();
    final tripService = context.read<TripService>();
    final locationService = context.read<LocationService>();
    final driverId = authService.currentUser?.id;

    if (driverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver ID not found')),
      );
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => RouteSelectionDialog(
        tripService: tripService,
        locationService: locationService,
      ),
    );

    if (result == null) return;

    try {
      final busId = result['busId'] as String;
      final routeId = result['routeId'] as String;
      final routeName = result['routeName'] as String;
      final destination = result['destination'] as LatLng;

      await tripService.startTrip(
        driverId: driverId,
        busId: busId,
        routeName: routeName,
      );

      await tripService.saveTripHistory(
        driverId: driverId,
        busId: busId,
        routeId: routeId,
        routeName: routeName,
        destination: destination,
      );

      await locationService.startTracking(busId: busId);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DriverMapScreen(
            busId: busId,
            routeName: routeName,
            destination: destination,
          ),
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip started successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start trip: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPreviousTrips,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton(
                        onPressed: _startTrip,
                        child: const Text('Start New Trip'),
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _previousTrips.length,
                        itemBuilder: (context, index) {
                          final trip = _previousTrips[index];
                          return ListTile(
                            title: Text('Bus ${trip['bus_id']}'),
                            subtitle: Text(
                              'Route: ${trip['route_name']}\n'
                              'Started: ${DateTime.parse(trip['start_time']).toString()}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.replay),
                              onPressed: () {
                                // TODO: Implement replay functionality
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}