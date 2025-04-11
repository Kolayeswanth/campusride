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
import '../../../core/services/trip_service.dart';
import '../../../core/services/map_service.dart';
import '../../../core/utils/location_utils.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/platform_safe_map.dart';
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
  List<latlong2.LatLng> _routePoints = [];
  List<latlong2.LatLng> _completedPoints = [];
  double _completion = 0.0; // 0 to 1
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
  Timer? _pulseTimer;
  double _pulseRadius = 15.0;
  bool _pulseExpanding = true;
  
  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _startPulseAnimation();
  }
  
  void _startPulseAnimation() {
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_pulseExpanding) {
        _pulseRadius += 0.5;
        if (_pulseRadius >= 25.0) {
          _pulseExpanding = false;
        }
      } else {
        _pulseRadius -= 0.5;
        if (_pulseRadius <= 15.0) {
          _pulseExpanding = true;
        }
      }
      
      // Update the circle if it exists
      _updateLocationCircle();
    });
  }
  
  void _updateLocationCircle() {
    if (_mapController != null && _currentPosition != null && _locationCircle != null) {
      _mapController!.updateCircle(_locationCircle!, CircleOptions(
        geometry: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        circleRadius: _pulseRadius,
      ));
    }
  }
  
  @override
  void dispose() {
    _stopLocationUpdates();
    _locationUpdateTimer?.cancel();
    _pulseTimer?.cancel();
    
    if (_mapController != null) {
      // Clean up map resources
      _mapController!.onSymbolTapped.remove(_onSymbolTapped);
      
      // Clean up circles
      if (_locationCircle != null) {
        _mapController!.removeCircle(_locationCircle!);
      }
      
      // Clean up symbols
      for (final symbol in _symbols) {
        _mapController!.removeSymbol(symbol);
      }
      
      // Clean up lines
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
  
  Future<void> _initializeLocation() async {
    try {
      // First check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Show dialog to prompt user to enable location services
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Location Services Disabled'),
              content: const Text(
                'Location services are disabled. Please enable location services in your device settings to use this feature.'
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Open Settings'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    Geolocator.openLocationSettings();
                  },
                ),
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
        throw Exception('Location services are disabled');
      }
      
      // Check and request location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Show dialog to guide user to app settings
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Location Permission Required'),
              content: const Text(
                'Location permission is permanently denied. Please enable it in app settings to use this feature.'
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Open Settings'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    Geolocator.openAppSettings();
                  },
                ),
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
        throw Exception('Location permission permanently denied');
      }

      // Try to get current position with a timeout
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (timeoutError) {
        print('Timeout getting current position: $timeoutError');
        
        // Try to get last known position as fallback
        position = await Geolocator.getLastKnownPosition();
        if (position == null) {
          throw Exception('Could not determine your location. Please try again later.');
        }
      }
      
      print('Got position: ${position.latitude}, ${position.longitude}');
      
      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });
      
      // Create a sample route for testing
      await _createSampleRoute();
      
    } catch (e) {
      print('Error initializing location: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      
      // Show error to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
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
        latlong2.LatLng(currentLat, currentLng), // Start point
        latlong2.LatLng(currentLat + offset, currentLng), // North
        latlong2.LatLng(currentLat + offset, currentLng + offset), // Northeast
        latlong2.LatLng(currentLat, currentLng + offset), // East
        latlong2.LatLng(currentLat - offset, currentLng + offset), // Southeast
        latlong2.LatLng(currentLat - offset, currentLng), // South
        latlong2.LatLng(currentLat - offset, currentLng - offset), // Southwest
        latlong2.LatLng(currentLat, currentLng - offset), // West
        latlong2.LatLng(currentLat + offset, currentLng - offset), // Northwest
        latlong2.LatLng(currentLat, currentLng), // Back to start
      ];
    });

    // Update the route display
    await _updateRouteDisplay();
  }
  
  void _onMapCreated(dynamic controller) {
  if (controller is MaplibreMapController) {
    print("Map controller created");
    
    setState(() {
      _mapController = controller;
      _isLoading = false; // Map is now loaded
    });
    
    // Set up symbol tap handler
    _mapController!.onSymbolTapped.add(_onSymbolTapped);
    
    // Since onStyleLoadedCallback isn't available, we'll handle initialization here
    // Wait briefly to ensure the map is fully initialized
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_currentPosition != null) {
        _updateDriverMarker();
        _centerOnCurrentLocation(); // Center on current location when map is ready
      } else {
        // If we don't have a position yet, try to get one
        _initializeLocation().then((_) {
          if (_currentPosition != null) {
            _updateDriverMarker();
            _centerOnCurrentLocation();
          }
        });
      }
    });
    
    _startLocationUpdates();
  } else {
    print("Controller is not MaplibreMapController: $controller");
  }
}
  
  Future<void> _updateDriverMarker() async {
    if (_mapController == null || _currentPosition == null) {
      print("Cannot update driver marker: controller or position is null");
      return;
    }

    try {
      // Check if map is ready
      bool isMapReady = true;
      try {
        // Try a simple operation to see if the map is ready
        await _mapController!.getVisibleRegion();
      } catch (e) {
        print("Map is not ready yet: $e");
        isMapReady = false;
      }
      
      if (!isMapReady) {
        print("Map is not ready, will try again later");
        // Try again after a short delay
        Future.delayed(const Duration(seconds: 1), () => _updateDriverMarker());
        return;
      }
      
      if (_driverMarker != null) {
        await _mapController!.removeSymbol(_driverMarker!);
        _symbols.remove(_driverMarker);
      }
      
      // Remove previous circle if it exists
      if (_locationCircle != null) {
        await _mapController!.removeCircle(_locationCircle!);
      }
      
      // Add a circle to highlight the current position
      _locationCircle = await _mapController!.addCircle(
        CircleOptions(
          geometry: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          circleColor: '#4285F4', // Google Maps blue
          circleOpacity: 0.3,
          circleRadius: _pulseRadius, // Use the pulse radius for animation
          circleStrokeColor: '#4285F4',
          circleStrokeWidth: 2.0,
        ),
      );
      
      // Then add the driver marker
      _driverMarker = await _mapController!.addSymbol(
        SymbolOptions(
          geometry: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          iconImage: 'bus',
          iconSize: 1.2, // Slightly larger for better visibility
          textField: _driverId ?? 'Driver',
          textOffset: const Offset(0, 1.5),
          textColor: '#0277BD', // Dark blue for better visibility
          textSize: 14.0,
          textHaloColor: '#FFFFFF', // White halo for better contrast
          textHaloWidth: 1.0,
        ),
        {
          'type': 'driver',
          'id': _driverId ?? 'driver',
        },
      );
      
      _symbols.add(_driverMarker!);

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
      const Duration(seconds: 3), // More frequent updates for better tracking
      (_) => _updateLocation(),
    );
    
    // Immediately update location
    _updateLocation();
  }
  
  Future<void> _updateLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      
      if (mounted) {
        setState(() => _currentPosition = position);
        print("Location updated: ${position.latitude}, ${position.longitude}");
        
        await _updateDriverMarker();
        if (_destinationPosition != null) {
          await _updateRouteLine();
        }
      }
    } catch (e) {
      print('Error updating location: $e');
      
      // Try to get last known position as fallback
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
  
  Future<void> _centerOnCurrentLocation() async {
    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Getting your current location...'),
        duration: Duration(seconds: 1),
      ),
    );
    
    try {
      // First check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Show dialog to prompt user to enable location services
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Location Services Disabled'),
              content: const Text(
                'Location services are disabled. Please enable location services in your device settings to use this feature.'
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Open Settings'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    Geolocator.openLocationSettings();
                  },
                ),
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
        throw Exception('Location services are disabled');
      }
      // First try to get the most up-to-date position
      Position? position;
      try {
        // Request a high-accuracy position with a reasonable timeout
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation, // Use highest accuracy
          timeLimit: const Duration(seconds: 10),
        );
        
        setState(() => _currentPosition = position);
        print("Got current position: ${position.latitude}, ${position.longitude}");
      } catch (e) {
        print('Could not get current position: $e');
        // Try to get last known position if current position fails
        try {
          position = await Geolocator.getLastKnownPosition();
          if (position != null) {
            setState(() => _currentPosition = position);
            print("Using last known position: ${position.latitude}, ${position.longitude}");
          }
        } catch (e2) {
          print('Could not get last known position: $e2');
        }
        
        // If we still don't have a position
        if (_currentPosition == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to determine your location. Please check your location permissions.')),
          );
          return;
        }
      }
      
      // If map controller is not ready, wait for it
      if (_mapController == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Map is initializing. Please try again in a moment.')),
        );
        return;
      }
      
      // Check if map is ready
      bool isMapReady = true;
      try {
        // Try a simple operation to see if the map is ready
        await _mapController!.getVisibleRegion();
      } catch (e) {
        print("Map is not ready yet: $e");
        isMapReady = false;
      }
      
      if (!isMapReady) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Map is still loading. Trying again in a moment...')),
        );
        
        // Try again after a short delay
        Future.delayed(const Duration(seconds: 2), () {
          _centerOnCurrentLocation();
        });
        return;
      }
      
      // Update the driver marker with the current position
      await _updateDriverMarker();
      
      // Animate the camera to the current position with a higher zoom level for better visibility
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          17.0, // Higher zoom level for better visibility
        ),
      );
      
      // Show a confirmation to the user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Centered on your current location'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error centering on current location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error centering on current location: $e')),
      );
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
  
  void _onMapClick(latlong2.LatLng coordinates) async {
    // Convert latlong2.LatLng to maplibre_gl.LatLng
    final maplibreCoordinates = LatLng(coordinates.latitude, coordinates.longitude);
    
    // Use the selectDestination method to handle the click
    _selectDestination(maplibreCoordinates);
  }
  
  void _onSymbolTapped(Symbol symbol) {
    // Handle symbol tap
    if (symbol.data != null) {
      final data = symbol.data!;
      
      if (data.containsKey('type')) {
        if (data['type'] == 'search_result') {
          // Handle search result tap
          final lat = data['latitude'] as double;
          final lng = data['longitude'] as double;
          _selectDestination(LatLng(lat, lng));
        } 
        else if (data['type'] == 'driver') {
          // Show current location info when tapping on driver marker
          _showCurrentLocationInfo();
        }
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Latitude: ${_currentPosition!.latitude.toStringAsFixed(6)}'),
            Text('Longitude: ${_currentPosition!.longitude.toStringAsFixed(6)}'),
            Text('Altitude: ${_currentPosition!.altitude.toStringAsFixed(2)} m'),
            Text('Speed: ${_currentPosition!.speed.toStringAsFixed(2)} m/s'),
            Text('Heading: ${_currentPosition!.heading.toStringAsFixed(2)}°'),
            Text('Accuracy: ${_currentPosition!.accuracy.toStringAsFixed(2)} m'),
            const SizedBox(height: 16),
            const Text('Tap the "My Location" button to center the map on your current location.'),
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
  
  void _onMapLongClick(LatLng latLng) {
    // Handle map long click
    print('Map long clicked at: ${latLng.latitude}, ${latLng.longitude}');
    _selectDestination(latLng);
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
      // Use MapTiler Geocoding API
      final apiKey = dotenv.env['MAPTILER_API_KEY'] ?? '';
      final url = 'https://api.maptiler.com/geocoding/$query.json?key=$apiKey';
      
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;
        
        setState(() {
          _searchResults = features.map((feature) {
            final coordinates = feature['geometry']['coordinates'] as List;
            return {
              'name': feature['place_name'],
              'latitude': coordinates[1],
              'longitude': coordinates[0],
            };
          }).toList();
          _isSearching = false;
        });
        
        // Show search results on map
        _showSearchResultsOnMap();
      } else {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to search location: ${response.statusCode}')),
        );
      }
    } catch (e) {
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching location: $e')),
      );
    }
  }
  
  Future<void> _showSearchResultsOnMap() async {
    if (_mapController == null) return;
    
    // Clear previous search result markers
    await _clearSearchResultMarkers();
    
    // Add markers for search results
    for (final result in _searchResults) {
      final marker = await _mapController!.addSymbol(
        SymbolOptions(
          geometry: LatLng(result['latitude'], result['longitude']),
          iconImage: 'marker',
          iconSize: 1.0,
          textField: result['name'],
          textOffset: const Offset(0, 1.5),
          iconColor: Colors.blue.toHexStringRGB(),
        ),
        {
          'type': 'search_result',
          'latitude': result['latitude'],
          'longitude': result['longitude'],
        },
      );
      
      _symbols.add(marker);
    }
    
    // If we have results, fit the map to show all of them
    if (_searchResults.isNotEmpty) {
      final points = _searchResults.map((result) => 
        LatLng(result['latitude'], result['longitude'])).toList();
      
      // Add current location to the points if available
      if (_currentPosition != null) {
        points.add(LatLng(_currentPosition!.latitude, _currentPosition!.longitude));
      }
      
      await _fitMapToBounds(points);
    }
  }
  
  Future<void> _clearSearchResultMarkers() async {
    if (_mapController == null) return;
    
    final symbolsToRemove = _symbols.where((symbol) {
      if (symbol.data != null) {
        final data = symbol.data!;
        return data.containsKey('type') && data['type'] == 'search_result';
      }
      return false;
    }).toList();
    
    for (final symbol in symbolsToRemove) {
      await _mapController!.removeSymbol(symbol);
      _symbols.remove(symbol);
    }
  }
  
  Future<void> _fitMapToBounds(List<LatLng> points) async {
    if (_mapController == null || points.isEmpty) return;
    
    try {
      // Calculate bounds manually
      double minLat = points[0].latitude;
      double maxLat = points[0].latitude;
      double minLng = points[0].longitude;
      double maxLng = points[0].longitude;
      
      for (final point in points) {
        minLat = minLat < point.latitude ? minLat : point.latitude;
        maxLat = maxLat > point.latitude ? maxLat : point.latitude;
        minLng = minLng < point.longitude ? minLng : point.longitude;
        maxLng = maxLng > point.longitude ? maxLng : point.longitude;
      }
      
      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );
      
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          bounds,
          top: 50,
          right: 50,
          bottom: 50,
          left: 50,
        ),
      );
    } catch (e) {
      print('Error fitting map to bounds: $e');
    }
  }
  
  void _selectDestination(LatLng coordinates) async {
    if (_driverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your driver ID first')),
      );
      return;
    }

    // Set destination marker
    if (_destinationMarker != null) {
      await _mapController?.removeSymbol(_destinationMarker!);
      _symbols.remove(_destinationMarker);
    }

    _destinationMarker = await _mapController?.addSymbol(
      SymbolOptions(
        geometry: coordinates,
        iconImage: 'marker-end',
        iconSize: 1.0,
        textField: 'Destination',
        textOffset: const Offset(0, 1.5),
      ),
      {
        'type': 'destination',
      },
    );
    
    if (_destinationMarker != null) {
      _symbols.add(_destinationMarker!);
    }

    setState(() => _destinationPosition = coordinates);
    await _updateRouteLine();
    
    // Clear search results
    setState(() {
      _searchResults = [];
      _searchController.clear();
    });
    await _clearSearchResultMarkers();
  }
  
  void _stopLocationUpdates() {
    _locationUpdateTimer?.cancel();
    setState(() {
      _isTracking = false;
    });
  }
  
  void _updateRouteCompletion(latlong2.LatLng currentPosition) {
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
  
  double _calculateDistance(latlong2.LatLng point1, latlong2.LatLng point2) {
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
          {
            'type': 'route_start',
          },
        );
        _symbols.add(_startMarker!);
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
          {
            'type': 'route_end',
          },
        );
        _symbols.add(_endMarker!);
      }
    } catch (e) {
      print('Error updating route display: $e');
    }
  }
  
  Future<void> _startTrip() async {
    // If driver ID is not set, prompt for it
    if (_driverId == null) {
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
      return;
    }
    
    // If destination is not set, prompt user to set it
    if (_destinationPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please tap on the map to set your destination first')),
      );
      return;
    }
    
    // Start the trip
    setState(() {
      _isTripStarted = true;
      _isTracking = true;
    });
    
    // Start location updates more frequently for live tracking
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _updateLocation(),
    );
    
    // Update UI to show trip has started
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Trip started! Your location is now being tracked.')),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    // Check if we have a current position and try to get it if not
    if (_currentPosition == null && !_isLoading && _error == null) {
      // Try to get the location again
      Future.delayed(Duration.zero, () {
        _initializeLocation();
      });
    }
    
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Getting your location...'),
            ],
          ),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
      ),

      body: _isLoading 
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Getting your location...'),
              ],
            ),
          )
        : Stack(
        children: [
          PlatformSafeMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: LatLng(
                _currentPosition?.latitude ?? 37.7749, // Default to San Francisco if location not available
                _currentPosition?.longitude ?? -122.4194,
              ),
              zoom: 15.0,
            ),
            myLocationEnabled: true,
            onMapClick: _onMapClick,
          ),
          
          // Search bar at the top
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search for destination',
                              border: InputBorder.none,
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchResults = [];
                                      });
                                      _clearSearchResultMarkers();
                                    },
                                  )
                                : null,
                            ),
                            onChanged: (value) {
                              if (value.length > 2) {
                                _searchLocation(value);
                              } else if (value.isEmpty) {
                                setState(() {
                                  _searchResults = [];
                                });
                                _clearSearchResultMarkers();
                              }
                            },
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
                            title: Text(result['name']),
                            onTap: () {
                              _selectDestination(LatLng(
                                result['latitude'],
                                result['longitude'],
                              ));
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Live location button - positioned at the bottom right corner, above the bottom card
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
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Icon(
                      Icons.my_location,
                      color: Colors.blue.shade700,
                      size: 28.0,
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Bottom card with driver info and trip controls
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
                    if (_destinationPosition != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Destination: ${_destinationPosition!.latitude.toStringAsFixed(4)}, ${_destinationPosition!.longitude.toStringAsFixed(4)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    if (_currentPosition != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Current Location: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (_isTripStarted) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _isTracking = !_isTracking;
                              });
                              if (_isTracking) {
                                _startLocationUpdates();
                              } else {
                                _stopLocationUpdates();
                              }
                            },
                            icon: Icon(_isTracking ? Icons.pause : Icons.play_arrow),
                            label: Text(_isTracking ? 'Pause' : 'Resume'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isTracking ? Colors.orange : Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _isTripStarted = false;
                                _isTracking = false;
                              });
                              _stopLocationUpdates();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Trip ended')),
                              );
                            },
                            icon: const Icon(Icons.stop),
                            label: const Text('End Trip'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      ElevatedButton.icon(
                        onPressed: _startTrip,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Trip'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
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