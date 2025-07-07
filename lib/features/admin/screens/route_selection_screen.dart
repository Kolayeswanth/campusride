import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/widgets/location_search_widget.dart';
import 'dart:math';

class RouteSelectionScreen extends StatefulWidget {
  const RouteSelectionScreen({super.key});

  @override
  State<RouteSelectionScreen> createState() => _RouteSelectionScreenState();
}

class _RouteSelectionScreenState extends State<RouteSelectionScreen> {
  MaplibreMapController? _mapController;
  latlong2.LatLng? _startPoint;
  latlong2.LatLng? _endPoint;
  String? _startLocation;
  String? _endLocation;
  List<latlong2.LatLng> _routePoints = [];
  bool _isLoading = false;
  Symbol? _startMarker;
  Symbol? _endMarker;
  Line? _routeLine;
  Timer? _debounceTimer;
  bool _isMapReady = false;
  Uint8List? _startMarkerImage;
  Uint8List? _endMarkerImage;

  @override
  void initState() {
    super.initState();
    _preloadMarkerImages();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _preloadMarkerImages() async {
    _startMarkerImage = await _getMarkerImageBytes(Colors.blue);
    _endMarkerImage = await _getMarkerImageBytes(Colors.red);
  }

  Future<Uint8List> _getMarkerImageBytes(Color color) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = const Size(32, 32);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw marker shape
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);

    // Add white border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, borderPaint);

    final image = await recorder.endRecording().toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _addMarkerImages() async {
    if (_mapController == null || _startMarkerImage == null || _endMarkerImage == null) return;

    await _mapController!.addImage('marker-start', _startMarkerImage!);
    await _mapController!.addImage('marker-end', _endMarkerImage!);
  }

  Future<Map<String, dynamic>> _getRouteDirections(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) async {
    try {
      final orsApiKey = dotenv.env['ORS_API_KEY'] ?? '';
      const url = 'https://api.openrouteservice.org/v2/directions/driving-car';
      final body = {
        'coordinates': [
          [startLng, startLat],
          [endLng, endLat]
        ],
        'preference': 'recommended',
        'instructions': true,
        'geometry_simplify': false,
        'format': 'geojson',
        'elevation': false,
        'maneuvers': true,
        'radiuses': [5000, 5000],
        'continue_straight': false,
      };

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': orsApiKey,
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to fetch route directions: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch route directions: $e');
    }
  }

  Future<void> _clearMap() async {
    if (_mapController == null) return;

    // Remove existing markers
    if (_startMarker != null) {
      await _mapController!.removeSymbol(_startMarker!);
      _startMarker = null;
    }
    if (_endMarker != null) {
      await _mapController!.removeSymbol(_endMarker!);
      _endMarker = null;
    }

    // Remove existing route
    if (_routeLine != null) {
      await _mapController!.removeLine(_routeLine!);
      _routeLine = null;
    }
  }

