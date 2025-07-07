import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
  final List<Marker> markers;
  final List<Polyline> polylines;

  const WebMap({
    Key? key,
    required this.initialCenter,
    this.initialZoom = 15.0,
    this.onMapCreated,
    this.showMyLocation = false,
    this.onTap,
    this.markers = const [],
    this.polylines = const [],
  }) : super(key: key);

  @override
  State<WebMap> createState() => _WebMapState();
}

class _WebMapState extends State<WebMap> {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  StreamSubscription<Position>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.onMapCreated != null) {
      widget.onMapCreated!(_mapController);
    }
    if (widget.showMyLocation) {
      _getCurrentLocation();
       _startLocationUpdates();
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  void _startLocationUpdates() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1,
    );
    _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
      },
      onError: (error) {
        print('Error receiving location updates: $error');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapService = Provider.of<MapService>(context);

    List<Marker> allMarkers = [...widget.markers];
    if (widget.showMyLocation && _currentLocation != null) {
       allMarkers.add(
         Marker(
           point: _currentLocation!,
           width: 40,
           height: 40,
           child: const Icon(
             Icons.my_location,
             color: Colors.blue,
             size: 30,
           ),
         ),
       );
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: widget.initialCenter,
        initialZoom: widget.initialZoom,
        onTap: widget.onTap != null ? (tapPosition, latLng) => widget.onTap!(latLng) : null,
        minZoom: 3,
        maxZoom: 18,
         interactionOptions: const InteractionOptions(
           flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
         ),
      ),
      children: [
        TileLayer(
          urlTemplate: mapService.mapStyleString, // Assuming MapService provides this
          userAgentPackageName: 'com.campusride.app',
        ),
        PolylineLayer(polylines: widget.polylines),
        MarkerLayer(markers: allMarkers),
      ],
    );
  }
}
