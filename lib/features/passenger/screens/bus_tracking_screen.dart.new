import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';
import 'package:campusride/core/services/map_service.dart';
import 'package:campusride/core/services/trip_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';

class BusTrackingScreen extends StatefulWidget {
  final String busId;
  final String routeId;

  const BusTrackingScreen({
    Key? key,
    required this.busId,
    required this.routeId,
  }) : super(key: key);

  @override
  State<BusTrackingScreen> createState() => _BusTrackingScreenState();
}

class _BusTrackingScreenState extends State<BusTrackingScreen> {
  late MapService _mapService;
  late TripService _tripService;
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _busStops = [];
  MaplibreMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _mapService = Provider.of<MapService>(context, listen: false);
    _tripService = Provider.of<TripService>(context, listen: false);
    _initializeTracking();
  }

  Future<void> _initializeTracking() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get route information and bus stops
      final routeInfo = await _tripService.fetchRouteInfo(widget.routeId);

      if (routeInfo != null && routeInfo.containsKey('stops')) {
        setState(() {
          _busStops = List<Map<String, dynamic>>.from(routeInfo['stops']);
        });
      }

      // Start tracking this bus
      _mapService.subscribeToBusLocation(widget.busId);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to initialize tracking: $e';
      });
    }
  }

  @override
  void dispose() {
    // Stop tracking when screen is closed
    _mapService.unsubscribeFromBusLocation(widget.busId);
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _onMapCreated(MaplibreMapController controller) async {
    _mapController = controller;
    _mapService.onMapCreated(controller);
    await _addBusStopsToMap();

    // Request location permission and update current location
    try {
      final position = await _mapService.getCurrentLocation();
      if (position.latitude != 0 && position.longitude != 0) {
        controller.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude),
            15.0,
          ),
        );
      } else {
        // If we couldn't get location, focus on the first bus stop
        if (_busStops.isNotEmpty) {
          final firstStop = _busStops.first;
          controller.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(
                firstStop['latitude'] as double,
                firstStop['longitude'] as double
              ),
              15.0,
            ),
          );
        }
      }
    } catch (e) {
      print('Error getting location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get your location. Showing route instead.')),
      );

      // Focus on the first bus stop if we can't get location
      if (_busStops.isNotEmpty) {
        final firstStop = _busStops.first;
        controller.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(
              firstStop['latitude'] as double,
              firstStop['longitude'] as double
            ),
            15.0,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bus ${widget.busId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeTracking,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeTracking,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Consumer<MapService>(
      builder: (context, mapService, child) {
        final currentLocation = mapService.currentLocation ?? const LatLng(0, 0);

        return Stack(
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: MaplibreMap(
                initialCameraPosition: CameraPosition(
                  target: currentLocation.latitude != 0 && currentLocation.longitude != 0
                      ? currentLocation
                      : const LatLng(33.7756, -84.3963), // Default location if current is not available
                  zoom: 15.0,
                ),
                styleString: kIsWeb
                    ? 'https://api.maptiler.com/maps/streets/style.json?key=X2gh37rGOvC2FnGm7GYy'
                    : 'asset://assets/map_style.json',
                myLocationEnabled: true,
                myLocationTrackingMode: MyLocationTrackingMode.Tracking,
                trackCameraPosition: true,
                onMapCreated: _onMapCreated,
                onMapClick: (point, latLng) {
                  // Handle map click if needed
                },
              ),
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton(
                    heroTag: "refreshBtn",
                    mini: true,
                    backgroundColor: Colors.white,
                    onPressed: _initializeTracking,
                    child: const Icon(Icons.refresh, color: Colors.blue),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton(
                    heroTag: "locationBtn",
                    backgroundColor: Colors.blue,
                    onPressed: () async {
                      setState(() {
                        _isLoading = true;
                      });

                      try {
                        // Show a loading indicator
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Getting your location...'),
                            duration: Duration(seconds: 1),
                          ),
                        );

                        final position = await _mapService.getCurrentLocation();

                        if (position.latitude != 0 && position.longitude != 0) {
                          _mapController?.animateCamera(
                            CameraUpdate.newLatLngZoom(
                              LatLng(position.latitude, position.longitude),
                              15.0,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not get your location. Please check your location permissions.'),
                            ),
                          );
                        }
                      } catch (e) {
                        print('Error getting location: $e');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error getting location: ${e.toString()}'),
                          ),
                        );
                      } finally {
                        setState(() {
                          _isLoading = false;
                        });
                      }
                    },
                    child: const Icon(Icons.my_location),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addBusStopsToMap() async {
    if (_mapController == null) return;

    for (final stop in _busStops) {
      await _mapService.addMarker(
        position: LatLng(
          stop['latitude'] as double,
          stop['longitude'] as double,
        ),
        data: {'id': 'stop_${stop['id']}', 'type': 'bus_stop'},
        title: stop['name'] as String,
        iconColor: Colors.green,
      );
    }
  }
}