import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/services/trip_service.dart';
import '../../../core/theme/theme.dart';

class BusTrackingScreen extends StatefulWidget {
  final String busId;
  final String routeId;

  const BusTrackingScreen({
    super.key,
    required this.busId,
    required this.routeId,
  });

  @override
  State<BusTrackingScreen> createState() => _BusTrackingScreenState();
}

class _BusTrackingScreenState extends State<BusTrackingScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _isLoading = true;
  String? _error;
  LatLng? _busLocation;
  Map<String, dynamic>? _routeData;

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _loadRouteData();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final tripService = context.read<TripService>();
      final busLocation = await tripService.getBusLocation(widget.routeId);
      
      if (busLocation != null) {
        setState(() {
          _busLocation = LatLng(busLocation['latitude'], busLocation['longitude']);
          _updateMarkers();
          _isLoading = false;
        });

        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: _busLocation!,
                zoom: 15,
              ),
            ),
          );
        }
      } else {
        setState(() {
          _error = 'Bus location not available';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to get bus location: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRouteData() async {
    try {
      final tripService = context.read<TripService>();
      final routeData = await tripService.getRouteData(widget.routeId);
      
      setState(() {
        _routeData = routeData;
        _updatePolylines();
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load route data: $e';
      });
    }
  }

  void _startLocationUpdates() {
    // Update bus location every 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        _updateBusLocation();
        _startLocationUpdates();
      }
    });
  }

  Future<void> _updateBusLocation() async {
    try {
      final tripService = context.read<TripService>();
      final busLocation = await tripService.getBusLocation(widget.routeId);
      
      if (busLocation != null) {
        setState(() {
          _busLocation = LatLng(busLocation['latitude'], busLocation['longitude']);
          _updateMarkers();
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to update bus location: $e';
      });
    }
  }

  void _updateMarkers() {
    _markers = {};
    if (_busLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('bus_location'),
          position: _busLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(title: 'Bus ${widget.busId}'),
        ),
      );
    }
  }

  void _updatePolylines() {
    _polylines = {};
    if (_routeData != null && _routeData!['path_points'] != null) {
      final List<dynamic> pathPoints = _routeData!['path_points'];
      final List<LatLng> points = pathPoints.map((point) {
        return LatLng(point['latitude'], point['longitude']);
      }).toList();
      
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: Colors.blue,
          width: 5,
        ),
      );
      
      // Add markers for stops
      if (_routeData!['stops'] != null) {
        final List<dynamic> stops = _routeData!['stops'];
        for (var stop in stops) {
          _markers.add(
            Marker(
              markerId: MarkerId('stop_${stop['id']}'),
              position: LatLng(stop['latitude'], stop['longitude']),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              infoWindow: InfoWindow(title: stop['name']),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bus: ${widget.busId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _updateBusLocation,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _busLocation ?? const LatLng(0, 0),
                        zoom: 15,
                      ),
                      markers: _markers,
                      polylines: _polylines,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      mapType: kIsWeb ? MapType.normal : MapType.normal,
                      onMapCreated: (GoogleMapController controller) {
                        setState(() {
                          _mapController = controller;
                        });
                        _initializeMap();
                      },
                    ),
                    if (_routeData != null)
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Route: ${_routeData!['name']}',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                if (_busLocation != null)
                                  Text(
                                    'Bus Location: ${_busLocation!.latitude}, ${_busLocation!.longitude}',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _updateBusLocation,
        child: const Icon(Icons.refresh),
      ),
    );
  }
} 