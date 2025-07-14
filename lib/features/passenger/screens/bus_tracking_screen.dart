import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;
import 'package:provider/provider.dart';
import 'package:campusride/core/services/map_service.dart';
import 'package:campusride/core/services/trip_service.dart';
import 'dart:async';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:supabase_flutter/supabase_flutter.dart';

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
  maplibre.MapLibreMapController? _mapController;
  late MapService _mapService;
  late TripService _tripService;
  bool _isLoading = false;
  bool _isTripActive = false;
  bool _isLiveTracking = false;
  bool _isSearching = false;

  bool _hasShownLocationMessage = false;
  latlong2.LatLng? _selectedDestination;
  Timer? _animationTimer;
  List<Map<String, dynamic>> _searchResults = [];
  final TextEditingController _searchController = TextEditingController();
  geo.Position? _currentPosition;
  final TextEditingController _startPointController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  bool _isEditingDriverId = false;
  final TextEditingController _driverIdController = TextEditingController();
  String _estimatedDistance = '';
  String _estimatedTime = '';
  Timer? _etaUpdateTimer;

  // Driver location tracking
  StreamSubscription? _driverLocationSubscription;
  geo.Position? _driverPosition;

  @override
  void initState() {
    super.initState();
    _mapService = Provider.of<MapService>(context, listen: false);
    _tripService = Provider.of<TripService>(context, listen: false);
    _initializeLocation();
    _driverIdController.text = widget.busId;
    _startDriverLocationTracking(); // Start tracking driver location
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationTimer?.cancel();
    _startPointController.dispose();
    _destinationController.dispose();
    _driverIdController.dispose();
    _etaUpdateTimer?.cancel();
    _driverLocationSubscription?.cancel(); // Clean up driver location subscription
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );

      if (position.latitude != 0 && position.longitude != 0) {
        setState(() {
          _currentPosition = position;
        });
      }
    } catch (e) {
      
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _initializeMap(maplibre.MapLibreMapController controller) {
    _mapController = controller;
    _getCurrentLocation();
  }

  // Helper functions to convert between LatLng types
  maplibre.LatLng _toMapLibreLatLng(latlong2.LatLng point) {
    return maplibre.LatLng(point.latitude, point.longitude);
  }

  latlong2.LatLng _toLatLong2(maplibre.LatLng point) {
    return latlong2.LatLng(point.latitude, point.longitude);
  }

  List<maplibre.LatLng> _convertRoutePoints(List<latlong2.LatLng> points) {
    return points.map((point) => _toMapLibreLatLng(point)).toList();
  }

  /// Update driver marker with smooth animation
  Future<void> _updateDriverMarker() async {
    if (_currentPosition == null) return;

    final currentPoint = latlong2.LatLng(
        _currentPosition!.latitude, _currentPosition!.longitude);

    // Update marker position
    await _mapService.updateMarker(
      'driver',
      _toMapLibreLatLng(currentPoint),
      data: {
        'id': 'driver',
        'type': 'bus',
        'heading': _currentPosition!.heading,
      },
    );

    // If live tracking is active, update the route
    if (_isLiveTracking && _selectedDestination != null) {
      await _updateRouteToPoint(maplibre.LatLng(
          _selectedDestination!.latitude, _selectedDestination!.longitude));
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );

      if (position.latitude != 0 && position.longitude != 0) {
        setState(() {
          _currentPosition = position;
        });

        // Animate to current location with higher zoom
        await _mapController?.animateCamera(
          maplibre.CameraUpdate.newLatLngZoom(
            maplibre.LatLng(position.latitude, position.longitude),
            17.0, // Higher zoom for better visibility
          ),
        );

        // Update driver marker
        _updateDriverMarker();

        // Clear any existing routes when focusing on current location
        if (!_isTripActive) {
          await _mapService.clearRoutes();
          await _mapService.removeMarkerById('destination');
        }

        // Show location acquired message only once
        if (!_hasShownLocationMessage) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You are at your current location'),
              duration: Duration(seconds: 2),
            ),
          );
          _hasShownLocationMessage = true;
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not get your location. Please check your location permissions.'),
          ),
        );
      }
    } catch (e) {
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDestination(maplibre.LatLng destination) async {
    try {
      // Remove any existing destination marker and routes
      await _mapService.removeMarkerById('destination');
      await _mapService.clearRoutes();

      // Add a new marker at the selected location
      await _mapService.addMarker(
        position: _toMapLibreLatLng(latlong2.LatLng(destination.latitude, destination.longitude)),
        data: {'id': 'destination'},
        title: 'Destination',
        iconColor: Colors.red,
      );

      // Get the current location
      final currentPosition = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );

      if (currentPosition.latitude != 0 && currentPosition.longitude != 0) {
        // Calculate and draw route from current location to destination
        final routePoints = await _tripService.calculateRoute(
          latlong2.LatLng(currentPosition.latitude, currentPosition.longitude),
          latlong2.LatLng(destination.latitude, destination.longitude),
        );

        if (routePoints.isNotEmpty) {
          // Draw the new route with a more visible style
          await _mapService.addRoute(
            points: _convertRoutePoints(routePoints),
            data: {'id': 'route_to_destination'},
            width: 6.0,
            color: Colors.blue,
          );

          // Only fit bounds if this is the initial route calculation
          if (!_isTripActive) {          await _mapService.fitBounds(
            [
              _toMapLibreLatLng(latlong2.LatLng(
                  currentPosition.latitude, currentPosition.longitude)),
              _toMapLibreLatLng(latlong2.LatLng(destination.latitude, destination.longitude))
            ],
            padding: 100.0,
          );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not find a valid route to the destination.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not get your current location.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not calculate route: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Update route to a specific point using road-based routing
  Future<void> _updateRouteToPoint(maplibre.LatLng point) async {
    if (_currentPosition == null) return;

    try {
      setState(() {
        _isLoading = true;
      });

      // Calculate route using road-based routing
      final routePoints = await _tripService.calculateRoute(
        latlong2.LatLng(
            _currentPosition!.latitude, _currentPosition!.longitude),
        latlong2.LatLng(point.latitude, point.longitude),
      );

      if (routePoints.isNotEmpty) {
        // Clear existing route
        await _mapService.clearRoutes();

        // Draw the new route with road-based path
        await _mapService.addRoute(
          points: _convertRoutePoints(routePoints),
          data: {'id': 'route_to_destination'},
          width: 6.0,
          color: Colors.blue,
        );

        // Update distance and ETA with road-based distance
        _updateDistanceAndETA();

        // Start ETA updates
        _etaUpdateTimer?.cancel();
        // Use real-time subscriptions instead of frequent polling
        // Reduced timer frequency from 30 seconds to 2 minutes for fallback only
        _etaUpdateTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
          _updateDistanceAndETA();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Could not find a valid road route to the destination.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update route: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Handle map click to set destination
  Future<void> _handleMapClick(maplibre.LatLng point) async {
    if (_isTripActive)
      return; // Don't allow changing destination during active trip

    // Check if click is near the selected destination
    if (_selectedDestination != null) {
      final distance = const latlong2.Distance().distance(
        latlong2.LatLng(
            _selectedDestination!.latitude, _selectedDestination!.longitude),
        latlong2.LatLng(point.latitude, point.longitude),
      );

      if (distance < 100) {
        // Within 100 meters
        await _updateRouteToPoint(point);
        return;
      }
    }

    // Set new destination
    setState(() {
      _selectedDestination = latlong2.LatLng(point.latitude, point.longitude);
      _destinationController.text = 'Selected Location';
    });

    // Calculate route to new destination
    await _updateRouteToPoint(point);
  }

  /// Start the trip with live tracking
  void _startTrip() {
    if (_selectedDestination == null) return;

    setState(() {
      _isTripActive = true;
      _isLiveTracking = true;
    });

    // Start location updates
    _startLocationUpdates();

    // Show a message to the user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Trip to ${_destinationController.text} started. Following road navigation.'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// End the trip and clean up
  void _endTrip() {
    setState(() {
      _isTripActive = false;
      _isLiveTracking = false;
      _animationTimer?.cancel();
    });

    // Clean up map
    _mapService.removeMarkerById('destination');
    _mapService.clearRoutes();

    // Reset destination
    setState(() {
      _selectedDestination = null;
    });

    // Show a message to the user
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You have reached your destination. Trip ended.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );

    // Show a dialog with trip summary
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Destination Reached'),
        content: const Text(
            'You have successfully reached your destination. We hope you had a pleasant journey!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Update distance and ETA information
  void _updateDistanceAndETA() {
    if (_currentPosition == null || _selectedDestination == null) return;

    final distance = const latlong2.Distance().as(
      latlong2.LengthUnit.Kilometer,
      latlong2.LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      _selectedDestination!,
    );

    // Calculate ETA based on current speed and distance
    final speed = _currentPosition!.speed; // in m/s
    final etaMinutes = speed > 0
        ? (distance / (speed * 3.6)).round() // Convert m/s to km/h
        : (distance / 30 * 60).round(); // Fallback to 30 km/h if speed is 0

    setState(() {
      _estimatedDistance = '${distance.toStringAsFixed(1)} km';
      _estimatedTime = '$etaMinutes min';
    });
  }

  /// Start receiving location updates
  void _startLocationUpdates() {
    // Cancel any existing timer
    _animationTimer?.cancel();

    // Start location updates
    geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((geo.Position position) {
      if (_isLiveTracking && mounted) {
        setState(() {
          _currentPosition = position;
        });
        _updateDriverMarker();
        _updateDistanceAndETA();
      }
    });
  }

  /// Cancel destination and reset map
  Future<void> _cancelDestination() async {
    setState(() {
      _selectedDestination = null;
      _isTripActive = false;
      _isLiveTracking = false;
      _destinationController.clear();
      _estimatedDistance = '0.0 km';
      _estimatedTime = '0 min';
    });

    // Clear route and reset map
    await _mapService.clearRoutes();
    await _mapService.clearMarkers();
    await _updateDriverMarker();
  }

  /// Start tracking driver's live location from database
  void _startDriverLocationTracking() {
    print('🚌 Starting driver location tracking for trip: ${widget.busId}');

    _driverLocationSubscription = Supabase.instance.client
        .from('driver_trip_locations')
        .stream(primaryKey: ['id'])
        .eq('trip_id', widget.busId)
        .order('timestamp', ascending: false)
        .limit(1)
        .listen(
          (List<Map<String, dynamic>> data) {
            if (data.isNotEmpty && mounted) {
              _updateDriverLocationFromDatabase(data.first);
            }
          },
          onError: (error) {
            print('❌ Driver location subscription error: $error');
          },
        );

    // Also get initial driver location
    _getInitialDriverLocation();
  }

  /// Get initial driver location from database
  Future<void> _getInitialDriverLocation() async {
    try {
      final response = await Supabase.instance.client
          .from('driver_trip_locations')
          .select('*')
          .eq('trip_id', widget.busId)
          .order('timestamp', ascending: false)
          .limit(1);

      if (response.isNotEmpty) {
        _updateDriverLocationFromDatabase(response.first);
      }
    } catch (e) {
      
    }
  }

  /// Update driver location from database data
  void _updateDriverLocationFromDatabase(Map<String, dynamic> locationData) {
    try {
      final latitude = locationData['latitude'] as double;
      final longitude = locationData['longitude'] as double;
      final heading = locationData['heading'] as double? ?? 0.0;
      final speed = locationData['speed'] as double? ?? 0.0;
      final timestamp = DateTime.parse(locationData['timestamp'] as String);

      // Check if this is a recent location (within last 5 minutes)
      final age = DateTime.now().difference(timestamp);
      if (age.inMinutes < 5) {
        setState(() {
          _driverPosition = geo.Position(
            latitude: latitude,
            longitude: longitude,
            timestamp: timestamp,
            accuracy: locationData['accuracy'] as double? ?? 10.0,
            altitude: 0.0,
            heading: heading,
            speed: speed / 3.6, // Convert km/h back to m/s
            speedAccuracy: 0.0,
            altitudeAccuracy: 0.0,
            headingAccuracy: 0.0,
          );
        });

        _updateDriverMarkerFromDatabase();
        print('🚌 Updated driver location: $latitude, $longitude (${age.inSeconds}s ago)');
      } else {
        print('⚠️ Driver location is too old: ${age.inMinutes} minutes ago');
      }
    } catch (e) {
      
    }
  }

  /// Update driver marker on map from database location
  Future<void> _updateDriverMarkerFromDatabase() async {
    if (_driverPosition == null) return;

    final driverPoint = latlong2.LatLng(_driverPosition!.latitude, _driverPosition!.longitude);

    // Update marker position
    await _mapService.updateMarker(
      'driver',
      _toMapLibreLatLng(driverPoint),
      data: {
        'id': 'driver',
        'type': 'bus',
        'heading': _driverPosition!.heading,
      },
    );

    // If live tracking is active, update the route to driver's location
    if (_isLiveTracking && _selectedDestination != null) {
      await _updateRouteToDriverLocation();
    }
  }

  /// Update route to driver's current location
  Future<void> _updateRouteToDriverLocation() async {
    if (_driverPosition == null || _currentPosition == null) return;

    try {
      // Calculate route from passenger's location to driver's location
      final routePoints = await _tripService.calculateRoute(
        latlong2.LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        latlong2.LatLng(_driverPosition!.latitude, _driverPosition!.longitude),
      );

      if (routePoints.isNotEmpty) {
        // Clear existing route
        await _mapService.clearRoutes();

        // Draw route to driver
        await _mapService.addRoute(
          points: _convertRoutePoints(routePoints),
          data: {'id': 'route_to_driver'},
          width: 6.0,
          color: Colors.orange, // Orange route to indicate tracking driver
        );

        // Update distance and ETA to driver
        _updateDistanceAndETAToDriver();
      }
    } catch (e) {
      
    }
  }

  /// Update distance and ETA to driver's location
  void _updateDistanceAndETAToDriver() {
    if (_driverPosition == null || _currentPosition == null) return;

    // Calculate distance to driver
    final distance = geo.Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _driverPosition!.latitude,
      _driverPosition!.longitude,
    ) / 1000; // Convert to km

    // Estimate ETA (assuming average travel speed)
    final etaMinutes = (distance / 30 * 60).round(); // Assuming 30 km/h average speed

    setState(() {
      _estimatedDistance = 'To Driver: ${distance.toStringAsFixed(1)} km';
      _estimatedTime = 'ETA: $etaMinutes min';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (_isEditingDriverId)
              Expanded(
                child: TextField(
                  controller: _driverIdController,
                  decoration: const InputDecoration(
                    hintText: 'Enter Driver ID',
                    border: InputBorder.none,
                  ),
                  onSubmitted: (value) {
                    setState(() {
                      _isEditingDriverId = false;
                    });
                  },
                ),
              )
            else
              Text('Bus ${widget.busId}'),
            IconButton(
              icon: Icon(_isEditingDriverId ? Icons.check : Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditingDriverId = !_isEditingDriverId;
                });
              },
            ),
          ],
        ),
        actions: [
          if (_selectedDestination != null)
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
      ),
      body: Stack(
        children: [
          maplibre.MapLibreMap(
            styleString:
                'https://api.maptiler.com/maps/streets/style.json?key=${dotenv.env['MAPTILER_API_KEY']}',
            initialCameraPosition: const maplibre.CameraPosition(
              target: maplibre.LatLng(33.7756, -84.3963),
              zoom: 15.0,
            ),
            myLocationEnabled: true,
            myLocationTrackingMode: maplibre.MyLocationTrackingMode.tracking,
            onMapCreated: _initializeMap,
            onStyleLoadedCallback: () {
              if (_currentPosition != null) {
                _updateDriverMarker();
              }
            },
            onMapClick: (point, coordinates) {
              _handleMapClick(
                  maplibre.LatLng(coordinates.latitude, coordinates.longitude));
            },
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
          ),

          // Search bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Start Point Field
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _startPointController,
                            decoration: InputDecoration(
                              hintText: 'Starting point',
                              border: InputBorder.none,
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.my_location),
                                onPressed: () async {
                                  final position =
                                      await geo.Geolocator.getCurrentPosition(
                                    desiredAccuracy: geo.LocationAccuracy.high,
                                  );
                                  _startPointController.text =
                                      'Current Location';
                                  setState(() {
                                    _currentPosition = position;
                                  });
                                  _updateDriverMarker();
                                },
                              ),
                            ),
                            onChanged: (value) {
                              if (value.length > 2) {
                                _searchLocation(value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Destination Field
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.flag, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _destinationController,
                            decoration: const InputDecoration(
                              hintText: 'Destination',
                              border: InputBorder.none,
                            ),
                            onChanged: (value) {
                              if (value.length > 2) {
                                _searchLocation(value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

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
                            subtitle: Text(result['address'] ?? ''),
                            onTap: () => _selectDestination(maplibre.LatLng(
                                result['latitude'], result['longitude'])),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Distance and ETA Display
          if (_selectedDestination != null)
            Positioned(
              bottom: 80,
              left: 16,
              right: 16,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          const Text('Distance',
                              style: TextStyle(fontSize: 12)),
                          Text(_estimatedDistance,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('ETA', style: TextStyle(fontSize: 12)),
                          Text(_estimatedTime,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      if (!_isTripActive)
                        ElevatedButton(
                          onPressed: _startTrip,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Start Trip'),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          // Location button
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: _getCurrentLocation,
              child: const Icon(Icons.my_location),
            ),
          ),

          // Loading indicator
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
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

    setState(() {
      _isSearching = true;
    });

    try {
      // Normalize the query for comparison
      final normalizedQuery = query.toLowerCase().trim();

      // Search in predefined locations
      final Map<String, latlong2.LatLng> predefinedLocations = {
        'library': const latlong2.LatLng(33.7756, -84.3963),
        'student center': const latlong2.LatLng(33.7756, -84.3963),
        'tech square': const latlong2.LatLng(33.7756, -84.3963),
        'crc': const latlong2.LatLng(33.7756, -84.3963),
      };

      latlong2.LatLng? destinationLatLng;
      String? matchedLocation;

      for (final entry in predefinedLocations.entries) {
        if (entry.key.contains(normalizedQuery) ||
            normalizedQuery.contains(entry.key)) {
          destinationLatLng = entry.value;
          matchedLocation = entry.key;
          break;
        }
      }

      if (destinationLatLng != null && matchedLocation != null) {
        // Store the destination name
        setState(() {
          _selectedDestination = destinationLatLng;
          _isTripActive = false;
          _isLiveTracking = false;
          _animationTimer?.cancel();
        });

        // Convert to MapLibre LatLng
        final mapLibreLatLng =
            maplibre.LatLng(destinationLatLng.latitude, destinationLatLng.longitude);

        // Calculate route to the found location without moving the map
        await _handleMapClick(mapLibreLatLng);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found "$matchedLocation" and calculated route'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        // Location not found
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Could not find "$query". Try a different search term.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching for location: $e')),
      );
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }
}
