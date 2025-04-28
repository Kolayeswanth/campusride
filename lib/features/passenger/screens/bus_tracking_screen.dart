import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';
import 'package:campusride/core/services/map_service.dart';
import 'package:campusride/core/services/trip_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../models/bus_location.dart';
import '../models/stop.dart';

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
  MaplibreMapController? _mapController;
  late MapService _mapService;
  late TripService _tripService;
  bool _isLoading = false;
  bool _isTripActive = false;
  bool _isLiveTracking = false;
  bool _isSearching = false;
  
  bool _hasShownLocationMessage = false;
  latlong2.LatLng? _selectedDestination;
  Timer? _animationTimer;
  double _pulseAnimation = 0.0;
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

  @override
  void initState() {
    super.initState();
    _mapService = Provider.of<MapService>(context, listen: false);
    _tripService = Provider.of<TripService>(context, listen: false);
    _initializeLocation();
    _driverIdController.text = widget.busId;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationTimer?.cancel();
    _startPointController.dispose();
    _destinationController.dispose();
    _driverIdController.dispose();
    _etaUpdateTimer?.cancel();
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
      print('Error initializing location: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _initializeMap(MaplibreMapController controller) {
    _mapController = controller;
    _getCurrentLocation();
  }

  /// Update driver marker with smooth animation
  Future<void> _updateDriverMarker() async {
    if (_currentPosition == null) return;

    final currentPoint = latlong2.LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    
    // Update marker position
    await _mapService.updateMarker(
      'driver',
      currentPoint,
      data: {
        'id': 'driver',
        'type': 'bus',
        'heading': _currentPosition!.heading,
      },
    );
    
    // If live tracking is active, update the route
    if (_isLiveTracking && _selectedDestination != null) {
      await _updateRouteToPoint(LatLng(_selectedDestination!.latitude, _selectedDestination!.longitude));
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
                          CameraUpdate.newLatLngZoom(
                            LatLng(position.latitude, position.longitude),
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
            content: Text('Could not get your location. Please check your location permissions.'),
                          ),
                        );
                      }
                    } catch (e) {
                      print('Error getting location: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
                      );
                    } finally {
                      setState(() {
                        _isLoading = false;
                      });
                    }
  }

  Future<void> _selectDestination(LatLng destination) async {
    try {
      // Remove any existing destination marker and routes
      await _mapService.removeMarkerById('destination');
      await _mapService.clearRoutes();
      
      // Add a new marker at the selected location
      await _mapService.addMarker(
        position: latlong2.LatLng(destination.latitude, destination.longitude),
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
          points: routePoints,
            data: {'id': 'route_to_destination'},
            width: 6.0,
          color: Colors.blue,
        );
        
          // Only fit bounds if this is the initial route calculation
          if (!_isTripActive) {
            await _mapService.fitBounds(
              [
                latlong2.LatLng(currentPosition.latitude, currentPosition.longitude),
                latlong2.LatLng(destination.latitude, destination.longitude)
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
      print('Error selecting destination: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not calculate route: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Update route to a specific point using road-based routing
  Future<void> _updateRouteToPoint(LatLng point) async {
    if (_currentPosition == null) return;

    try {
      setState(() {
        _isLoading = true;
      });

      // Calculate route using road-based routing
      final routePoints = await _tripService.calculateRoute(
        latlong2.LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        latlong2.LatLng(point.latitude, point.longitude),
        );
        
        if (routePoints.isNotEmpty) {
        // Clear existing route
          await _mapService.clearRoutes();
          
        // Draw the new route with road-based path
          await _mapService.addRoute(
            points: routePoints,
            data: {'id': 'route_to_destination'},
          width: 6.0,
            color: Colors.blue,
          );
          
        // Update distance and ETA with road-based distance
        _updateDistanceAndETA();
        
        // Start ETA updates
        _etaUpdateTimer?.cancel();
        _etaUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
          _updateDistanceAndETA();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not find a valid road route to the destination.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error updating route: $e');
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
  Future<void> _handleMapClick(LatLng point) async {
    if (_isTripActive) return; // Don't allow changing destination during active trip
    
    // Check if click is near the selected destination
    if (_selectedDestination != null) {
      final distance = const latlong2.Distance().distance(
        latlong2.LatLng(_selectedDestination!.latitude, _selectedDestination!.longitude),
        latlong2.LatLng(point.latitude, point.longitude),
      );
      
      if (distance < 100) { // Within 100 meters
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
        content: Text('Trip to ${_destinationController.text} started. Following road navigation.'),
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
        content: const Text('You have successfully reached your destination. We hope you had a pleasant journey!'),
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

    final distance = latlong2.Distance().as(
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
          MaplibreMap(
            styleString: 'https://api.maptiler.com/maps/streets/style.json?key=${dotenv.env['MAPTILER_API_KEY']}',
            initialCameraPosition: CameraPosition(
              target: LatLng(33.7756, -84.3963),
              zoom: 15.0,
            ),
            myLocationEnabled: true,
            myLocationTrackingMode: MyLocationTrackingMode.tracking,
            onMapCreated: _initializeMap,
            onStyleLoadedCallback: () {
              if (_currentPosition != null) {
                _updateDriverMarker();
              }
            },
            onMapClick: (point, coordinates) {
              _handleMapClick(LatLng(coordinates.latitude, coordinates.longitude));
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
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
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
                                  final position = await geo.Geolocator.getCurrentPosition(
                                    desiredAccuracy: geo.LocationAccuracy.high,
                                  );
                                  _startPointController.text = 'Current Location';
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
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
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
                            onTap: () => _selectDestination(
                              LatLng(result['latitude'], result['longitude'])),
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
                          const Text('Distance', style: TextStyle(fontSize: 12)),
                          Text(_estimatedDistance, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('ETA', style: TextStyle(fontSize: 12)),
                          Text(_estimatedTime, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
        'library': latlong2.LatLng(33.7756, -84.3963),
        'student center': latlong2.LatLng(33.7756, -84.3963),
        'tech square': latlong2.LatLng(33.7756, -84.3963),
        'crc': latlong2.LatLng(33.7756, -84.3963),
      };
      
      latlong2.LatLng? destinationLatLng;
      String? matchedLocation;
      
      for (final entry in predefinedLocations.entries) {
        if (entry.key.contains(normalizedQuery) || normalizedQuery.contains(entry.key)) {
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
        final mapLibreLatLng = LatLng(destinationLatLng.latitude, destinationLatLng.longitude);
        
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
            content: Text('Could not find "$query". Try a different search term.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error searching location: $e');
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