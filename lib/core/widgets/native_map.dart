import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'dart:math';

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

  @override
  Widget build(BuildContext context) {
    return MaplibreMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(initialCenter.latitude, initialCenter.longitude),
        zoom: initialZoom,
      ),
      onMapCreated: onMapCreated,
      styleString: 'asset://assets/map_style.json',
      myLocationEnabled: showMyLocation,
      onMapClick: onTap != null 
          ? (_, latLng) => onTap!(latlong2.LatLng(latLng.latitude, latLng.longitude)) 
          : null,
    );
  }
}