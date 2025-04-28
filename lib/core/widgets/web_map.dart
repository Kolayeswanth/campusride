import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../services/map_service.dart';
import 'dart:async';

/// A web-safe implementation of a map widget using flutter_map package
/// which is compatible with web platforms.
class WebMap extends StatefulWidget {
  final void Function(MapController)? onMapCreated;
  final LatLng initialCenter;
  final double initialZoom;
  final bool showMyLocation;
  final void Function(LatLng)? onTap;

  const WebMap({
    Key? key,
    required this.initialCenter,
    this.initialZoom = 15.0,
    this.onMapCreated,
    this.showMyLocation = false,
    this.onTap,
  }) : super(key: key);

  @override
  State<WebMap> createState() => _WebMapState();
}

class _WebMapState extends State<WebMap> {
  final MapController _mapController = MapController();
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  LatLng? _currentLocation;

  @override
  void initState() {
    super.initState();
    if (widget.onMapCreated != null) {
      widget.onMapCreated!(_mapController);
    }
    if (widget.showMyLocation) {
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _addCurrentLocationMarker();
      });
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  void _addCurrentLocationMarker() {
    if (_currentLocation == null) return;

    setState(() {
      _markers.removeWhere((marker) => marker.key == const Key('current_location'));
      _markers.add(
        Marker(
          key: const Key('current_location'),
          point: _currentLocation!,
          width: 30,
          height: 30,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.7),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(
              Icons.my_location,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      );
    });
  }

  void _addDestinationMarker(LatLng point) {
    // Remove old destination marker
    _markers.removeWhere((marker) => marker.key == const Key('destination'));

    // Add new destination marker
    _markers.add(
      Marker(
        key: const Key('destination'),
        point: point,
        width: 30,
        height: 30,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.location_on,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final mapService = Provider.of<MapService>(context);
    
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: widget.initialCenter,
            initialZoom: widget.initialZoom,
            onTap: widget.onTap != null 
                ? (_, point) {
                    widget.onTap!(point);
                    _addDestinationMarker(point);
                  } 
                : null,
            interactionOptions: const InteractionOptions(
              enableScrollWheel: true,
              enableMultiFingerGestureRace: true,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: mapService.mapStyleString,
              userAgentPackageName: 'com.campusride.app',
              additionalOptions: const {
                'tileSize': '512',
                'zoomOffset': '-1',
              },
            ),
            MarkerLayer(markers: _markers),
            PolylineLayer(polylines: _polylines),
          ],
        ),
        if (widget.showMyLocation)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () {
                _getCurrentLocation();
                if (_currentLocation != null) {
                  _mapController.move(_currentLocation!, widget.initialZoom);
                }
              },
              child: const Icon(
                Icons.my_location,
                color: Colors.blue,
              ),
            ),
          ),
      ],
    );
  }
}