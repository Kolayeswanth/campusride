import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';
import 'package:campusride/core/services/map_service.dart';
import 'package:campusride/core/services/trip_service.dart';
import 'package:campusride/core/widgets/platform_safe_map.dart';

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
  late MapService _mapService;
  late TripService _tripService;
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _busStops = [];
  
  @override
  void initState() {
    super.initState();
    _mapService = Provider.of<MapService>(context, listen: false);
    _tripService = Provider.of<TripService>(context, listen: false);
    _initializeTracking();
  }

  Future<void> _initializeTracking() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get route information and bus stops
      final routeInfo = await _tripService.fetchRouteInfo(widget.routeId);
      
      if (routeInfo != null && routeInfo.containsKey('stops')) {
        setState(() {
          _busStops = List<Map<String, dynamic>>.from(routeInfo['stops']);
        });
      }
      
      // Start tracking this bus
      _mapService.subscribeToBusLocation(widget.busId);
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to initialize tracking: $e';
      });
    }
  }

  @override
  void dispose() {
    // Stop tracking when screen is closed
    _mapService.unsubscribeFromBusLocation(widget.busId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bus ${widget.busId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeTracking,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeTracking,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Consumer<MapService>(
      builder: (context, mapService, child) {
        final currentLocation = mapService.currentLocation ?? const LatLng(0, 0);
        
        return Stack(
          children: [
            kIsWeb 
              ? Container(
                  color: Colors.grey[200],
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Map view is not available in web preview',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please use the mobile app for full functionality',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              : PlatformSafeMap(
                  initialCameraPosition: CameraPosition(
                    target: currentLocation,
                    zoom: 15.0,
                  ),
                  myLocationEnabled: true,
                  trackCameraPosition: true,
                  onMapCreated: (dynamic controller) {
                    mapService.onMapCreated(controller);
                    _addBusStopsToMap();
                  },
                ),
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton(
                onPressed: () {
                  if (mapService.currentLocation != null) {
                    mapService.moveToLocation(mapService.currentLocation!);
                  }
                },
                child: const Icon(Icons.my_location),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addBusStopsToMap() async {
    for (final stop in _busStops) {
      await _mapService.addMarker(
        position: LatLng(
          stop['latitude'] as double,
          stop['longitude'] as double,
        ),
        title: stop['name'] as String,
        iconColor: Colors.green,
      );
    }
  }
} 