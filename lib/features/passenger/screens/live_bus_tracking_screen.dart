import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import '../../../core/services/realtime_service.dart';
import '../../../core/services/ola_location_service.dart';
import '../../../core/services/ola_maps_service.dart';
import '../../../core/services/trip_service.dart';
import '../../../core/theme/app_colors.dart';
import '../models/bus_info.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class LiveBusTrackingScreen extends StatefulWidget {
  final BusInfo busInfo;

  const LiveBusTrackingScreen({
    Key? key,
    required this.busInfo,
  }) : super(key: key);

  @override
  State<LiveBusTrackingScreen> createState() => _LiveBusTrackingScreenState();
}

class _LiveBusTrackingScreenState extends State<LiveBusTrackingScreen> with TickerProviderStateMixin {
  MaplibreMapController? _mapController;
  StreamSubscription? _locationSubscription;
  Timer? _updateTimer;
  final OlaMapsService _olaMapsService = OlaMapsService();
  
  latlong2.LatLng? _currentUserLocation;
  latlong2.LatLng? _currentBusLocation;
  bool _isLoadingLocation = true;
  bool _isFollowingBus = true;
  String? _estimatedArrival;
  double? _distanceToUser;
  
  // Route information
  BusRoute? _routeInfo;
  bool _isLoadingRoute = true;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    
    // Initialize bus location from widget
    if (widget.busInfo.lastLocation != null) {
      _currentBusLocation = widget.busInfo.lastLocation;
    } else if (widget.busInfo.currentLocation.latitude != 0) {
      _currentBusLocation = latlong2.LatLng(
        widget.busInfo.currentLocation.latitude,
        widget.busInfo.currentLocation.longitude,
      );
    }
    
