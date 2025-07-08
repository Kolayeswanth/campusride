import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'dart:async';
import '../../../core/theme/theme.dart';
import '../../../core/services/route_management_service.dart';
import '../../../core/services/open_route_service.dart';
import '../../../core/services/maptiler_service.dart';
import '../../../core/services/locationiq_service.dart';
import '../../../core/services/fallback_routing_service.dart';
import '../models/college.dart';

class RouteMapScreen extends StatefulWidget {
  final Map<String, dynamic> route;
  final College college;
  final Function(Map<String, dynamic>) onRouteSaved;

  const RouteMapScreen({
    Key? key,
    required this.route,
    required this.college,
    required this.onRouteSaved,
  }) : super(key: key);

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final MapController _mapController = MapController();
  final OpenRouteService _routingService = OpenRouteService();
  final MapTilerService _mapService = MapTilerService();
  final LocationIQService _searchService = LocationIQService();
  
  // Location data
  LatLng _currentMapCenter = LatLng(28.7041, 77.1025); // Default to Delhi
  
  // Route data
  List<LatLng> _routePoints = [];
  List<Map<String, dynamic>> _stops = [];
  bool _isLoading = false;
  bool _hasPolyline = false;
  String? _polylineData;
  double? _distanceKm;
  
  // Map interaction
  bool _selectingFromLocation = false;
  bool _selectingToLocation = false;
  bool _addingWaypoint = false;
  bool _apiKeyValid = false;

  // Additional state variables
  List<String> _stopDistances = [];
  String? _totalTime;

  LatLng? get _fromLocation => _stops.isNotEmpty ? LatLng(_stops.first['lat'], _stops.first['lng']) : null;
  LatLng? get _toLocation => _stops.length > 1 ? LatLng(_stops.last['lat'], _stops.last['lng']) : null;

