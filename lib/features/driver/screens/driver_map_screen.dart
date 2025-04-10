import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../../core/services/trip_service.dart';
import '../../../core/services/map_service.dart';
import '../../../core/widgets/map_widget.dart';
import '../../../core/widgets/buttons/primary_button.dart';
import '../../../core/utils/location_utils.dart';

class DriverMapScreen extends StatefulWidget {
  final String routeId;
  final String busId;

  const DriverMapScreen({
    Key? key,
    required this.routeId,
    required this.busId,
  }) : super(key: key);

  @override
  State<DriverMapScreen> createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends State<DriverMapScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Position? _currentPosition;
  MapController? _mapController;
  StreamSubscription<Position>? _positionStream;
  bool _isLoading = true;
  bool _isTracking = false;
  String _error = '';
  List<LatLng> _routePoints = [];
  List<LatLng> _completedPoints = [];
  double _completion = 0.0; // 0 to 1
  Timer? _updateTimer;
  
  @override
  void initState() {
    super.initState();
    _checkLocationPermissions();
    _loadRouteData();
  }
  
  @override
  void dispose() {
    _stopLocationUpdates();
    _updateTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _checkLocationPermissions() async {
    try {
      final position = await LocationUtils.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadRouteData() async {
    final tripService = Provider.of<TripService>(context, listen: false);
    
    try {
      final routeData = await tripService.getRouteData(widget.routeId);
      final points = routeData['points'] as List;
      
      setState(() {
        _routePoints = points
            .map((point) => LatLng(
                point['latitude'] as double, 
                point['longitude'] as double))
            .toList();
        _isLoading = false;
      });
      
      _updateRouteDisplay();
    } catch (e) {
      setState(() {
        _error = 'Failed to load route data: $e';
        _isLoading = false;
      });
    }
  }
  
  void _startLocationUpdates() {
    if (_isTracking) return;
    
    setState(() {
      _isTracking = true;
    });
    
    // Start location updates
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen(_onLocationUpdate);
    
    // Start periodic updates to server
    _updateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _updateBusLocation();
    });
  }
  
  void _stopLocationUpdates() {
    _positionStream?.cancel();
    _updateTimer?.cancel();
    setState(() {
      _isTracking = false;
    });
  }
  
  void _onLocationUpdate(Position position) {
    setState(() {
      _currentPosition = position;
    });
    
    // Update map if controller exists
    if (_mapController != null && _currentPosition != null) {
      final mapService = Provider.of<MapService>(context, listen: false);
      final currentPosition = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
      
      mapService.updateUserLocation(_currentPosition!);
      
      // Update route completion
      _updateRouteCompletion(currentPosition);
    }
  }
  
  void _updateRouteCompletion(LatLng currentPosition) {
    if (_routePoints.isEmpty) return;
    
    // Find closest point on route
    int closestPointIndex = 0;
    double minDistance = double.infinity;
    
    for (int i = 0; i < _routePoints.length; i++) {
      final point = _routePoints[i];
      final distance = _calculateDistance(currentPosition, point);
      
      if (distance < minDistance) {
        minDistance = distance;
        closestPointIndex = i;
      }
    }
    
    // Update completed points
    setState(() {
      _completedPoints = _routePoints.sublist(0, closestPointIndex + 1);
      _completion = closestPointIndex / _routePoints.length;
    });
    
    _updateRouteDisplay();
  }
  
  double _calculateDistance(LatLng point1, LatLng point2) {
    return LocationUtils.calculateDistance(point1, point2);
  }
  
  void _updateRouteDisplay() {
    if (_routePoints.isEmpty) return;
    
    final mapService = Provider.of<MapService>(context, listen: false);
    
    // Add full route polyline
    mapService.addRoute(
      id: 'full_route',
      points: _routePoints,
      color: Colors.grey.withOpacity(0.7),
      width: 5.0,
    );
    
    // Add completed route polyline
    if (_completedPoints.isNotEmpty) {
      mapService.addRoute(
        id: 'completed_route',
        points: _completedPoints,
        color: Colors.green,
        width: 5.0,
      );
    }
    
    // Add markers for route start and end
    mapService.addMarker(
      id: 'route_start',
      position: LatLng(_routePoints.first.latitude, _routePoints.first.longitude),
      title: 'Start',
      color: Colors.green,
    );
    
    mapService.addMarker(
      id: 'route_end',
      position: _routePoints.last,
      title: 'End',
      color: Colors.red,
    );
  }
  
  Future<void> _updateBusLocation() async {
    if (!_isTracking || _currentPosition == null) return;
    
    final tripService = Provider.of<TripService>(context, listen: false);
    
    try {
      await tripService.updateBusLocation(
        widget.busId,
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        _currentPosition!.heading,
        _currentPosition!.speed,
      );
    } catch (e) {
      print('Failed to update bus location: $e');
      // We don't want to show errors to the driver for every update failure
    }
  }
  
  void _toggleTracking() {
    if (_isTracking) {
      _stopLocationUpdates();
    } else {
      _startLocationUpdates();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final mapService = Provider.of<MapService>(context);
    
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Campus Route'),
        actions: [
          IconButton(
            icon: const Icon(Icons.layers),
            onPressed: () {
              // Show map options
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_error.isNotEmpty)
            Center(child: Text(_error, textAlign: TextAlign.center))
          else
            MapWidget(
              onMapCreated: (controller) {
                setState(() {
                  _mapController = controller;
                });
                
                if (_currentPosition != null) {
                  final position = LatLng(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                  );
                  mapService.moveCameraToPosition(position);
                }
                
                if (_routePoints.isNotEmpty) {
                  // Use the flutter_map LatLngBounds.fromPoints utility
                  final bounds = LatLngBounds.fromPoints(_routePoints);
                  // Fit the map to the bounds
                  final centerZoom = controller.centerZoomFitBounds(
                    bounds,
                    options: const FitBoundsOptions(padding: EdgeInsets.all(50.0)),
                  );
                  controller.move(centerZoom.center, centerZoom.zoom);
                }
              },
            ),
          
          // Bottom panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Route completion indicator
                  LinearProgressIndicator(
                    value: _completion,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Route ${(_completion * 100).toStringAsFixed(0)}% complete',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      PrimaryButton(
                        text: _isTracking ? 'Stop Tracking' : 'Start Tracking',
                        icon: _isTracking ? Icons.stop : Icons.play_arrow,
                        onPressed: _toggleTracking,
                        backgroundColor: _isTracking 
                            ? Colors.red 
                            : Theme.of(context).colorScheme.primary,
                        minWidth: 180,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 