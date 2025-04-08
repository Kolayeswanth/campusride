import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/services/trip_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/models/route.dart';

class RouteSelectionDialog extends StatefulWidget {
  final TripService tripService;
  final LocationService locationService;

  const RouteSelectionDialog({
    super.key,
    required this.tripService,
    required this.locationService,
  });

  @override
  State<RouteSelectionDialog> createState() => _RouteSelectionDialogState();
}

class _RouteSelectionDialogState extends State<RouteSelectionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _busIdController = TextEditingController();
  final _destinationController = TextEditingController();
  BusRoute? _selectedRoute;
  List<BusRoute> _routes = [];
  bool _isLoading = true;
  String? _error;
  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  LatLng? _selectedDestination;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _loadRoutes();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
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
    _markers = {};
    if (_currentLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }
    if (_selectedDestination != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _selectedDestination!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
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
        _routes = routes;
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
      // Here you would typically call a directions API to get the route
      // For now, we'll just draw a straight line
      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: [_currentLocation!, _selectedDestination!],
            color: Colors.blue,
            width: 5,
          ),
        };
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
                                    : GoogleMap(
                                        initialCameraPosition: CameraPosition(
                                          target: _currentLocation!,
                                          zoom: 15,
                                        ),
                                        onMapCreated: (controller) {
                                          _mapController = controller;
                                        },
                                        markers: _markers,
                                        polylines: _polylines,
                                        onTap: (position) {
                                          setState(() {
                                            _selectedDestination = position;
                                            _updateMarkers();
                                            _calculateRoute();
                                          });
                                        },
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
                                    subtitle: Text('${route.startLocation} → ${route.endLocation}'),
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
    _mapController?.dispose();
    super.dispose();
  }
} 