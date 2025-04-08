import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;
import '../../../core/services/auth_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/map_service.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final MapController _mapController = MapController();
  latlong.LatLng? _currentLocation;
  bool _isTracking = false;
  final _locationService = LocationService();
  final _authService = AuthService();
  final _mapService = MapService();

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      final mapLibreLocation = await _mapService.getCurrentLocation();
      setState(() {
        _currentLocation = latlong.LatLng(
          mapLibreLocation.latitude,
          mapLibreLocation.longitude,
        );
      });
    } catch (e) {
      // Handle location error
    }
  }

  void _startTracking() async {
    if (!_isTracking) {
      final userId = _authService.currentUser?.id;
      if (userId != null) {
        await _locationService.startTracking(userId, 'driver');
        setState(() => _isTracking = true);
      }
    }
  }

  void _stopTracking() async {
    if (_isTracking) {
      await _locationService.stopTracking();
      setState(() => _isTracking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _authService.signOut(),
          ),
        ],
      ),
      body: _currentLocation == null
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                center: _currentLocation!,
                zoom: 15.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                ),
                MarkerLayer(
                  markers: [
                    if (_currentLocation != null)
                      Marker(
                        point: _currentLocation!,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40.0,
                        ),
                        width: 40.0,
                        height: 40.0,
                      ),
                  ],
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isTracking ? _stopTracking : _startTracking,
        label: Text(_isTracking ? 'Stop Tracking' : 'Start Tracking'),
        icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
      ),
    );
  }

  @override
  void dispose() {
    _locationService.dispose();
    super.dispose();
  }
}