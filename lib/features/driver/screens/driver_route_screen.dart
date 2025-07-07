import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/navigation_service.dart';
import '../../../core/services/map_service.dart';
import '../../../core/services/trip_service.dart';
import '../../../shared/widgets/widgets.dart';

class DriverRouteScreen extends StatefulWidget {
  final String routeId;

  const DriverRouteScreen({
    Key? key,
    required this.routeId,
  }) : super(key: key);

  @override
  State<DriverRouteScreen> createState() => _DriverRouteScreenState();
}

class _DriverRouteScreenState extends State<DriverRouteScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _routeData;
  List<LatLng> _routePoints = [];
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _loadRouteData();
  }

  Future<void> _loadRouteData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tripService = Provider.of<TripService>(context, listen: false);
      final routeData = await tripService.fetchRouteInfo(widget.routeId);
      
      if (routeData != null) {
        setState(() {
          _routeData = routeData;
          _routePoints = (routeData['stops'] as List)
              .map((point) => LatLng(
                    point['latitude'] as double,
                    point['longitude'] as double,
                  ))
              .toList();
          _isLoading = false;
        });

        // Update map with route
        final mapService = Provider.of<MapService>(context, listen: false);
        await mapService.addRoute(
          points: _routePoints,
          data: {'id': 'current_route'},
          width: 5.0,
          color: AppColors.primary,
        );
      } else {
        setState(() {
          _error = 'Failed to load route data';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading route: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleNavigation() async {
    final navigationService = Provider.of<NavigationService>(context, listen: false);
    
    try {
      if (_isNavigating) {
        await navigationService.stopNavigation();
      } else {
        await navigationService.startNavigation(widget.routeId);
      }
      
      setState(() {
        _isNavigating = !_isNavigating;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Route Details')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadRouteData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_routeData?['name'] ?? 'Route Details'),
        actions: [
          IconButton(
            icon: Icon(_isNavigating ? Icons.stop : Icons.play_arrow),
            onPressed: _toggleNavigation,
            tooltip: _isNavigating ? 'Stop Navigation' : 'Start Navigation',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<NavigationService>(
              builder: (context, navigationService, child) {
                return Stack(
                  children: [
                    // Map will be shown here
                    const Center(child: Text('Map View')),
                    
                    // Navigation info overlay
                    if (_isNavigating)
                      Positioned(
                        top: 16,
                        left: 16,
                        right: 16,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Navigation Active',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Distance Traveled: ${(navigationService.distanceTraveled / 1000).toStringAsFixed(1)} km',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                if (navigationService.navigationStartTime != null)
                                  Text(
                                    'Started: ${navigationService.navigationStartTime!.toLocal().toString()}',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          
          // Route details
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Route Stops',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _routePoints.length,
                  itemBuilder: (context, index) {
                    final stop = _routeData?['stops'][index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary,
                        child: Text('${index + 1}'),
                      ),
                      title: Text(stop['name'] ?? 'Stop ${index + 1}'),
                      subtitle: Text(
                        '${stop['latitude']}, ${stop['longitude']}',
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 