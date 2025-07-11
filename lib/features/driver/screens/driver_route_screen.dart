import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/services/trip_service.dart';
import '../../../core/services/ola_maps_service.dart';
import '../../../core/theme/app_colors.dart';

class DriverRouteScreen extends StatefulWidget {
  final String routeId;

  const DriverRouteScreen({
    Key? key,
    required this.routeId,
  }) : super(key: key);

  @override
  State<DriverRouteScreen> createState() => _DriverRouteScreenState();
}

class _DriverRouteScreenState extends State<DriverRouteScreen> {
  bool _isLoading = true;
  String? _error;
  BusRoute? _route;
  List<LatLng> _routePoints = [];
  List<Polyline> _polylines = [];
  List<Marker> _markers = [];
  final MapController _mapController = MapController();
  bool _isRideActive = false;
  DriverTrip? _currentTrip;
  final OlaMapsService _olaMapsService = OlaMapsService();
  bool _isLoadingRoute = false;
  bool _locationPermissionDenied = false;
  bool _followDriver = true; // Auto-follow driver during live tracking
  double _currentZoom = 16.0; // Zoom level for live tracking
  
  // Default map center (India)
  LatLng _mapCenter = const LatLng(20.5937, 78.9629);
  
  // Off-route detection and rerouting
  bool _isDriverOffRoute = false;
  List<LatLng> _reroute = [];
  Timer? _offRouteCheckTimer;
  final double _offRouteThresholdMeters = 50.0; // Consider off-route if more than 50m from route
  bool _isGeneratingReroute = false;
  DateTime? _lastRerouteTime;
  // Direction arrow for driver
  double _driverHeading = 0.0;

  @override
  void initState() {
    super.initState();
    _loadRouteData();
    _checkLocationPermission();
    _checkForExistingTrip();
  }

  Future<void> _checkForExistingTrip() async {
    try {
      final tripService = Provider.of<TripService>(context, listen: false);
      final existingTrip = await tripService.getDriverActiveTrip(widget.routeId);
      
      if (existingTrip != null) {
        print('Found existing trip on this route: ${existingTrip.id}');
        setState(() {
          _isRideActive = true;
          _currentTrip = existingTrip;
        });
        
        // If the trip service doesn't have this trip loaded, resume it
        if (tripService.currentTrip?.id != existingTrip.id) {
          await _resumeExistingTrip(existingTrip);
        }
      }
    } catch (e) {
      print('Error checking for existing trip: $e');
    }
  }

  Future<void> _resumeExistingTrip(DriverTrip trip) async {
    try {
      if (_route != null) {
        final tripService = Provider.of<TripService>(context, listen: false);
        final resumed = await tripService.resumeActiveTrip(trip, _route!);
        
        if (resumed) {
          print('Successfully resumed existing trip');
          _startLiveLocationTracking();
          
          // Center map on driver's current location if available
          final currentLocation = tripService.currentLocation;
          if (currentLocation != null) {
            _centerMapOnDriver(currentLocation);
          }
          
          _showSnackBar('Resumed ongoing trip - Live location sharing enabled');
        }
      }
    } catch (e) {
      print('Error resuming trip: $e');
      _showSnackBar('Error resuming trip: $e');
    }
  }

