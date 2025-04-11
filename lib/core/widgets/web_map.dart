import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';

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
  late MapController _mapController;
  LatLng? _currentLocation;
  List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  
  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    
    // Call onMapCreated callback if provided
    if (widget.onMapCreated != null) {
      // Use Future.delayed to ensure the controller is ready
      Future.delayed(Duration.zero, () => widget.onMapCreated!(_mapController));
    }
    
    if (widget.showMyLocation) {
      _getCurrentLocation();
    }
  }
  
  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requestedPermission = await Geolocator.requestPermission();
        if (requestedPermission == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _updateMarkers();
      });
    } catch (e) {
      print('Error getting location: $e');
    }
  }
  
  void _updateMarkers() {
    if (_currentLocation == null) return;
    
    setState(() {
      _markers = [
        ..._markers.where((marker) => marker.key != const Key('current_location')),
        Marker(
          key: const Key('current_location'),
          point: _currentLocation!,
          width: 30,
          height: 30,
          child: const Icon(
            Icons.location_on,
            color: Colors.blue,
            size: 30,
          ),
        ),
      ];
    });
  }
  
  void _addDestinationMarker(LatLng point) {
    setState(() {
      _markers = [
        ..._markers.where((marker) => marker.key != const Key('destination')),
        Marker(
          key: const Key('destination'),
          point: point,
          width: 30,
          height: 30,
          child: const Icon(
            Icons.place,
            color: Colors.red,
            size: 30,
          ),
        ),
      ];
      
      // If we have current location, add a route line
      if (_currentLocation != null) {
        _polylines = [
          Polyline(
            points: [_currentLocation!, point],
            color: Colors.blue,
            strokeWidth: 3.0,
          ),
        ];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get MapTiler API key from .env file
    final mapTilerKey = dotenv.env['MAPTILER_API_KEY'] ?? '';
    
    return FlutterMap(
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
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=$mapTilerKey',
          userAgentPackageName: 'com.campusride.app',
          additionalOptions: {
            'tileSize': '512',
            'zoomOffset': '-1',
          },
        ),
        MarkerLayer(markers: _markers),
        PolylineLayer(polylines: _polylines),
      ],
    );
  }
}