  void _debounceMapClick(LatLng coordinates) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      _handleMapClick(coordinates);
    });
  }

  Future<void> _handleMapClick(LatLng coordinates) async {
    if (!_isMapReady) return;

    if (_startPoint == null) {
      await _clearMap();
      setState(() {
        _startPoint = latlong2.LatLng(coordinates.latitude, coordinates.longitude);
        _startLocation = '${coordinates.latitude}, ${coordinates.longitude}';
      });
      await _addMarker(coordinates, 'Start', isStart: true);
    } else {
      // Always update end point when clicking after start point is set
      await _clearMap();
      setState(() {
        _endPoint = latlong2.LatLng(coordinates.latitude, coordinates.longitude);
        _endLocation = '${coordinates.latitude}, ${coordinates.longitude}';
      });
      await _addMarker(coordinates, 'End', isStart: false);
      await _drawRoute();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Route'),
      ),
      body: Stack(
        children: [
          MaplibreMap(
            onMapCreated: (controller) async {
              setState(() {
                _mapController = controller;
              });
              setState(() {
                _isMapReady = true;
              });
            },
            onStyleLoadedCallback: () async {
              await _addMarkerImages();
            },
            initialCameraPosition: const CameraPosition(
              target: LatLng(17.3850, 78.4867), // Default to Hyderabad
              zoom: 12,
            ),
            styleString: 'https://tiles.locationiq.com/v3/streets/vector.json?key=${dotenv.env['LOCATIONIQ_API_KEY']}',
            onMapClick: (point, coordinates) => _debounceMapClick(coordinates),
            gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
            minMaxZoomPreference: const MinMaxZoomPreference(5, 18),
            compassEnabled: true,
            compassViewPosition: CompassViewPosition.topRight,
            compassViewMargins: const Point(20, 20),
            myLocationEnabled: true,
            myLocationTrackingMode: MyLocationTrackingMode.tracking,
            myLocationRenderMode: MyLocationRenderMode.normal,
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                LocationSearchWidget(
                  hintText: 'Search for start location...',
                  onLocationSelected: (location) async {
                    if (!_isMapReady) return;
                    await _clearMap();
                    setState(() {
                      _startPoint = location;
                      _startLocation = '${location.latitude}, ${location.longitude}';
                    });
                    await _addMarker(LatLng(location.latitude, location.longitude), 'Start', isStart: true);
                  },
                ),
                const SizedBox(height: 8),
                if (_startPoint != null)
                  LocationSearchWidget(
                    hintText: 'Search for end location...',
                    onLocationSelected: (location) async {
                      if (!_isMapReady) return;
                      await _clearMap();
                      setState(() {
                        _endPoint = location;
                        _endLocation = '${location.latitude}, ${location.longitude}';
                      });
                      await _addMarker(LatLng(location.latitude, location.longitude), 'End', isStart: false);
                      await _drawRoute();
                    },
                  ),
              ],
            ),
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Future<void> _addMarker(LatLng coordinates, String title, {required bool isStart}) async {
    if (_mapController == null || !_isMapReady) return;

    // Remove existing marker of the same type before adding the new one
    if (isStart && _startMarker != null) {
      await _mapController!.removeSymbol(_startMarker!);
      _startMarker = null;
    } else if (!isStart && _endMarker != null) {
      await _mapController!.removeSymbol(_endMarker!);
      _endMarker = null;
    }

    final marker = await _mapController!.addSymbol(
      SymbolOptions(
        geometry: coordinates,
        iconImage: isStart ? 'marker-start' : 'marker-end',
        iconSize: 1.5,
        textField: title,
        textColor: isStart ? '#2196F3' : '#FF0000',
        textHaloColor: '#FFFFFF',
        textHaloWidth: 1.0,
        textOffset: const Offset(0, 2),
        iconAnchor: 'bottom',
      ),
    );

    if (isStart) {
      _startMarker = marker;
    } else {
      _endMarker = marker;
    }
  }

  Future<void> _drawRoute() async {
    if (_startPoint == null || _endPoint == null || _mapController == null || !_isMapReady) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final route = await _getRouteDirections(
        _startPoint!.latitude,
        _startPoint!.longitude,
        _endPoint!.latitude,
        _endPoint!.longitude,
      );

      if (route['features'] != null && route['features'].isNotEmpty) {
        final coordinates = route['features'][0]['geometry']['coordinates'];
        setState(() {
          _routePoints = coordinates.map((coord) => latlong2.LatLng(coord[1], coord[0])).toList();
        });

        _routeLine = await _mapController!.addLine(
          LineOptions(
            geometry: _routePoints.map((point) => LatLng(point.latitude, point.longitude)).toList(),
            lineColor: '#4285F4',
            lineWidth: 4.0,
            lineOpacity: 0.8,
          ),
        );

        // Fit camera to show the entire route with padding
        if (_routePoints.isNotEmpty) {
          final minLat = _routePoints.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
          final minLng = _routePoints.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
          final maxLat = _routePoints.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
          final maxLng = _routePoints.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);

          // Add padding to the bounds
          final latPadding = (maxLat - minLat) * 0.1;
          final lngPadding = (maxLng - minLng) * 0.1;

          await _mapController!.animateCamera(
            CameraUpdate.newLatLngBounds(
              LatLngBounds(
                southwest: LatLng(minLat - latPadding, minLng - lngPadding),
                northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
              ),
              left: 50,
              right: 50,
              top: 150,
              bottom: 50,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error drawing route: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
} 