import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'dart:ui' hide Point;
import 'dart:math';

class DriverMapService {
  final MaplibreMapController? mapController;
  final Function(LatLng) onMapClick;
  final Function() onCameraIdle;

  DriverMapService({
    required this.mapController,
    required this.onMapClick,
    required this.onCameraIdle,
  });

  Future<void> addMapIcons() async {
    try {
      await mapController?.addImage(
        "marker",
        await _loadIconImage('assets/images/marker.png'),
      );

      await mapController?.addImage(
        "marker-end",
        await _loadIconImage('assets/images/destination_marker.png'),
      );

      await mapController?.addImage(
        "bus-icon",
        await _loadIconImage('assets/images/bus_icon.png'),
      );
    } catch (e) {
      print('Error loading map icons: $e');
    }
  }

  Future<Uint8List> _loadIconImage(String assetPath) async {
    if (!await _assetExists(assetPath)) {
      return await _createFallbackIcon();
    }

    final ByteData bytes = await rootBundle.load(assetPath);
    return bytes.buffer.asUint8List();
  }

  Future<bool> _assetExists(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Uint8List> _createFallbackIcon() async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 32.0;
    const radius = size / 2;

    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    canvas.drawCircle(const Offset(radius, radius), radius, paint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  Future<void> addBusIcon(latlong2.LatLng position, double bearing) async {
    if (mapController == null) return;
    try {
      await mapController?.addSymbol(
        SymbolOptions(
          geometry: LatLng(position.latitude, position.longitude),
          iconImage: "bus-icon",
          iconSize: 1.2,
          iconRotate: bearing,
          textField: 'Bus',
          textOffset: const Offset(0, 1.5),
          textColor: '#000000',
          textHaloColor: '#FFFFFF',
          textHaloWidth: 1.0,
          iconAnchor: "bottom",
        ),
      );
    } catch (e) {
      print('Error adding bus icon: $e');
    }
  }

  Future<void> updateRouteLine(List<latlong2.LatLng> routePoints) async {
    if (mapController == null || routePoints.isEmpty) return;

    try {
      final routeLatLngs = routePoints
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();

      await mapController?.addLine(
        LineOptions(
          geometry: routeLatLngs,
          lineColor: "#4285F4",
          lineWidth: 6.0,
          lineOpacity: 0.9,
        ),
      );
    } catch (e) {
      print('Error updating route line: $e');
    }
  }

  Future<void> fitMapToRoute(List<latlong2.LatLng> routePoints) async {
    if (routePoints.isEmpty) return;

    try {
      const padding = 0.0002;

      final bounds = LatLngBounds(
        southwest: LatLng(
          routePoints.map((p) => p.latitude).reduce(min) - padding,
          routePoints.map((p) => p.longitude).reduce(min) - padding,
        ),
        northeast: LatLng(
          routePoints.map((p) => p.latitude).reduce(max) + padding,
          routePoints.map((p) => p.longitude).reduce(max) + padding,
        ),
      );

      await mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(
          bounds,
          left: 50,
          right: 50,
          top: 150,
          bottom: 150,
        ),
      );
    } catch (e) {
      print('Error fitting map to route: $e');
    }
  }

  double calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final dLon = (lon2 - lon1) * pi / 180;
    final lat1Rad = lat1 * pi / 180;
    final lat2Rad = lat2 * pi / 180;

    final y = sin(dLon) * cos(lat2Rad);
    final x =
        cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(dLon);

    final bearing = atan2(y, x) * 180 / pi;
    return (bearing + 360) % 360;
  }
}
