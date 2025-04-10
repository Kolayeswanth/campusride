import 'package:flutter/material.dart';
import 'package:maplibre_gl/mapbox_gl.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MaplibreMapController? mapController;

  void _onMapCreated(MaplibreMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("MapLibre Map")),
      body: MaplibreMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target: LatLng(37.7749, -122.4194),
          zoom: 10,
        ),
        styleString:
            "https://api.maptiler.com/maps/streets/style.json?key=X2gh37rGOvC2FnGm7GYy",
      ),
    );
  }
}
