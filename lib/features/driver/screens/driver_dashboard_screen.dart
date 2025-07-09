import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' hide Point;
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../../core/services/trip_service.dart';
import '../../../core/services/map_service.dart';
import '../../../core/utils/location_utils.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/platform_safe_map.dart';
import '../widgets/driver_id_dialog.dart';
import '../widgets/trip_controls.dart';
import '../models/village_crossing.dart';
import '../widgets/trip_status_card.dart';
import '../widgets/speed_tracker.dart';
import '../widgets/village_crossing_log.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/map_constants.dart';

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
  bool _hasReachedDestination = false;
  String? _error;
  String? _driverId;
  List<latlong2.LatLng> _routePoints = [];
  List<latlong2.LatLng> _completedPoints = [];
  double _completion = 0.0;
  Timer? _locationUpdateTimer;
  Symbol? _driverMarker;
  Symbol? _destinationMarker;
  Line? _routeLine;
  Line? _completedRouteLine;
  Symbol? _startMarker;
  Symbol? _endMarker;
  List<Symbol> _symbols = [];
  Circle? _locationCircle;
  
  TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  
  // Animation controller for pulsing effect
  Timer? _animationTimer;
  double _animationProgress = 0.0;
  Symbol? _busIconId;
  
  // Add these new variables at the start of the class
  bool _userInteractingWithMap = false;
  DateTime? _lastUserInteraction;

  // Add new state variables
  TextEditingController _startLocationController = TextEditingController();
  TextEditingController _destinationController = TextEditingController();
  TextEditingController _driverIdController = TextEditingController();
  String? _estimatedDistance;
  String? _estimatedTime;
  bool _isEditingDriverId = false;
  LatLng? _lastClickedPoint;
  DateTime? _estimatedArrivalTime;

  // Add new state variables for start location search
  List<Map<String, dynamic>> _startLocationResults = [];
  bool _isSearchingStartLocation = false;

  // Add new state variables for speed tracking
  double _lastDeviationCheckDistance = 0.0;
  static const double _deviationThreshold = 50.0; // meters
  static const double _deviationCheckInterval = 100.0; // meters

  String _timeToDestination = '--:--';
  String _distanceRemaining = '-- km';

  // Add new state variable for zoom control
  bool _shouldAutoZoom = false;
  static const double _autoZoomRadius = 3.0; // 3 km radius

  // Add new state variables for UI visibility
  bool _isUIVisible = true;
  bool _isManualControl = false;

  // Add new state variables for clear icon visibility
  bool _showStartClearIcon = false;
  bool _showDestClearIcon = false;

  // Village tracking variables
  Set<String> _passedVillages = {};
  List<VillageCrossing> _villageCrossings = [];
  Timer? _villageCheckTimer;
  static const double _villageCheckInterval = 500.0; // meters
  double _lastVillageCheckDistance = 0.0;
  bool _showVillageCrossingLog = false;
  
  // Trip tracking
  String? _tripId;

  double _currentSpeed = 0.0; // Add this field to track current speed

  // Add method to toggle UI visibility
  void _toggleUIVisibility() {
    setState(() {
      _isUIVisible = !_isUIVisible;
      _isManualControl = !_isUIVisible;
    });
  }

  // Add method to handle map interaction start
  void _handleMapInteractionStart() {
    if (_isUIVisible) {
      setState(() {
        _isUIVisible = false;
        _isManualControl = true;
      });
    }
  }

  // Add method to handle map interaction end
  void _handleMapInteractionEnd() {
    if (_isManualControl) {
      setState(() {
        _isManualControl = false;
      });
    }
  }

  // Add method to check if driver has deviated from route
  bool _hasDeviatedFromRoute(Position currentPosition) {
    if (_routePoints.isEmpty) return false;
    
    // Find the closest point on the route
    double minDistance = double.infinity;
    for (final point in _routePoints) {
      final distance = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        point.latitude,
        point.longitude,
      );
      minDistance = min(minDistance, distance);
    }
    
    return minDistance > _deviationThreshold;
  }

  // Add method to recalculate route from current position
  Future<void> _recalculateRouteFromCurrentPosition() async {
    if (_currentPosition == null || _destinationPosition == null) return;
    
    try {
      final requestBody = {
        'coordinates': [
          [_currentPosition!.longitude, _currentPosition!.latitude],
          [_destinationPosition!.longitude, _destinationPosition!.latitude]
        ],
        'preference': 'shortest',
        'instructions': false,
        'units': 'km',
        'geometry_simplify': false,
        'continue_straight': true
      };

      final orsApiKey = dotenv.env['ORS_API_KEY'] ?? '5b3ce3597851110001cf6248a0ac0e4cb1ac489fa0857d1c6fc7203e';
      
      final uri = Uri.parse('https://api.openrouteservice.org/v2/directions/driving-car/geojson').replace(
        queryParameters: {'api_key': orsApiKey},
      );
      
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json, application/geo+json'
        },
        body: json.encode(requestBody)
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['features'] != null && 
            data['features'].isNotEmpty && 
            data['features'][0]['geometry'] != null) {
          
          final coordinates = data['features'][0]['geometry']['coordinates'] as List;
          final List<LatLng> routePoints = coordinates.map((coord) {
            return LatLng(coord[1] as double, coord[0] as double);
          }).toList();

          // Update the route display
          if (_routeLine != null) {
            await _mapController?.removeLine(_routeLine!);
          }

          _routeLine = await _mapController?.addLine(
            LineOptions(
              geometry: routePoints,
              lineColor: "#4285F4",
              lineWidth: 6.0,
              lineOpacity: 0.9,
            ),
          );

          setState(() {
            _routePoints = routePoints.map((point) => 
              latlong2.LatLng(point.latitude, point.longitude)).toList();
          });

          _updateETAAndDistance();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Route updated based on current position'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error recalculating route: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _driverIdController.text = _driverId ?? '';
    
    // Initialize MapService
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mapService = Provider.of<MapService>(context, listen: false);
      mapService.initializeMap();
    });

    // Start speed updates
    _locationUpdateTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateLocation(),
    );
  }

  @override
  void dispose() {
    _startLocationController.dispose();
    _destinationController.dispose();
    _driverIdController.dispose();
    _stopLocationUpdates();
    _locationUpdateTimer?.cancel();
    _animationTimer?.cancel();
    
    if (_mapController != null) {
      _mapController!.onSymbolTapped.remove(_onSymbolTapped);
      if (_locationCircle != null) {
        _mapController!.removeCircle(_locationCircle!);
      }
      for (final symbol in _symbols) {
        _mapController!.removeSymbol(symbol);
      }
      if (_routeLine != null) {
        _mapController!.removeLine(_routeLine!);
      }
      if (_completedRouteLine != null) {
        _mapController!.removeLine(_completedRouteLine!);
      }
      _mapController!.dispose();
    }
    
    _searchController.dispose();
    super.dispose();
  }

  void _updateLocationCircle() {
    if (_mapController != null && _currentPosition != null) {
      try {
        // Remove any existing bus icon
        if (_busIconId != null) {
          _mapController!.removeSymbol(_busIconId!);
          _busIconId = null;
        }
        
        // Add new bus icon at current location
        _addBusIcon(latlong2.LatLng(_currentPosition!.latitude, _currentPosition!.longitude));
      } catch (e) {
        print('Error updating location: $e');
      }
    }
  }

  Future<void> _initializeLocation() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _error = 'Location services are disabled. Please enable location services.';
          _isLoading = false;
        });
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _error = 'Location permissions are denied. Please enable them in settings.';
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _error = 'Location permissions are permanently denied. Please enable them in settings.';
          _isLoading = false;
        });
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );

      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });

      // If map is already created, update the marker and center the map
      if (_mapController != null) {
        await _updateDriverMarker();
        await _centerOnCurrentLocation();
      }
    } catch (e) {
      setState(() {
        _error = 'Error getting location: $e';
        _isLoading = false;
      });
    }
  }

  void _showLocationServiceDisabledDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Location Services Disabled'),
        content: const Text('Please enable location services in your device settings'),
        actions: [
          TextButton(
            child: const Text('Open Settings'),
            onPressed: () {
              Navigator.of(context).pop();
              Geolocator.openLocationSettings();
            },
          ),
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _showLocationPermissionRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text('Please enable location permissions in app settings'),
        actions: [
          TextButton(
            child: const Text('Open Settings'),
            onPressed: () {
              Navigator.of(context).pop();
              Geolocator.openAppSettings();
            },
          ),
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _createSampleRoute() async {
    if (_currentPosition == null) return;

    final currentLat = _currentPosition!.latitude;
    final currentLng = _currentPosition!.longitude;
    const offset = 0.001;
    
    setState(() {
      _routePoints = [
        latlong2.LatLng(currentLat, currentLng),
        latlong2.LatLng(currentLat + offset, currentLng),
        latlong2.LatLng(currentLat + offset, currentLng + offset),
        latlong2.LatLng(currentLat, currentLng + offset),
        latlong2.LatLng(currentLat - offset, currentLng + offset),
        latlong2.LatLng(currentLat - offset, currentLng),
        latlong2.LatLng(currentLat - offset, currentLng - offset),
        latlong2.LatLng(currentLat, currentLng - offset),
        latlong2.LatLng(currentLat + offset, currentLng - offset),
        latlong2.LatLng(currentLat, currentLng),
      ];
    });

    await _updateRouteDisplay();
  }

  void _onMapCreated(dynamic controller) async {
    if (controller is MaplibreMapController) {
      setState(() {
        _mapController = controller;
        _isLoading = false;
      });
      
      _mapController!.onSymbolTapped.add(_onSymbolTapped);

      // Add default marker icons
      await _addMapIcons();
      
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_currentPosition != null) {
          _updateDriverMarker();
          _centerOnCurrentLocation();
        } else {
          _initializeLocation().then((_) {
            if (_currentPosition != null) {
              _updateDriverMarker();
              _centerOnCurrentLocation();
            }
          });
        }
      });
      
      _startLocationUpdates();
    }
  }

  Future<void> _addMapIcons() async {
    try {
      // Add marker icon
      await _mapController!.addImage(
        "marker",
        await _loadIconImage('assets/images/marker.png'),
      );
      
      // Add destination marker icon
      await _mapController!.addImage(
        "marker-end",
        await _loadIconImage('assets/images/destination_marker.png'),
      );
      
      // Add bus icon
      await _mapController!.addImage(
        "bus-icon",
        await _loadIconImage('assets/images/bus_icon.png'),
      );
      } catch (e) {
      print('Error loading map icons: $e');
    }
  }

  Future<Uint8List> _loadIconImage(String assetPath) async {
    // For testing, create a simple colored circle as a fallback icon
    if (!await _assetExists(assetPath)) {
      return await _createFallbackIcon();
    }
    
    final ByteData bytes = await rootBundle.load(assetPath);
    return bytes.buffer.asUint8List();
  }

  Future<bool> _assetExists(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Uint8List> _createFallbackIcon() async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final size = 32.0;
    final radius = size / 2;
    
    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(Offset(radius, radius), radius, paint);
    
    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ImageByteFormat.png);
    
    return byteData!.buffer.asUint8List();
  }

  Future<void> _updateDriverMarker() async {
    if (_mapController == null || _currentPosition == null) return;

    try {
      // Remove any existing bus icon
      if (_busIconId != null) {
        await _mapController!.removeSymbol(_busIconId!);
        _busIconId = null;
      }
      
      // Add new bus icon at current position
      _addBusIcon(latlong2.LatLng(_currentPosition!.latitude, _currentPosition!.longitude));

      // Center map if no destination
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

  Future<void> _addBusIcon(latlong2.LatLng position) async {
    if (_mapController == null) return;
    try {
      // Remove existing bus icon if any
      if (_busIconId != null) {
        await _mapController!.removeSymbol(_busIconId!);
      }
      
      // Add new bus icon with initial rotation
      _busIconId = await _mapController!.addSymbol(
        SymbolOptions(
          geometry: LatLng(position.latitude, position.longitude),
          iconImage: "bus-icon",
          iconSize: 1.2,
          iconRotate: 0.0,
          textField: 'Bus',
          textOffset: const Offset(0, 1.5),
          textColor: '#000000',
          textHaloColor: '#FFFFFF',
          textHaloWidth: 1.0,
          iconAnchor: "bottom",
        ),
        {'type': 'bus'},
      );
    } catch (e) {
      print('Error adding bus icon: $e');
    }
  }

  void _startLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _updateLocation(),
    );
    _updateLocation();
  }

  Future<void> _updateLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 5),
      );
      
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _currentSpeed = position.speed >= 0 ? position.speed : 0.0; // Update speed
        });
        await _updateDriverMarker();
        
        // Only update camera if user hasn't interacted recently and we're not in active navigation
        final now = DateTime.now();
        final shouldUpdateCamera = _lastUserInteraction == null || 
            now.difference(_lastUserInteraction!) > const Duration(seconds: 30);
            
        if (_destinationPosition != null && !_userInteractingWithMap && shouldUpdateCamera) {
          await _updateRouteLine();
        }
      }
    } catch (e) {
      print('Error updating location: $e');
      try {
        final position = await Geolocator.getLastKnownPosition();
        if (position != null && mounted) {
          setState(() => _currentPosition = position);
          await _updateDriverMarker();
        }
      } catch (e2) {
        print('Error getting last known position: $e2');
      }
    }
  }

  // Track if we've already shown the location message
  bool _hasShownLocationMessage = false;

  Future<void> _centerOnCurrentLocation() async {
    // Only show the "Getting location" message if it's the first time
    if (!_hasShownLocationMessage) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Getting your current location...'),
          duration: Duration(seconds: 2),
        ),
    );
      _hasShownLocationMessage = true;
    }
    
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationServiceDisabledDialog();
        return;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
          timeLimit: const Duration(seconds: 2),
        );
      } catch (e) {
        position = await Geolocator.getLastKnownPosition();
        if (position == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to determine your location'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      setState(() => _currentPosition = position);
      
      if (_mapController == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Map is initializing'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      try {
        await _mapController!.getVisibleRegion();
      } catch (e) {
        Future.delayed(const Duration(seconds: 2), () {
          _centerOnCurrentLocation();
        });
        return;
      }

      await _updateDriverMarker();
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          17.0,
        ),
      );

      // Show a one-time message that you're at your current location
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are at your current location'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateRouteLine() async {
  if (_mapController == null || _routePoints.isEmpty) return;

    try {
      if (_routeLine != null) {
        await _mapController!.removeLine(_routeLine!);
      }

    final routeLatLngs = _routePoints.map((point) =>
      LatLng(point.latitude, point.longitude)).toList();

      _routeLine = await _mapController!.addLine(
        LineOptions(
        geometry: routeLatLngs,
        lineColor: "#2196F3", // Blue color
        lineWidth: 4.0,
        lineOpacity: 0.8,
      ),
    );

    await _fitMapToRoute(routeLatLngs);
    } catch (e) {
      print('Error updating route line: $e');
    }
  }


  void _onSymbolTapped(Symbol symbol) {
    if (symbol.data != null) {
      final data = symbol.data!;
      if (data['type'] == 'search_result') {
        _selectDestination(LatLng(data['latitude'], data['longitude']));
      } else if (data['type'] == 'driver') {
        _showCurrentLocationInfo();
      }
    }
  }

  void _showCurrentLocationInfo() {
    if (_currentPosition == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Current Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Latitude: ${_currentPosition!.latitude.toStringAsFixed(6)}'),
            Text('Longitude: ${_currentPosition!.longitude.toStringAsFixed(6)}'),
            const SizedBox(height: 16),
            const Text('Tap the location button to center the map'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _centerOnCurrentLocation();
            },
            child: const Text('Center Map'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    
    setState(() => _isSearching = true);
    
    try {
      // Use OpenStreetMap's Nominatim service for searching
      final encodedQuery = Uri.encodeComponent(query);
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&countrycodes=in&limit=10&addressdetails=1'
      );
      
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'CampusRide/1.0',
        }
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        if (data.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No results found. Try a different search term.'),
              backgroundColor: Colors.orange,
            ),
          );
        setState(() {
            _searchResults = [];
            _isSearching = false;
          });
          return;
        }
        
        setState(() {
          _searchResults = data.map((place) {
            final address = place['address'] as Map<String, dynamic>;
            final city = address['city'] ?? address['town'] ?? address['village'] ?? '';
            final state = address['state'] ?? '';
            final displayName = [
              place['name'] ?? '',
              city,
              state,
            ].where((s) => s.isNotEmpty).join(', ');

            return {
              'name': displayName,
              'full_address': place['display_name'] as String,
              'latitude': double.parse(place['lat']),
              'longitude': double.parse(place['lon']),
              'type': place['type'] ?? 'place',
              'city': city,
              'state': state,
            };
          }).toList();
          _isSearching = false;
        });
        
        // Show the results on the map
        await _showSearchResultsOnMap();
      } else {
        throw Exception('Failed to search location');
      }
    } catch (e) {
      print('Search error: $e');
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error searching location. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showSearchResultsOnMap() async {
    if (_mapController == null || _searchResults.isEmpty) return;
    
    try {
    await _clearSearchResultMarkers();
    
      // Don't adjust the map view during search - just add markers
    for (final result in _searchResults) {
      final marker = await _mapController!.addSymbol(
        SymbolOptions(
            geometry: LatLng(
              result['latitude'] as double,
              result['longitude'] as double
            ),
          iconImage: 'marker',
          iconSize: 1.0,
            textField: result['name'] as String,
          textOffset: const Offset(0, 1.5),
            textColor: '#000000',
            textHaloColor: '#FFFFFF',
            textHaloWidth: 1.0,
        ),
        {
          'type': 'search_result',
          'latitude': result['latitude'],
          'longitude': result['longitude'],
            'name': result['name'],
        },
      );
      _symbols.add(marker);
    }
    
      // We're not adjusting the map view during search anymore
      // This prevents the distracting zooming in and out
      
    } catch (e) {
      print('Error showing search results on map: $e');
    }
  }

  Future<void> _clearSearchResultMarkers() async {
    if (_mapController == null) return;
    
    final symbolsToRemove = _symbols.where((symbol) {
      return symbol.data != null && symbol.data!['type'] == 'search_result';
    }).toList();
    
    for (final symbol in symbolsToRemove) {
      await _mapController!.removeSymbol(symbol);
      _symbols.remove(symbol);
    }
  }

  Future<void> _fitMapToBounds(List<LatLng> points) async {
    if (_mapController == null || points.isEmpty) return;
    
    try {
      double minLat = points[0].latitude;
      double maxLat = points[0].latitude;
      double minLng = points[0].longitude;
      double maxLng = points[0].longitude;
      
      for (final point in points) {
        minLat = min(minLat, point.latitude);
        maxLat = max(maxLat, point.latitude);
        minLng = min(minLng, point.longitude);
        minLng = max(maxLng, point.longitude);
      }
      
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          top: 50, right: 50, bottom: 50, left: 50,
        ),
      );
    } catch (e) {
      print('Error fitting map to bounds: $e');
    }
  }

  Future<void> _selectDestination(LatLng coordinates) async {
    if (_mapController == null || _currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for map and location to initialize'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Clear existing route and markers
      await _clearExistingRoute();

      // Add destination marker
      _destinationMarker = await _mapController?.addSymbol(
        SymbolOptions(
          geometry: coordinates,
          iconImage: 'marker',
          iconSize: 1.2,
          textField: 'Destination',
          textOffset: const Offset(0, 1.5),
          textColor: '#2196F3',
          textHaloColor: '#FFFFFF',
          textHaloWidth: 1.0,
          iconAnchor: "bottom",
        ),
      );
      
      if (_destinationMarker != null) {
        _symbols.add(_destinationMarker!);
      }

      setState(() => _destinationPosition = coordinates);

      // Calculate and display route
      await _calculateRoute(coordinates);

      // Clear search results after selecting destination
      setState(() {
        _searchResults = [];
        _searchController.clear();
      });
      await _clearSearchResultMarkers();

    } catch (e) {
      print('Error selecting destination: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error selecting destination. Please try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }

    // Update map zoom after setting destination
    await _updateMapZoom();

    // After showing the route, zoom in to the live location at 100m (zoom level 18)
    if (_currentPosition != null && _mapController != null) {
      Future.delayed(const Duration(seconds: 2), () async {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            MapConstants.liveLocationZoom,
          ),
        );
      });
    }
  }

  Future<void> _clearExistingRoute() async {
    try {
      // Remove existing destination marker
      if (_destinationMarker != null) {
        await _mapController?.removeSymbol(_destinationMarker!);
        _symbols.remove(_destinationMarker);
        _destinationMarker = null;
      }

      // Remove existing start marker
      if (_startMarker != null) {
        await _mapController?.removeSymbol(_startMarker!);
        _symbols.remove(_startMarker);
        _startMarker = null;
      }

      // Remove existing end marker
      if (_endMarker != null) {
        await _mapController?.removeSymbol(_endMarker!);
        _symbols.remove(_endMarker);
        _endMarker = null;
      }

      // Remove existing route line
      if (_routeLine != null) {
        await _mapController?.removeLine(_routeLine!);
        _routeLine = null;
      }

      // Remove completed route line if exists
      if (_completedRouteLine != null) {
        await _mapController!.removeLine(_completedRouteLine!);
        _completedRouteLine = null;
      }

      _routePoints.clear();
      _completedPoints.clear();
      _completion = 0.0;
      
      setState(() {
        _destinationPosition = null;
        _hasReachedDestination = false;
      });
    } catch (e) {
      print('Error clearing route: $e');
    }
  }

  Future<void> _calculateRoute(LatLng destination) async {
    if (_currentPosition == null) {
      print('DEBUG: Current position is null');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Current location not available. Please wait.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _clearExistingRoute();
      
      // Create start and destination points
      final start = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
      
      final requestBody = {
        'coordinates': [
          [start.longitude, start.latitude],
          [destination.longitude, destination.latitude]
        ],
        'preference': 'shortest',
        'instructions': false,
        'units': 'km',
        'geometry_simplify': false,
        'continue_straight': true
      };

        final orsApiKey = dotenv.env['ORS_API_KEY'] ?? '5b3ce3597851110001cf6248a0ac0e4cb1ac489fa0857d1c6fc7203e';
        
        final uri = Uri.parse('https://api.openrouteservice.org/v2/directions/driving-car/geojson').replace(
          queryParameters: {'api_key': orsApiKey},
        );
        
        final response = await http.post(
        uri,
          headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json, application/geo+json'
        },
        body: json.encode(requestBody)
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
        
        if (data['features'] != null && 
            data['features'].isNotEmpty && 
            data['features'][0]['geometry'] != null) {
          
          final coordinates = data['features'][0]['geometry']['coordinates'] as List;
          List<LatLng> routePoints = coordinates.map((coord) {
            return LatLng(coord[1] as double, coord[0] as double);
          }).toList();

          // Ensure the route includes start and end points exactly
          if (!routePoints.contains(start)) {
            routePoints.insert(0, start);
          }
          if (!routePoints.contains(destination)) {
            routePoints.add(destination);
          }

          // Update the route points in state
          setState(() {
            _routePoints = routePoints.map((point) => 
              latlong2.LatLng(point.latitude, point.longitude)).toList();
            _destinationPosition = destination;
          });

          // Remove existing route line if any
          if (_routeLine != null) {
            await _mapController?.removeLine(_routeLine!);
          }

          // Draw the route line
          _routeLine = await _mapController?.addLine(
            LineOptions(
              geometry: routePoints,
              lineColor: "#4285F4",
              lineWidth: 6.0,
              lineOpacity: 0.9,
            ),
          );

          // Add destination marker
          _destinationMarker = await _mapController?.addSymbol(
            SymbolOptions(
              geometry: destination,
              iconImage: 'marker-end',
              iconSize: 1.2,
              textField: 'Destination',
              textOffset: const Offset(0, 1.5),
              textColor: '#4285F4',
              textHaloColor: '#FFFFFF',
              textHaloWidth: 1.5,
              iconAnchor: "bottom",
            ),
          );

          if (_destinationMarker != null) {
            _symbols.add(_destinationMarker!);
          }

          // Update ETA and distance
          _updateETAAndDistance();

          // Fit map to show the entire route with padding
          await _fitMapToRoute(routePoints);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Route calculated successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
        } else {
          throw Exception('Failed to calculate route: ${response.statusCode}');
        }
    } catch (e) {
      print('DEBUG: Route calculation error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error calculating route: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fitMapToRoute(List<LatLng> routePoints) async {
    if (routePoints.isEmpty) return;

    try {
      // Add padding to the bounds calculation
      const padding = 0.0002; // Roughly 20-30 meters
      
      // Calculate bounds with padding
      final bounds = LatLngBounds(
        southwest: LatLng(
          routePoints.map((p) => p.latitude).reduce(min) - padding,
          routePoints.map((p) => p.longitude).reduce(min) - padding,
        ),
        northeast: LatLng(
          routePoints.map((p) => p.latitude).reduce(max) + padding,
          routePoints.map((p) => p.longitude).reduce(max) + padding,
        ),
      );

      // Animate camera to show the entire route with padding
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(
          bounds,
          left: 50, right: 50, top: 150, bottom: 150,
        ),
      );
    } catch (e) {
      print('Error fitting map to route: $e');
      
      // Fallback to a simpler approach if the bounds calculation fails
      try {
        if (routePoints.length >= 2) {
          final start = routePoints.first;
          final end = routePoints.last;
          final center = LatLng(
            (start.latitude + end.latitude) / 2,
            (start.longitude + end.longitude) / 2,
          );
          
          await _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(center, 15),
          );
        }
      } catch (fallbackError) {
        print('Error in fallback map fitting: $fallbackError');
      }
    }
  }

  void _stopLocationUpdates() {
    _locationUpdateTimer?.cancel();
    setState(() => _isTracking = false);
  }

  Future<void> _updateRouteDisplay() async {
    if (_routePoints.isEmpty || _mapController == null) return;
    
    try {
      // Clear existing routes
      if (_routeLine != null) await _mapController!.removeLine(_routeLine!);
      if (_completedRouteLine != null) await _mapController!.removeLine(_completedRouteLine!);
      
      final routeLatLngs = _routePoints.map((point) => 
        LatLng(point.latitude, point.longitude)).toList();
      
      // Draw the main route in blue
      _routeLine = await _mapController!.addLine(
        LineOptions(
          geometry: routeLatLngs,
          lineColor: "#2196F3", // Material Blue color
          lineWidth: 5.0,
          lineOpacity: 0.8,
          draggable: false,
        ),
      );
      
      if (_completedPoints.isNotEmpty) {
        final completedLatLngs = _completedPoints.map((point) => 
          LatLng(point.latitude, point.longitude)).toList();
        
        _completedRouteLine = await _mapController!.addLine(
          LineOptions(
            geometry: completedLatLngs,
            lineColor: "#64B5F6", // Lighter blue for completed route
            lineWidth: 5.0,
            lineOpacity: 1.0,
            draggable: false,
          ),
        );
      }
      
      // Update route markers
      await _updateRouteMarkers();
    } catch (e) {
      print('Error updating route display: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating route display: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _updateRouteMarkers() async {
    if (_routePoints.isEmpty || _mapController == null) return;
    
    try {
      // Remove existing route markers
      if (_startMarker != null) {
        await _mapController!.removeSymbol(_startMarker!);
        _symbols.remove(_startMarker);
        _startMarker = null;
      }
      if (_endMarker != null) {
        await _mapController!.removeSymbol(_endMarker!);
        _symbols.remove(_endMarker);
        _endMarker = null;
      }

      // Add start marker
        _startMarker = await _mapController!.addSymbol(
          SymbolOptions(
            geometry: LatLng(_routePoints.first.latitude, _routePoints.first.longitude),
          iconImage: "marker",
          iconSize: 1.2,
            textField: "Start",
            textOffset: const Offset(0, 1.5),
          textColor: "#2196F3",
          textHaloColor: "#FFFFFF",
          textHaloWidth: 1.0,
          iconAnchor: "bottom",
          ),
        );
        _symbols.add(_startMarker!);
      
      // Add end marker
        _endMarker = await _mapController!.addSymbol(
          SymbolOptions(
            geometry: LatLng(_routePoints.last.latitude, _routePoints.last.longitude),
          iconImage: "marker",
          iconSize: 1.2,
          textField: "Destination",
            textOffset: const Offset(0, 1.5),
          textColor: "#2196F3",
          textHaloColor: "#FFFFFF",
          textHaloWidth: 1.0,
          iconAnchor: "bottom",
          ),
        );
        _symbols.add(_endMarker!);

    } catch (e) {
      print('Error updating route markers: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating route markers: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _startTrip() async {
    if (_driverId == null) {
      final driverId = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const DriverIdDialog(),
      );
      
      if (driverId != null && driverId.isNotEmpty) {
        setState(() => _driverId = driverId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Welcome driver $driverId!')),
        );
      }
      return;
    }
    
    if (_destinationPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set your destination first')),
      );
      return;
    }
    
    // Check if location services are enabled and we have permission
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location services are disabled. Please enable them to start the trip.'),
          backgroundColor: Colors.red,
        ),
      );
      _showLocationServiceDisabledDialog();
      return;
    }
    
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are denied. Cannot start trip.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permissions are permanently denied. Cannot start trip.'),
          backgroundColor: Colors.red,
        ),
      );
      _showLocationPermissionRequiredDialog();
      return;
    }
    
    setState(() {
      _isTripStarted = true;
      _hasReachedDestination = false;
      _completedPoints = [];
      _lastVillageCheckDistance = 0.0;
      _showVillageCrossingLog = false;
      _shouldAutoZoom = true; // Enable auto-zoom when trip starts
    });

    // Add bus icon at current position
    if (_currentPosition != null) {
      _addBusIcon(latlong2.LatLng(_currentPosition!.latitude, _currentPosition!.longitude));
    }

    // Start real-time location tracking with higher frequency
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(
      const Duration(seconds: 1), // More frequent updates during trip
      (_) => _updateRealTimeLocation(),
    );
    
    // Show a message to the user
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Trip started! Your location will be tracked in real-time.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }
  
  // Modify the _updateRealTimeLocation method to include deviation checking
  Future<void> _updateRealTimeLocation() async {
    if (!_isTripStarted) return;
    
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 2),
      );
      
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _currentSpeed = position.speed >= 0 ? position.speed : 0.0; // Update speed
        });
        
        // Update the bus icon position with smooth animation
        final currentLocation = latlong2.LatLng(position.latitude, position.longitude);
        await _updateBusPosition(currentLocation);
        
        // Add this point to completed points
        _completedPoints.add(currentLocation);
        
        // Update the completed route line
        await _updateCompletedRouteLine();
        
        // Update ETA and distance
        _updateETAAndDistance();
        
        // Check for village crossings
        await _checkVillageCrossing(position);
        
        // Check for route deviation
        if (_routePoints.isNotEmpty) {
          final distanceTraveled = _calculateTraveledDistance();
          if (distanceTraveled - _lastDeviationCheckDistance >= _deviationCheckInterval) {
            _lastDeviationCheckDistance = distanceTraveled;
            if (_hasDeviatedFromRoute(position)) {
              await _recalculateRouteFromCurrentPosition();
            }
          }
        }
        
        // Check if we've reached the destination
        if (_destinationPosition != null) {
          final distanceToDestination = Geolocator.distanceBetween(
            position.latitude, position.longitude,
            _destinationPosition!.latitude, _destinationPosition!.longitude,
          );
          
          // If within 50 meters of destination, consider it reached
          if (distanceToDestination < 50 && !_hasReachedDestination) {
            setState(() => _hasReachedDestination = true);
            
            // Show destination reached message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Destination reached! Trip ending automatically...'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
            
            // Automatically end the trip after a short delay
            Future.delayed(const Duration(seconds: 2), () {
              _autoEndTrip();
            });
          }
        }

        // Update map zoom if auto-zoom is enabled
        if (_shouldAutoZoom) {
          await _updateMapZoom();
        }
      }
    } catch (e) {
      print('Error updating real-time location: $e');
    }
  }

  // New method to automatically end the trip
  Future<void> _autoEndTrip() async {
    if (!_isTripStarted) return;
    
    // Cancel all timers
    _locationUpdateTimer?.cancel();
    _animationTimer?.cancel();
    
    // Remove all map elements
    if (_mapController != null) {
      try {
        // Remove bus icon
        if (_busIconId != null) {
          await _mapController!.removeSymbol(_busIconId!);
          _busIconId = null;
        }
        
        // Remove route line
        if (_routeLine != null) {
          await _mapController!.removeLine(_routeLine!);
          _routeLine = null;
        }
        
        // Remove completed route line
        if (_completedRouteLine != null) {
          await _mapController!.removeLine(_completedRouteLine!);
          _completedRouteLine = null;
        }
        
        // Remove destination marker
        if (_destinationMarker != null) {
          await _mapController!.removeSymbol(_destinationMarker!);
          _symbols.remove(_destinationMarker);
          _destinationMarker = null;
        }
      } catch (e) {
        print('Error cleaning up map elements: $e');
      }
    }
    
    // Reset all state variables
    setState(() {
      _isTripStarted = false;
      _hasReachedDestination = false;
      _completion = 0.0;
      _routePoints.clear();
      _completedPoints.clear();
      _destinationPosition = null;
      _shouldAutoZoom = false; // Disable auto-zoom when trip ends
    });
    
    // Show trip summary dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Trip Completed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('You have successfully reached your destination.'),
            const SizedBox(height: 16),
            Text('Total Distance: ${_estimatedDistance ?? 'N/A'}'),
            Text('Trip Duration: ${_estimatedTime ?? 'N/A'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Update the completed route line to show progress
  Future<void> _updateCompletedRouteLine() async {
    if (_mapController == null || _completedPoints.isEmpty) return;
    
    try {
      // Remove existing completed route line
      if (_completedRouteLine != null) {
        await _mapController!.removeLine(_completedRouteLine!);
      }
      
      // Convert points to LatLng for MapLibre
      final List<LatLng> points = _completedPoints
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();
      
      // Add the completed route line
      _completedRouteLine = await _mapController!.addLine(
        LineOptions(
          geometry: points,
          lineColor: "#4CAF50", // Green for completed route
          lineWidth: 6.0,
          lineOpacity: 0.9,
        ),
      );
      
      // Calculate completion percentage
      if (_routePoints.isNotEmpty && _destinationPosition != null) {
        final totalDistance = _calculateTotalRouteDistance();
        final traveledDistance = _calculateTraveledDistance();
        
        setState(() {
          _completion = totalDistance > 0 ? (traveledDistance / totalDistance) : 0.0;
          // Clamp to 0-1 range
          _completion = max(0.0, min(1.0, _completion));
        });
      }
    } catch (e) {
      print('Error updating completed route line: $e');
    }
  }
  
  // Calculate the total route distance
  double _calculateTotalRouteDistance() {
    double totalDistance = 0.0;
    
    if (_routePoints.length < 2) return 0.0;
    
    for (int i = 0; i < _routePoints.length - 1; i++) {
      final p1 = _routePoints[i];
      final p2 = _routePoints[i + 1];
      
      totalDistance += Geolocator.distanceBetween(
        p1.latitude, p1.longitude,
        p2.latitude, p2.longitude,
      );
    }
    
    return totalDistance;
  }
  
  // Calculate the distance traveled so far
  double _calculateTraveledDistance() {
    if (_completedPoints.isEmpty || _destinationPosition == null) return 0.0;
    
    // Get the last tracked position
    final lastPosition = _completedPoints.last;
    
    // Calculate the distance to the destination
    final distanceToDestination = Geolocator.distanceBetween(
      lastPosition.latitude, lastPosition.longitude,
      _destinationPosition!.latitude, _destinationPosition!.longitude,
    );
    
    // Total route distance minus remaining distance
    final totalDistance = _calculateTotalRouteDistance();
    return max(0.0, totalDistance - distanceToDestination);
  }
  
  // Stop the current trip
  void _stopTrip() async {
    // Cancel animation timer if running
    _animationTimer?.cancel();
    
    // Reset trip state
    setState(() {
      _isTripStarted = false;
      _hasReachedDestination = false;
      _completion = 0.0;
      _lastVillageCheckDistance = 0.0;
      _showVillageCrossingLog = false;
    });
    
    // Remove bus icon
    if (_busIconId != null && _mapController != null) {
      try {
        await _mapController!.removeSymbol(_busIconId!);
        _busIconId = null;
      } catch (e) {
        print('Error removing bus icon: $e');
      }
    }
    
    // Remove completed route line
    if (_completedRouteLine != null && _mapController != null) {
      try {
        await _mapController!.removeLine(_completedRouteLine!);
        _completedRouteLine = null;
      } catch (e) {
        print('Error removing completed route line: $e');
      }
    }
    
    // Reset location update timer to normal frequency
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _updateLocation(),
    );
    
    // Clear completed points
    _completedPoints.clear();
    
    // Show message to user
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Trip stopped'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _updateBusPosition(latlong2.LatLng newPosition) async {
    if (_mapController == null) return;
    
    try {
      // Calculate bearing for bus icon rotation
      double bearing = 0;
      if (_completedPoints.isNotEmpty) {
        final lastPoint = _completedPoints.last;
        bearing = _calculateBearing(
          lastPoint.latitude, lastPoint.longitude,
          newPosition.latitude, newPosition.longitude
        );
      }
      
      // Remove existing bus icon if any
      if (_busIconId != null) {
        await _mapController!.removeSymbol(_busIconId!);
      }
      
      // Add new bus icon with rotation and smooth animation
      _busIconId = await _mapController!.addSymbol(
        SymbolOptions(
          geometry: LatLng(newPosition.latitude, newPosition.longitude),
          iconImage: "bus-icon",
          iconSize: 1.2,
          iconRotate: bearing,
          textField: 'Bus',
          textOffset: const Offset(0, 1.5),
          textColor: '#000000',
          textHaloColor: '#FFFFFF',
          textHaloWidth: 1.0,
          iconAnchor: "bottom",
        ),
      );

      // Animate the camera to follow the bus if not manually interacting
      if (_shouldAutoZoom && _isTripStarted && !_hasReachedDestination) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(newPosition.latitude, newPosition.longitude),
            MapConstants.liveLocationZoom,
          ),
        );
      }
    } catch (e) {
      print('Error updating bus position: $e');
    }
  }

  double _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final dLon = (lon2 - lon1) * pi / 180;
    final lat1Rad = lat1 * pi / 180;
    final lat2Rad = lat2 * pi / 180;
    
    final y = sin(dLon) * cos(lat2Rad);
    final x = cos(lat1Rad) * sin(lat2Rad) -
             sin(lat1Rad) * cos(lat2Rad) * cos(dLon);
    
    final bearing = atan2(y, x) * 180 / pi;
    return (bearing + 360) % 360;
  }

  // Add method to update ETA and distance
  void _updateETAAndDistance() {
    if (_currentPosition != null && _destinationPosition != null) {
      final distanceInMeters = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        _destinationPosition!.latitude,
        _destinationPosition!.longitude,
      );

      // Convert to kilometers with 1 decimal place
      final distanceInKm = (distanceInMeters / 1000).toStringAsFixed(1);
      
      // Estimate time (assuming average speed of 40 km/h)
      final timeInHours = distanceInMeters / (40 * 1000);
      final timeInMinutes = (timeInHours * 60).round();
      
      // Calculate ETA
      final now = DateTime.now();
      final eta = now.add(Duration(minutes: timeInMinutes));

      setState(() {
        _estimatedDistance = '$distanceInKm km';
        _estimatedTime = timeInMinutes > 60
            ? '${(timeInMinutes / 60).floor()}h ${timeInMinutes % 60}min'
            : '$timeInMinutes min';
        _estimatedArrivalTime = eta;
      });
    }
  }

  // Add method to handle map clicks for route adjustment
  void _handleMapClick(LatLng point) {
    if (_destinationPosition != null) {
      // Check if click is near the destination (within 500 meters)
      final distanceToDestination = Geolocator.distanceBetween(
        point.latitude,
        point.longitude,
        _destinationPosition!.latitude,
        _destinationPosition!.longitude,
      );

      if (distanceToDestination < 500) {
        setState(() => _lastClickedPoint = point);
        _recalculateRouteWithViaPoint(point);
      }
    }
  }

  // Add method to recalculate route with via point
  Future<void> _recalculateRouteWithViaPoint(LatLng viaPoint) async {
    if (_currentPosition == null || _destinationPosition == null) return;

    try {
      final requestBody = {
        'coordinates': [
          [_currentPosition!.longitude, _currentPosition!.latitude],
          [viaPoint.longitude, viaPoint.latitude],
          [_destinationPosition!.longitude, _destinationPosition!.latitude]
        ],
        'preference': 'shortest',
        'instructions': false,
        'units': 'km',
        'geometry_simplify': false
      };

      final orsApiKey = dotenv.env['ORS_API_KEY'] ?? '5b3ce3597851110001cf6248a0ac0e4cb1ac489fa0857d1c6fc7203e';
      
      final uri = Uri.parse('https://api.openrouteservice.org/v2/directions/driving-car/geojson').replace(
        queryParameters: {'api_key': orsApiKey},
      );
      
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json, application/geo+json'
        },
        body: json.encode(requestBody)
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['features'] != null && 
            data['features'].isNotEmpty && 
            data['features'][0]['geometry'] != null) {
          
          final coordinates = data['features'][0]['geometry']['coordinates'] as List;
          final List<LatLng> routePoints = coordinates.map((coord) {
            return LatLng(coord[1] as double, coord[0] as double);
          }).toList();

          // Update the route display
          if (_routeLine != null) {
            await _mapController?.removeLine(_routeLine!);
          }

          _routeLine = await _mapController?.addLine(
            LineOptions(
              geometry: routePoints,
              lineColor: "#4285F4",
              lineWidth: 6.0,
              lineOpacity: 0.9,
            ),
          );

          setState(() {
            _routePoints = routePoints.map((point) => 
              latlong2.LatLng(point.latitude, point.longitude)).toList();
          });

          _updateETAAndDistance();
        }
      }
    } catch (e) {
      print('Error recalculating route: $e');
    }
  }

  // Add new method for searching start location
  Future<void> _searchStartLocation(String query) async {
    if (query.isEmpty) {
      setState(() {
        _startLocationResults = [];
        _isSearchingStartLocation = false;
      });
      return;
    }
    
    setState(() => _isSearchingStartLocation = true);
    
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&countrycodes=in&limit=5&addressdetails=1'
      );
      
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'CampusRide/1.0',
        }
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        setState(() {
          _startLocationResults = data.map((place) {
            final address = place['address'] as Map<String, dynamic>;
            final city = address['city'] ?? address['town'] ?? address['village'] ?? '';
            final state = address['state'] ?? '';
            final displayName = [
              place['name'] ?? '',
              city,
              state,
            ].where((s) => s.isNotEmpty).join(', ');

            return {
              'name': displayName,
              'full_address': place['display_name'] as String,
              'latitude': double.parse(place['lat']),
              'longitude': double.parse(place['lon']),
              'type': place['type'] ?? 'place',
              'city': city,
              'state': state,
            };
          }).toList();
          _isSearchingStartLocation = false;
        });
      }
    } catch (e) {
      print('Start location search error: $e');
      setState(() {
        _startLocationResults = [];
        _isSearchingStartLocation = false;
      });
    }
  }

  // Add method to cancel destination
  Future<void> _cancelDestination() async {
    try {
      await _clearExistingRoute();
      setState(() {
        _destinationPosition = null;
        _routePoints.clear();
        _completedPoints.clear();
        _completion = 0.0;
      });
      
      // Center back to current location
      if (_currentPosition != null) {
        await _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            15.0,
          ),
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Destination cancelled'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error cancelling destination: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error cancelling destination'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _updateTripInfo() {
    if (_currentPosition != null && _destinationPosition != null) {
      final distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        _destinationPosition!.latitude,
        _destinationPosition!.longitude,
      );
      
      setState(() {
        _distanceRemaining = '${(distance / 1000).toStringAsFixed(1)} km';
        
        if (_currentSpeed > 0) {
          final timeInHours = distance / (_currentSpeed * 1000);
          final hours = timeInHours.floor();
          final minutes = ((timeInHours - hours) * 60).round();
          _timeToDestination = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
        } else {
          _timeToDestination = '--:--';
        }
      });
    }
  }

  Future<void> _updateMapZoom() async {
    if (_mapController == null || _currentPosition == null) return;

    if (_shouldAutoZoom) {
      if (_destinationPosition != null) {
        // If destination is set, zoom to show both current location and destination
        final bounds = LatLngBounds(
          southwest: LatLng(
            min(_currentPosition!.latitude, _destinationPosition!.latitude),
            min(_currentPosition!.longitude, _destinationPosition!.longitude),
          ),
          northeast: LatLng(
            max(_currentPosition!.latitude, _destinationPosition!.latitude),
            max(_currentPosition!.longitude, _destinationPosition!.longitude),
          ),
        );

        await _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(
            bounds,
            left: 50, right: 50, top: 150, bottom: 150,
          ),
        );
      } else {
        // If no destination, zoom to 3 km radius around current location
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            _calculateZoomForRadius(_autoZoomRadius),
          ),
        );
      }
    }
  }

  double _calculateZoomForRadius(double radiusInKm) {
    // Approximate zoom level calculation for a given radius
    // This is an approximation and may need adjustment based on testing
    return 15.0 - log(radiusInKm) / log(2);
  }

  void _handleMapInteraction() {
    setState(() {
      _userInteractingWithMap = true;
      _lastUserInteraction = DateTime.now();
      _shouldAutoZoom = false;
    });
  }

  void _handleMapIdle() {
    if (_userInteractingWithMap) {
      setState(() {
        _userInteractingWithMap = false;
        _lastUserInteraction = DateTime.now();
        _shouldAutoZoom = true;
      });
      _updateMapZoom();
    }
  }

  /// Check if the driver has crossed a village boundary
  Future<void> _checkVillageCrossing(Position currentPosition) async {
    if (_routePoints.isEmpty) return;

    // Only check every 500 meters to avoid too frequent checks
    final distanceTraveled = _calculateTraveledDistance();
    if (distanceTraveled - _lastVillageCheckDistance < _villageCheckInterval) {
      return;
    }
    _lastVillageCheckDistance = distanceTraveled;

    try {
      // Use the TripService to get the village name and center
      final tripService = Provider.of<TripService>(context, listen: false);
      final latLng = latlong2.LatLng(currentPosition.latitude, currentPosition.longitude);
      final villageName = await tripService.getVillageName(latLng);
      if (villageName == null) return;
      final villageCenter = await tripService.getVillageCenter(villageName);
      if (villageCenter == null) return;
      final distance = const latlong2.Distance().distance(latLng, villageCenter);
      if (distance > MapConstants.villageDetectionRadius) return;
      if (_passedVillages.contains(villageName)) return;

          // Add to passed villages set
          _passedVillages.add(villageName);
          
          // Create a village crossing record
          final now = DateTime.now();
          final crossing = VillageCrossing(
            name: villageName,
            timestamp: now,
            latitude: currentPosition.latitude,
            longitude: currentPosition.longitude,
          );
          
          // Add to the list of crossings
          setState(() {
            _villageCrossings.add(crossing);
          });
          
          // Save to trip data if needed
          _saveCrossingToTripData(crossing);
          
          // Show notification
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.location_city, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🏁 You crossed $villageName',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            'at ${crossing.formattedTime}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.white,
                duration: const Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.all(10),
                action: SnackBarAction(
                  label: 'VIEW LOG',
                  textColor: Theme.of(context).primaryColor,
                  onPressed: () {
                    setState(() {
                      _showVillageCrossingLog = true;
                    });
                  },
                ),
              ),
            );
      }
    } catch (e) {
      print('Error checking village crossing: $e');
    }
  }
  
  /// Save village crossing data to trip record
  void _saveCrossingToTripData(VillageCrossing crossing) {
    // This could save to local storage or to a backend service
    // For now, we'll just keep it in memory
    try {
      if (_tripId != null) {
        // Here you would typically save to a database
        // For example:
        // _tripService.addVillageCrossing(_tripId!, crossing.toJson());
        print('Saved crossing of ${crossing.name} at ${crossing.formattedTime} to trip $_tripId');
      }
    } catch (e) {
      print('Error saving village crossing: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: _isUIVisible ? AppBar(
        title: const Text('Driver Dashboard'),
        actions: [
          if (_destinationPosition != null)
            IconButton(
              icon: const Icon(Icons.cancel),
              tooltip: 'Cancel Destination',
              onPressed: _cancelDestination,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeLocation,
          ),
        ],
      ) : null,
      body: Stack(
      children: [
        // Map
        MaplibreMap(
          styleString: 'https://api.maptiler.com/maps/streets/style.json?key=${dotenv.env['MAPTILER_API_KEY']}',
          initialCameraPosition: CameraPosition(
            target: LatLng(
                _currentPosition?.latitude ?? 16.5062,
                _currentPosition?.longitude ?? 80.6480,
            ),
            zoom: 15.0,
          ),
          myLocationEnabled: true,
          myLocationTrackingMode: MyLocationTrackingMode.tracking,
          onMapCreated: _onMapCreated,
          onStyleLoadedCallback: () {
            if (_currentPosition != null) {
              _updateDriverMarker();
            }
          },
            onCameraIdle: () {
              _handleMapInteractionEnd();
              if (_userInteractingWithMap) {
                setState(() {
                  _userInteractingWithMap = false;
                  _lastUserInteraction = DateTime.now();
                  _shouldAutoZoom = true;
                });
                _updateMapZoom();
              }
            },
            onMapClick: (point, latLng) {
              _handleMapInteractionStart();
              setState(() {
                _userInteractingWithMap = true;
                _lastUserInteraction = DateTime.now();
                _shouldAutoZoom = false;
              });
              _handleMapClick(latLng);
            },
            compassEnabled: true,
            zoomGesturesEnabled: true,
            rotateGesturesEnabled: true,
            scrollGesturesEnabled: true,
            doubleClickZoomEnabled: true,
            minMaxZoomPreference: const MinMaxZoomPreference(1.0, 20.0),
          ),
          
          // UI Components that should be hidden during manual control
          if (_isUIVisible) ...[
            // Search bars
        Positioned(
          top: 16,
          left: 16,
          right: 16,
              child: _buildSearchBars(),
        ),
        
            // Location button
        Positioned(
          bottom: 200,
          right: 20,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _centerOnCurrentLocation,
                borderRadius: BorderRadius.circular(8.0),
                child: const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Icon(
                    Icons.my_location,
                    color: Colors.blue,
                    size: 28.0,
                  ),
                ),
              ),
            ),
          ),
        ),
        
            // Bottom info card
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
                          // Driver ID with edit button
                          Row(
                            children: [
                              const Icon(Icons.person, size: 20),
                              const SizedBox(width: 8),
                              if (_isEditingDriverId)
                                Expanded(
                                  child: TextField(
                                    controller: _driverIdController,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    ),
                                    onSubmitted: (value) {
                                      setState(() {
                                        _driverId = value;
                                        _isEditingDriverId = false;
                                      });
                                    },
                                  ),
                                )
                              else
                                Expanded(
                                  child: Text(
                    'Driver ID: ${_driverId ?? 'Not Set'}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                                ),
                              IconButton(
                                icon: Icon(_isEditingDriverId ? Icons.check : Icons.edit),
                                onPressed: () {
                                  setState(() {
                                    if (_isEditingDriverId) {
                                      _driverId = _driverIdController.text;
                                    }
                                    _isEditingDriverId = !_isEditingDriverId;
                                  });
                                },
                                iconSize: 20,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          
                          // Route information
                  if (_destinationPosition != null) ...[
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (_estimatedDistance != null)
                                  Row(
                                    children: [
                                      const Icon(Icons.directions_car, size: 16),
                                      const SizedBox(width: 4),
                                      Text(_estimatedDistance!),
                                    ],
                                  ),
                                if (_estimatedTime != null)
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time, size: 16),
                                      const SizedBox(width: 4),
                                      Text(_estimatedTime!),
                                    ],
                                  ),
                              ],
                            ),
                            if (_estimatedArrivalTime != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.schedule, size: 16),
                                    const SizedBox(width: 4),
                    Text(
                                      'ETA: ${_estimatedArrivalTime!.hour.toString().padLeft(2, '0')}:${_estimatedArrivalTime!.minute.toString().padLeft(2, '0')}',
                    ),
                  ],
                                ),
                              ),
                          ],
                          
                  const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                      // Show Enter ID dialog or logic
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Enter Driver ID'),
                          content: TextField(
                            decoration: const InputDecoration(hintText: 'Enter your ID'),
                            onSubmitted: (value) {
                              // Save the ID or handle as needed
                              Navigator.pop(context);
                            },
                            ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                            },
                    icon: const Icon(Icons.person),
                    label: const Text('Enter ID'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
          
          // Restore UI button (shown only during manual control)
          if (!_isUIVisible)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _toggleUIVisibility,
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Icon(
                        Icons.visibility,
                        color: Colors.blue,
                        size: 24.0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBars() {
    return Card(
      elevation: 4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Starting point field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.my_location, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Focus(
                    onFocusChange: (hasFocus) {
                      setState(() {
                        // Update state to show/hide clear icon based on focus
                        _startLocationController.text.isNotEmpty || hasFocus
                            ? _showStartClearIcon = true
                            : _showStartClearIcon = false;
                      });
                    },
                    child: TextField(
                      controller: _startLocationController,
                      decoration: InputDecoration(
                        hintText: 'Enter starting point or choose current location',
                        border: InputBorder.none,
                        suffixIcon: _showStartClearIcon
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _startLocationController.clear();
                                  setState(() {
                                    _startLocationResults = [];
                                    _showStartClearIcon = false;
                                  });
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _showStartClearIcon = value.isNotEmpty;
                          if (value.length > 2) {
                            _searchStartLocation(value);
                          } else {
                            _startLocationResults = [];
                          }
                        });
                      },
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (context) => DraggableScrollableSheet(
                            initialChildSize: 0.4,
                            minChildSize: 0.3,
                            maxChildSize: 0.8,
                            expand: false,
                            builder: (context, scrollController) => Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.my_location, color: Colors.blue),
                                  title: const Text('Use Current Location'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    if (_currentPosition != null) {
                                      setState(() {
                                        _startLocationController.text = 'Current Location';
                                        _startLocationResults = [];
                                        _showStartClearIcon = true;
                                      });
                                    }
                                  },
                                ),
                                const Divider(),
                                const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text('Or search for a location:', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                Expanded(
                                  child: ListView.builder(
                                    controller: scrollController,
                                    itemCount: _startLocationResults.length,
                                    itemBuilder: (context, index) {
                                      final result = _startLocationResults[index];
                                      return ListTile(
                                        leading: const Icon(Icons.location_city),
                                        title: Text(result['name']),
                                        subtitle: Text(
                                          result['full_address'],
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        onTap: () {
                                          Navigator.pop(context);
                                          setState(() {
                                            _startLocationController.text = result['name'];
                                            _startLocationResults = [];
                                            _showStartClearIcon = true;
                                          });
                                        },
                                      );
                                    },
                                  ),
                                ),
                                
                                // Village crossing log
                                if (_showVillageCrossingLog)
                                  Positioned(
                                    top: 80,
                                    left: 16,
                                    right: 16,
                                    child: VillageCrossingLog(
                                      crossings: _villageCrossings,
                                      onClose: () {
                                        setState(() {
                                          _showVillageCrossingLog = false;
                                        });
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Destination field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.red),
                const SizedBox(width: 12),
                Expanded(
                  child: Focus(
                    onFocusChange: (hasFocus) {
                      setState(() {
                        // Update state to show/hide clear icon based on focus
                        _destinationController.text.isNotEmpty || hasFocus
                            ? _showDestClearIcon = true
                            : _showDestClearIcon = false;
                      });
                    },
                    child: TextField(
                      controller: _destinationController,
                      decoration: InputDecoration(
                        hintText: 'Enter destination',
                        border: InputBorder.none,
                        suffixIcon: _showDestClearIcon
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _destinationController.clear();
                                  setState(() {
                                    _searchResults = [];
                                    _showDestClearIcon = false;
                                  });
                                  _clearSearchResultMarkers();
                                  _cancelDestination();
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _showDestClearIcon = value.isNotEmpty;
                          if (value.length > 2) {
                            _searchLocation(value);
                          } else if (value.isEmpty) {
                            _searchResults = [];
                            _clearSearchResultMarkers();
                            _cancelDestination();
                          }
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Search results
          if (_searchResults.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final result = _searchResults[index];
                  return ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(result['name']),
                    subtitle: Text(
                      result['full_address'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      _destinationController.text = result['name'];
                      _selectDestination(
                        LatLng(result['latitude'], result['longitude'])
                      );
                      setState(() => _searchResults = []);
                    },
                  );
                },
              ),
          ),
        ],
      ),
    );
  }
}