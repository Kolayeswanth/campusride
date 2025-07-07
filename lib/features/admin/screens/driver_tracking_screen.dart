import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:campusride/core/theme/app_colors.dart';
import '../models/driver.dart';
import '../models/driver_location.dart';
import '../services/driver_location_service.dart';
import 'dart:ui' as ui;

class DriverTrackingScreen extends StatefulWidget {
  final List<Driver> drivers;
  const DriverTrackingScreen({Key? key, required this.drivers}) : super(key: key);

  @override
  State<DriverTrackingScreen> createState() => _DriverTrackingScreenState();
}

class _DriverTrackingScreenState extends State<DriverTrackingScreen> {
  GoogleMapController? _mapController;
  final Map<String, Marker> _markers = {};
  final Map<String, Set<Polyline>> _routes = {};
  bool _showList = false;

  @override
  void initState() {
    super.initState();
    final ids = widget.drivers.map((d) => d.id).toList();
    Future.microtask(() => context.read<DriverLocationService>().startTracking(ids));
  }

  @override
  void dispose() {
    _mapController?.dispose();
    context.read<DriverLocationService>().stopTracking();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _updateMarkersAndRoutes(Map<String, DriverLocation> locations) {
    _markers.clear();
    _routes.clear();

    for (final driver in widget.drivers) {
      final location = locations[driver.id];
      if (location != null) {
        // Update marker
        final marker = Marker(
          markerId: MarkerId(driver.id),
          position: LatLng(location.latitude, location.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          rotation: location.heading ?? 0,
          anchor: const Offset(0.5, 0.5),
          infoWindow: InfoWindow(
            title: driver.name,
            snippet: 'Last updated: ${location.timestamp.hour}:${location.timestamp.minute}:${location.timestamp.second}',
          ),
        );
        _markers[driver.id] = marker;

        // Update route
        if (location.routePoints.isNotEmpty) {
          final polyline = Polyline(
            polylineId: PolylineId(driver.id),
            points: location.routePoints.map((point) => LatLng(point.latitude, point.longitude)).toList(),
            color: AppColors.primary,
            width: 3,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          );
          _routes[driver.id] = {polyline};
        }
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Real-Time Tracking'),
        actions: [
          IconButton(
            icon: Icon(_showList ? Icons.map : Icons.list),
            onPressed: () {
              setState(() {
                _showList = !_showList;
              });
            },
          ),
        ],
      ),
      body: Consumer<DriverLocationService>(
        builder: (context, service, child) {
          final locations = service.locations;
          _updateMarkersAndRoutes(locations);

          if (_showList) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: widget.drivers.map((driver) {
                final loc = locations[driver.id];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryLight,
                      child: Text(driver.name[0], style: const TextStyle(color: AppColors.primary)),
                    ),
                    title: Text(driver.name),
                    subtitle: loc == null
                        ? const Text('No location yet')
                        : Text(
                            'Lat: ${loc.latitude.toStringAsFixed(5)}, Lng: ${loc.longitude.toStringAsFixed(5)}\n'
                            'Speed: ${loc.speed?.toStringAsFixed(1) ?? "N/A"} km/h\n'
                            'Updated: ${loc.timestamp.hour}:${loc.timestamp.minute}:${loc.timestamp.second}',
                          ),
                    trailing: Icon(Icons.location_on, color: AppColors.primary),
                  ),
                );
              }).toList(),
            );
          }

          return GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(
              target: LatLng(17.0, 78.0), // Default to Hyderabad
              zoom: 12,
            ),
            markers: _markers.values.toSet(),
            polylines: _routes.values.expand((polylines) => polylines).toSet(),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            mapToolbarEnabled: true,
            compassEnabled: true,
            trafficEnabled: true,
          );
        },
      ),
    );
  }
} 