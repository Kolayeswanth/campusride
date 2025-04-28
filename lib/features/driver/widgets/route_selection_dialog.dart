import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart' as geo; // Import with alias
import '../../../core/services/trip_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/map_service.dart';  // Import MapService
import '../../../core/models/route.dart';

class RouteSelectionDialog extends StatefulWidget {
  final TripService tripService;
  final LocationService locationService;

  const RouteSelectionDialog({
    Key? key,
    required this.tripService,
    required this.locationService,
  }) : super(key: key);

  @override
  _RouteSelectionDialogState createState() => _RouteSelectionDialogState();
}

class _RouteSelectionDialogState extends State<RouteSelectionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _busIdController = TextEditingController();
  final _destinationController = TextEditingController();
  BusRoute? _selectedRoute;
  List<BusRoute> _routes = [];  // Use BusRoute model
  bool _isLoading = true;
  String? _error;
  LatLng? _currentLocation;
  LatLng? _selectedDestination;
  final List<Marker> _markers = []; // Use list of Marker
  final List<Polyline> _polylines = []; // Use list of Polyline
  MapController _mapController = MapController(); // Create an instance

  @override
  void initState() {
    super.initState();
    _loadRoutes();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await geo.Geolocator.getCurrentPosition( // Use alias
          desiredAccuracy: geo.LocationAccuracy.high);  // Use alias
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _updateMarkers();
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to get current location: $e';
      });
    }
  }

  void _updateMarkers() {
    _markers.clear();  // Clear the existing markers

    if (_currentLocation != null) {
      _markers.add(
        Marker(
          width: 40.0,
          height: 40.0,
          point: _currentLocation!,
          builder: (ctx) => Container(
            child: const Icon(Icons.location_pin, color: Colors.blue),
          ),
        ),
      );
    }

    if (_selectedDestination != null) {
      _markers.add(
        Marker(
          width: 40.0,
          height: 40.0,
          point: _selectedDestination!,
          builder: (ctx) => Container(
            child: const Icon(Icons.pin_drop, color: Colors.red),
          ),
        ),
      );
    }
  }

  Future<void> _loadRoutes() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final routes = await widget.tripService.loadRoutes();
      setState(() {
        _routes = routes.map((e) => e as BusRoute).toList();  // Cast routes
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load routes: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _calculateRoute() async {
    if (_currentLocation == null || _selectedDestination == null) return;
    try {
      // Use the TripService to calculate the route using OpenRouteService API
      final routePoints = await widget.tripService.calculateRoute(
        LatLng(_currentLocation!.latitude, _currentLocation!.longitude),
        LatLng(_selectedDestination!.latitude, _selectedDestination!.longitude),
      );
      
      setState(() {
        _polylines.clear();  // Clear existing polylines
        
        // If we got route points from the API, use them
        if (routePoints.isNotEmpty) {
          _polylines.add(
            Polyline(
              points: routePoints.map((point) => LatLng(point.latitude, point.longitude)).toList(),
              color: Colors.blue,
              strokeWidth: 5,
            ),
          );
        } else {
          // Fallback to a straight line if no route was returned
          _polylines.add(
            Polyline(
              points: [_currentLocation!, _selectedDestination!],
              color: Colors.blue,
              strokeWidth: 5,
            ),
          );
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to calculate route: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Start New Trip',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _busIdController,
                    decoration: const InputDecoration(
                      labelText: 'Bus Number',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a bus number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _destinationController,
                    decoration: const InputDecoration(
                      labelText: 'Destination',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      // Here you would typically implement geocoding to convert
                      // the text input to coordinates
                      // For example:
                      // _geocodeDestination(value);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : Column(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: _currentLocation == null
                                    ? const Center(
                                        child: Text('Loading map...'),
                                      )
                                    : FlutterMap(
                                        mapController: _mapController, // Use controller instance
                                        options: MapOptions(
                                          center: _currentLocation!,
                                          zoom: 15,
                                          onTap: (tapPosition, point) {
                                            setState(() {
                                              _selectedDestination = point;
                                              _updateMarkers();
                                              _calculateRoute();
                                            });
                                          },
                                        ),
                                        children: [
                                          TileLayer(
                                            urlTemplate:
                                                'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                            userAgentPackageName: 'com.example.app',
                                          ),
                                          MarkerLayer(
                                            markers: _markers, // Use _markers list
                                          ),
                                          PolylineLayer(
                                            polylines: _polylines, // Use _polylines list
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _routes.length,
                                itemBuilder: (context, index) {
                                  final route = _routes[index];
                                  return RadioListTile<BusRoute>(
                                    title: Text(route.name),
                                    subtitle: Text(
                                        '${route.startLocation} → ${route.endLocation}'),
                                    value: route,
                                    groupValue: _selectedRoute,
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedRoute = value;
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _selectedRoute == null || _selectedDestination == null
                      ? null
                      : () {
                          if (_formKey.currentState!.validate()) {
                            Navigator.pop(
                              context,
                              {
                                'busId': _busIdController.text,
                                'routeId': _selectedRoute!.id,
                                'routeName': _selectedRoute!.name,
                                'destination': _selectedDestination,
                              },
                            );
                          }
                        },
                  child: const Text('Start Trip'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _busIdController.dispose();
    _destinationController.dispose();
    _mapController.dispose(); // Dispose the map controller
    super.dispose();
  }
}
