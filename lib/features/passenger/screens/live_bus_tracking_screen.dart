import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import '../../../core/services/realtime_service.dart';
import '../../../core/services/ola_location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../models/bus_info.dart';
import 'dart:async';

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
  
  latlong2.LatLng? _currentUserLocation;
  latlong2.LatLng? _currentBusLocation;
  bool _isLoadingLocation = true;
  bool _isFollowingBus = true;
  String? _estimatedArrival;
  double? _distanceToUser;
  
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

  String _calculateETA(double distanceInMeters) {
    // Assume average bus speed of 25 km/h in city traffic
    final speedKmH = 25.0;
    final distanceKm = distanceInMeters / 1000;
    final timeHours = distanceKm / speedKmH;
    final timeMinutes = (timeHours * 60).round();
    
    if (timeMinutes < 1) {
      return 'Arriving now';
    } else if (timeMinutes < 60) {
      return '$timeMinutes min';
    } else {
      final hours = timeMinutes ~/ 60;
      final mins = timeMinutes % 60;
      return '${hours}h ${mins}m';
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
      
      final bounds = LatLngBounds(
        southwest: LatLng(
          [_currentUserLocation!.latitude, _currentBusLocation!.latitude].reduce((a, b) => a < b ? a : b),
          [_currentUserLocation!.longitude, _currentBusLocation!.longitude].reduce((a, b) => a < b ? a : b),
        ),
        northeast: LatLng(
          [_currentUserLocation!.latitude, _currentBusLocation!.latitude].reduce((a, b) => a > b ? a : b),
          [_currentUserLocation!.longitude, _currentBusLocation!.longitude].reduce((a, b) => a > b ? a : b),
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
    if (_isLoadingLocation) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Getting your location...'),
          ],
        ),
      );
    }

    return MaplibreMap(
      styleString: '''
      {
        "version": 8,
        "sources": {
          "ola-raster": {
            "type": "raster",
            "tiles": [
              "https://api.olamaps.io/tiles/raster/v1/styles/default/{z}/{x}/{y}?api_key=u8bxvlb9ubgP2wKgJyxEY2ya1hYNcvyxFDCpA85y"
            ],
            "tileSize": 256,
            "maxzoom": 19,
            "attribution": "© Ola Maps"
          }
        },
        "layers": [
          {
            "id": "ola-raster-layer",
            "type": "raster",
            "source": "ola-raster"
          }
        ]
      }
      ''',
      onMapCreated: (controller) {
        _mapController = controller;
        _setupMapMarkers();
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
  }

  Future<void> _setupMapMarkers() async {
    if (_mapController == null || !mounted) return;

    try {
      // Clear existing markers first
      await _mapController!.clearCircles();
      
      // Add user location marker with built-in icon
      if (_currentUserLocation != null) {
        await _mapController!.addCircle(
          CircleOptions(
            geometry: LatLng(_currentUserLocation!.latitude, _currentUserLocation!.longitude),
            circleRadius: 8.0,
            circleColor: "#2196F3",
            circleStrokeColor: "#FFFFFF",
            circleStrokeWidth: 2.0,
          ),
        );
        
      } else {
        
      }

      // Add bus location marker with built-in icon
      if (_currentBusLocation != null) {
        await _mapController!.addCircle(
          CircleOptions(
            geometry: LatLng(_currentBusLocation!.latitude, _currentBusLocation!.longitude),
            circleRadius: 12.0,
            circleColor: "#4CAF50",
            circleStrokeColor: "#FFFFFF",
            circleStrokeWidth: 3.0,
          ),
        );
        
      } else {
        
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
    } catch (e) {
      
      
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
                  Text(
                    widget.busInfo.routeName ?? widget.busInfo.destination,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
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
