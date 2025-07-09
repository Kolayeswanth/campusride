import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import '../../../core/theme/theme.dart';
import '../../../core/services/route_management_service.dart';
import '../../../core/services/ola_maps_service.dart';
import '../../../core/config/api_keys.dart';
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
  MapController? _mapController;
  
  // Services
  final OlaMapsService _routeService = OlaMapsService();
  
  // Location data
  LatLng _currentMapCenter = const LatLng(28.7041, 77.1025); // Default to Delhi
  
  // Route data
  List<LatLng> _routePoints = [];
  List<Map<String, dynamic>> _stops = [];
  List<Polyline> _polylines = [];
  List<Marker> _markers = [];
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
  String _errorMessage = '';

  // Location search state
  List<Map<String, dynamic>> _fromLocationSuggestions = [];
  List<Map<String, dynamic>> _toLocationSuggestions = [];
  bool _showingFromSuggestions = false;
  bool _showingToSuggestions = false;

  LatLng? get _fromLocation => _stops.isNotEmpty ? LatLng(_stops.first['lat'], _stops.first['lng']) : null;
  LatLng? get _toLocation => _stops.length > 1 ? LatLng(_stops.last['lat'], _stops.last['lng']) : null;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
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
    // Use Ola Maps API key validation
    setState(() {
      _apiKeyValid = ApiKeys.isValidOlaMapsKey();
    });
    
    if (!_apiKeyValid) {
      _showError('Ola Maps API key is not configured properly');
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
      body: GestureDetector(
        onTap: _dismissSuggestions,
        child: SafeArea(
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
                // From location input with suggestions
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: EdgeInsets.only(bottom: _showingFromSuggestions ? 0 : 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade300),
                        color: Colors.green.shade50,
                      ),
                      child: TextFormField(
                        controller: _fromController,
                        decoration: InputDecoration(
                          labelText: 'From',
                          hintText: 'Search for starting location',
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
                        onChanged: (text) => _onLocationTextChanged(text, true),
                        onTap: () => _showLocationSearch(true),
                        readOnly: false,
                      ),
                    ),
                    if (_showingFromSuggestions)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade300),
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _fromLocationSuggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = _fromLocationSuggestions[index];
                            return ListTile(
                              leading: const Icon(Icons.location_on, color: Colors.green),
                              title: Text(
                                suggestion['name'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text(
                                suggestion['address'] ?? '',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              onTap: () => _selectLocationSuggestion(suggestion, true),
                              dense: true,
                            );
                          },
                        ),
                      ),
                  ],
                ),
                
                // To location input with suggestions
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: EdgeInsets.only(bottom: _showingToSuggestions ? 0 : 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade300),
                        color: Colors.red.shade50,
                      ),
                      child: TextFormField(
                        controller: _toController,
                        decoration: InputDecoration(
                          labelText: 'To',
                          hintText: 'Search for destination',
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
                        onChanged: (text) => _onLocationTextChanged(text, false),
                        onTap: () => _showLocationSearch(false),
                        readOnly: false,
                      ),
                    ),
                    if (_showingToSuggestions)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade300),
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _toLocationSuggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = _toLocationSuggestions[index];
                            return ListTile(
                              leading: const Icon(Icons.location_on, color: Colors.red),
                              title: Text(
                                suggestion['name'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text(
                                suggestion['address'] ?? '',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              onTap: () => _selectLocationSuggestion(suggestion, false),
                              dense: true,
                            );
                          },
                        ),
                      ),
                  ],
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
      ),
    );
  }

  Widget _buildMapVisualization() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentMapCenter,
            initialZoom: 14.0,
            onTap: (tapPosition, point) => _onMapTap(point),
          ),
          children: [
            TileLayer(
              urlTemplate: ApiKeys.mapLibreStyleUrl.contains('maptiler')
                  ? 'https://api.maptiler.com/maps/streets/256/{z}/{x}/{y}.png?key=${ApiKeys.mapTilerApiKey}'
                  : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.campusride',
            ),
            if (_polylines.isNotEmpty)
              PolylineLayer(
                polylines: _polylines,
              ),
            if (_markers.isNotEmpty)
              MarkerLayer(
                markers: _markers,
              ),
          ],
        ),
        
        // Loading indicator
        if (_isLoading)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        
        // Error message
        if (_errorMessage.isNotEmpty)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              color: Colors.red[100],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _errorMessage,
                  style: TextStyle(color: Colors.red[800]),
                ),
              ),
            ),
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
          width: 40,
          height: 40,
          child: const Icon(
            Icons.trip_origin,
            color: Colors.green,
            size: 40,
          ),
        );
      } else if (index == _stops.length - 1) {
        return Marker(
          point: point,
          width: 40,
          height: 40,
          child: const Icon(
            Icons.location_on,
            color: Colors.red,
            size: 40,
          ),
        );
      } else {
        return Marker(
          point: point,
          width: 40,
          height: 40,
          child: const Icon(
            Icons.location_on,
            color: Colors.orange,
            size: 40,
          ),
        );
      }
    }).toList();
  }

  void _updateMarkersAndPolylines() {
    setState(() {
      _markers = _buildStopMarkers();
      
      if (_routePoints.isNotEmpty) {
        _polylines = [
          Polyline(
            points: _routePoints,
            color: AppColors.primary,
            strokeWidth: 4,
          ),
        ];
      } else {
        _polylines.clear();
      }
    });
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
    // Clear previous suggestions
    setState(() {
      if (isFrom) {
        _showingFromSuggestions = false;
        _fromLocationSuggestions.clear();
      } else {
        _showingToSuggestions = false;
        _toLocationSuggestions.clear();
      }
    });
  }

  Future<void> _onLocationTextChanged(String text, bool isFrom) async {
    if (text.trim().isEmpty) {
      setState(() {
        if (isFrom) {
          _fromLocationSuggestions.clear();
          _showingFromSuggestions = false;
        } else {
          _toLocationSuggestions.clear();
          _showingToSuggestions = false;
        }
      });
      return;
    }

    try {
      // Use current map center as bias for more relevant results
      final suggestions = await _routeService.searchLocations(
        text,
        biasLocation: _currentMapCenter,
      );

      setState(() {
        if (isFrom) {
          _fromLocationSuggestions = suggestions;
          _showingFromSuggestions = suggestions.isNotEmpty;
        } else {
          _toLocationSuggestions = suggestions;
          _showingToSuggestions = suggestions.isNotEmpty;
        }
      });
    } catch (e) {
      print('Location search failed: $e');
    }
  }

  void _selectLocationSuggestion(Map<String, dynamic> suggestion, bool isFrom) {
    final location = LatLng(suggestion['latitude'], suggestion['longitude']);
    
    setState(() {
      if (isFrom) {
        _fromController.text = suggestion['name'];
        _fromLocationSuggestions.clear();
        _showingFromSuggestions = false;
        // Update the first stop
        if (_stops.isNotEmpty) {
          _stops[0] = {
            'lat': location.latitude,
            'lng': location.longitude,
            'name': suggestion['name'],
          };
        } else {
          _stops.add({
            'lat': location.latitude,
            'lng': location.longitude,
            'name': suggestion['name'],
          });
        }
      } else {
        _toController.text = suggestion['name'];
        _toLocationSuggestions.clear();
        _showingToSuggestions = false;
        // Update the last stop
        if (_stops.length >= 2) {
          _stops.last = {
            'lat': location.latitude,
            'lng': location.longitude,
            'name': suggestion['name'],
          };
        } else if (_stops.length == 1) {
          _stops.add({
            'lat': location.latitude,
            'lng': location.longitude,
            'name': suggestion['name'],
          });
        } else {
          // If no stops exist, add both from and to
          _stops.addAll([
            {
              'lat': _currentMapCenter.latitude,
              'lng': _currentMapCenter.longitude,
              'name': 'Start',
            },
            {
              'lat': location.latitude,
              'lng': location.longitude,
              'name': suggestion['name'],
            },
          ]);
        }
      }
      
      _updateMarkersAndPolylines();
    });
  }

  Future<void> _updateLocationText(LatLng location, bool isFrom) async {
    // For now, just use coordinates as the text
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

  bool _canGenerateRoute() {
    return _stops.length >= 2 && !_isLoading;
  }

  Future<void> _generateRoute() async {
    if (!_canGenerateRoute()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Convert stops to LatLng waypoints
      final waypoints = _stops.map((s) => LatLng(s['lat'], s['lng'])).toList();
      
      // Validate coordinates first
      if (!_areCoordinatesValid(waypoints)) {
        _showError('Invalid coordinates provided. Please check your locations.');
        return;
      }
      
      Map<String, dynamic> routeData;
      bool usingFallback = false;
      
      // Try to use Ola Maps first if API keys are valid
      if (_apiKeyValid) {
        try {
          final route = await _fetchRoute(waypoints.first, waypoints.last);
          if (route.isNotEmpty) {
            routeData = _createRouteData(route, waypoints);
          } else {
            throw Exception('No route found');
          }
        } catch (e) {
          print('Ola Maps failed: $e');
          // Fall back to direct routing
          routeData = _generateDirectRoute(waypoints);
          usingFallback = true;
          
          // Show a more informative warning
          final errorMsg = e.toString().toLowerCase();
          String userMessage;
          if (errorMsg.contains('no route found')) {
            userMessage = 'Could not find a road route between the selected locations. Using direct path estimation.';
          } else if (errorMsg.contains('timeout') || errorMsg.contains('network')) {
            userMessage = 'Network connection issue. Using offline route estimation.';
          } else if (errorMsg.contains('api key') || errorMsg.contains('access denied')) {
            userMessage = 'External routing service unavailable. Using direct route estimation.';
          } else {
            userMessage = 'External routing service unavailable. Using direct route estimation.';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(userMessage),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }
      } else {
        // Use fallback routing if API keys are invalid
        routeData = _generateDirectRoute(waypoints);
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

      // Update markers and polylines
      _updateMarkersAndPolylines();
      
      // Fit the map to show the entire route
      _fitBounds();
      
      // Show success message with route type indication
      String routeType;
      Color messageColor;
      
      if (usingFallback || routeData.containsKey('is_fallback')) {
        routeType = 'Direct route (estimated)';
        messageColor = Colors.orange;
      } else {
        // Check if this might be a straight-line route by examining segment count
        final segments = routeData['segment_distances'] as List<String>? ?? [];
        if (segments.isEmpty || _routePoints.length < 5) {
          routeType = 'Direct route (estimated)';
          messageColor = Colors.orange;
        } else {
          routeType = 'Optimized road route';
          messageColor = Colors.green;
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$routeType generated! Distance: ${_distanceKm?.toStringAsFixed(1)} km'),
          backgroundColor: messageColor,
          duration: Duration(seconds: 3),
          action: routeType.contains('Direct') ? SnackBarAction(
            label: 'Info',
            textColor: Colors.white,
            onPressed: () {
              _showRouteTypeInfo();
            },
          ) : null,
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

  bool _areCoordinatesValid(List<LatLng> waypoints) {
    for (final point in waypoints) {
      if (point.latitude < -90 || point.latitude > 90 || 
          point.longitude < -180 || point.longitude > 180) {
        return false;
      }
    }
    return true;
  }

  Future<List<LatLng>> _fetchRoute(LatLng from, LatLng to) async {
    try {
      final response = await _routeService.getDirections(
        waypoints: [from, to],
        mode: 'DRIVING',
      );
      
      final parsedResponse = _routeService.parseDirectionsResponse(response);
      final routePoints = parsedResponse['route_points'] as List<LatLng>?;
      
      if (routePoints != null && routePoints.isNotEmpty) {
        print('Ola Maps route found with ${routePoints.length} points');
        return routePoints;
      } else {
        throw Exception('No route points found in response');
      }
    } catch (e) {
      print('Ola Maps route request failed: $e');
      // Create a simple straight-line route as fallback
      return [from, to];
    }
  }

  Map<String, dynamic> _createRouteData(List<LatLng> route, List<LatLng> waypoints) {
    // Calculate distance
    double totalDistance = 0.0;
    for (int i = 0; i < route.length - 1; i++) {
      totalDistance += _calculateDistance(route[i], route[i + 1]);
    }

    return {
      'route_points': route,
      'total_distance': totalDistance,
      'total_duration': totalDistance * 60, // Rough estimate: 1 km per minute
      'polyline_data': json.encode(route.map((p) => [p.longitude, p.latitude]).toList()),
      'segment_distances': ['${totalDistance.toStringAsFixed(1)} km'],
    };
  }

  Map<String, dynamic> _generateDirectRoute(List<LatLng> waypoints) {
    // Calculate approximate distance
    double totalDistance = 0.0;
    for (int i = 0; i < waypoints.length - 1; i++) {
      totalDistance += _calculateDistance(waypoints[i], waypoints[i + 1]);
    }

    return {
      'route_points': waypoints,
      'total_distance': totalDistance,
      'total_duration': totalDistance * 60, // Rough estimate: 1 km per minute
      'polyline_data': json.encode(waypoints.map((p) => [p.longitude, p.latitude]).toList()),
      'segment_distances': ['${totalDistance.toStringAsFixed(1)} km'],
      'is_fallback': true,
    };
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final double lat1Rad = point1.latitude * (math.pi / 180);
    final double lat2Rad = point2.latitude * (math.pi / 180);
    final double deltaLatRad = (point2.latitude - point1.latitude) * (math.pi / 180);
    final double deltaLngRad = (point2.longitude - point1.longitude) * (math.pi / 180);

    final double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLngRad / 2) * math.sin(deltaLngRad / 2);
    final double c = 2 * math.asin(math.sqrt(a));

    return earthRadius * c;
  }

  void _showRouteTypeInfo() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Route Information'),
          content: const Text(
            'This is a direct route estimate. The routing service couldn\'t find an optimized road route for these coordinates, so a straight-line route has been calculated instead.\n\n'
            'This may happen when:\n'
            '• Coordinates are not near accessible roads\n'
            '• The routing service doesn\'t have coverage for this area\n'
            '• Network connectivity issues\n\n'
            'The distance and duration are rough estimates based on straight-line distance.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
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
    if (_routePoints.isEmpty || _mapController == null) return;
    
    double minLat = _routePoints.first.latitude;
    double maxLat = _routePoints.first.latitude;
    double minLng = _routePoints.first.longitude;
    double maxLng = _routePoints.first.longitude;
    
    for (final point in _routePoints) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }
    
    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );
    
    _mapController!.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
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

  void _dismissSuggestions() {
    setState(() {
      _showingFromSuggestions = false;
      _showingToSuggestions = false;
      _fromLocationSuggestions.clear();
      _toLocationSuggestions.clear();
    });
  }
}