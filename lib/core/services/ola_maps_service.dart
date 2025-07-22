import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import '../config/api_keys.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class OlaMapsService {
  static const String _baseUrl = 'https://api.olamaps.io';
  final Dio _dio = Dio();
  final _uuid = const Uuid();

  Future<bool> validateApiKey() async {
    if (!ApiKeys.isValidOlaMapsKey()) {
      return false;
    }

    try {
      // Test the API key with a simple geocoding request
      final response = await _dio.get(
        '$_baseUrl/places/v1/geocode',
        queryParameters: {
          'address': 'India Gate, New Delhi',
          'api_key': ApiKeys.olaMapsApiKey,
        },
        options: Options(
          headers: {
            'X-Request-Id': _uuid.v4(),
          },
        ),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Ola Maps API key validation failed: $e');
      return false;
    }
  }

  // Test API key with a simple request
  Future<bool> testApiKey() async {
    try {
      final response = await _dio.get(
        '$_baseUrl/places/v1/geocode',
        queryParameters: {
          'address': 'New Delhi, India',
          'api_key': ApiKeys.olaMapsApiKey,
        },
        options: Options(
          headers: {
            'X-Request-Id': _uuid.v4(),
          },
        ),
      );
      debugPrint('API test response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('API test failed: $e');
      return false;
    }
  }

  String get apiKey => ApiKeys.olaMapsApiKey;

  Future<Map<String, dynamic>> getDirections({
    required List<LatLng> waypoints,
    String mode = 'DRIVING',
  }) async {
    if (!ApiKeys.isValidOlaMapsKey()) {
      throw Exception('Invalid Ola Maps API key');
    }

    if (waypoints.length < 2) {
      throw Exception('At least 2 waypoints are required');
    }

    // Validate coordinates
    for (final point in waypoints) {
      if (point.latitude < -90 || point.latitude > 90 || 
          point.longitude < -180 || point.longitude > 180) {
        throw Exception('Invalid coordinates: ${point.latitude}, ${point.longitude}');
      }
    }

    try {
      // Test API key first
      final apiTest = await testApiKey();
      if (!apiTest) {
        debugPrint('API key test failed, using fallback routing');
        return await _getFallbackRoute(waypoints);
      }

      // Convert waypoints to Ola Maps format - origin and destination as lat,lng
      final origin = '${waypoints.first.latitude},${waypoints.first.longitude}';
      final destination = '${waypoints.last.latitude},${waypoints.last.longitude}';
      
      // Build waypoints string for intermediate points
      String? waypointsStr;
      if (waypoints.length > 2) {
        final intermediates = waypoints
            .skip(1)
            .take(waypoints.length - 2)
            .map((point) => '${point.latitude},${point.longitude}')
            .toList();
        waypointsStr = intermediates.join('|');
      }

      // Use query parameters instead of request body (this is the working format)
      final queryParams = <String, dynamic>{
        'origin': origin,
        'destination': destination,
        'mode': mode,
        'api_key': ApiKeys.olaMapsApiKey,
      };

      // Add waypoints if there are intermediate points
      if (waypointsStr != null && waypointsStr.isNotEmpty) {
        queryParams['waypoints'] = waypointsStr;
      }

      debugPrint('Ola Maps request with query params: $queryParams');

      final response = await _dio.post(
        '$_baseUrl/routing/v1/directions',
        queryParameters: queryParams,
        options: Options(
          headers: {
            'X-Request-Id': _uuid.v4(),
            'Content-Type': 'application/json',
          },
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data == null) {
          throw Exception('Empty response from routing service');
        }
        debugPrint('Ola Maps routing successful');
        return data;
      } else {
        throw Exception('Failed to get directions: ${response.statusCode} - ${response.statusMessage}');
      }
    } on DioException catch (e) {
      debugPrint('Ola Maps routing failed with DioException: ${e.type} - ${e.response?.statusCode}');
      
      // Log the complete error response for debugging
      if (e.response?.data != null) {
        debugPrint('Ola Maps error response: ${e.response?.data}');
      } else {
        debugPrint('Ola Maps error message: ${e.message}');
      }
      
      if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception('Connection timeout. Please check your internet connection.');
      } else if (e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Request timeout. The routing service is taking too long to respond.');
      } else if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        throw Exception('Invalid API key or access denied.');
      } else if (e.response?.statusCode == 400) {
        debugPrint('400 error with query params format, trying basic directions API as fallback');
        return await _getBasicDirections(waypoints, mode);
      } else if (e.response?.statusCode == 422) {
        debugPrint('422 error, trying basic directions API as fallback');
        return await _getBasicDirections(waypoints, mode);
      } else {
        // For other network errors, try fallback before giving up
        debugPrint('Network error, trying fallback: ${e.message}');
        return await _getFallbackRoute(waypoints);
      }
    } catch (e) {
      debugPrint('Primary routing failed: $e');
      return await _getFallbackRoute(waypoints);
    }
  }

  // Fallback to basic directions API
  Future<Map<String, dynamic>> _getBasicDirections(List<LatLng> waypoints, String mode) async {
    try {
      final origin = '${waypoints.first.latitude},${waypoints.first.longitude}';
      final destination = '${waypoints.last.latitude},${waypoints.last.longitude}';
      
      // Build waypoints string for intermediate points
      String? waypointsStr;
      if (waypoints.length > 2) {
        final intermediates = waypoints
            .skip(1)
            .take(waypoints.length - 2)
            .map((point) => '${point.latitude},${point.longitude}')
            .toList();
        waypointsStr = intermediates.join('|');
      }

      final queryParams = <String, dynamic>{
        'origin': origin,
        'destination': destination,
        'mode': mode,
        'api_key': ApiKeys.olaMapsApiKey,
      };

      // Add waypoints if there are intermediate points
      if (waypointsStr != null && waypointsStr.isNotEmpty) {
        queryParams['waypoints'] = waypointsStr;
      }

      debugPrint('Ola Maps basic request with query params: $queryParams');

      final response = await _dio.post(
        '$_baseUrl/routing/v1/directions/basic',
        queryParameters: queryParams,
        options: Options(
          headers: {
            'X-Request-Id': _uuid.v4(),
            'Content-Type': 'application/json',
          },
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      if (response.statusCode == 200) {
        debugPrint('Basic directions API successful');
        return response.data;
      } else {
        throw Exception('Basic directions failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Basic directions also failed: $e');
      return _createStraightLineRoute(waypoints);
    }
  }

  // Create a simple straight-line route as last resort
  Map<String, dynamic> _createStraightLineRoute(List<LatLng> waypoints) {
    debugPrint('Creating straight-line route for ${waypoints.length} waypoints');
    
    final coordinates = waypoints
        .map((point) => [point.longitude, point.latitude])
        .toList();

    // Calculate approximate distance
    double totalDistance = 0.0;
    for (int i = 0; i < waypoints.length - 1; i++) {
      totalDistance += _calculateDistance(waypoints[i], waypoints[i + 1]);
    }

    debugPrint('Straight-line route created: ${totalDistance.toStringAsFixed(2)} km total distance');

    return {
      'routes': [
        {
          'geometry': {
            'coordinates': coordinates,
            'type': 'LineString',
          },
          'legs': _createLegs(waypoints),
          'distance': totalDistance * 1000, // Convert to meters
          'duration': totalDistance * 60, // Rough estimate: 1 km per minute
          'weight': totalDistance * 60,
          'weight_name': 'routability',
        }
      ],
      'waypoints': waypoints.map((point) => {
        'location': [point.longitude, point.latitude],
        'name': '',
      }).toList(),
    };
  }

  // Create legs for straight-line route
  List<Map<String, dynamic>> _createLegs(List<LatLng> waypoints) {
    final legs = <Map<String, dynamic>>[];
    
    for (int i = 0; i < waypoints.length - 1; i++) {
      final distance = _calculateDistance(waypoints[i], waypoints[i + 1]);
      legs.add({
        'distance': distance * 1000, // Convert to meters
        'duration': distance * 60, // Rough estimate
        'weight': distance * 60,
        'steps': [],
        'summary': 'Straight line route',
      });
    }
    
    return legs;
  }

  // Calculate distance between two points using Haversine formula
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final double lat1Rad = point1.latitude * (pi / 180);
    final double lat2Rad = point2.latitude * (pi / 180);
    final double deltaLatRad = (point2.latitude - point1.latitude) * (pi / 180);
    final double deltaLngRad = (point2.longitude - point1.longitude) * (pi / 180);

    final double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
        sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    final double c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  // Fallback routing method
  Future<Map<String, dynamic>> _getFallbackRoute(List<LatLng> waypoints) async {
    debugPrint('All routing methods failed, creating straight-line route');
    return _createStraightLineRoute(waypoints);
  }

  // Convert Ola Maps response to our format
  Map<String, dynamic> parseDirectionsResponse(Map<String, dynamic> olaResponse) {
    final routes = olaResponse['routes'] as List?;
    if (routes == null || routes.isEmpty) {
      throw Exception('No route found - the routing service could not find a path between the specified locations.');
    }

    final route = routes[0] as Map<String, dynamic>;
    final legs = route['legs'] as List<dynamic>? ?? [];
    
    // Check for overview_polyline (new Ola Maps format) - it's a string directly
    final overviewPolyline = route['overview_polyline'] as String?;
    List<LatLng> routePoints = [];
    
    if (overviewPolyline != null && overviewPolyline.isNotEmpty) {
      // Try to decode polyline string directly
      try {
        routePoints = _decodePolyline(overviewPolyline);
        debugPrint('Successfully decoded overview_polyline with ${routePoints.length} points');
      } catch (e) {
        debugPrint('Error decoding overview_polyline: $e');
      }
    }
    
    // If no points from overview_polyline, try to extract from legs
    if (routePoints.isEmpty && legs.isNotEmpty) {
      debugPrint('No overview_polyline points, extracting from legs');
      for (final leg in legs) {
        final legMap = leg as Map<String, dynamic>;
        final steps = legMap['steps'] as List<dynamic>? ?? [];
        
        for (final step in steps) {
          final stepMap = step as Map<String, dynamic>;
          final startLocation = stepMap['start_location'];
          final endLocation = stepMap['end_location'];
          
          // Safely extract start location
          if (startLocation != null) {
            final lat = _extractNumericValue(startLocation is Map ? startLocation['lat'] : null);
            final lng = _extractNumericValue(startLocation is Map ? startLocation['lng'] : null);
            if (lat != 0.0 && lng != 0.0) {
              routePoints.add(LatLng(lat, lng));
            }
          }
          
          // Add end location for the last step
          if (step == steps.last && endLocation != null) {
            final lat = _extractNumericValue(endLocation is Map ? endLocation['lat'] : null);
            final lng = _extractNumericValue(endLocation is Map ? endLocation['lng'] : null);
            if (lat != 0.0 && lng != 0.0) {
              routePoints.add(LatLng(lat, lng));
            }
          }
        }
      }
    }
    
    // Fallback: check for legacy geometry format
    if (routePoints.isEmpty) {
      final geometry = route['geometry'] as Map<String, dynamic>?;
      if (geometry != null) {
        final coordinates = geometry['coordinates'] as List<dynamic>?;
        if (coordinates != null && coordinates.isNotEmpty) {
          try {
            for (final coord in coordinates) {
              final coordList = coord as List<dynamic>;
              if (coordList.length >= 2) {
                final lng = (coordList[0] as num).toDouble();
                final lat = (coordList[1] as num).toDouble();
                routePoints.add(LatLng(lat, lng));
              }
            }
          } catch (e) {
            debugPrint('Error parsing legacy geometry coordinates: $e');
          }
        }
      }
    }

    if (routePoints.isEmpty) {
      throw Exception('No valid route points could be extracted from the response.');
    }

    // Calculate distances between legs
    final distances = <String>[];
    double totalDistance = 0.0;
    double totalDuration = 0.0;
    
    for (final leg in legs) {
      final legMap = leg as Map<String, dynamic>;
      
      // Handle distance - can be either a Map or a direct number
      final distanceValue = _extractNumericValue(legMap['distance']);
      if (distanceValue > 0) {
        final distanceText = '${(distanceValue / 1000).toStringAsFixed(1)} km';
        distances.add(distanceText);
        totalDistance += distanceValue;
      }
      
      // Handle duration - can be either a Map or a direct number  
      final durationValue = _extractNumericValue(legMap['duration']);
      if (durationValue > 0) {
        totalDuration += durationValue;
      }
    }
    
    // If no legs data, try to get from route level
    if (totalDistance == 0.0) {
      totalDistance = _extractNumericValue(route['distance']);
    }
    
    if (totalDuration == 0.0) {
      totalDuration = _extractNumericValue(route['duration']);
    }

    // Convert distances to km if they're in meters
    final finalDistance = totalDistance > 1000 ? totalDistance / 1000.0 : totalDistance;
    
    return {
      'route_points': routePoints,
      'total_distance': finalDistance,
      'total_duration': totalDuration,
      'polyline_data': overviewPolyline ?? jsonEncode(routePoints.map((p) => [p.longitude, p.latitude]).toList()),
      'segment_distances': distances.isEmpty ? ['${finalDistance.toStringAsFixed(1)} km'] : distances,
    };
  }

  // Decode Google/Ola Maps encoded polyline format
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int byte;
      
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);
      
      int deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += deltaLat;

      shift = 0;
      result = 0;
      
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);
      
      int deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += deltaLng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }

  // Geocoding functionality to search for locations
  Future<List<Map<String, dynamic>>> searchLocations(String query, {LatLng? biasLocation}) async {
    if (query.trim().isEmpty) {
      return [];
    }

    if (!ApiKeys.isValidOlaMapsKey()) {
      throw Exception('Invalid Ola Maps API key');
    }

    try {
      final queryParams = <String, String>{
        'address': query.trim(),
        'api_key': ApiKeys.olaMapsApiKey,
        'language': 'en',
      };

      // Add bias location if provided
      if (biasLocation != null) {
        queryParams['location'] = '${biasLocation.latitude},${biasLocation.longitude}';
        queryParams['radius'] = '50000'; // 50km radius
      }

      final response = await _dio.get(
        '$_baseUrl/places/v1/geocode',
        queryParameters: queryParams,
        options: Options(
          headers: {
            'X-Request-Id': _uuid.v4(),
          },
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final geocodingResults = data['geocodingResults'] as List?;
        
        if (geocodingResults != null) {
          return geocodingResults.map<Map<String, dynamic>>((result) {
            final geometry = result['geometry'] as Map<String, dynamic>?;
            
            if (geometry != null) {
              final location = geometry['location'] as Map<String, dynamic>?;
              if (location != null) {
                final lat = (location['lat'] as num).toDouble();
                final lng = (location['lng'] as num).toDouble();
                
                return {
                  'name': result['formatted_address'] ?? 'Unknown location',
                  'address': result['formatted_address'] ?? '',
                  'latitude': lat,
                  'longitude': lng,
                  'country': result['address_components']?.firstWhere(
                    (component) => (component['types'] as List).contains('country'),
                    orElse: () => {'long_name': ''},
                  )?['long_name'] ?? '',
                  'region': result['address_components']?.firstWhere(
                    (component) => (component['types'] as List).contains('administrative_area_level_1'),
                    orElse: () => {'long_name': ''},
                  )?['long_name'] ?? '',
                  'locality': result['address_components']?.firstWhere(
                    (component) => (component['types'] as List).contains('locality'),
                    orElse: () => {'long_name': ''},
                  )?['long_name'] ?? '',
                };
              }
            }
            return <String, dynamic>{};
          }).where((location) => location.isNotEmpty).toList();
        }
      }
      
      // If geocoding fails, try with autocomplete
      return await _searchWithAutocomplete(query, biasLocation);
    } catch (e) {
      debugPrint('Ola Maps geocoding failed: $e');
      // Try autocomplete as fallback
      return await _searchWithAutocomplete(query, biasLocation);
    }
  }

  // Fallback to autocomplete API
  Future<List<Map<String, dynamic>>> _searchWithAutocomplete(String query, LatLng? biasLocation) async {
    try {
      final queryParams = <String, String>{
        'input': query.trim(),
        'api_key': ApiKeys.olaMapsApiKey,
        'language': 'en',
      };

      // Add bias location if provided
      if (biasLocation != null) {
        queryParams['location'] = '${biasLocation.latitude},${biasLocation.longitude}';
        queryParams['radius'] = '50000'; // 50km radius
      }

      final response = await _dio.get(
        '$_baseUrl/places/v1/autocomplete',
        queryParameters: queryParams,
        options: Options(
          headers: {
            'X-Request-Id': _uuid.v4(),
          },
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final predictions = data['predictions'] as List?;
        
        if (predictions != null) {
          // Get details for each prediction
          final List<Map<String, dynamic>> locations = [];
          
          for (final prediction in predictions.take(5)) { // Limit to 5 results
            final placeId = prediction['place_id'] as String?;
            if (placeId != null) {
              try {
                final details = await _getPlaceDetails(placeId);
                if (details != null) {
                  locations.add(details);
                }
              } catch (e) {
                debugPrint('Failed to get place details for $placeId: $e');
              }
            }
          }
          
          return locations;
        }
      }
      
      return [];
    } catch (e) {
      debugPrint('Autocomplete search failed: $e');
      return [];
    }
  }

  // Get place details from place_id
  Future<Map<String, dynamic>?> _getPlaceDetails(String placeId) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/places/v1/details',
        queryParameters: {
          'place_id': placeId,
          'api_key': ApiKeys.olaMapsApiKey,
        },
        options: Options(
          headers: {
            'X-Request-Id': _uuid.v4(),
          },
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final result = data['result'] as Map<String, dynamic>?;
        
        if (result != null) {
          final geometry = result['geometry'] as Map<String, dynamic>?;
          if (geometry != null) {
            final location = geometry['location'] as Map<String, dynamic>?;
            if (location != null) {
              final lat = (location['lat'] as num).toDouble();
              final lng = (location['lng'] as num).toDouble();
              
              return {
                'name': result['name'] ?? result['formatted_address'] ?? 'Unknown location',
                'address': result['formatted_address'] ?? '',
                'latitude': lat,
                'longitude': lng,
                'country': result['address_components']?.firstWhere(
                  (component) => (component['types'] as List).contains('country'),
                  orElse: () => {'long_name': ''},
                )?['long_name'] ?? '',
                'region': result['address_components']?.firstWhere(
                  (component) => (component['types'] as List).contains('administrative_area_level_1'),
                  orElse: () => {'long_name': ''},
                )?['long_name'] ?? '',
                'locality': result['address_components']?.firstWhere(
                  (component) => (component['types'] as List).contains('locality'),
                  orElse: () => {'long_name': ''},
                )?['long_name'] ?? '',
              };
            }
          }
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Place details request failed: $e');
      return null;
    }
  }

  // Reverse geocoding to get place name from coordinates
  Future<String?> reverseGeocode(LatLng location) async {
    if (!ApiKeys.isValidOlaMapsKey()) {
      return null;
    }

    try {
      final response = await _dio.get(
        '$_baseUrl/places/v1/reverse-geocode',
        queryParameters: {
          'latlng': '${location.latitude},${location.longitude}',
          'api_key': ApiKeys.olaMapsApiKey,
        },
        options: Options(
          headers: {
            'X-Request-Id': _uuid.v4(),
          },
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final results = data['results'] as List?;
        
        if (results != null && results.isNotEmpty) {
          final firstResult = results[0] as Map<String, dynamic>;
          return firstResult['formatted_address'] as String?;
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Reverse geocoding failed: $e');
      return null;
    }
  }

  // Helper method to extract numeric values from different response formats
  double _extractNumericValue(dynamic value) {
    if (value == null) return 0.0;
    
    // If it's already a number, return it
    if (value is num) {
      return value.toDouble();
    }
    
    // If it's a map with 'value' field (Google/Ola Maps format)
    if (value is Map<String, dynamic>) {
      final numValue = value['value'] as num?;
      if (numValue != null) {
        return numValue.toDouble();
      }
    }
    
    // If it's a string, try to parse it
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
    
    return 0.0;
  }
}
