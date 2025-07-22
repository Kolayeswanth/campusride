import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart' as geo; // Import with alias
import '../../../core/services/trip_service.dart';
import '../../../core/services/location_service.dart';

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
  List<BusRoute> _routes = [];
  BusRoute? _selectedRoute;
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  LatLng? _selectedDestination;
  List<LatLng> _routePoints = [];
  List<Marker> _markers = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadRoutes();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await widget.locationService.getCurrentPosition();
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _updateMarkers();
      });
    } catch (e) {
      setState(() {
        _error = "Could not get location: $e";
      });
    }
  }

  void _updateMarkers() {
    _markers.clear(); // Clear the existing markers

    if (_currentLocation != null) {
      _markers.add(
        Marker(
          width: 40.0,
          height: 40.0,
          point: _currentLocation!,
          child: const Icon(Icons.location_pin, color: Colors.blue),
        ),
      );
    }

    if (_selectedDestination != null) {
      _markers.add(
        Marker(
          width: 40.0,
          height: 40.0,
          point: _selectedDestination!,
          child: const Icon(Icons.pin_drop, color: Colors.red),
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
      final routes = await widget.tripService.fetchDriverRoutes();
      setState(() {
        _routes = routes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = "Error loading routes: $e";
      });
    }
  }

  Future<void> _calculateRoute() async {
    if (_currentLocation == null || _selectedDestination == null) {
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      
      // Call your route calculation service here
      // Example:
      // final routePoints = await routeService.calculateRoute(_currentLocation!, _selectedDestination!);
      // setState(() {
      //   _routePoints = routePoints;
      // });
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = "Error calculating route: $e";
      });
    }
  }

  void _selectRoute(BusRoute? route) {
    setState(() {
      _selectedRoute = route;
    });
    Navigator.of(context).pop(route);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.8,
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Route',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : _buildContent(),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Map'),
              Tab(text: 'List'),
            ],
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Map Tab
                _buildMapTab(),
                // List Tab
                _buildListTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapTab() {
    return _currentLocation == null
        ? const Center(child: Text('Getting location...'))
        : Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentLocation!,
                      initialZoom: 15,
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
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.campusride',
                      ),
                      MarkerLayer(markers: _markers),
                      if (_routePoints.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _routePoints,
                              color: Colors.blue,
                              strokeWidth: 4.0,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _selectedDestination == null
                      ? 'Tap on the map to select a destination'
                      : 'Destination selected',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
  }

  Widget _buildListTab() {
    return _routes.isEmpty
        ? const Center(child: Text('No routes available'))
        : ListView.builder(
            itemCount: _routes.length,
            itemBuilder: (context, index) {
              final route = _routes[index];
              return RadioListTile<BusRoute>(
                value: route,
                groupValue: _selectedRoute,
                title: Text(route.name),
                subtitle: Text('${route.startLocation.latitude}, ${route.startLocation.longitude} → '
                    '${route.endLocation.latitude}, ${route.endLocation.longitude}'),
                onChanged: (BusRoute? value) {
                  _selectRoute(value);
                },
              );
            },
          );
  }
}
