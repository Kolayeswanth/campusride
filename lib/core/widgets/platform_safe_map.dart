import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:flutter_map/flutter_map.dart' show MapController;

// Import both map implementations
import 'web_map.dart';
import 'native_map.dart';

/// A platform-safe implementation of a map widget that uses different
/// implementations for web and mobile platforms.
class PlatformSafeMap extends StatelessWidget {
  final dynamic initialCameraPosition;
  final Function(dynamic)? onMapCreated;
  final Function(latlong2.LatLng)? onMapClick;
  final bool myLocationEnabled;
  final bool trackCameraPosition;

  const PlatformSafeMap({
    Key? key,
    required this.initialCameraPosition,
    this.onMapCreated,
    this.onMapClick,
    this.myLocationEnabled = false,
    this.trackCameraPosition = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // For web platform, use the WebMap implementation
    if (kIsWeb) {
      // Extract latitude and longitude from the initialCameraPosition
      final lat = initialCameraPosition.target.latitude;
      final lng = initialCameraPosition.target.longitude;
      final zoom = initialCameraPosition.zoom;
      
      return WebMap(
        initialCenter: latlong2.LatLng(lat, lng),
        initialZoom: zoom,
        showMyLocation: myLocationEnabled,
        onMapCreated: onMapCreated != null 
            ? (MapController controller) => onMapCreated!(controller) 
            : null,
        onTap: onMapClick != null 
            ? (latlong2.LatLng latLng) => onMapClick!(latLng) 
            : null,
      );
    } 
    // For mobile platforms, use the NativeMap implementation
    else {
      // Extract latitude and longitude from the initialCameraPosition
      final lat = initialCameraPosition.target.latitude;
      final lng = initialCameraPosition.target.longitude;
      final zoom = initialCameraPosition.zoom;
      
      return NativeMap(
        initialCenter: latlong2.LatLng(lat, lng),
        initialZoom: zoom,
        showMyLocation: myLocationEnabled,
        onMapCreated: onMapCreated != null 
            ? (MaplibreMapController controller) => onMapCreated!(controller) 
            : null,
        onTap: onMapClick != null 
            ? (latlong2.LatLng latLng) => onMapClick!(latLng) 
            : null,
      );
    }
  }
}