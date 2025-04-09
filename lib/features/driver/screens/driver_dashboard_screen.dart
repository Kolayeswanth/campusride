import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/mapbox_gl.dart';
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
  const DriverDashboardScreen({Key? key}) : super(key: key);

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  MapboxMapController? _mapController;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  bool _isLoading = true;
  bool _isTracking = false;
  bool _isTripStarted = false;
  String _error = '';
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
    _initializeMap();
    _checkLocationPermissions();
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
      // Initialize map configuration
      // No need to call setRenderMode or setAccessToken directly
      // These are handled by the MapLibreMap widget
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize map: $e';
        _isLoading = false;
      });
    }
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
  
  void _onMapCreated(MapboxMapController controller) async {
    _mapController = controller;
    
    // Add custom images for markers - using PNG files instead of SVG
    try {
      await _mapController!.addImage(
        'driver-marker',
        await _getBytesFromAsset('assets/icons/driver_marker.png'),
      );
      
      await _mapController!.addImage(
        'start-marker',
        await _getBytesFromAsset('assets/icons/start_marker.png'),
      );
      
      await _mapController!.addImage(
        'end-marker',
        await _getBytesFromAsset('assets/icons/end_marker.png'),
      );
    } catch (e) {
      print('Error loading marker images: $e');
      // Fallback to default markers if custom images fail to load
    }
    
    // Center map on current location
    if (_currentPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          15.0,
        ),
      );
    }
  }
  
  Future<Uint8List> _getBytesFromAsset(String path) async {
    final ByteData data = await rootBundle.load(path);
    return data.buffer.asUint8List();
  }
  
  void _onSymbolTapped(Symbol symbol) {
    // Handle symbol tap
  }
  
  void _onMapClick(Point<double> point, LatLng latLng) {
    // Handle map click
    print('Map clicked at: ${latLng.latitude}, ${latLng.longitude}');
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
  
  Future<void> _startTrip() async {
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (context) => const DriverIdDialog(),
      );
      
      if (result != null && result.isNotEmpty) {
        setState(() {
          _driverId = result;
          _isTripStarted = true;
          _isLoading = true;
        });
        
        // Load route data for this driver
        await _loadRouteData();
        
        // Start location tracking
        _startLocationUpdates();
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to start trip: $e';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadRouteData() async {
    final tripService = Provider.of<TripService>(context, listen: false);
    
    try {
      // For testing purposes, create a sample route if the API call fails
      try {
        final routeData = await tripService.getRouteData(_driverId);
        final points = routeData['points'] as List;
        
        setState(() {
          _routePoints = points
              .map((point) => latlong.LatLng(
                  point['latitude'] as double, 
                  point['longitude'] as double))
              .toList();
          _isLoading = false;
        });
      } catch (e) {
        // Create a sample route for testing
        print('Error loading route data: $e');
        _createSampleRoute();
      }
      
      // Update the route display
      if (_routePoints.isNotEmpty) {
        _updateRouteDisplay();
      } else {
        setState(() {
          _error = 'No route data available';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load route data: $e';
        _isLoading = false;
      });
    }
  }
  
  void _createSampleRoute() {
    // Create a sample route around the current location
    if (_currentPosition != null) {
      final lat = _currentPosition!.latitude;
      final lng = _currentPosition!.longitude;
      
      // Create a simple circular route
      final points = <latlong.LatLng>[];
      for (int i = 0; i < 36; i++) {
        final angle = i * 10 * (3.14159 / 180); // Convert to radians
        final radius = 0.01; // Approximately 1km
        final pointLat = lat + radius * cos(angle);
        final pointLng = lng + radius * sin(angle);
        points.add(latlong.LatLng(pointLat, pointLng));
      }
      
      setState(() {
        _routePoints = points;
        _isLoading = false;
      });
    } else {
      // Create a default route if current position is not available
      // Using a default location (e.g., city center)
      final defaultLat = 37.7749; // San Francisco latitude
      final defaultLng = -122.4194; // San Francisco longitude
      
      final points = <latlong.LatLng>[];
      for (int i = 0; i < 36; i++) {
        final angle = i * 10 * (3.14159 / 180); // Convert to radians
        final radius = 0.01; // Approximately 1km
        final pointLat = defaultLat + radius * cos(angle);
        final pointLng = defaultLng + radius * sin(angle);
        points.add(latlong.LatLng(pointLat, pointLng));
      }
      
      setState(() {
        _routePoints = points;
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      body: Stack(
        children: [
          // Map
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_error.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _error = '';
                          _isLoading = true;
                        });
                        _initializeMap();
                        _checkLocationPermissions();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else
            MapboxMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _currentPosition != null 
                  ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                  : const LatLng(0, 0),
                zoom: 15.0,
              ),
              styleString: 'https://api.maptiler.com/maps/streets/style.json?key=${dotenv.env['MAPLIBRE_ACCESS_TOKEN']}',
              myLocationEnabled: true,
              onMapClick: _onMapClick,
            ),
          
          // Top app bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0),
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(
                    child: Text(
                      'Driver Dashboard',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () {
                      // Show menu
                    },
                  ),
                ],
              ),
            ),
          ),
          
          // Trip status card
          if (_isTripStarted)
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: TripStatusCard(
                isTracking: _isTracking,
                isTripActive: _isTripStarted,
                driverId: _driverId,
                onStartTrip: _startTrip,
                onToggleTracking: _toggleTracking,
                onEndTrip: () {
                  setState(() {
                    _isTripStarted = false;
                    _driverId = '';
                    _routePoints = [];
                    _completedPoints = [];
                    _completion = 0.0;
                  });
                  _stopLocationUpdates();
                },
              ),
            ),
          
          // Start trip button
          if (!_isTripStarted)
            Positioned(
              bottom: 32,
              left: 16,
              right: 16,
              child: TripControls(
                isTripStarted: _isTripStarted,
                isTracking: _isTracking,
                onStartTrip: _startTrip,
                onToggleTracking: _toggleTracking,
                onEndTrip: () {
                  setState(() {
                    _isTripStarted = false;
                    _driverId = '';
                    _routePoints = [];
                    _completedPoints = [];
                    _completion = 0.0;
                  });
                  _stopLocationUpdates();
                },
              ),
            ),
        ],
      ),
    );
  }
} 