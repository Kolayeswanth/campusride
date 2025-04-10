import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
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
import 'package:permission_handler/permission_handler.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({Key? key}) : super(key: key);

  @override
  _DriverDashboardScreenState createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  MaplibreMapController? _mapController;
  Position? _currentPosition;
  LatLng? _destinationPosition;
  bool _isLoading = true;
  bool _isTracking = false;
  bool _isTripStarted = false;
  String? _error;
  String? _driverId;
  List<latlong.LatLng> _routePoints = [];
  List<latlong.LatLng> _completedPoints = [];
  double _completion = 0.0; // 0 to 1
  Timer? _locationUpdateTimer;
  Symbol? _driverMarker;
  Symbol? _destinationMarker;
  Line? _routeLine;
  Line? _completedRouteLine;
  Symbol? _startMarker;
  Symbol? _endMarker;
  
  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }
  
  @override
  void dispose() {
    _stopLocationUpdates();
    _locationUpdateTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
  
  Future<void> _initializeLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requestedPermission = await Geolocator.requestPermission();
        if (requestedPermission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied');
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });
      
      // Create a sample route for testing
      await _createSampleRoute();
      
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  
  Future<void> _createSampleRoute() async {
    if (_currentPosition == null) return;

    // Create a sample route that goes in a square around the current position
    final currentLat = _currentPosition!.latitude;
    final currentLng = _currentPosition!.longitude;
    const offset = 0.001; // About 100 meters
    
    setState(() {
      _routePoints = [
        latlong.LatLng(currentLat, currentLng), // Start point
        latlong.LatLng(currentLat + offset, currentLng), // North
        latlong.LatLng(currentLat + offset, currentLng + offset), // Northeast
        latlong.LatLng(currentLat, currentLng + offset), // East
        latlong.LatLng(currentLat - offset, currentLng + offset), // Southeast
        latlong.LatLng(currentLat - offset, currentLng), // South
        latlong.LatLng(currentLat - offset, currentLng - offset), // Southwest
        latlong.LatLng(currentLat, currentLng - offset), // West
        latlong.LatLng(currentLat + offset, currentLng - offset), // Northwest
        latlong.LatLng(currentLat, currentLng), // Back to start
      ];
    });

    // Update the route display
    await _updateRouteDisplay();
  }
  
  void _onMapCreated(MaplibreMapController controller) {
    _mapController = controller;
    _updateDriverMarker();
    _startLocationUpdates();
  }
  
  Future<void> _updateDriverMarker() async {
    if (_mapController == null || _currentPosition == null) return;

    try {
      if (_driverMarker != null) {
        await _mapController!.removeSymbol(_driverMarker!);
      }
      
      _driverMarker = await _mapController!.addSymbol(
        SymbolOptions(
          geometry: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          iconImage: 'bus',
          iconSize: 1.0,
          textField: _driverId ?? 'Driver',
          textOffset: const Offset(0, 1.5),
        ),
      );

      // Center map on driver's position if no destination is set
      if (_destinationPosition == null) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            15.0,
          ),
        );
      }
    } catch (e) {
      print('Error updating driver marker: $e');
    }
  }
  
  void _startLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _updateLocation(),
    );
  }
  
  Future<void> _updateLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() => _currentPosition = position);
      await _updateDriverMarker();
      if (_destinationPosition != null) {
        await _updateRouteLine();
      }
    } catch (e) {
      print('Error updating location: $e');
    }
  }
  
  Future<void> _updateRouteLine() async {
    if (_mapController == null || _currentPosition == null || _destinationPosition == null) return;

    try {
      if (_routeLine != null) {
        await _mapController!.removeLine(_routeLine!);
      }

      _routeLine = await _mapController!.addLine(
        LineOptions(
          geometry: [
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            _destinationPosition!,
          ],
          lineColor: "#4CAF50",
          lineWidth: 3.0,
        ),
      );

      // Adjust camera to show both points
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              _currentPosition!.latitude < _destinationPosition!.latitude
                  ? _currentPosition!.latitude
                  : _destinationPosition!.latitude,
              _currentPosition!.longitude < _destinationPosition!.longitude
                  ? _currentPosition!.longitude
                  : _destinationPosition!.longitude,
            ),
            northeast: LatLng(
              _currentPosition!.latitude > _destinationPosition!.latitude
                  ? _currentPosition!.latitude
                  : _destinationPosition!.latitude,
              _currentPosition!.longitude > _destinationPosition!.longitude
                  ? _currentPosition!.longitude
                  : _destinationPosition!.longitude,
            ),
          ),
          left: 50,
          right: 50,
          top: 50,
          bottom: 50,
        ),
      );
    } catch (e) {
      print('Error updating route line: $e');
    }
  }
  
  Future<void> _onMapClick(Point<double> point, LatLng coordinates) async {
    if (_driverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your driver ID first')),
      );
      return;
    }

    // Set destination marker
    if (_destinationMarker != null) {
      await _mapController?.removeSymbol(_destinationMarker!);
    }

    _destinationMarker = await _mapController?.addSymbol(
      SymbolOptions(
        geometry: coordinates,
        iconImage: 'marker-end',
        iconSize: 1.0,
        textField: 'Destination',
        textOffset: const Offset(0, 1.5),
      ),
    );

    setState(() => _destinationPosition = coordinates);
    await _updateRouteLine();
  }
  
  void _onSymbolTapped(Symbol symbol) {
    // Handle symbol tap
  }
  
  void _onMapLongClick(Point<double> point, LatLng latLng) {
    // Handle map long click
    print('Map long clicked at: ${latLng.latitude}, ${latLng.longitude}');
  }
  
  void _stopLocationUpdates() {
    _locationUpdateTimer?.cancel();
    setState(() {
      _isTracking = false;
    });
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
  
  Future<void> _updateRouteDisplay() async {
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
          geometry: routeLatLngs,
          lineColor: "#9E9E9E",
          lineWidth: 5.0,
          lineOpacity: 0.7,
        ),
      );
      
      // Add completed route polyline if there are completed points
      if (_completedPoints.isNotEmpty) {
        final completedLatLngs = _completedPoints.map((point) => 
          LatLng(point.latitude, point.longitude)).toList();
        
        _completedRouteLine = await _mapController!.addLine(
          LineOptions(
            geometry: completedLatLngs,
            lineColor: "#4CAF50",
            lineWidth: 5.0,
            lineOpacity: 1.0,
          ),
        );
      }
      
      // Add markers for route start and end if they don't exist
      if (_startMarker == null && _routePoints.isNotEmpty) {
        _startMarker = await _mapController!.addSymbol(
          SymbolOptions(
            geometry: LatLng(_routePoints.first.latitude, _routePoints.first.longitude),
            iconImage: "marker-start",
            iconSize: 1.0,
            textField: "Start",
            textOffset: const Offset(0, 1.5),
          ),
        );
      }
      
      if (_endMarker == null && _routePoints.isNotEmpty) {
        _endMarker = await _mapController!.addSymbol(
          SymbolOptions(
            geometry: LatLng(_routePoints.last.latitude, _routePoints.last.longitude),
            iconImage: "marker-end",
            iconSize: 1.0,
            textField: "End",
            textOffset: const Offset(0, 1.5),
          ),
        );
      }
    } catch (e) {
      print('Error updating route display: $e');
    }
  }
  
  Future<void> _startTrip() async {
    if (_driverId != null) return;

    final driverId = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const DriverIdDialog(),
    );
    
    if (driverId != null && driverId.isNotEmpty) {
      setState(() => _driverId = driverId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Welcome driver $driverId! Tap on the map to set your destination.')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $_error'),
              ElevatedButton(
                onPressed: _initializeLocation,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final styleUrl = kIsWeb 
        ? dotenv.env['MAPLIBRE_STYLE_URL'] ?? 'https://api.maptiler.com/maps/streets/style.json?key=default'
        : 'asset://assets/map_style.json';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
      ),
      body: Stack(
        children: [
          MaplibreMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: LatLng(
                _currentPosition?.latitude ?? 0.0,
                _currentPosition?.longitude ?? 0.0,
              ),
              zoom: 15.0,
            ),
            styleString: styleUrl,
            myLocationEnabled: true,
            onMapClick: _onMapClick,
            onStyleLoadedCallback: () {
              print("Map style loaded successfully!");
              if (_currentPosition != null) {
                _updateDriverMarker();
              }
            },
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                children: [
                    Text(
                      'Driver ID: ${_driverId ?? 'Not Set'}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _startTrip,
                      child: const Text('Start Trip'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                ),
              ),
            ),
        ],
      ),
    );
  }
} 