  /// Listen to live location updates and center map when active
  void _startLiveLocationTracking() {
    final tripService = Provider.of<TripService>(context, listen: false);
    
    // Listen to live location changes
    tripService.addListener(() {
      if (mounted && _isRideActive && tripService.currentLocation != null) {
        final currentLocation = tripService.currentLocation!;
        
        // For this implementation, we'll use a fixed heading or 
        // calculate it based on map view direction
        // In a real app, you would get this from the GPS bearing
        
        // Update driver marker with current position and heading
        _updateDriverMarker(currentLocation, _driverHeading);
        
        // Check if driver is off-route
        _checkIfDriverOffRoute(currentLocation);
        
        // Center map if following driver
        if (_followDriver) {
          _centerMapOnDriver(currentLocation);
        }
      }
    });
    
    // Start a timer to periodically check if driver is off-route
    _offRouteCheckTimer?.cancel();
    _offRouteCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted && _isRideActive && tripService.currentLocation != null) {
        _checkIfDriverOffRoute(tripService.currentLocation!);
      }
    });
  }
  
  /// Update the driver marker with the current position and heading
  void _updateDriverMarker(LatLng position, double heading) {
    setState(() {
      // Remove the old driver marker if it exists
      _markers.removeWhere((marker) => marker.key == const Key('driver_marker'));
      
      // Add the new driver marker
      _markers.add(
        Marker(
          key: const Key('driver_marker'),
          point: position,
          width: 60,
          height: 60,
          child: Transform.rotate(
            angle: heading * math.pi / 180,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.8),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.navigation,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      );
    });
  }

  /// Center map on driver's current location with smooth animation
  /// Implements a Google Maps-like navigation view with heading rotation
  void _centerMapOnDriver(LatLng driverLocation) {
    if (!mounted) return;
    
    try {
      // Calculate ideal zoom level based on current state
      double zoom = _currentZoom;
      double rotation = _driverHeading;
      
      // If off-route, zoom out slightly to show more context
      if (_isDriverOffRoute) {
        zoom = math.max(15.0, _currentZoom - 1.0);
      }
      
      // Use a navigation-style view with heading up when following driver
      if (_followDriver) {
        _mapController.moveAndRotate(
          driverLocation,
          zoom,
          rotation, // Orient map to driver heading
        );
        
        // Store the current zoom level
        _currentZoom = zoom;
      } else {
        // If not following, just center without rotation
        _mapController.move(driverLocation, zoom);
      }
    } catch (e) {
      debugPrint('Error centering map on driver: $e');
    }
  }

  /// Calculate live distance traveled based on current trip polyline
  double _calculateLiveDistance() {
    final tripService = Provider.of<TripService>(context, listen: false);
    final polyline = tripService.currentTripPolyline;
    
    if (polyline.length < 2) return 0.0;
    
    double totalDistance = 0.0;
    
    for (int i = 0; i < polyline.length - 1; i++) {
      // Simple distance calculation using Haversine formula approximation
      final lat1 = polyline[i].latitude * math.pi / 180;
      final lat2 = polyline[i + 1].latitude * math.pi / 180;
      final deltaLat = lat2 - lat1;
      final deltaLng = (polyline[i + 1].longitude - polyline[i].longitude) * math.pi / 180;
      
      final a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
          math.cos(lat1) * math.cos(lat2) *
          math.sin(deltaLng / 2) * math.sin(deltaLng / 2);
      final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
      final distance = 6371000 * c; // Earth's radius in meters
      
      totalDistance += distance;
    }
    
    return totalDistance / 1000; // Convert meters to kilometers
  }

  /// Toggle auto-follow mode
  void _toggleFollowDriver() {
    setState(() {
      _followDriver = !_followDriver;
    });
    
    // If re-enabling follow mode and ride is active, center on driver
    if (_followDriver && _isRideActive) {
      final tripService = Provider.of<TripService>(context, listen: false);
      if (tripService.currentLocation != null) {
        _centerMapOnDriver(tripService.currentLocation!);
      }
    }
  }

  Future<void> _checkLocationPermission() async {
    try {
      final status = await Permission.location.status;
      setState(() {
        _locationPermissionDenied = status.isDenied || status.isPermanentlyDenied;
      });
    } catch (e) {
      // If permission check fails, assume permission is needed
      setState(() {
        _locationPermissionDenied = true;
      });
    }
  }

  @override
  void dispose() {
    _offRouteCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRouteData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tripService = Provider.of<TripService>(context, listen: false);
      
      // Try to get the route from cache first
      _route = tripService.getRouteById(widget.routeId);
      
      // If route not found in cache, fetch routes
      if (_route == null) {
        print('Route not found in cache, fetching routes...');
        await tripService.fetchDriverRoutes();
        final routes = tripService.routes;
        
        _route = routes.firstWhere(
          (route) => route.id == widget.routeId,
          orElse: () => throw Exception('Route not found'),
        );
      } else {
        print('Using cached route: ${_route!.displayName}');
      }
      
      if (_route != null) {
        // Set initial map center
        _mapCenter = LatLng(
          (_route!.startLocation.latitude + _route!.endLocation.latitude) / 2,
          (_route!.startLocation.longitude + _route!.endLocation.longitude) / 2,
        );
        
        // Update markers
        _updateMarkers();
        
        // Get route directions using Ola Maps
        await _generateRoute();
        
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading route: $e';
        _isLoading = false;
      });
    }
  }

  void _updateMarkers() {
    setState(() {
      _markers.clear();
      
      if (_route != null) {
        // Start marker
        _markers.add(
          Marker(
            point: _route!.startLocation,
            width: 80,
            height: 80,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Start',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Icon(
                  Icons.play_arrow,
                  color: Colors.green,
                  size: 30,
                ),
              ],
            ),
          ),
        );
        
        // End marker
        _markers.add(
          Marker(
            point: _route!.endLocation,
            width: 80,
            height: 80,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'End',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Icon(
                  Icons.stop,
                  color: Colors.red,
                  size: 30,
                ),
              ],
            ),
          ),
        );
      }
    });
  }

  Future<void> _generateRoute() async {
    if (_route == null) return;
    
    setState(() {
      _isLoadingRoute = true;
      _error = null;
    });
    
    try {
      // Use Ola Maps to get detailed route directions
      final result = await _olaMapsService.getDirections(
        waypoints: [_route!.startLocation, _route!.endLocation],
        mode: 'DRIVING',
      );
      
      // Extract route data from the response
      final routeData = _extractRouteDataFromResponse(result);
      
      if (routeData != null && (routeData['coordinates'] as List<LatLng>).isNotEmpty) {
        setState(() {
          _routePoints = routeData['coordinates'] as List<LatLng>;
          
          // Create a styled polyline
          _polylines = [
            Polyline(
              points: _routePoints,
              color: AppColors.primary,
              strokeWidth: 4.0,
              pattern: StrokePattern.dashed(segments: [10, 5]),
            ),
          ];
        });
        
        // Fit map to route after a brief delay to ensure map is rendered
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _fitMapToRoute();
          }
        });
      } else {
        // Fallback to simple route calculation
        final tripService = Provider.of<TripService>(context, listen: false);
        _routePoints = await tripService.calculateRoute(
          _route!.startLocation,
          _route!.endLocation,
        );
        
        setState(() {
          _polylines = [
            Polyline(
              points: _routePoints,
              color: AppColors.primary,
              strokeWidth: 4.0,
              pattern: StrokePattern.dashed(segments: [10, 5]),
            ),
          ];
        });
        
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _fitMapToRoute();
          }
        });
      }
    } catch (e) {
      print('Failed to get Ola Maps directions: $e');
      // Fallback to simple route calculation
      final tripService = Provider.of<TripService>(context, listen: false);
      _routePoints = await tripService.calculateRoute(
        _route!.startLocation,
        _route!.endLocation,
      );
      
      setState(() {
        _polylines = [
          Polyline(
            points: _routePoints,
            color: AppColors.primary,
            strokeWidth: 4.0,
            pattern: StrokePattern.dashed(segments: [10, 5]),
          ),
        ];
      });
      
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _fitMapToRoute();
        }
      });
    } finally {
      setState(() {
        _isLoadingRoute = false;
      });
    }
  }

  /// Extract route data from the OlaMaps directions response
  Map<String, dynamic>? _extractRouteDataFromResponse(Map<String, dynamic> response) {
    try {
      // Extract route information from the response
      final routes = response['routes'] as List?;
      
      if (routes == null || routes.isEmpty) {
        debugPrint('No routes found in the response');
        return null;
      }
      
      final route = routes[0] as Map<String, dynamic>;
      
      // Extract distance and duration from legs
      double totalDistance = 0.0;
      double totalDuration = 0.0;
      List<LatLng> coordinates = [];
      
      // First, try to use the overview_polyline for the best route visualization
      final overviewPolyline = route['overview_polyline'] as String?;
      if (overviewPolyline != null && overviewPolyline.isNotEmpty) {
        debugPrint('Using overview_polyline for route visualization');
        coordinates = _decodePolyline(overviewPolyline);
      }
      
      final legs = route['legs'] as List?;
      
      if (legs != null && legs.isNotEmpty) {
        for (final leg in legs) {
          if (leg is Map<String, dynamic>) {
            // Extract distance (in meters, convert to km)
            if (leg['distance'] != null && leg['distance'] is num) {
              totalDistance += (leg['distance'] as num) / 1000.0;
            }
            
            // Extract duration (in seconds)
            if (leg['duration'] != null && leg['duration'] is num) {
              totalDuration += (leg['duration'] as num).toDouble();
            }
            
            // If we don't have overview polyline, fallback to step-by-step polylines
            if (coordinates.isEmpty) {
              final steps = leg['steps'] as List?;
              if (steps != null) {
                for (final step in steps) {
                  if (step is Map<String, dynamic>) {
                    // Try to use step polyline first
                    final stepPolyline = step['polyline'] as String?;
                    if (stepPolyline != null && stepPolyline.isNotEmpty) {
                      coordinates.addAll(_decodePolyline(stepPolyline));
                    } else {
                      // Fallback to start/end locations if no polyline
                      final startLoc = step['start_location'] as Map<String, dynamic>?;
                      if (startLoc != null && 
                          startLoc['lat'] != null && 
                          startLoc['lng'] != null) {
                        final lat = (startLoc['lat'] as num).toDouble();
                        final lng = (startLoc['lng'] as num).toDouble();
                        coordinates.add(LatLng(lat, lng));
                      }
                      
                      final endLoc = step['end_location'] as Map<String, dynamic>?;
                      if (endLoc != null && 
                          endLoc['lat'] != null && 
                          endLoc['lng'] != null) {
                        final lat = (endLoc['lat'] as num).toDouble();
                        final lng = (endLoc['lng'] as num).toDouble();
                        coordinates.add(LatLng(lat, lng));
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
      
      // Final fallback: create a simple line between start and end
      if (coordinates.isEmpty) {
        coordinates = [_route!.startLocation, _route!.endLocation];
      }
      
      // Convert duration from seconds to minutes for display
      final durationMinutes = totalDistance > 0 ? totalDuration / 60.0 : 0.0;
      
      debugPrint('Extracted route data - Distance: ${totalDistance.toStringAsFixed(2)} km, Duration: ${durationMinutes.toStringAsFixed(1)} min, Coordinates: ${coordinates.length} points');
      
      return {
        'coordinates': coordinates,
        'distance': totalDistance,
        'duration': durationMinutes,
      };
    } catch (e) {
      debugPrint('Error extracting route data: $e');
      return null;
    }
  }

  /// Decode a polyline string into a list of LatLng coordinates
  /// Uses the Google Polyline Algorithm (also used by Ola Maps)
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  void _fitMapToRoute() {
    if (_routePoints.isNotEmpty && mounted) {
      // Calculate bounds for all route points
      double minLat = _routePoints.first.latitude;
      double maxLat = _routePoints.first.latitude;
      double minLng = _routePoints.first.longitude;
      double maxLng = _routePoints.first.longitude;
      
      for (final point in _routePoints) {
        minLat = math.min(minLat, point.latitude);
        maxLat = math.max(maxLat, point.latitude);
        minLng = math.min(minLng, point.longitude);
        maxLng = math.max(maxLng, point.longitude);
      }
      
      // Add some padding to the bounds (about 10% on each side)
      final latPadding = (maxLat - minLat) * 0.1;
      final lngPadding = (maxLng - minLng) * 0.1;
      
      final bounds = LatLngBounds(
        LatLng(minLat - latPadding, minLng - lngPadding),
        LatLng(maxLat + latPadding, maxLng + lngPadding),
      );
      
      // Fit the map to show the bounds
      try {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(50),
          ),
        );
      } catch (e) {
        debugPrint('Error fitting map to route: $e');
        // Fallback to simple center
        _mapController.moveAndRotate(_mapCenter, 13.0, 0);
      }
    }
  }

  Future<void> _startRide() async {
    if (_route == null) {
      _showSnackBar('Route not loaded');
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _locationPermissionDenied = false;
      });

      // Verify location permissions first
      final locationStatus = await Permission.location.status;
      if (locationStatus.isDenied || locationStatus.isPermanentlyDenied) {
        setState(() {
          _isLoading = false;
          _locationPermissionDenied = true;
        });
        return;
      }

      // Verify location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoading = false);
        _showSnackBar('Location services are disabled. Please enable GPS.');
        return;
      }

      final tripService = Provider.of<TripService>(context, listen: false);
      
      // Check what action we can take on this route
      final canStartResult = await tripService.canStartTripOnRoute(widget.routeId);
      
      if (!canStartResult['canStart']) {
        setState(() => _isLoading = false);
        _showSnackBar(canStartResult['reason']);
        return;
      }

      DriverTrip? trip;
      
      try {
        if (canStartResult['hasExistingTrip']) {
          // Resume existing trip
          final existingTrip = canStartResult['existingTrip'] as DriverTrip;
          print('Resuming existing trip: ${existingTrip.id}');
          
          final resumed = await tripService.resumeActiveTrip(existingTrip, _route!);
          if (resumed) {
            trip = existingTrip;
            _showSnackBar('Resumed ongoing trip - Live location sharing enabled');
          } else {
            setState(() => _isLoading = false);
            _showSnackBar('Failed to resume existing trip');
            return;
          }
        } else {
          // Start new trip
          trip = await tripService.startDriverTrip(
            routeId: widget.routeId,
            busNumber: null, // No bus number required - will be auto-generated
            route: _route!,
          );
          
          if (trip != null) {
            _showSnackBar('Ride started successfully! Live location sharing enabled.');
          }
        }
      } catch (e) {
        setState(() => _isLoading = false);
        _showSnackBar('Error starting trip: ${e.toString()}');
        print('Trip start error: $e');
        return;
      }

      if (trip != null) {
        setState(() {
          _isRideActive = true;
          _currentTrip = trip;
          _isLoading = false;
          _locationPermissionDenied = false; // Clear permission denial state
          _followDriver = true; // Enable auto-follow when ride starts
          _currentZoom = 16.0; // Set zoom for navigation mode
        });
        
        // Start live location tracking
        _startLiveLocationTracking();
        
        // Center map on driver's current location if available
        final currentLocation = tripService.currentLocation;
        if (currentLocation != null) {
          _centerMapOnDriver(currentLocation);
        }
      } else {
        setState(() => _isLoading = false);
        _showSnackBar('Failed to start ride');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      
      // Check if the error is related to location permissions
      if (e.toString().contains('denied permissions') || 
          e.toString().contains('location') ||
          e.toString().contains('permission')) {
        setState(() {
          _locationPermissionDenied = true;
        });
      } else {
        _showSnackBar('Error starting ride: $e');
        print('General error in _startRide: $e');
      }
    }
  }

  Future<void> _endRide() async {
    try {
      setState(() => _isLoading = true);

      final tripService = Provider.of<TripService>(context, listen: false);
      final success = await tripService.endDriverTrip();

      if (success) {
        setState(() {
          _isRideActive = false;
          _currentTrip = null;
          _isLoading = false;
        });
        _showSnackBar('Ride ended successfully!');
        
        // Navigate back to driver dashboard
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        setState(() => _isLoading = false);
        _showSnackBar('Failed to end ride');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error ending ride: $e');
    }
  }

  Future<void> _requestLocationPermission() async {
    try {
      setState(() {
        _isLoading = true;
        _locationPermissionDenied = false;
      });

      // Check current permission status
      PermissionStatus status = await Permission.location.status;
      
      if (status.isDenied) {
        // Request permission
        status = await Permission.location.request();
      }
      
      if (status.isGranted) {
        // Permission granted, try to start the trip
        await _startRide();
      } else if (status.isPermanentlyDenied) {
        // Permission permanently denied, show settings option
        setState(() {
          _isLoading = false;
          _locationPermissionDenied = true;
        });
        _showSnackBar('Location permission permanently denied. Please enable it in app settings.');
      } else {
        // Permission denied
        setState(() {
          _isLoading = false;
          _locationPermissionDenied = true;
        });
        _showSnackBar('Location permission is required to start a ride.');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _locationPermissionDenied = true;
      });
      _showSnackBar('Error requesting permission: $e');
    }
  }

  Future<void> _openAppSettings() async {
    try {
      final opened = await openAppSettings();
      if (opened) {
        _showSnackBar('Please enable location permission and try again');
      } else {
        _showSnackBar(
          'Please go to Settings > Apps > CampusRide > Permissions > Location and enable location access',
        );
      }
    } catch (e) {
      _showSnackBar(
        'Please go to Settings > Apps > CampusRide > Permissions > Location and enable location access',
      );
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildMap() {
    return Stack(
      children: [
        // Main map container
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300, width: 2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: 13.0,
              maxZoom: 20.0,
              minZoom: 3.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.campusride',
                maxZoom: 20,
              ),
              // Planned route polyline
              PolylineLayer(
                polylines: _polylines,
              ),
              // Current trip polyline (live tracking)
              Consumer<TripService>(
                builder: (context, tripService, child) {
                  if (tripService.currentTripPolyline.isNotEmpty) {
                    return PolylineLayer(
                      polylines: [
                        Polyline(
                          points: tripService.currentTripPolyline,
                          color: Colors.green,
                          strokeWidth: 5.0,
                        ),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              
              // Driver direction arrow with off-route indicator
              if (_isRideActive)
                Consumer<TripService>(
                  builder: (context, tripService, _) {
                    if (tripService.currentLocation != null) {
                      // Check if map controller is ready for rendering
                      try {
                        // This is just to verify the camera is initialized properly
                        // We're not actually using the bounds here
                        var _ = _mapController.camera.pixelBounds;
                      } catch (e) {
                        return const SizedBox.shrink();
                      }
                      
                      try {
                        final screenPoint = _mapController.camera.latLngToScreenPoint(
                          tripService.currentLocation!);
                        
                        return CustomPaint(
                          painter: DirectionArrowPainter(
                            center: Offset(screenPoint.x.toDouble(), screenPoint.y.toDouble()),
                            heading: _driverHeading,
                            offRoute: _isDriverOffRoute,
                          ),
                          size: Size.infinite,
                        );
                      } catch (e) {
                        print('Error rendering direction arrow: $e');
                        return const SizedBox.shrink();
                      }
                    }
                    return const SizedBox.shrink();
                  },
                ),
              // Markers layer
              Consumer<TripService>(
                builder: (context, tripService, child) {
                  final allMarkers = <Marker>[
                    ..._markers,
                    // Current location marker if ride is active
                    if (tripService.currentLocation != null && _isRideActive)
                      Marker(
                        point: tripService.currentLocation!,
                        width: 50,
                        height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.blue.shade400,
                                Colors.blue.shade600,
                              ],
                            ),
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.navigation,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                  ];
                  
                  return MarkerLayer(markers: allMarkers);
                },
              ),
            ],
          ),
        ),
        
        // Map controls overlay
        Positioned(
          right: 16,
          bottom: 24,
          child: Column(
            children: [
              // Follow driver button (only show during active ride)
              if (_isRideActive) ...[
                Container(
                  decoration: BoxDecoration(
                    color: _followDriver ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: _toggleFollowDriver,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        Icons.my_location,
                        size: 20,
                        color: _followDriver ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Zoom in button
                    InkWell(
                      onTap: () {
                        _mapController.moveAndRotate(
                          _mapController.camera.center,
                          _mapController.camera.zoom + 1.0,
                          _mapController.camera.rotation,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        child: const Icon(
                          Icons.add,
                          size: 20,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: Colors.grey.withOpacity(0.3),
                    ),
                    // Zoom out button
                    InkWell(
                      onTap: () {
                        _mapController.moveAndRotate(
                          _mapController.camera.center,
                          _mapController.camera.zoom - 1.0,
                          _mapController.camera.rotation,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        child: const Icon(
                          Icons.remove,
                          size: 20,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Recenter button
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: () {
                    if (_routePoints.isNotEmpty) {
                      _fitMapToRoute();
                    } else {
                      _mapController.moveAndRotate(_mapCenter, 13.0, 0);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: const Icon(
                      Icons.center_focus_strong,
                      size: 20,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Loading indicator overlay
        if (_isLoadingRoute)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.1),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        Text('Generating route...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPermissionRequestCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.location_disabled,
            size: 48,
            color: Colors.orange.shade600,
          ),
          const SizedBox(height: 12),
          Text(
            'Location Permission Required',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'To start a ride and track your location, CampusRide needs access to your device location.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.orange.shade700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _requestLocationPermission,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openAppSettings,
                  icon: const Icon(Icons.settings),
                  label: const Text('Settings'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange.shade700,
                    side: BorderSide(color: Colors.orange.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.orange.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Go to Settings > Apps > CampusRide > Permissions > Location',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRideControls() {
    // Show permission request card if location permission is denied
    if (_locationPermissionDenied) {
      return _buildPermissionRequestCard();
    }
    
    if (_isRideActive) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          border: Border.all(color: Colors.green.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.radio_button_checked, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Ride Active',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Text(
                  'Bus: ${_currentTrip?.busNumber ?? "N/A"}',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.green.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Consumer<TripService>(
              builder: (context, tripService, child) {
                final duration = _currentTrip != null
                    ? DateTime.now().difference(_currentTrip!.startTime)
                    : Duration.zero;
                
                return Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        'Duration',
                        '${duration.inHours}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}',
                        Icons.access_time,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoCard(
                        'Distance',
                        '${_calculateLiveDistance().toStringAsFixed(1)} km',
                        Icons.straighten,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoCard(
                        'Status',
                        tripService.isLiveLocationSharing ? 'Live' : 'Offline',
                        Icons.gps_fixed,
                        tripService.isLiveLocationSharing ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _endRide,
                icon: const Icon(Icons.stop),
                label: const Text('End Ride'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border.all(color: Colors.blue.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : () async {
                // Check permission first
                final status = await Permission.location.status;
                if (status.isDenied || status.isPermanentlyDenied) {
                  setState(() {
                    _locationPermissionDenied = true;
                  });
                } else {
                  _startRide();
                }
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Ride'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRouteInfo() {
    if (_route == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _route!.displayName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: Colors.green),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'From: ${_route!.startLocationName}',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.location_off, size: 16, color: Colors.red),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'To: ${_route!.endLocationName}',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Distance: ${_route!.formattedDistance}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(width: 16),
              Text(
                'Est. Time: ${_route!.formattedDuration}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Check if the driver is off-route based on current location and route
  void _checkIfDriverOffRoute(LatLng currentLocation) {
    if (_routePoints.isEmpty) {
      print("Route points array is empty. Cannot check if driver is off-route.");
      return;
    }
    
    try {
      // Calculate the distance from the current location to the nearest route point
      final nearestPoint = _findNearestRoutePoint(currentLocation);
      final distanceToRoute = _calculateDistance(currentLocation, nearestPoint);
      
      if (distanceToRoute > _offRouteThresholdMeters) {
        // Driver is off-route, trigger rerouting
        if (!_isDriverOffRoute) {
          setState(() {
            _isDriverOffRoute = true;
          });
          _showSnackBar('You are off the planned route. Rerouting...');
          
          // Start rerouting process
          _generateReroute(currentLocation);
        }
      } else {
        // Driver is on-route
        if (_isDriverOffRoute) {
          setState(() {
            _isDriverOffRoute = false;
          });
          _showSnackBar('You are back on the planned route');
        }
      }
    } catch (e) {
      print('Error handling route deviation: $e');
      // Don't set driver off-route if there was an error checking
    }
  }

  /// Find the nearest route point to the given location
  LatLng _findNearestRoutePoint(LatLng location) {
    // Check if route points exist
    if (_routePoints.isEmpty) {
      // If no route points, return the current location as a fallback
      return location;
    }
    
    LatLng nearestPoint = _routePoints.first;
    double minDistance = double.infinity;
    
    for (final point in _routePoints) {
      final distance = _calculateDistance(location, point);
      if (distance < minDistance) {
        minDistance = distance;
        nearestPoint = point;
      }
    }
    
    return nearestPoint;
  }

  /// Calculate distance between two LatLng points in meters
  double _calculateDistance(LatLng p1, LatLng p2) {
    final lat1 = p1.latitude * math.pi / 180;
    final lat2 = p2.latitude * math.pi / 180;
    final deltaLat = lat2 - lat1;
    final deltaLng = (p2.longitude - p1.longitude) * math.pi / 180;
    
    final a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) * math.cos(lat2) *
        math.sin(deltaLng / 2) * math.sin(deltaLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return 6371000 * c; // Earth's radius in meters
  }

  /// Generate a new route from the current location back to the planned route
  Future<void> _generateReroute(LatLng currentLocation) async {
    // Prevent multiple reroute calculations in parallel
    if (_isGeneratingReroute) return;
    
    // Don't generate new routes too frequently
    final now = DateTime.now();
    if (_lastRerouteTime != null && 
        now.difference(_lastRerouteTime!).inSeconds < 15) {
      return;
    }
    
    setState(() {
      _isGeneratingReroute = true;
      _lastRerouteTime = now;
    });
    
    try {
      print('Starting reroute calculation from ${currentLocation.latitude},${currentLocation.longitude}');
      
      // Find the best point on the route to navigate back to
      // In a real app, you might want to use more sophisticated logic
      // to find the best waypoint on the original route
      // This implementation includes basic error handling
      
      // For this example, we'll find the nearest point on the path ahead
      // of the driver's current position (using distance along route)
      LatLng? bestRoutePoint;
      double minAdditionalDistance = double.infinity;
      
      // Find where we are along the route - approximate nearest point
      int nearestSegmentIndex = 0;
      double minDistanceToRoute = double.infinity;
      
      // First find the nearest segment of the route to the current location
      for (int i = 0; i < _routePoints.length - 1; i++) {
        final p1 = _routePoints[i];
        final p2 = _routePoints[i + 1];
        
        // Calculate distance to this segment
        final distance = _distanceToSegment(currentLocation, p1, p2);
        if (distance < minDistanceToRoute) {
          minDistanceToRoute = distance;
          nearestSegmentIndex = i;
        }
      }
      
      // Look at points ahead on the route
      // We'll look at the next N points or up to the end
      const lookAheadPoints = 10;
      final startIndex = nearestSegmentIndex + 1;
      final endIndex = math.min(startIndex + lookAheadPoints, _routePoints.length - 1);
      
      for (int i = startIndex; i <= endIndex; i++) {
        final routePoint = _routePoints[i];
        
        // Calculate total extra distance if we reroute through this point
        final directDistance = _calculateDistance(currentLocation, routePoint);
        
        if (directDistance < minAdditionalDistance) {
          minAdditionalDistance = directDistance;
          bestRoutePoint = routePoint;
        }
      }
      
      // If we couldn't find a good point ahead, just use the nearest point
      bestRoutePoint ??= _findNearestRoutePoint(currentLocation);
      
      // Generate route from current location to the best route point
      // Calculate the direct distance before making API call to avoid server limits
      final directDistanceKm = _calculateDistance(currentLocation, bestRoutePoint) / 1000;
      
      // Only use API for reasonable distances (under 5000km)
      Map<String, dynamic> rerouteResponse;
      if (directDistanceKm > 5000) {
        print('Distance too large for API call: ${directDistanceKm.toStringAsFixed(2)} km. Using direct route.');
        // Create a simple mock response
        rerouteResponse = {
          'routes': [
            {
              'overview_polyline': '',
              'legs': [
                {
                  'distance': directDistanceKm * 1000, // Convert back to meters for consistency
                  'duration': directDistanceKm * 60, // Assume 60 seconds per km as a rough estimate
                }
              ]
            }
          ]
        };
      } else {
        try {
          rerouteResponse = await _olaMapsService.getDirections(
            waypoints: [currentLocation, bestRoutePoint],
            mode: 'DRIVING',
          );
        } catch (e) {
          print('Error getting directions: $e');
          // Create a simple mock response on failure
          rerouteResponse = {
            'routes': [
              {
                'overview_polyline': '',
                'legs': [
                  {
                    'distance': directDistanceKm * 1000,
                    'duration': directDistanceKm * 60,
                  }
                ]
              }
            ]
          };
        }
      }
      
      // Extract the rerouting coordinates
      final routeData = _extractRouteDataFromResponse(rerouteResponse);
      
      if (routeData != null && (routeData['coordinates'] as List<LatLng>).isNotEmpty) {
        setState(() {
          _reroute = routeData['coordinates'] as List<LatLng>;
          
          // Update polylines - show both the original route and the reroute
          _polylines = [
            // Original route - make it gray and slightly transparent
            Polyline(
              points: _routePoints,
              color: Colors.grey.withOpacity(0.7),
              strokeWidth: 3.0,
            ),
            // Reroute - show prominently
            Polyline(
              points: _reroute,
              color: Colors.blue,
              strokeWidth: 5.0,
            ),
          ];
        });
      } else {
        // Fallback to simple straight line if API fails
        setState(() {
          // Make sure bestRoutePoint is not null
          if (bestRoutePoint != null) {
            _reroute = [currentLocation, bestRoutePoint];
            
            // Update polylines - show both the original route and the reroute
            _polylines = [
              // Original route - make it gray
              Polyline(
                points: _routePoints,
                color: Colors.grey.withOpacity(0.7),
                strokeWidth: 3.0,
              ),
              // Reroute - show prominently
              Polyline(
                points: _reroute,
                color: Colors.blue,
                strokeWidth: 5.0,
              ),
            ];
          }
        });
      }
    } catch (e) {
      debugPrint('Error generating reroute: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingReroute = false;
        });
      }
    }
  }
  
  /// Calculate the distance from a point to a line segment (p1-p2)
  double _distanceToSegment(LatLng point, LatLng p1, LatLng p2) {
    // Convert to x,y coordinates for simplicity
    // This is an approximation that works for small distances
    const double earthRadius = 6371000; // Earth radius in meters
    
    // Convert lat/lng to radians
    final lat = point.latitude * math.pi / 180;
    final lat1 = p1.latitude * math.pi / 180;
    final lat2 = p2.latitude * math.pi / 180;
    
    // Approximate conversion to cartesian coordinates
    // This works reasonably well for small distances
    final x = earthRadius * math.cos(lat) * math.cos(point.longitude * math.pi / 180);
    final y = earthRadius * math.cos(lat) * math.sin(point.longitude * math.pi / 180);
    final z = earthRadius * math.sin(lat);
    
    final x1 = earthRadius * math.cos(lat1) * math.cos(p1.longitude * math.pi / 180);
    final y1 = earthRadius * math.cos(lat1) * math.sin(p1.longitude * math.pi / 180);
    final z1 = earthRadius * math.sin(lat1);
    
    final x2 = earthRadius * math.cos(lat2) * math.cos(p2.longitude * math.pi / 180);
    final y2 = earthRadius * math.cos(lat2) * math.sin(p2.longitude * math.pi / 180);
    final z2 = earthRadius * math.sin(lat2);
    
    // Calculate distance to line segment
    final A = x - x1;
    final B = y - y1;
    final C = z - z1;
    final D = x2 - x1;
    final E = y2 - y1;
    final F = z2 - z1;
    
    final dot = A * D + B * E + C * F;
    final len_sq = D * D + E * E + F * F;
    
    var param = -1.0;
    if (len_sq != 0) {
      param = dot / len_sq;
    }
    
    double xx, yy, zz;
    
    if (param < 0) {
      xx = x1;
      yy = y1;
      zz = z1;
    } else if (param > 1) {
      xx = x2;
      yy = y2;
      zz = z2;
    } else {
      xx = x1 + param * D;
      yy = y1 + param * E;
      zz = z1 + param * F;
    }
    
    final dx = x - xx;
    final dy = y - yy;
    final dz = z - zz;
    
    // Return distance
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }

  /// Calculate heading in degrees (0-360) from one point to another
  double _calculateHeading(LatLng from, LatLng to) {
    // Convert from degrees to radians
    final startLat = from.latitude * math.pi / 180;
    final startLng = from.longitude * math.pi / 180;
    final destLat = to.latitude * math.pi / 180;
    final destLng = to.longitude * math.pi / 180;

    // Calculate heading
    final y = math.sin(destLng - startLng) * math.cos(destLat);
    final x = math.cos(startLat) * math.sin(destLat) -
              math.sin(startLat) * math.cos(destLat) * math.cos(destLng - startLng);
    
    var heading = math.atan2(y, x) * 180 / math.pi;
    
    // Normalize to 0-360
    heading = (heading + 360) % 360;
    return heading;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoading ? 'Loading...' : _route?.name ?? 'Route Details'),
        actions: [
          // Toggle auto-follow mode
          if (_isRideActive)
            IconButton(
              icon: Icon(_followDriver ? Icons.navigation : Icons.location_searching),
              tooltip: _followDriver ? 'Free map movement' : 'Follow vehicle',
              onPressed: _toggleFollowDriver,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : Column(
                  children: [
                    Expanded(child: _buildMap()),
                    if (_route != null) _buildRouteInfo(),
                    _buildRideControls(),
                  ],
                ),
    );
  }
} // End of _DriverRouteScreenState class

/// Custom painter for direction arrow overlay
class DirectionArrowPainter extends CustomPainter {
  final Offset center;
  final double heading;
  final bool offRoute;
  
  DirectionArrowPainter({
    required this.center, 
    required this.heading,
    this.offRoute = false,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    try {
      // Draw direction arrow
      final paint = Paint()
        ..color = offRoute ? Colors.red : Colors.blue
        ..strokeWidth = 3
        ..style = PaintingStyle.fill;
        
      // Arrow size
      final arrowSize = 40.0;
      
      // Create a path for the arrow
      final path = ui.Path();
      
      // Translate and rotate to center with heading
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate((heading - 90) * math.pi / 180); // -90 to point upward
      
      // Draw arrow shape
      path.moveTo(0, -arrowSize / 2);
      path.lineTo(arrowSize / 3, arrowSize / 2);
      path.lineTo(0, arrowSize / 4);
      path.lineTo(-arrowSize / 3, arrowSize / 2);
      path.close();
      
      canvas.drawPath(path, paint);
      
      // If off-route, add a warning circle
      if (offRoute) {
        final warningPaint = Paint()
          ..color = Colors.red.withOpacity(0.3)
          ..style = PaintingStyle.fill;
        
        canvas.drawCircle(Offset.zero, arrowSize, warningPaint);
        
        // Add a pulsing effect
        final now = DateTime.now();
        final pulseOpacity = 0.6 + 0.4 * math.sin(now.millisecondsSinceEpoch / 300);
        
        final pulsePaint = Paint()
          ..color = Colors.red.withOpacity(pulseOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        
        canvas.drawCircle(Offset.zero, arrowSize, pulsePaint);
      }
      
      canvas.restore();
    } catch (e) {
      debugPrint('Error painting direction arrow: $e');
    }
  }
  
  @override
  bool shouldRepaint(DirectionArrowPainter oldDelegate) {
    return oldDelegate.heading != heading || 
           oldDelegate.center != center ||
           oldDelegate.offRoute != offRoute;
  }
}