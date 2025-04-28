import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'dart:math';
import 'package:provider/provider.dart';
import '../services/map_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// A native implementation of a map widget using maplibre_gl package
/// which is compatible with mobile platforms.

class NativeMap extends StatelessWidget {
  final void Function(MaplibreMapController)? onMapCreated;
  final latlong2.LatLng initialCenter;
  final double initialZoom;
  final bool showMyLocation;
  final void Function(latlong2.LatLng)? onTap;

  const NativeMap({
    Key? key,
    required this.initialCenter,
    this.initialZoom = 15.0,
    this.onMapCreated,
    this.showMyLocation = false,
    this.onTap,
  }) : super(key: key);

  Future<String> _loadMapStyle() async {
    try {
      final mapStyle = await rootBundle.loadString('assets/map_style.json');
      return mapStyle;
    } catch (e) {
      print('Error loading map style: $e');
      // Return a basic style if the file can't be loaded
      return json.encode({
        "version": 8,
        "sources": {
          "maptiler-streets": {
            "type": "raster",
            "tiles": [
              "https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}.png?key=${dotenv.env['MAPTILER_API_KEY']}"
            ],
            "tileSize": 256,
            "attribution": "© MapTiler © OpenStreetMap contributors"
          }
        },
        "layers": [
          {
            "id": "background",
            "type": "background",
            "paint": {
              "background-color": "#f8f4f0"
            }
          },
          {
            "id": "maptiler-streets-layer",
            "type": "raster",
            "source": "maptiler-streets",
            "minzoom": 0,
            "maxzoom": 22
          }
        ]
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapService = Provider.of<MapService>(context);
    
    return MaplibreMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(initialCenter.latitude, initialCenter.longitude),
        zoom: initialZoom,
      ),
      onMapCreated: onMapCreated,
      styleString: mapService.mapStyleString,
      myLocationEnabled: showMyLocation,
      myLocationTrackingMode: MyLocationTrackingMode.none,
      onMapClick: onTap != null 
          ? (_, latLng) => onTap!(latlong2.LatLng(latLng.latitude, latLng.longitude)) 
          : null,
    );
  }
}