    _loadRouteInformation();
    _initializeTracking();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _pulseController.repeat(reverse: true);
  }

  Future<void> _loadRouteInformation() async {
    try {
      if (widget.busInfo.routeId != null) {
        final response = await Supabase.instance.client
            .from('routes')
            .select()
            .eq('id', widget.busInfo.routeId!)
            .single();
        
        setState(() {
          _routeInfo = BusRoute.fromJson(response);
          _isLoadingRoute = false;
        });
        
        print('Route loaded: ${_routeInfo?.name} from ${_routeInfo?.startLocationName} to ${_routeInfo?.endLocationName}');
      } else {
        setState(() {
          _isLoadingRoute = false;
        });
        print('No route ID available for this bus');
      }
    } catch (e) {
      print('Error loading route information: $e');
      setState(() {
        _isLoadingRoute = false;
      });
    }
  }

  Future<void> _initializeTracking() async {
    await _getCurrentLocation();
    _startListeningToBusUpdates();
    _startPeriodicUpdates();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final location = await OlaLocationService.getCurrentLocation();
      
      if (location != null) {
        setState(() {
          _currentUserLocation = location;
          _isLoadingLocation = false;
        });

        // Start listening to location changes using Ola Maps enhanced tracking
        _locationSubscription = OlaLocationService.getLocationStream().listen((location) {
          setState(() {
            _currentUserLocation = location;
          });
          _updateDistanceAndETA();
        });
      }
    } catch (e) {
      
      setState(() => _isLoadingLocation = false);
    }
  }

  void _startListeningToBusUpdates() {
    final realtimeService = Provider.of<RealtimeService>(context, listen: false);
    
    // Ensure driver locations subscription is active
    realtimeService.subscribeToDriverLocations();
    
    // Add listener for location updates
    realtimeService.addListener(_onBusLocationUpdate);
    
    
  }

  void _onBusLocationUpdate() {
    final realtimeService = Provider.of<RealtimeService>(context, listen: false);
    
    final tripId = widget.busInfo.tripId ?? widget.busInfo.busId;
    
    
    if (tripId.isNotEmpty) {
      final location = realtimeService.driverLocations[tripId];
      
      
      if (location != null) {
        
        final newLocation = latlong2.LatLng(
          (location['latitude'] as num).toDouble(),
          (location['longitude'] as num).toDouble(),
        );
        
        setState(() {
          _currentBusLocation = newLocation;
        });
        
        _updateBusLocationOnMap(newLocation);
        _updateDistanceAndETA();
        
        if (_isFollowingBus) {
          _centerMapOnBus();
        }
      } else {
        
      }
    } else {
      
    }
  }

  void _startPeriodicUpdates() {
    _updateTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      _updateDistanceAndETA();
    });
  }

  void _updateBusLocationOnMap(latlong2.LatLng location) async {
    if (_mapController != null) {
      
      // Update the bus location and refresh markers
      setState(() {
        _currentBusLocation = location;
      });
      // Re-setup markers to reflect new bus location
      await _setupMapMarkers();
    }
  }

  void _updateDistanceAndETA() async {
    if (_currentUserLocation != null && _currentBusLocation != null) {
      final distance = latlong2.Distance().as(
        latlong2.LengthUnit.Meter,
        _currentUserLocation!,
        _currentBusLocation!,
      );
      
      // Use Ola Maps for enhanced ETA calculation with traffic data
      final eta = await OlaLocationService.calculateETAWithTraffic(
        origin: _currentUserLocation!,
        destination: _currentBusLocation!,
      );
      
      setState(() {
        _distanceToUser = distance;
        _estimatedArrival = eta;
      });
    }
  }

  void _centerMapOnBus() {
    if (_mapController != null && _currentBusLocation != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentBusLocation!.latitude, _currentBusLocation!.longitude),
          16.0,
        ),
      );
    }
  }

  void _centerMapOnUser() {
    if (_mapController != null && _currentUserLocation != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentUserLocation!.latitude, _currentUserLocation!.longitude),
          16.0,
        ),
      );
    }
  }

  void _showBothLocations() {
    if (_mapController != null && 
        _currentUserLocation != null && 
        _currentBusLocation != null) {
      
      final userLat = _currentUserLocation!.latitude;
      final userLng = _currentUserLocation!.longitude;
      final busLat = _currentBusLocation!.latitude;
      final busLng = _currentBusLocation!.longitude;
      
      final bounds = LatLngBounds(
        southwest: LatLng(
          userLat < busLat ? userLat : busLat,
          userLng < busLng ? userLng : busLng,
        ),
        northeast: LatLng(
          userLat > busLat ? userLat : busLat,
          userLng > busLng ? userLng : busLng,
        ),
      );
      
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          bounds,
          top: 100,
          left: 100,
          bottom: 100,
          right: 100,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bus ${widget.busInfo.busNumber ?? widget.busInfo.routeNumber}'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _showBothLocations,
            icon: Icon(Icons.center_focus_strong),
            tooltip: 'Show both locations',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          _buildMap(),
          
          // Bus Info Card
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: _buildBusInfoCard(),
          ),
          
          // Control Buttons
          Positioned(
            bottom: 100,
            right: 16,
            child: _buildControlButtons(),
          ),
          
          // Bottom Info Panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomInfoPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    if (_isLoadingLocation || _isLoadingRoute) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(_isLoadingLocation 
              ? 'Getting your location...' 
              : 'Loading route information...'),
          ],
        ),
      );
    }

    return MaplibreMap(
      styleString: '''
      {
        "version": 8,
        "sources": {
          "maplibre": {
            "type": "raster",
            "tiles": [
              "https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=m37d3xPYmQx85rLtCyoW"
            ],
            "tileSize": 256,
            "attribution": "© MapTiler © OpenStreetMap contributors"
          }
        },
        "layers": [
          {
            "id": "maplibre-layer",
            "type": "raster",
            "source": "maplibre"
          }
        ]
      }
      ''',
      onMapCreated: (controller) {
        _mapController = controller;
        _setupMapMarkers();
        _drawRoute();
      },
      onStyleLoadedCallback: _onStyleLoaded,
      initialCameraPosition: CameraPosition(
        target: _currentUserLocation != null
          ? LatLng(_currentUserLocation!.latitude, _currentUserLocation!.longitude)
          : LatLng(12.9716, 77.5946), // Default to Bangalore
        zoom: 14.0,
      ),
      trackCameraPosition: true,
    );
  }

  void _onStyleLoaded() {
    _setupMapMarkers();
    _drawRoute();
  }

  Future<void> _drawRoute() async {
    if (_mapController == null || !mounted || _routeInfo == null) return;
    
    // Get route start and end points from routeInfo
    final startLocation = _routeInfo!.startLocation;
    final endLocation = _routeInfo!.endLocation;
    
    // Draw the route line between start and end locations
    await _drawRouteLine(startLocation, endLocation);
    
    // Add start and end location markers
    await _addRouteMarkers(startLocation, endLocation);
  }

  Future<void> _drawRouteLine(latlong2.LatLng start, latlong2.LatLng end) async {
    if (_mapController == null) return;
    
    try {
      // Clear existing lines
      await _mapController!.clearLines();
      
      // Fetch actual route from Ola Maps
      final routeCoordinates = await _fetchRouteFromOlaMaps(start, end);
      
      if (routeCoordinates.isNotEmpty) {
        // Draw the actual route path (matching driver dashboard styling)
        await _mapController!.addLine(
          LineOptions(
            geometry: routeCoordinates,
            lineColor: "#4285F4", // Blue color like driver dashboard
            lineWidth: 6.0,
            lineOpacity: 0.9,
          ),
        );
        
        print('Actual route drawn with ${routeCoordinates.length} points from ${_routeInfo?.startLocationName} to ${_routeInfo?.endLocationName}');
      } else {
        // Fallback to straight line if route fetching fails
        await _mapController!.addLine(
          LineOptions(
            geometry: [
              LatLng(start.latitude, start.longitude),
              LatLng(end.latitude, end.longitude),
            ],
            lineColor: "#FF5722", // Orange color for route
            lineWidth: 3.0,
            lineOpacity: 0.8,
          ),
        );
        
        print('Fallback straight line route drawn from ${_routeInfo?.startLocationName} to ${_routeInfo?.endLocationName}');
      }
    } catch (e) {
      print('Error drawing route line: $e');
    }
  }

  Future<List<LatLng>> _fetchRouteFromOlaMaps(latlong2.LatLng start, latlong2.LatLng end) async {
    try {
      print('Fetching route from Ola Maps: ${start.latitude},${start.longitude} to ${end.latitude},${end.longitude}');
      
      // Use Ola Maps service to get directions
      final result = await _olaMapsService.getDirections(
        waypoints: [start, end],
        mode: 'DRIVING',
      );
      
      print('Ola Maps API response received successfully');
      
      // Extract route coordinates from response
      final routeCoordinates = _extractRouteCoordinatesFromOlaResponse(result);
      
      if (routeCoordinates.isNotEmpty) {
        print('Successfully extracted ${routeCoordinates.length} route points from Ola Maps');
        return routeCoordinates;
      } else {
        print('No route coordinates found in Ola Maps response');
      }
    } catch (e) {
      print('Error fetching route from Ola Maps: $e');
    }
    
    // Return empty list if route fetching fails
    print('Route fetching failed, returning empty list');
    return [];
  }

  List<LatLng> _extractRouteCoordinatesFromOlaResponse(Map<String, dynamic> response) {
    try {
      // Extract route information from the response (similar to driver route screen)
      final routes = response['routes'] as List?;
      
      if (routes == null || routes.isEmpty) {
        print('No routes found in Ola Maps response');
        return [];
      }
      
      final route = routes[0] as Map<String, dynamic>;
      
      // Try to use the overview_polyline for the best route visualization
      final overviewPolyline = route['overview_polyline'] as String?;
      if (overviewPolyline != null && overviewPolyline.isNotEmpty) {
        print('Using overview_polyline from Ola Maps for route visualization');
        return _decodePolyline(overviewPolyline);
      }
      
      // Fallback to extracting coordinates from legs/steps if available
      final legs = route['legs'] as List?;
      if (legs != null && legs.isNotEmpty) {
        List<LatLng> coordinates = [];
        for (final leg in legs) {
          if (leg is Map<String, dynamic>) {
            final steps = leg['steps'] as List?;
            if (steps != null) {
              for (final step in steps) {
                if (step is Map<String, dynamic>) {
                  final polyline = step['polyline'] as Map<String, dynamic>?;
                  if (polyline != null) {
                    final points = polyline['points'] as String?;
                    if (points != null && points.isNotEmpty) {
                      coordinates.addAll(_decodePolyline(points));
                    }
                  }
                }
              }
            }
          }
        }
        return coordinates;
      }
      
      print('No usable route data found in Ola Maps response');
      return [];
    } catch (e) {
      print('Error extracting route coordinates from Ola Maps response: $e');
      return [];
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    // Decode polyline (same algorithm as used in Google Maps/Ola Maps)
    List<LatLng> polyline = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
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

      polyline.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return polyline;
  }

  Future<void> _addRouteMarkers(latlong2.LatLng start, latlong2.LatLng end) async {
    if (_mapController == null) return;
    
    try {
      // Add start location marker (green)
      await _mapController!.addCircle(
        CircleOptions(
          geometry: LatLng(start.latitude, start.longitude),
          circleRadius: 8.0,
          circleColor: "#4CAF50", // Green for start
          circleStrokeColor: "#FFFFFF",
          circleStrokeWidth: 2.0,
        ),
      );
      
      // Add end location marker (red)
      await _mapController!.addCircle(
        CircleOptions(
          geometry: LatLng(end.latitude, end.longitude),
          circleRadius: 8.0,
          circleColor: "#F44336", // Red for end
          circleStrokeColor: "#FFFFFF",
          circleStrokeWidth: 2.0,
        ),
      );
      
      print('Route markers added for start and end locations');
    } catch (e) {
      print('Error adding route markers: $e');
    }
  }

  Future<void> _setupMapMarkers() async {
    if (_mapController == null || !mounted) return;

    try {
      // Clear existing circles (but not lines)
      await _mapController!.clearCircles();
      
      // Add user location marker (blue)
      if (_currentUserLocation != null) {
        await _mapController!.addCircle(
          CircleOptions(
            geometry: LatLng(_currentUserLocation!.latitude, _currentUserLocation!.longitude),
            circleRadius: 8.0,
            circleColor: "#2196F3", // Blue for user
            circleStrokeColor: "#FFFFFF",
            circleStrokeWidth: 2.0,
          ),
        );
        
        print('User location marker added');
      } else {
        print('User location not available for marker');
      }

      // Add bus location marker (large green with pulse effect)
      if (_currentBusLocation != null) {
        await _mapController!.addCircle(
          CircleOptions(
            geometry: LatLng(_currentBusLocation!.latitude, _currentBusLocation!.longitude),
            circleRadius: 15.0,
            circleColor: "#4CAF50", // Green for bus
            circleStrokeColor: "#FFFFFF",
            circleStrokeWidth: 3.0,
          ),
        );
        
        print('Bus location marker added');
      } else {
        print('Bus location not available, trying to get from real-time service');
        // Try to get the latest driver location from real-time service
        final realtimeService = Provider.of<RealtimeService>(context, listen: false);
        final tripId = widget.busInfo.tripId ?? widget.busInfo.busId;
        if (tripId.isNotEmpty) {
          final location = realtimeService.driverLocations[tripId];
          if (location != null) {
            final busLocation = latlong2.LatLng(
              (location['latitude'] as num).toDouble(),
              (location['longitude'] as num).toDouble(),
            );
            setState(() {
              _currentBusLocation = busLocation;
            });
            // Recursively call to add the marker now that we have location
            await _setupMapMarkers();
            return;
          }
        }
      }

      // Re-add route markers if we have route info
      if (_routeInfo != null) {
        await _addRouteMarkers(_routeInfo!.startLocation, _routeInfo!.endLocation);
      }
    } catch (e) {
      print('Error setting up map markers: $e');
      // Continue without markers rather than crashing
    }
  }

  Widget _buildBusInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(_pulseAnimation.value),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.directions_bus,
                    color: Colors.white,
                    size: 24,
                  ),
                );
              },
            ),
            
            SizedBox(width: 16),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.busInfo.busNumber ?? widget.busInfo.routeNumber,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_routeInfo != null) ...[
                    Text(
                      '${_routeInfo!.startLocationName} → ${_routeInfo!.endLocationName}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ] else ...[
                    Text(
                      widget.busInfo.routeName ?? widget.busInfo.destination,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'LIVE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ),
                if (_estimatedArrival != null) ...[
                  SizedBox(height: 4),
                  Text(
                    'ETA: $_estimatedArrival',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    return Column(
      children: [
        FloatingActionButton(
          heroTag: 'follow-bus',
          onPressed: () {
            setState(() => _isFollowingBus = true);
            _centerMapOnBus();
          },
          backgroundColor: _isFollowingBus ? AppColors.primary : Colors.grey[300],
          child: Icon(
            Icons.directions_bus,
            color: _isFollowingBus ? Colors.white : Colors.grey[600],
          ),
        ),
        
        SizedBox(height: 12),
        
        FloatingActionButton(
          heroTag: 'my-location',
          onPressed: () {
            setState(() => _isFollowingBus = false);
            _centerMapOnUser();
          },
          backgroundColor: !_isFollowingBus ? AppColors.primary : Colors.grey[300],
          child: Icon(
            Icons.my_location,
            color: !_isFollowingBus ? Colors.white : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomInfoPanel() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildInfoItem(
              icon: Icons.location_on,
              label: 'Distance',
              value: _distanceToUser != null 
                ? '${(_distanceToUser! / 1000).toStringAsFixed(1)} km'
                : '--',
            ),
            
            Container(
              width: 1,
              height: 40,
              color: Colors.grey[300],
            ),
            
            _buildInfoItem(
              icon: Icons.access_time,
              label: 'ETA',
              value: _estimatedArrival ?? '--',
            ),
            
            Container(
              width: 1,
              height: 40,
              color: Colors.grey[300],
            ),
            
            _buildInfoItem(
              icon: Icons.speed,
              label: 'Status',
              value: widget.busInfo.isActive ? 'Active' : 'Inactive',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primary),
          SizedBox(height: 0.5),
          Text(
            value,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 7,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Remove real-time service listener
    try {
      final realtimeService = Provider.of<RealtimeService>(context, listen: false);
      realtimeService.removeListener(_onBusLocationUpdate);
    } catch (e) {
      // Ignore context errors during disposal
    }
    
    _pulseController.dispose();
    _locationSubscription?.cancel();
    _updateTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}
