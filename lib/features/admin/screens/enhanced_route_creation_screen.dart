import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/theme.dart';
import '../../../core/services/ola_maps_service.dart';
import '../../../core/config/api_keys.dart';
import '../models/college.dart';
import '../widgets/location_search_field.dart';

/// Helper class to represent route data
class _RouteData {
  final List<LatLng> coordinates;
  final double distance;
  final double duration;

  _RouteData({
    required this.coordinates,
    required this.distance,
    required this.duration,
  });
  
  bool get isSuccess => coordinates.isNotEmpty;
}

class EnhancedRouteCreationScreen extends StatefulWidget {
  final College college;
  final Map<String, dynamic>? existingRoute;
  final Function(Map<String, dynamic>) onRouteSaved;

  const EnhancedRouteCreationScreen({
    Key? key,
    required this.college,
    required this.onRouteSaved,
    this.existingRoute,
  }) : super(key: key);

  @override
  State<EnhancedRouteCreationScreen> createState() => _EnhancedRouteCreationScreenState();
}

class _EnhancedRouteCreationScreenState extends State<EnhancedRouteCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _busNumberController = TextEditingController();
  final _routeNameController = TextEditingController();
  final MapController _mapController = MapController();
  final OlaMapsService _routeService = OlaMapsService();

  // Location data
  String? _fromLocationName;
  String? _toLocationName;
  LatLng? _fromLocationCoords;
  LatLng? _toLocationCoords;

  // Map data
  List<LatLng> _routePoints = [];
  List<Polyline> _polylines = [];
  List<Marker> _markers = [];
  List<Marker> _villageMarkers = [];  // New: village markers along the route
  bool _isLoadingRoute = false;
  bool _isSavingRoute = false;  // New state variable for save operation
  bool _isLoadingVillages = false;  // New: loading state for villages
  double? _routeDistance;
  double? _routeDuration;
  String? _errorMessage;

  // Default map center (India)
  LatLng _mapCenter = const LatLng(20.5937, 78.9629);

  @override
  void initState() {
    super.initState();
    _initializeExistingRoute();
  }

  @override
  void dispose() {
    _busNumberController.dispose();
    _routeNameController.dispose();
    super.dispose();
  }

  void _initializeExistingRoute() {
    if (widget.existingRoute != null) {
      final route = widget.existingRoute!;
      // Use name field for the bus number in the new schema
      _busNumberController.text = route['name'] ?? '';
      _routeNameController.text = route['name'] ?? ''; // Same as bus number in new schema
      
      // Handle the new JSONB format for start_location and end_location
      if (route['start_location'] is Map) {
        final startLocation = Map<String, dynamic>.from(route['start_location'] as Map);
        _fromLocationName = startLocation['name'] as String? ?? '';
        
        if (startLocation['latitude'] != null && startLocation['longitude'] != null) {
          _fromLocationCoords = LatLng(
            (startLocation['latitude'] as num).toDouble(),
            (startLocation['longitude'] as num).toDouble(),
          );
        }
      }
      
      // Handle the new JSONB format for end_location
      if (route['end_location'] is Map) {
        final endLocation = Map<String, dynamic>.from(route['end_location'] as Map);
        _toLocationName = endLocation['name'] as String? ?? '';
        
        if (endLocation['latitude'] != null && endLocation['longitude'] != null) {
          _toLocationCoords = LatLng(
            (endLocation['latitude'] as num).toDouble(),
            (endLocation['longitude'] as num).toDouble(),
          );
        }
      }

      // Load existing route if coordinates are available
      if (_fromLocationCoords != null && _toLocationCoords != null) {
        _generateRoute();
      }
    }
  }

  void _onFromLocationSelected(String locationName, LatLng coordinates) {
    setState(() {
      _fromLocationName = locationName;
      _fromLocationCoords = coordinates;
      _errorMessage = null;
    });
    
    _updateMarkers();
    _centerMapOnLocations();
    
    // Generate route if both locations are selected
    if (_toLocationCoords != null) {
      _generateRoute();
    }
  }

  void _onToLocationSelected(String locationName, LatLng coordinates) {
    setState(() {
      _toLocationName = locationName;
      _toLocationCoords = coordinates;
      _errorMessage = null;
    });
    
    _updateMarkers();
    _centerMapOnLocations();
    
    // Generate route if both locations are selected
    if (_fromLocationCoords != null) {
      _generateRoute();
    }
  }

  void _updateMarkers() {
    setState(() {
      _markers.clear();
      
      if (_fromLocationCoords != null) {
        _markers.add(
          Marker(
            point: _fromLocationCoords!,
            width: 80,
            height: 80,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'From',
                    style: AppTypography.labelSmall.copyWith(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ),
                const Icon(
                  Icons.location_on,
                  color: Colors.green,
                  size: 30,
                ),
              ],
            ),
          ),
        );
      }
      
      if (_toLocationCoords != null) {
        _markers.add(
          Marker(
            point: _toLocationCoords!,
            width: 80,
            height: 80,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'To',
                    style: AppTypography.labelSmall.copyWith(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ),
                const Icon(
                  Icons.flag,
                  color: Colors.red,
                  size: 30,
                ),
              ],
            ),
          ),
        );
      }
    });
  }

  void _centerMapOnLocations() {
    if (_fromLocationCoords != null && _toLocationCoords != null) {
      // Calculate the center point between from and to
      final centerLat = (_fromLocationCoords!.latitude + _toLocationCoords!.latitude) / 2;
      final centerLng = (_fromLocationCoords!.longitude + _toLocationCoords!.longitude) / 2;
      
      // Calculate distance between points to determine zoom level
      const double earthRadius = 6371; // in km
      final double lat1 = _fromLocationCoords!.latitude * math.pi / 180;
      final double lat2 = _toLocationCoords!.latitude * math.pi / 180;
      final double lng1 = _fromLocationCoords!.longitude * math.pi / 180;
      final double lng2 = _toLocationCoords!.longitude * math.pi / 180;
      
      final double dLat = lat2 - lat1;
      final double dLng = lng2 - lng1;
      
      final double a = math.sin(dLat/2) * math.sin(dLat/2) +
                      math.cos(lat1) * math.cos(lat2) * 
                      math.sin(dLng/2) * math.sin(dLng/2);
      final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a));
      final double distance = earthRadius * c;
      
      // Determine zoom level based on distance
      double zoom = 14.0; // Default zoom level
      if (distance > 50) zoom = 8.0;
      else if (distance > 20) zoom = 9.0;
      else if (distance > 10) zoom = 10.0;
      else if (distance > 5) zoom = 11.0;
      else if (distance > 2) zoom = 12.0;
      else if (distance > 1) zoom = 13.0;
      
      _mapCenter = LatLng(centerLat, centerLng);
      // Use the calculated zoom level
      _mapController.moveAndRotate(_mapCenter, zoom, 0);
    } else if (_fromLocationCoords != null) {
      _mapCenter = _fromLocationCoords!;
      _mapController.moveAndRotate(_mapCenter, 14, 0);
    } else if (_toLocationCoords != null) {
      _mapCenter = _toLocationCoords!;
      _mapController.moveAndRotate(_mapCenter, 14, 0);
    }
  }

  Future<void> _generateRoute() async {
    // Only proceed if both locations are selected
    if (_fromLocationCoords == null || _toLocationCoords == null) {
      setState(() {
        _errorMessage = 'Both start and end locations are required to generate a route';
      });
      return;
    }
    
    setState(() {
      _isLoadingRoute = true;
      _errorMessage = null;
    });
    
    try {
      // Use getDirections instead of getRouteData and pass waypoints as a list
      final result = await _routeService.getDirections(
        waypoints: [_fromLocationCoords!, _toLocationCoords!],
        mode: 'DRIVING',
      );
      
      // Process the directions response to extract route data
      final routeData = _extractRouteDataFromResponse(result);
      
      if (routeData != null && routeData.coordinates.isNotEmpty) {
        setState(() {
          _routePoints = routeData.coordinates;
          
          // Create a styled polyline
          _polylines = [
            Polyline(
              points: _routePoints,
              color: AppColors.primary,
              strokeWidth: 5.0,
            ),
          ];
          
          _routeDistance = routeData.distance;
          _routeDuration = routeData.duration;
        });
        
        // Ensure the map is properly centered on the route with proper bounds
        _fitMapToRoute();
        
        // Load villages along the route
        _loadVillagesAlongRoute();
      } else {
        setState(() {
          _errorMessage = 'Failed to generate route. Please try different locations.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoadingRoute = false;
      });
    }
  }

  void _fitMapToRoute() {
    if (_routePoints.isNotEmpty) {
      // Calculate bounds for all route points
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
      
      // Add some padding to the bounds (about 10% on each side)
      final latPadding = (maxLat - minLat) * 0.1;
      final lngPadding = (maxLng - minLng) * 0.1;
      
      final bounds = LatLngBounds(
        LatLng(minLat - latPadding, minLng - lngPadding),
        LatLng(maxLat + latPadding, maxLng + lngPadding),
      );
      
      // Fit the map to show the bounds
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(20),
        ),
      );
    } else {
      // Fallback to center between markers if no route points
      _centerMapOnLocations();
    }
  }

  /// Extract route data from the OlaMaps directions response
  _RouteData? _extractRouteDataFromResponse(Map<String, dynamic> response) {
    try {
      // Extract route information from the response
      final routes = response['routes'] as List?;
      
      if (routes == null || routes.isEmpty) {
        debugPrint('No routes found in the response');
        return null;
      }
      
      final route = routes[0] as Map<String, dynamic>;
      
      // Extract distance and duration from legs
      double totalDistance = 0.0;
      double totalDuration = 0.0;
      List<LatLng> coordinates = [];
      
      // First, try to use the overview_polyline for the best route visualization
      final overviewPolyline = route['overview_polyline'] as String?;
      if (overviewPolyline != null && overviewPolyline.isNotEmpty) {
        debugPrint('Using overview_polyline for route visualization');
        coordinates = _decodePolyline(overviewPolyline);
      }
      
      final legs = route['legs'] as List?;
      
      if (legs != null && legs.isNotEmpty) {
        for (final leg in legs) {
          if (leg is Map<String, dynamic>) {
            // Extract distance (in meters, convert to km)
            if (leg['distance'] != null && leg['distance'] is num) {
              totalDistance += (leg['distance'] as num) / 1000.0;
            }
            
            // Extract duration (in seconds)
            if (leg['duration'] != null && leg['duration'] is num) {
              totalDuration += (leg['duration'] as num).toDouble();
            }
            
            // If we don't have overview polyline, fallback to step-by-step polylines
            if (coordinates.isEmpty) {
              final steps = leg['steps'] as List?;
              if (steps != null) {
                for (final step in steps) {
                  if (step is Map<String, dynamic>) {
                    // Try to use step polyline first
                    final stepPolyline = step['polyline'] as String?;
                    if (stepPolyline != null && stepPolyline.isNotEmpty) {
                      coordinates.addAll(_decodePolyline(stepPolyline));
                    } else {
                      // Fallback to start/end locations if no polyline
                      final startLoc = step['start_location'] as Map<String, dynamic>?;
                      if (startLoc != null && 
                          startLoc['lat'] != null && 
                          startLoc['lng'] != null) {
                        final lat = (startLoc['lat'] as num).toDouble();
                        final lng = (startLoc['lng'] as num).toDouble();
                        coordinates.add(LatLng(lat, lng));
                      }
                      
                      final endLoc = step['end_location'] as Map<String, dynamic>?;
                      if (endLoc != null && 
                          endLoc['lat'] != null && 
                          endLoc['lng'] != null) {
                        final lat = (endLoc['lat'] as num).toDouble();
                        final lng = (endLoc['lng'] as num).toDouble();
                        coordinates.add(LatLng(lat, lng));
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
      
      // Final fallback: create a simple line between start and end
      if (coordinates.isEmpty) {
        coordinates = [_fromLocationCoords!, _toLocationCoords!];
      }
      
      // Convert duration from seconds to minutes for display
      final durationMinutes = totalDistance > 0 ? totalDuration / 60.0 : 0.0;
      
      debugPrint('Extracted route data - Distance: ${totalDistance.toStringAsFixed(2)} km, Duration: ${durationMinutes.toStringAsFixed(1)} min, Coordinates: ${coordinates.length} points');
      
      return _RouteData(
        coordinates: coordinates,
        distance: totalDistance,
        duration: durationMinutes, // Return in minutes for consistency
      );
    } catch (e) {
      debugPrint('Error extracting route data: $e');
      return null;
    }
  }

  /// Decode a polyline string into a list of LatLng coordinates
  /// Uses the Google Polyline Algorithm (also used by Ola Maps)
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  /// Load villages and localities along the route
  Future<void> _loadVillagesAlongRoute() async {
    if (_routePoints.isEmpty) return;
    
    setState(() {
      _isLoadingVillages = true;
      _villageMarkers.clear();
    });

    try {
      // Sample points along the route (every 20th point to avoid too many API calls)
      List<LatLng> samplePoints = [];
      for (int i = 0; i < _routePoints.length; i += 20) {
        samplePoints.add(_routePoints[i]);
      }
      
      // Limit to maximum 10 points to avoid rate limiting
      if (samplePoints.length > 10) {
        final step = samplePoints.length ~/ 10;
        samplePoints = samplePoints.where((point) => 
          samplePoints.indexOf(point) % step == 0).toList();
      }

      List<Marker> villageMarkers = [];
      Set<String> addedPlaces = {}; // To avoid duplicate village names

      for (LatLng point in samplePoints) {
        try {
          // Use simple reverse geocoding to get place name
          final placeName = await _routeService.reverseGeocode(point);
          
          if (placeName != null && placeName.isNotEmpty) {
            // Extract village/locality name from the address
            String? villageName = _extractSimpleVillageName(placeName);
            
            if (villageName != null && 
                villageName.isNotEmpty && 
                !addedPlaces.contains(villageName) &&
                villageName.length < 20) { // Avoid very long names
              
              addedPlaces.add(villageName);
              
              villageMarkers.add(
                Marker(
                  point: point,
                  width: 100,
                  height: 35,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_city,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            villageName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
          }
          
          // Small delay to avoid rate limiting
          await Future.delayed(const Duration(milliseconds: 300));
        } catch (e) {
          debugPrint('Error getting place for point ${point.latitude}, ${point.longitude}: $e');
        }
      }

      setState(() {
        _villageMarkers = villageMarkers;
        _isLoadingVillages = false;
      });
      
      debugPrint('Loaded ${villageMarkers.length} village markers along the route');
    } catch (e) {
      debugPrint('Error loading villages along route: $e');
      setState(() {
        _isLoadingVillages = false;
      });
    }
  }

  /// Extract village/locality name from formatted address string
  String? _extractSimpleVillageName(String formattedAddress) {
    try {
      // Split by comma and try to find a reasonable place name
      List<String> parts = formattedAddress.split(',');
      
      for (String part in parts) {
        String trimmed = part.trim();
        
        // Skip if it's just numbers (like pin codes)
        if (RegExp(r'^\d+$').hasMatch(trimmed)) continue;
        
        // Skip if it contains typical non-place patterns
        if (trimmed.toLowerCase().contains('road') || 
            trimmed.toLowerCase().contains('highway') ||
            trimmed.toLowerCase().contains('nh ') ||
            trimmed.toLowerCase().contains('state') ||
            trimmed.toLowerCase().contains('unnamed') ||
            trimmed.length < 3) continue;
        
        // Check if it's a reasonable place name
        if (trimmed.length >= 3 && trimmed.length <= 18) {
          // Remove common prefixes/suffixes
          trimmed = trimmed.replaceAll(RegExp(r'\b(village|town|city|tehsil|block|district)\b', caseSensitive: false), '').trim();
          
          if (trimmed.isNotEmpty && trimmed.length >= 3) {
            return trimmed;
          }
        }
      }
    } catch (e) {
      debugPrint('Error extracting village name: $e');
    }
    return null;
  }

  /// Extract village/locality name from reverse geocode result
  String? _extractVillageName(Map<String, dynamic> result) {
    try {
      // Try to get from address components first
      if (result['address_components'] != null) {
        final components = result['address_components'] as List;
        
        // Look for locality, sublocality, or administrative_area_level_3
        for (var component in components) {
          if (component is Map<String, dynamic>) {
            final types = component['types'] as List?;
            if (types != null) {
              if (types.contains('locality') || 
                  types.contains('sublocality') ||
                  types.contains('administrative_area_level_3') ||
                  types.contains('neighborhood')) {
                return component['long_name'] as String?;
              }
            }
          }
        }
      }
      
      // Fallback: try to extract from formatted address
      if (result['formatted_address'] != null) {
        String address = result['formatted_address'] as String;
        // Split by comma and try to find a reasonable place name
        List<String> parts = address.split(',');
        if (parts.length >= 2) {
          String candidate = parts[1].trim();
          // Check if it looks like a place name (not a pin code or state)
          if (!RegExp(r'^\d+$').hasMatch(candidate) && 
              candidate.length > 2 && 
              candidate.length < 25) {
            return candidate;
          }
        }
      }
    } catch (e) {
      debugPrint('Error extracting village name: $e');
    }
    return null;
  }

  Map<String, dynamic> _prepareRouteDataForDatabase(Map<String, dynamic> routeData) {
    // Clone the data to avoid modifying the original
    final data = Map<String, dynamic>.from(routeData);
    
    // Remove any non-database fields that might have been added for UI purposes
    data.remove('polyline_points');

    // Handle special fields that need transformation for the database
    if (data['polyline_data'] != null) {
      data['polyline_data'] = data['polyline_data'].toString();
    }
    
    // For UUID columns, ensure they're properly formatted
    if (data.containsKey('id') && data['id'] == null) {
      data.remove('id');  // Let Supabase generate the ID
    }
    
    return data;
  }

  Future<bool> _retryWithoutDescription(Map<String, dynamic> data) async {
    try {
      final withoutDescription = Map<String, dynamic>.from(data);
      withoutDescription.remove('description');  // Remove this field that's causing issues
      
      final supabase = Supabase.instance.client;
      
      if (widget.existingRoute != null) {
        await supabase.from('bus_routes')
            .update(withoutDescription)
            .eq('id', widget.existingRoute!['id'])
            .select();
        
        debugPrint('Route updated with fallback: ${widget.existingRoute!['id']}');
        return true;
      } else {
        final newResponse = await supabase.from('bus_routes')
            .insert(withoutDescription)
            .select();
        
        if (newResponse.isNotEmpty) {
          debugPrint('Route created with fallback: ${newResponse[0]['id']}');
        } else {
          debugPrint('Route created with fallback but no response data returned');
        }
        return true;
      }
    } catch (e) {
      debugPrint('ERROR EVEN WITH FALLBACK: $e');
      return false;
    }
  }

  void _saveRoute() async {
    // Validate the form
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    
    // Check if locations are selected
    if (_fromLocationCoords == null || _toLocationCoords == null) {
      setState(() {
        _errorMessage = 'Both start and end locations must be selected';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSavingRoute = true;
      _errorMessage = null;
    });
    
    // Bus number is used as the route name in the new schema
    final busNumber = _busNumberController.text.trim();
    
    // Changed to match the new schema with JSONB for location fields
    final routeData = {
      'name': busNumber,
      'college_code': widget.college.code,
      'start_location': {
        'name': _fromLocationName,
        'latitude': _fromLocationCoords!.latitude,
        'longitude': _fromLocationCoords!.longitude,
      },
      'end_location': {
        'name': _toLocationName,
        'latitude': _toLocationCoords!.latitude,
        'longitude': _toLocationCoords!.longitude,
      },
      'is_active': widget.existingRoute?['is_active'] ?? false,  // Use existing active status or false
    };
    
    // Add polyline data if available
    if (_routePoints.isNotEmpty) {
      routeData['polyline_data'] = _routePoints.map((point) => 
          '${point.latitude},${point.longitude}').join(';');
      
      routeData['distance_km'] = _routeDistance;
      routeData['estimated_duration_minutes'] = _routeDuration!.round();
    }
    
    // If editing an existing route, include its ID
    if (widget.existingRoute != null) {
      routeData['id'] = widget.existingRoute!['id'];
    }

    // Convert data to match the database schema exactly
    final databaseReadyData = _prepareRouteDataForDatabase(routeData);
    
    // Save directly to Supabase with the correct schema
    final supabase = Supabase.instance.client;
    bool success = false;
    
    try {
      // Detailed debug output to help diagnose issues
      debugPrint('Saving route with schema:');
      databaseReadyData.forEach((key, value) => debugPrint(' - $key: ${value.runtimeType} = $value'));
      
      if (widget.existingRoute != null) {
        // Update existing route
        final response = await supabase.from('routes')
            .update(databaseReadyData)
            .eq('id', widget.existingRoute!['id'])
            .select(); // Add select() to get the updated record
        
        debugPrint('Route updated successfully: ${widget.existingRoute!['id']}');
        debugPrint('Updated data: $response');
        success = true;
      } else {
        // Insert new route
        final response = await supabase.from('routes')
            .insert(databaseReadyData)
            .select();
        
        if (response.isNotEmpty) {
          debugPrint('Route created successfully: ${response[0]['id']}');
          debugPrint('Inserted data: $response');
          success = true;
        } else {
          debugPrint('Route created but no response data returned');
          success = true;
        }
      }
    } catch (e) {
      // Enhanced error logging
      debugPrint('DATABASE ERROR DETAILS:');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Error message: $e');
      
      // Check specifically for schema cache errors
      if (e.toString().contains('schema cache') || e.toString().contains('column')) {
        debugPrint('LIKELY SCHEMA CACHE ERROR DETECTED - Attempting fallback strategy');
        
        // Show a dialog offering options
        final shouldRetry = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Schema Cache Error'),
            content: const Text(
              'There is an issue with the database schema cache. Would you like to:\n\n'
              '1. Try saving without the description field\n'
              '2. Cancel and run the schema refresh script'
            ),
            actions: [
              TextButton(
                child: const Text('Try Fallback'),
                onPressed: () => Navigator.of(context).pop(true),
              ),
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        );
        
        if (shouldRetry == true) {
          success = await _retryWithoutDescription(databaseReadyData);
        }
      } else {
        // General database error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Database error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'Dismiss',
              onPressed: () {},
            ),
          ),
        );
      }
    }

    setState(() {
      _isSavingRoute = false;
    });
    
    // Only proceed if the operation was successful
    if (success) {
      widget.onRouteSaved(routeData);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existingRoute != null 
                ? 'Route updated successfully!' 
                : 'Route created successfully!'
          ),
          backgroundColor: Colors.green,
        ),
      );
      
      if (widget.existingRoute == null) {
        // Clear form fields if it was a new route creation
        _busNumberController.clear();
        _routeNameController.clear();
        setState(() {
          _fromLocationName = null;
          _toLocationName = null;
          _fromLocationCoords = null;
          _toLocationCoords = null;
          _routePoints = [];
          _polylines = [];
          _markers = [];
          _routeDistance = null;
          _routeDuration = null;
        });
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingRoute != null ? 'Edit Route' : 'Create New Route'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          _isSavingRoute
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _saveRoute,
                  child: Text(
                    widget.existingRoute != null ? 'Update' : 'Save',
                    style: AppTypography.buttonMedium.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
        ],
      ),
      body: Column(
        children: [
          // Map Section at the top (reduced from flex: 4 to flex: 3)
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                // Map container with border
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300, width: 2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _mapCenter,
                      initialZoom: 8.0,
                      maxZoom: 20.0,
                      minZoom: 3.0,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://api.olamaps.io/tiles/v1/styles/default-light-standard/{z}/{x}/{y}.png?api_key=${ApiKeys.olaMapsApiKey}',
                        userAgentPackageName: 'com.example.campusride',
                        maxZoom: 20,
                        retinaMode: RetinaMode.isHighDensity(context),
                        additionalOptions: const {
                          'attribution': '© Ola Maps',
                        },
                      ),
                      PolylineLayer(
                        polylines: _polylines,
                      ),
                      MarkerLayer(
                        markers: [..._markers, ..._villageMarkers],
                      ),
                    ],
                  ),
                ),
                
                // Map controls overlay
                Positioned(
                  right: 16,
                  bottom: 24,
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Zoom in button
                            InkWell(
                              onTap: () {
                                _mapController.moveAndRotate(
                                  _mapController.camera.center,
                                  _mapController.camera.zoom + 1.0,
                                  _mapController.camera.rotation,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                child: const Icon(
                                  Icons.add,
                                  size: 20,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: Colors.grey.withOpacity(0.3),
                            ),
                            // Zoom out button
                            InkWell(
                              onTap: () {
                                _mapController.moveAndRotate(
                                  _mapController.camera.center,
                                  _mapController.camera.zoom - 1.0,
                                  _mapController.camera.rotation,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                child: const Icon(
                                  Icons.remove,
                                  size: 20,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Recenter button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: InkWell(
                          onTap: () {
                            if (_routePoints.isNotEmpty) {
                              _fitMapToRoute();
                            } else {
                              _centerMapOnLocations();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            child: const Icon(
                              Icons.center_focus_strong,
                              size: 20,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Form Section below the map (increased from flex: 3 to flex: 4)
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Route details card - Bus Number and Name in horizontal layout (1:1 ratio)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Route Details',
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Horizontal layout: Bus Number (1:1) and Bus Name (1:1)
                            Row(
                              children: [
                                // Bus Number - 1/2 of the width (1:1 ratio)
                                Expanded(
                                  flex: 1,
                                  child: TextFormField(
                                    controller: _busNumberController,
                                    decoration: const InputDecoration(
                                      labelText: 'Bus No.',
                                      hintText: '101',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.directions_bus),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                      isDense: true,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Required';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Bus Name - 1/2 of the width (1:1 ratio)
                                Expanded(
                                  flex: 1,
                                  child: TextFormField(
                                    controller: _routeNameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Route Name',
                                      hintText: 'Campus to Downtown',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.route),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                      isDense: true,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter route name';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Location fields with vertical layout
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Route Locations',
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            
                            // From location field
                            LocationSearchField(
                              label: 'From Location',
                              hint: 'Search for starting location...',
                              icon: Icons.location_on,
                              iconColor: Colors.green,
                              initialValue: _fromLocationName,
                              biasLocation: _mapCenter,
                              onLocationSelected: _onFromLocationSelected,
                            ),
                            
                            const SizedBox(height: 8),
                            
                            // Simple direction indicator
                            Center(
                              child: Icon(
                                Icons.arrow_downward,
                                color: Colors.grey,
                                size: 16,
                              ),
                            ),
                            
                            const SizedBox(height: 8),
                            
                            // To location field
                            LocationSearchField(
                              label: 'To Location',
                              hint: 'Search for destination...',
                              icon: Icons.flag,
                              iconColor: Colors.red,
                              initialValue: _toLocationName,
                              biasLocation: _mapCenter,
                              onLocationSelected: _onToLocationSelected,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Route information and status in one row
                    Row(
                      children: [
                        // Route information card
                        if (_routeDistance != null && _routeDuration != null)
                          Expanded(
                            child: Card(
                              margin: const EdgeInsets.only(right: 4),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Route Info',
                                      style: AppTypography.titleSmall.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Distance',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 9,
                                              ),
                                            ),
                                            Text(
                                              '${_routeDistance!.toStringAsFixed(1)} km',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Duration',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 9,
                                              ),
                                            ),
                                            Text(
                                              '${_routeDuration!.round()} min',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        
                        // Loading/Error status card
                        if (_isLoadingRoute || _isLoadingVillages || (_errorMessage != null && _errorMessage!.isNotEmpty))
                          Expanded(
                            child: Card(
                              margin: const EdgeInsets.only(left: 4),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_isLoadingRoute) ...[
                                      const SizedBox(
                                        height: 12,
                                        width: 12,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Generating...',
                                        style: TextStyle(fontSize: 9),
                                      ),
                                    ] else if (_isLoadingVillages) ...[
                                      const SizedBox(
                                        height: 12,
                                        width: 12,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Loading places...',
                                        style: TextStyle(fontSize: 9),
                                      ),
                                    ] else if (_errorMessage != null && _errorMessage!.isNotEmpty) ...[
                                      Icon(
                                        Icons.error_outline,
                                        color: Colors.red,
                                        size: 12,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Route Error',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 9,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
