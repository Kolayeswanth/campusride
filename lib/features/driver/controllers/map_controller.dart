import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:geolocator/geolocator.dart';
import 'dart:math';

class DriverMapController {
  MaplibreMapController? mapController;
  Symbol? driverMarker;
  Symbol? destinationMarker;
  Line? routeLine;
  Line? completedRouteLine;
  Symbol? startMarker;
  Symbol? endMarker;
  List<Symbol> symbols = [];
  Circle? locationCircle;
  Symbol? busIconId;

  // Animation variables
  Timer? animationTimer;
  double animationProgress = 0.0;

  // Map interaction variables
  bool userInteractingWithMap = false;
  DateTime? lastUserInteraction;
  bool shouldAutoZoom = false;
  static const double autoZoomRadius = 3.0; // 3 km radius

  // Track which images have been added to the map controller
  final Set<String> _addedImages = {};

  // Initialize the map controller
  void onMapCreated(MaplibreMapController controller) {
    mapController = controller;
    startAnimationTimer();
  }

  // Dispose resources
  void dispose() {
    animationTimer?.cancel();

    if (mapController != null) {
      if (locationCircle != null) {
        mapController!.removeCircle(locationCircle!);
      }
      for (final symbol in symbols) {
        mapController!.removeSymbol(symbol);
      }
      if (routeLine != null) {
        mapController!.removeLine(routeLine!);
      }
      if (completedRouteLine != null) {
        mapController!.removeLine(completedRouteLine!);
      }
      mapController!.dispose();
    }
  }

  // Start animation timer for pulsing effect
  void startAnimationTimer() {
    animationTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (timer) {
        animationProgress += 0.02;
        if (animationProgress > 1.0) {
          animationProgress = 0.0;
        }
        updateBusIcon();
      },
    );
  }

  // Update bus icon with pulsing effect
  void updateBusIcon() {
    // This would be implemented to update the bus icon with animation
  }

  // Add bus icon to the map
  Future<void> addBusIcon(latlong2.LatLng position) async {
    if (mapController == null) return;

    try {
      // Remove existing bus icon
      if (busIconId != null) {
        mapController!.removeSymbol(busIconId!);
        busIconId = null;
      }

      // Register the bus icon image with the map controller if not already added
      if (!_addedImages.contains('bus-icon')) {
        final ByteData bytes = await rootBundle.load('assets/images/bus_icon.png');
        final Uint8List list = bytes.buffer.asUint8List();
        await mapController!.addImage('bus-icon', list);
        _addedImages.add('bus-icon');
      }

      // Add the bus icon symbol using the registered image key
      busIconId = await mapController!.addSymbol(
        SymbolOptions(
          geometry: LatLng(position.latitude, position.longitude),
          iconImage: 'bus-icon',
          iconSize: 1.0,
          iconAnchor: 'bottom',
        ),
      );
    } catch (e) {
      print('Error adding bus icon: $e');
    }
  }

  // Update driver marker on the map
  Future<void> updateDriverMarker(Position position) async {
    if (mapController == null) return;

    try {
      // Remove existing driver marker
      if (driverMarker != null) {
        await mapController!.removeSymbol(driverMarker!);
      }

      // Add new driver marker
      driverMarker = await mapController!.addSymbol(
        SymbolOptions(
          geometry: LatLng(position.latitude, position.longitude),
          iconImage: 'assets/images/driver_marker.png',
          iconSize: 1.0,
        ),
      );
    } catch (e) {
      print('Error updating driver marker: $e');
    }
  }

  // Center map on current location
  Future<void> centerOnLocation(Position position) async {
    if (mapController == null) return;

    await mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(position.latitude, position.longitude),
        15.0,
      ),
    );
  }

  // Add route line to the map
  Future<void> addRouteLine(List<LatLng> routePoints) async {
    if (mapController == null) return;

    // Remove existing route line
    if (routeLine != null) {
      await mapController!.removeLine(routeLine!);
    }

    // Add new route line
    routeLine = await mapController!.addLine(
      LineOptions(
        geometry: routePoints,
        lineColor: "#4285F4",
        lineWidth: 6.0,
        lineOpacity: 0.9,
      ),
    );
  }

  // Add completed route line to the map
  Future<void> addCompletedRouteLine(List<LatLng> completedPoints) async {
    if (mapController == null) return;

    // Remove existing completed route line
    if (completedRouteLine != null) {
      await mapController!.removeLine(completedRouteLine!);
    }

    // Add new completed route line
    completedRouteLine = await mapController!.addLine(
      LineOptions(
        geometry: completedPoints,
        lineColor: "#00C853",
        lineWidth: 6.0,
        lineOpacity: 0.9,
      ),
    );
  }

  // Add destination marker to the map
  Future<void> addDestinationMarker(LatLng position) async {
    if (mapController == null) return;

    // Remove existing destination marker
    if (destinationMarker != null) {
      await mapController!.removeSymbol(destinationMarker!);
    }

    // Add new destination marker
    destinationMarker = await mapController!.addSymbol(
      SymbolOptions(
        geometry: position,
        iconImage: 'assets/images/destination_marker.png',
        iconSize: 1.0,
      ),
    );
  }

  // Clear all map elements
  Future<void> clearMap() async {
    if (mapController == null) return;

    if (driverMarker != null) {
      await mapController!.removeSymbol(driverMarker!);
      driverMarker = null;
    }

    if (destinationMarker != null) {
      await mapController!.removeSymbol(destinationMarker!);
      destinationMarker = null;
    }

    if (routeLine != null) {
      await mapController!.removeLine(routeLine!);
      routeLine = null;
    }

    if (completedRouteLine != null) {
      await mapController!.removeLine(completedRouteLine!);
      completedRouteLine = null;
    }

    for (final symbol in symbols) {
      await mapController!.removeSymbol(symbol);
    }
    symbols.clear();
  }

  // Update map zoom based on current position and destination
  Future<void> updateMapZoom(
      Position currentPosition, LatLng? destinationPosition) async {
    if (mapController == null) return;

    if (shouldAutoZoom) {
      if (destinationPosition != null) {
        // If destination is set, zoom to show both current location and destination
        final bounds = LatLngBounds(
          southwest: LatLng(
            min(currentPosition.latitude, destinationPosition.latitude),
            min(currentPosition.longitude, destinationPosition.longitude),
          ),
          northeast: LatLng(
            max(currentPosition.latitude, destinationPosition.latitude),
            max(currentPosition.longitude, destinationPosition.longitude),
          ),
        );

        await mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(
            bounds,
            left: 50,
            right: 50,
            top: 150,
            bottom: 150,
          ),
        );
      } else {
        // If no destination, zoom to radius around current location
        await mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(currentPosition.latitude, currentPosition.longitude),
            calculateZoomForRadius(autoZoomRadius),
          ),
        );
      }
    }
  }

  // Calculate zoom level for a given radius
  double calculateZoomForRadius(double radiusInKm) {
    // Approximate zoom level calculation for a given radius
    return 15.0 - log(radiusInKm) / log(2);
  }

  // Handle map interaction start
  void handleMapInteractionStart() {
    userInteractingWithMap = true;
    lastUserInteraction = DateTime.now();
    shouldAutoZoom = false;
  }

  // Handle map interaction end
  void handleMapInteractionEnd() {
    userInteractingWithMap = false;
    lastUserInteraction = DateTime.now();
    shouldAutoZoom = true;
  }
}
