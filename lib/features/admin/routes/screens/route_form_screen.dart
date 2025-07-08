import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import '../../../../core/services/map_service.dart' as core_map_service;
import '../../../../core/theme/app_colors.dart';
import '../models/route.dart' as route_model;
import '../services/route_service.dart';
import '../../../../core/widgets/platform_safe_map.dart';
import '../../services/map_service.dart' as admin_map_service;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../models/location_point.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../../core/widgets/buttons/primary_button.dart';
import '../../../../core/constants/map_constants.dart';
import '../../../../core/utils/location_utils.dart';
import '../../../../core/services/geocoding_service.dart';
import '../../../../core/services/trip_service.dart';
import '../../../../core/models/route.dart';
import '../../../../core/models/bus.dart';
import 'dart:async';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../../../core/widgets/location_search_widget.dart';

class RouteFormScreen extends StatefulWidget {
  final route_model.Route? route;
  final String? collegeId;
  final String? driverId;

  const RouteFormScreen({
    Key? key,
    this.route,
    this.collegeId,
    this.driverId,
  }) : super(key: key);

  @override
  State<RouteFormScreen> createState() => _RouteFormScreenState();
}

class _RouteFormScreenState extends State<RouteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _busNumberController;
  late TextEditingController _startLocationController;
  late TextEditingController _endLocationController;
  bool _isActive = true;
  bool _isLoading = false;
  String? _error;
  MaplibreMapController? _mapController;
  List<Map<String, dynamic>> _startSearchResults = [];
  List<Map<String, dynamic>> _endSearchResults = [];
  bool _isSearchingStart = false;
  bool _isSearchingEnd = false;
  latlong2.LatLng? _startLocation;
  latlong2.LatLng? _endLocation;
  List<latlong2.LatLng> _routePoints = [];
  bool _showRoute = false;
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    _busNumberController = TextEditingController(text: widget.route?.busNumber ?? '');
    _startLocationController = TextEditingController(text: widget.route?.startLocation ?? '');
    _endLocationController = TextEditingController(text: widget.route?.endLocation ?? '');
    _isActive = widget.route?.isActive ?? true;
    // Delay map initialization to avoid blocking the UI
    Future.microtask(() => _initializeMap());
  }

  @override
  void dispose() {
    _busNumberController.dispose();
    _startLocationController.dispose();
    _endLocationController.dispose();
    _mapController?.dispose();
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    if (widget.route != null) {
      try {
        final startCoords = await locationFromAddress(widget.route!.startLocation);
        final endCoords = await locationFromAddress(widget.route!.endLocation);
        if (mounted && startCoords.isNotEmpty && endCoords.isNotEmpty) {
          setState(() {
            _startLocation = latlong2.LatLng(startCoords.first.latitude, startCoords.first.longitude);
            _endLocation = latlong2.LatLng(endCoords.first.latitude, endCoords.first.longitude);
          });
          _addMarkers();
          await _fetchRoute();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _error = 'Error getting coordinates: $e';
          });
        }
      }
    }
  }

  Future<void> _disposeDebounce() async {
    if (_searchDebounceTimer != null && _searchDebounceTimer!.isActive) {
      _searchDebounceTimer!.cancel();
    }
  }

  Future<List<Map<String, dynamic>>> searchLocations(String query) async {
    if (query.isEmpty) return [];

    final apiKey = dotenv.env['LOCATIONIQ_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      print('LOCATIONIQ_API_KEY not found in .env');
      return [];
    }

    final url = Uri.parse(
      'https://api.locationiq.com/v1/autocomplete.php?key=$apiKey&q=$query&limit=5&format=json',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        return results.map((location) => {
          'name': location['display_name'],
          'lat': double.parse(location['lat']),
          'lon': double.parse(location['lon']),
        }).toList();
      } else {
        print('LocationIQ search failed: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error during LocationIQ search: $e');
      return [];
    }
  }

  Future<void> _searchLocation(String query, bool isStart) async {
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          if (isStart) {
            _startSearchResults = [];
            _isSearchingStart = false;
          } else {
            _endSearchResults = [];
            _isSearchingEnd = false;
          }
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        if (isStart) {
          _isSearchingStart = true;
        } else {
          _isSearchingEnd = true;
        }
        _error = null;
      });
    }

    try {
      final results = await searchLocations(query);

      if (mounted) {
        setState(() {
          if (isStart) {
            _startSearchResults = results;
            _isSearchingStart = false;
          } else {
            _endSearchResults = results;
            _isSearchingEnd = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to search location: $e';
          if (isStart) {
            _isSearchingStart = false;
          } else {
            _isSearchingEnd = false;
          }
        });
      }
    }
  }

  Future<void> _debounceSearch(String query, bool isStart) async {
    if (_searchDebounceTimer != null && _searchDebounceTimer!.isActive) {
      _searchDebounceTimer!.cancel();
    }
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _searchLocation(query, isStart);
    });
  }

  void _selectLocation(Map<String, dynamic> location, bool isStart) {
    final lat = location['lat'] as double;
    final lon = location['lon'] as double;
    final address = location['name'] as String;

    if (isStart) {
      setState(() {
        _startLocation = latlong2.LatLng(lat, lon);
        _startLocationController.text = address;
        _startSearchResults = [];
      });
    } else {
      setState(() {
        _endLocation = latlong2.LatLng(lat, lon);
        _endLocationController.text = address;
        _endSearchResults = [];
      });
    }

    _addMarkers();

    if (_startLocation != null && _endLocation != null) {
      _fetchRoute();
    }

    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(LatLng(lat, lon)),
      );
    }
  }

  Future<void> _fetchRoute() async {
    if (_startLocation == null || _endLocation == null || _mapController == null) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final orsApiKey = dotenv.env['ORS_API_KEY'] ?? '';
      print('ORS_API_KEY: ${orsApiKey.isNotEmpty ? "Loaded" : "Not Loaded"}');
      if (orsApiKey.isEmpty) {
        throw Exception('OpenRouteService API key not configured');
      }

      const url = 'https://api.openrouteservice.org/v2/directions/driving-car';
      final body = {
        'coordinates': [
          [_startLocation!.longitude, _startLocation!.latitude],
          [_endLocation!.longitude, _endLocation!.latitude]
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
        final data = json.decode(response.body);
        print('OpenRouteService Route API Response Body: ${response.body}');
        if (data['features'] != null && data['features'].isNotEmpty) {
          final geometry = data['features'][0]['geometry'];
          print('OpenRouteService Route API Geometry: ${geometry}');
          if (geometry != null && geometry['type'] == 'LineString' && geometry['coordinates'] is List) {
            final coordinates = geometry['coordinates'];
            print('OpenRouteService Route API Coordinates: ${coordinates}');
            setState(() {
              _routePoints = coordinates.map<latlong2.LatLng>((coord) => latlong2.LatLng(coord[1].toDouble(), coord[0].toDouble())).toList();
              _showRoute = true;
            });
            _drawRouteLine();
          } else {
            print('OpenRouteService API returned features but geometry is missing or invalid.');
            if (mounted) {
              setState(() {
                _error = 'Could not fetch route geometry for the selected locations.';
              });
            }
          }
        } else {
          print('OpenRouteService API returned no routable path. Status: ${response.statusCode}');
          if (mounted) {
            setState(() {
              _error = 'Could not find a routable path between the selected locations. Try different points.';
              _showRoute = false;
              _routePoints = [];
              _mapController?.clearLines();
            });
          }
        }
      } else {
        print('OpenRouteService API call failed with status: ${response.statusCode}. Body: ${response.body}');
        if (mounted) {
          setState(() {
            _error = 'Failed to fetch route directions. Status: ${response.statusCode}';
          });
        }
      }
    } catch (e) {
      print('Error during OpenRouteService route fetch: $e');
      if (mounted) {
        setState(() {
          _error = 'Error fetching route: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _drawRouteLine() {
    if (_mapController == null || _routePoints.isEmpty) return;

    _mapController!.clearLines();

    _mapController!.addLine(
      LineOptions(
        geometry: _routePoints.map((point) => LatLng(point.latitude, point.longitude)).toList(),
        lineColor: '#${AppColors.primary.value.toRadixString(16).substring(2)}',
        lineWidth: 3.0,
      ),
    );

    if (_routePoints.isNotEmpty && _mapController != null) {
      double minLat = _routePoints.first.latitude;
      double maxLat = _routePoints.first.latitude;
      double minLon = _routePoints.first.longitude;
      double maxLon = _routePoints.first.longitude;

      for (var point in _routePoints) {
        if (point.latitude < minLat) minLat = point.latitude;
        if (point.latitude > maxLat) maxLat = point.latitude;
        if (point.longitude < minLon) minLon = point.longitude;
        if (point.longitude > maxLon) maxLon = point.longitude;
      }

      final southwest = LatLng(minLat, minLon);
      final northeast = LatLng(maxLat, maxLon);

      final bounds = LatLngBounds(southwest: southwest, northeast: northeast);

      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          bounds,
          left: 50,
          right: 50,
          top: 150,
          bottom: 50,
        ),
      );
    }
  }

  Future<void> _saveRoute() async {
    if (_formKey.currentState!.validate()) {
      if (_startLocation == null || _endLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select both start and end locations')),
        );
        return;
      }

      setState(() {
        _isLoading = true;
        _error = null;
      });

      try {
        final routeService = Provider.of<RouteService>(context, listen: false);

        if (widget.route == null) {
          if (widget.collegeId == null || widget.driverId == null) {
            throw Exception('College ID or Driver ID is missing.');
          }
          
          await routeService.createRoute(
            busNumber: _busNumberController.text,
            startLocation: _startLocationController.text,
            endLocation: _endLocationController.text,
            startLat: _startLocation!.latitude,
            startLng: _startLocation!.longitude,
            endLat: _endLocation!.latitude,
            endLng: _endLocation!.longitude,
            collegeId: widget.collegeId!,
            driverId: widget.driverId!,
          );
        } else {
          await routeService.updateRoute(
            id: widget.route!.id,
            busNumber: _busNumberController.text,
            startLocation: _startLocationController.text,
            endLocation: _endLocationController.text,
            startLat: _startLocation!.latitude,
            startLng: _startLocation!.longitude,
            endLat: _endLocation!.latitude,
            endLng: _endLocation!.longitude,
            isActive: _isActive,
            collegeId: widget.collegeId!,
            driverId: widget.driverId!,
          );
        }

        if (mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        setState(() {
          _error = 'Failed to save route: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addMarkers() async {
    if (_mapController == null) return;

    await _mapController!.clearSymbols();

    if (_startLocation != null) {
      await _mapController!.addSymbol(
        SymbolOptions(
          geometry: LatLng(_startLocation!.latitude, _startLocation!.longitude),
          iconImage: 'marker',
          iconSize: 1.5,
          textField: 'Start',
          textColor: '#0000FF',
          textHaloColor: '#FFFFFF',
          textHaloWidth: 0.5,
          textOffset: const Offset(0, 2),
        ),
      );
    }

    if (_endLocation != null) {
      await _mapController!.addSymbol(
        SymbolOptions(
          geometry: LatLng(_endLocation!.latitude, _endLocation!.longitude),
          iconImage: 'marker',
          iconSize: 1.5,
          textField: 'End',
          textColor: '#FF0000',
          textHaloColor: '#FFFFFF',
          textHaloWidth: 0.5,
          textOffset: const Offset(0, 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.route == null ? 'Add Route' : 'Edit Route'),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              flex: 2,
              child: Stack(
                children: [
                  MaplibreMap(
                    onMapCreated: (controller) {
                      _mapController = controller;
                      _addMarkers();
                    },
                    onStyleLoadedCallback: () {
                      _addMarkers();
                    },
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(17.3850, 78.4867),
                      zoom: 12,
                    ),
                    styleString: 'https://api.maptiler.com/maps/streets/style.json?key=${dotenv.env['MAPTILER_API_KEY']}',
                  ),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator()),
                  if (_error != null)
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Card(
                        color: Colors.red.shade100,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(_error!, style: const TextStyle(color: Colors.red)),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            Expanded(
              flex: 3,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  TextFormField(
                    controller: _busNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Bus Number',
                      hintText: 'Enter bus number',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a bus number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16.0),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _startLocationController,
                        decoration: InputDecoration(
                          labelText: 'Start Location',
                          hintText: 'Search start location',
                          suffixIcon: _isSearchingStart
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.search),
                        ),
                        onChanged: (value) {
                          _debounceSearch(value, true);
                        },
                      ),
                      if (_startSearchResults.isNotEmpty)
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                             border: Border.all(color: Colors.grey.shade300),
                             borderRadius: BorderRadius.circular(4.0),
                          ),
                          child: ListView.builder(
                            itemCount: _startSearchResults.length,
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemBuilder: (context, index) {
                              final result = _startSearchResults[index];
                              return ListTile(
                                title: Text(result['name'] ?? 'Unknown Location'),
                                onTap: () => _selectLocation(result, true),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16.0),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _endLocationController,
                        decoration: InputDecoration(
                          labelText: 'End Location',
                          hintText: 'Search end location',
                          suffixIcon: _isSearchingEnd
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.search),
                        ),
                        onChanged: (value) {
                          _debounceSearch(value, false);
                        },
                      ),
                      if (_endSearchResults.isNotEmpty)
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                           decoration: BoxDecoration(
                             border: Border.all(color: Colors.grey.shade300),
                             borderRadius: BorderRadius.circular(4.0),
                          ),
                          child: ListView.builder(
                            itemCount: _endSearchResults.length,
                            shrinkWrap: true,
                             padding: EdgeInsets.zero,
                            itemBuilder: (context, index) {
                              final result = _endSearchResults[index];
                              return ListTile(
                                title: Text(result['name'] ?? 'Unknown Location'),
                                onTap: () => _selectLocation(result, false),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16.0),

                  SwitchListTile(
                    title: const Text('Active'),
                    value: _isActive,
                    onChanged: (value) {
                      setState(() {
                        _isActive = value;
                      });
                    },
                  ),
                  const SizedBox(height: 24.0),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveRoute,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(widget.route == null ? 'Add Route' : 'Update Route'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