  @override
  void initState() {
    super.initState();
    _validateApiKeys();
    _initializeRoute();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentMapCenter = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  Future<void> _validateApiKeys() async {
    final routingValid = await _routingService.validateApiKey();
    final mapValid = await _mapService.validateApiKey();
    final searchValid = await _searchService.validateApiKey();
    
    setState(() {
      _apiKeyValid = routingValid && mapValid && searchValid;
    });
    
    if (!_apiKeyValid) {
      String errorMsg = 'API keys validation failed:';
      if (!routingValid) errorMsg += '\n- OpenRouteService key invalid';
      if (!mapValid) errorMsg += '\n- MapTiler key invalid';
      if (!searchValid) errorMsg += '\n- LocationIQ key invalid';
      _showError(errorMsg);
    }
  }

  void _initializeRoute() {
    _fromController.text = widget.route['start_location'] ?? '';
    _toController.text = widget.route['end_location'] ?? '';
    
    if (widget.route['waypoints'] != null && (widget.route['waypoints'] as List).isNotEmpty) {
      _stops = List<Map<String, dynamic>>.from(widget.route['waypoints']);
    }
    
    if (widget.route['polyline_data'] != null && 
        widget.route['polyline_data'].toString().isNotEmpty) {
      _hasPolyline = true;
      _polylineData = widget.route['polyline_data'];
      _distanceKm = widget.route['distance_km']?.toDouble();
      
      _generatePolylineVisualization();

      if (_stops.isNotEmpty) {
        _updateLocationText(_fromLocation!, true);
        if (_toLocation != null) {
          _updateLocationText(_toLocation!, false);
        }
      }
    }
  }

  void _reorderStops(int oldIndex, int newIndex) {
    if (oldIndex < 0 || newIndex < 0 || oldIndex >= _stops.length || newIndex >= _stops.length) return;
    if (oldIndex == 0 || oldIndex == _stops.length - 1 || 
        newIndex == 0 || newIndex == _stops.length - 1) {
      _showError('Cannot reorder start or end points');
      return;
    }

    setState(() {
      final stop = _stops.removeAt(oldIndex);
      _stops.insert(newIndex, stop);
    });
    _generateRoute();
  }

  Future<bool> _confirmStopRemoval(int index) async {
    if (index == 0 || index == _stops.length - 1) {
      _showError('Cannot remove start or end points');
      return false;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove Stop'),
          content: const Text('Are you sure you want to remove this stop?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('REMOVE'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        );
      },
    );

    return confirmed ?? false;
  }

  void _removeStop(int index) async {
    if (await _confirmStopRemoval(index)) {
      setState(() {
        _stops.removeAt(index);
      });
      _generateRoute();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Set Route: ${widget.route['bus_number']}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_hasPolyline)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ElevatedButton.icon(
                onPressed: _saveRoute,
                icon: const Icon(Icons.save_alt, size: 16),
                label: const Text('SAVE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
          // Route info section
          _buildRouteInfo(),
          // Route input section
          Container(
            constraints: const BoxConstraints(maxHeight: 300), // Limit max height
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // From location input
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade300),
                    color: Colors.green.shade50,
                  ),
                  child: TextFormField(
                    controller: _fromController,
                    decoration: InputDecoration(
                      labelText: 'From',
                      hintText: 'Enter starting location',
                      prefixIcon: const Icon(Icons.trip_origin, color: Colors.green),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _selectingFromLocation ? Icons.location_searching : Icons.location_on,
                          color: _selectingFromLocation ? Colors.green : Colors.grey,
                        ),
                        onPressed: () => _startLocationSelection(true),
                        tooltip: 'Select on map',
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onTap: () => _showLocationSearch(true),
                    readOnly: false,
                  ),
                ),
                
                // To location input
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade300),
                    color: Colors.red.shade50,
                  ),
                  child: TextFormField(
                    controller: _toController,
                    decoration: InputDecoration(
                      labelText: 'To',
                      hintText: 'Enter destination',
                      prefixIcon: const Icon(Icons.location_on, color: Colors.red),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _selectingToLocation ? Icons.location_searching : Icons.location_on,
                          color: _selectingToLocation ? Colors.red : Colors.grey,
                        ),
                        onPressed: () => _startLocationSelection(false),
                        tooltip: 'Select on map',
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onTap: () => _showLocationSearch(false),
                    readOnly: false,
                  ),
                ),
                const SizedBox(height: 16),                  // Use Wrap instead of Row to handle overflow
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _canGenerateRoute() ? _generateRoute : null,
                          icon: _isLoading 
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.route),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(_isLoading ? 'Generating...' : 'Generate Route'),
                          ),
                        ),
                      ),
                      if (_hasPolyline) ...[
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _clearRoute,
                                icon: const Icon(Icons.clear),
                                label: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('Clear'),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _addingWaypoint = !_addingWaypoint;
                                    if (_addingWaypoint) {
                                      _selectingFromLocation = false;
                                      _selectingToLocation = false;
                                    }
                                  });
                                },
                                icon: Icon(_addingWaypoint ? Icons.cancel : Icons.add_location_alt),
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(_addingWaypoint ? 'Cancel' : 'Add Stop'),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _addingWaypoint ? Colors.orange : Theme.of(context).primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
          
          // Map visualization section
          Expanded(
            flex: _hasPolyline ? 2 : 3,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildMapVisualization(),
              ),
            ),
          ),
          
          // Route details section - make it flexible and scrollable
          if (_hasPolyline)
            Flexible(
              flex: 1,
              child: SingleChildScrollView(
                child: _buildRouteDetails(),
              ),
            ),
        ],
        ),
      ),
    );
  }

  Widget _buildMapVisualization() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentMapCenter,
        initialZoom: 14.0,
        onTap: (tapPosition, point) => _onMapTap(point),
        maxZoom: 18.0,
        minZoom: 5.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.campusride',
        ),
        if (_routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePoints,
                strokeWidth: 6.0,
                color: Colors.black45,
              ),
              Polyline(
                points: _routePoints,
                strokeWidth: 4.0,
                color: AppColors.primary,
              ),
            ],
          ),
        
        MarkerLayer(
          markers: _buildStopMarkers(),
        ),
        
        if (_selectingFromLocation || _selectingToLocation || _addingWaypoint)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_searching,
                      size: 48,
                      color: _addingWaypoint 
                          ? Colors.orange 
                          : (_selectingFromLocation ? Colors.green : Colors.red),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _addingWaypoint
                          ? 'Tap on the map to add a stop'
                          : _selectingFromLocation 
                              ? 'Tap to select FROM location' 
                              : 'Tap to select TO location',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _cancelLocationSelection,
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<Marker> _buildStopMarkers() {
    return _stops.asMap().entries.map((entry) {
      final int index = entry.key;
      final Map<String, dynamic> stop = entry.value;
      final LatLng point = LatLng(stop['lat'], stop['lng']);

      if (index == 0) {
        return Marker(
          point: point,
          width: 60,
          height: 40,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                child: const Text('FROM', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
              const Icon(Icons.trip_origin, color: Colors.green, size: 24),
            ],
          ),
        );
      } else if (index == _stops.length - 1) {
        return Marker(
          point: point,
          width: 60,
          height: 40,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                child: const Text('TO', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
              const Icon(Icons.location_on, color: Colors.red, size: 24),
            ],
          ),
        );
      } else {
        return Marker(
          point: point,
          width: 40,
          height: 50,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  '$index',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const Icon(Icons.location_on, color: Colors.orange, size: 24),
            ],
          ),
        );
      }
    }).toList();
  }

  Widget _buildRouteDetails() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Route Details',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildDetailItem(
            icon: Icons.straighten,
            label: 'Distance',
            value: '${_distanceKm?.toStringAsFixed(1) ?? '0'} km',
            color: Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildDetailItem(
            icon: Icons.route,
            label: 'Stops',
            value: '${_stops.length} stops',
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.labelSmall.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _startLocationSelection(bool isFrom) {
    setState(() {
      if (isFrom) {
        _selectingFromLocation = true;
        _selectingToLocation = false;
        _addingWaypoint = false;
      } else {
        _selectingToLocation = true;
        _selectingFromLocation = false;
        _addingWaypoint = false;
      }
    });
  }

  void _onMapTap(LatLng point) {
    if (_selectingFromLocation) {
      setState(() {
        if (_stops.isEmpty) {
          _stops.add({'lat': point.latitude, 'lng': point.longitude});
        } else {
          _stops[0] = {'lat': point.latitude, 'lng': point.longitude};
        }
      });
      _updateLocationText(point, true);
      _cancelLocationSelection();
    } else if (_selectingToLocation) {
      if (_stops.isEmpty) return;
      setState(() {
        if (_stops.length == 1) {
          _stops.add({'lat': point.latitude, 'lng': point.longitude});
        } else {
          _stops[_stops.length - 1] = {'lat': point.latitude, 'lng': point.longitude};
        }
      });
      _updateLocationText(point, false);
      _cancelLocationSelection();
    } else if (_addingWaypoint) {
      _addStop(point);
    }
  }

  void _addStop(LatLng point) {
    if (_stops.length < 2) return;
    setState(() {
      _stops.insert(_stops.length - 1, {'lat': point.latitude, 'lng': point.longitude});
      _addingWaypoint = false;
    });
    _generateRoute();
  }

  void _cancelLocationSelection() {
    setState(() {
      _selectingFromLocation = false;
      _selectingToLocation = false;
      _addingWaypoint = false;
    });
  }

  void _showLocationSearch(bool isFrom) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => LocationSearchSheet(
        searchService: _searchService,
        onLocationSelected: (location, address) {
          if (isFrom) {
            setState(() {
              if (_stops.isEmpty) {
                _stops.add({'lat': location.latitude, 'lng': location.longitude});
              } else {
                _stops[0] = {'lat': location.latitude, 'lng': location.longitude};
              }
              _fromController.text = address;
            });
          } else {
            if (_stops.isEmpty) return;
            setState(() {
              if (_stops.length == 1) {
                _stops.add({'lat': location.latitude, 'lng': location.longitude});
              } else {
                _stops[_stops.length - 1] = {'lat': location.latitude, 'lng': location.longitude};
              }
              _toController.text = address;
            });
          }
          Navigator.pop(context);
          if (_stops.length >= 2) {
            _generateRoute();
          }
        },
      ),
    );
  }

  Future<void> _updateLocationText(LatLng location, bool isFrom) async {
    try {
      final address = await _searchService.reverseGeocode(location);
      if (mounted) {
        setState(() {
          if (isFrom) {
            _fromController.text = address;
          } else {
            _toController.text = address;
          }
        });
      }
    } catch (e) {
      print('Error with reverse geocoding: $e');
      // Fallback to coordinates
      final coordText = '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
      if (mounted) {
        setState(() {
          if (isFrom) {
            _fromController.text = coordText;
          } else {
            _toController.text = coordText;
          }
        });
      }
    }
  }

  bool _canGenerateRoute() {
    return _stops.length >= 2 && !_isLoading;
  }

  Future<void> _generateRoute() async {
    if (!_canGenerateRoute()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Convert stops to LatLng waypoints
      final waypoints = _stops.map((s) => LatLng(s['lat'], s['lng'])).toList();
      
      // Validate coordinates first
      if (!FallbackRoutingService.areCoordinatesValid(waypoints)) {
        _showError('Invalid coordinates provided. Please check your locations.');
        return;
      }
      
      Map<String, dynamic> routeData;
      bool usingFallback = false;
      
      // Try to use OpenRouteService first if API keys are valid
      if (_apiKeyValid) {
        try {
          final orsResponse = await _routingService.getDirections(waypoints: waypoints);
          routeData = _routingService.parseDirectionsResponse(orsResponse);
        } catch (e) {
          print('OpenRouteService failed: $e');
          // Fall back to direct routing
          routeData = FallbackRoutingService.generateDirectRoute(waypoints: waypoints);
          usingFallback = true;
          
          // Show a warning that we're using fallback routing
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('External routing service unavailable. Using direct route estimation.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        // Use fallback routing if API keys are invalid
        routeData = FallbackRoutingService.generateDirectRoute(waypoints: waypoints);
        usingFallback = true;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('API keys not configured. Using direct route estimation.'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 4),
          ),
        );
      }

      setState(() {
        _routePoints = routeData['route_points'];
        _distanceKm = routeData['total_distance'];
        _polylineData = routeData['polyline_data'];
        _hasPolyline = true;
        _stopDistances = routeData['segment_distances'];
        _totalTime = _formatDuration(routeData['total_duration']);
      });

      // Fit the map to show the entire route
      _fitBounds();
      
      // Show success message
      final routeType = usingFallback ? 'Direct route' : 'Optimized route';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$routeType generated successfully! Distance: ${_distanceKm?.toStringAsFixed(1)} km'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

    } catch (e) {
      print('Error generating route: $e');
      _showError('Failed to generate route: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _generatePolylineVisualization() {
    if (_polylineData == null) return;
    try {
      final List<dynamic> decoded = jsonDecode(_polylineData!);
      setState(() {
        _routePoints = decoded.map<LatLng>((coord) => LatLng(coord[1], coord[0])).toList();
      });
      _fitBounds();
    } catch (e) {
      print('Error decoding polyline: $e');
    }
  }

  void _fitBounds() {
    if (_routePoints.isEmpty) return;
    var bounds = LatLngBounds.fromPoints(_routePoints);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50.0),
      ),
    );
  }

  void _clearRoute() {
    setState(() {
      _routePoints = [];
      _stops = [];
      _hasPolyline = false;
      _polylineData = null;
      _distanceKm = null;
      _fromController.clear();
      _toController.clear();
    });
  }

  void _saveRoute() {
    if (!_hasPolyline || _stops.length < 2) {
      _showError('A complete route must be generated before saving.');
      return;
    }

    final routeData = {
      'id': widget.route['id'],
      'start_location': _fromController.text,
      'end_location': _toController.text,
      'polyline_data': _polylineData,
      'distance_km': _distanceKm,
      'waypoints': _stops,
    };

    Provider.of<RouteManagementService>(context, listen: false)
        .updateRoute(routeData)
        .then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Route saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      widget.onRouteSaved(routeData);
      Navigator.of(context).pop();
    }).catchError((error) {
      _showError('Failed to save route: $error');
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _formatDuration(num seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  Widget _buildRouteInfo() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_hasPolyline) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_totalTime != null && _distanceKm != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Total: ${_distanceKm!.toStringAsFixed(1)} km • $_totalTime',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(height: 8),
          if (_stops.length > 2)
            Container(
              height: 120,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                onReorder: _reorderStops,
                itemCount: _stops.length - 2, // Exclude start and end points
                itemBuilder: (context, index) {
                  final actualIndex = index + 1; // Skip the start point
                  return Card(
                    key: ValueKey(_stops[actualIndex]),
                    child: Container(
                      width: 150,
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Stop ${index + 1}'),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () => _removeStop(actualIndex),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          if (actualIndex < _stopDistances.length)
                            Text(
                              'Next: ${_stopDistances[actualIndex]}',
                              style: const TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class LocationSearchSheet extends StatefulWidget {
  final LocationIQService searchService;
  final Function(LatLng location, String address) onLocationSelected;

  const LocationSearchSheet({
    Key? key,
    required this.searchService,
    required this.onLocationSelected,
  }) : super(key: key);

  @override
  State<LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<LocationSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    // Debounce the search to avoid too many API calls
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      setState(() {
        _isLoading = true;
      });

      try {
        final results = await widget.searchService.searchPlaces(query.trim());
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _searchResults = [];
            _isLoading = false;
          });
        }
        // Don't show error in UI for search, just log it
        print('Search error: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Search field
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search for a location',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: _performSearch,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              // Loading or results
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final result = _searchResults[index];
                          return ListTile(
                            leading: const Icon(Icons.location_on),
                            title: Text(
                              result['display_name'],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${result['lat'].toStringAsFixed(4)}, ${result['lng'].toStringAsFixed(4)}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            onTap: () {
                              widget.onLocationSelected(
                                LatLng(result['lat'], result['lng']),
                                result['display_name'],
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}