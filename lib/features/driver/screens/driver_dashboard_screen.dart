import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:latlong2/latlong.dart' as latlong;
import '../../../core/services/trip_service.dart';
import '../../../core/services/map_service.dart';
import '../../../core/utils/location_utils.dart';
import '../../../core/theme/theme.dart';
import '../widgets/driver_id_dialog.dart';
import '../widgets/trip_controls.dart';
import '../widgets/trip_status_card.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DriverDashboardScreen extends StatefulWidget {
  final String driverId;

  const DriverDashboardScreen({
    Key? key,
    required this.driverId,
  }) : super(key: key);

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  MaplibreMapController? _mapController;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  bool _isLoading = true;
  bool _isTracking = false;
  bool _isTripStarted = false;
  String? _errorMessage;
  String _driverId = '';
  List<latlong.LatLng> _routePoints = [];
  List<latlong.LatLng> _completedPoints = [];
  double _completion = 0.0; // 0 to 1
  Timer? _updateTimer;
  Symbol? _driverMarker;
  Line? _routeLine;
  Line? _completedRouteLine;
  Symbol? _startMarker;
  Symbol? _endMarker;
  
  @override
  void initState() {
    super.initState();
    _driverId = widget.driverId;
    _initializeMap();
  }
  
  @override
  void dispose() {
    _stopLocationUpdates();
    _updateTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
  
  Future<void> _initializeMap() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'Location permissions are required to use this app';
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'Location permissions are permanently denied';
          _isLoading = false;
        });
        return;
      }

      // Get current position
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error initializing map: $e';
        _isLoading = false;
      });
    }
  }
  
  void _onMapCreated(MaplibreMapController controller) {
    _mapController = controller;
    _loadRouteData();
  }
  
  Future<void> _loadRouteData() async {
    if (_mapController == null || _currentPosition == null) return;

    try {
      // Center map on current position
      await _mapController!.moveCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          15.0,
        ),
      );

      // Add a marker for the current position
      await _mapController!.addSymbol(
        SymbolOptions(
          geometry: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          iconImage: 'car-15',
          iconSize: 1.5,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading route: $e';
      });
    }
  }
  
  void _onSymbolTapped(Symbol symbol) {
    // Handle symbol tap
  }
  
  void _onMapClick(Point<double> point, LatLng latLng) {
    // Handle map click
    print('Map clicked at: ${latLng.latitude}, ${latLng.longitude}');
  }
  
  void _onMapLongClick(Point<double> point, LatLng latLng) {
    // Handle map long click
    print('Map long clicked at: ${latLng.latitude}, ${latLng.longitude}');
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
      final currentPosition = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
      
      // Update driver marker
      _updateDriverMarker(currentPosition, position.heading);
      
      // Update route completion
      _updateRouteCompletion(latlong.LatLng(currentPosition.latitude, currentPosition.longitude));
    }
  }
  
  void _updateDriverMarker(LatLng position, double heading) async {
    if (_mapController == null) return;
    
    try {
      // Remove old driver marker if exists
      if (_driverMarker != null) {
        await _mapController!.removeSymbol(_driverMarker!);
      }
      
      // Add new driver marker
      _driverMarker = await _mapController!.addSymbol(
        SymbolOptions(
          geometry: position,
          iconImage: 'driver-marker',
          iconSize: 1.0,
          iconRotate: heading,
          iconColor: '#4285F4', // Google Blue
        ),
      );
      
      // Center map on driver if tracking is enabled
      if (_isTracking) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(position, 15.0),
        );
      }
    } catch (e) {
      print('Error updating driver marker: $e');
    }
  }
  
  void _updateRouteCompletion(latlong.LatLng currentPosition) {
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
  
  double _calculateDistance(latlong.LatLng point1, latlong.LatLng point2) {
    return LocationUtils.calculateDistance(point1, point2);
  }
  
  void _updateRouteDisplay() async {
    if (_routePoints.isEmpty || _mapController == null) return;
    
    try {
      // Remove existing route lines if they exist
      if (_routeLine != null) {
        await _mapController!.removeLine(_routeLine!);
      }
      
      if (_completedRouteLine != null) {
        await _mapController!.removeLine(_completedRouteLine!);
      }
      
      // Convert route points to MapLibre LatLng
      final routeLatLngs = _routePoints.map((point) => 
        LatLng(point.latitude, point.longitude)).toList();
      
      // Add full route polyline
      _routeLine = await _mapController!.addLine(
        LineOptions(
          lineColor: '#9E9E9E', // Grey
          lineWidth: 5.0,
          lineOpacity: 0.7,
          geometry: routeLatLngs,
        ),
      );
      
      // Add completed route polyline if there are completed points
      if (_completedPoints.isNotEmpty) {
        final completedLatLngs = _completedPoints.map((point) => 
          LatLng(point.latitude, point.longitude)).toList();
        
        _completedRouteLine = await _mapController!.addLine(
          LineOptions(
            lineColor: '#4CAF50', // Green
            lineWidth: 5.0,
            lineOpacity: 1.0,
            geometry: completedLatLngs,
          ),
        );
      }
      
      // Add markers for route start and end if they don't exist
      if (_startMarker == null && _routePoints.isNotEmpty) {
        _startMarker = await _mapController!.addSymbol(
          SymbolOptions(
            geometry: LatLng(_routePoints.first.latitude, _routePoints.first.longitude),
            iconImage: 'start-marker',
            iconSize: 1.0,
            textField: 'Start',
            textOffset: const Offset(0, 1.5),
          ),
        );
      }
      
      if (_endMarker == null && _routePoints.isNotEmpty) {
        _endMarker = await _mapController!.addSymbol(
          SymbolOptions(
            geometry: LatLng(_routePoints.last.latitude, _routePoints.last.longitude),
            iconImage: 'end-marker',
            iconSize: 1.0,
            textField: 'End',
            textOffset: const Offset(0, 1.5),
          ),
        );
      }
    } catch (e) {
      print('Error updating route display: $e');
    }
  }
  
  Future<void> _updateBusLocation() async {
    if (!_isTracking || _currentPosition == null) return;
    
    final tripService = Provider.of<TripService>(context, listen: false);
    
    try {
      await tripService.updateBusLocation(
        _driverId,
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
  
  void _startTrip() {
    // Implement trip starting logic here
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Trip started successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _initializeMap,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    MaplibreMap(
                      onMapCreated: _onMapCreated,
                      initialCameraPosition: CameraPosition(
                        target: LatLng(
                          _currentPosition?.latitude ?? 0,
                          _currentPosition?.longitude ?? 0,
                        ),
                        zoom: 15.0,
                      ),
                      styleString: 'asset://assets/map_style.json',
                      onMapClick: _onMapClick,
                      onMapLongClick: _onMapLongClick,
                      myLocationEnabled: true,
                      myLocationTrackingMode: MyLocationTrackingMode.TrackingCompass,
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: TripControls(
                        driverId: widget.driverId,
                      ),
                    ),
                  ],
                ),
    );
  }
} 