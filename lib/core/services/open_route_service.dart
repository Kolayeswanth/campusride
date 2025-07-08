import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import '../config/api_keys.dart';
import 'dart:convert';

class OpenRouteService {
  static const String _baseUrl = 'https://api.openrouteservice.org/v2';
  final Dio _dio = Dio();

  Future<bool> validateApiKey() async {
    if (!ApiKeys.isValidOrsKey()) {
      return false;
    }

    try {
      final response = await _dio.get(
        '$_baseUrl/directions/driving-car',
        queryParameters: {
          'api_key': ApiKeys.orsApiKey,
          'start': '8.681495,49.41461',
          'end': '8.687872,49.420318',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      print('OpenRouteService API key validation failed: $e');
      return false;
    }
  }

  String get apiKey => ApiKeys.orsApiKey;

  Future<Map<String, dynamic>> getDirections({
    required List<LatLng> waypoints,
    String profile = 'driving-car',
  }) async {
    if (!ApiKeys.isValidOrsKey()) {
      throw Exception('Invalid OpenRouteService API key');
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
      final coordinates = waypoints
          .map((point) => [point.longitude, point.latitude])
          .toList();

      final response = await _dio.post(
        '$_baseUrl/directions/$profile',
        data: {
          'coordinates': coordinates,
          'format': 'geojson',
          'instructions': true,
          'geometry': true,
          'elevation': false,
        },
        options: Options(
          headers: {
            'Authorization': ApiKeys.orsApiKey,
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data == null) {
          throw Exception('Empty response from routing service');
        }
        return data;
      } else {
        throw Exception('Failed to get directions: ${response.statusCode} - ${response.statusMessage}');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception('Connection timeout. Please check your internet connection.');
      } else if (e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Request timeout. The routing service is taking too long to respond.');
      } else if (e.response?.statusCode == 404) {
        throw Exception('Routing service endpoint not found.');
      } else if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        throw Exception('Invalid API key or access denied.');
      } else if (e.response?.statusCode == 422) {
        throw Exception('Invalid coordinates or routing parameters.');
      } else {
        throw Exception('Network error: ${e.message}');
      }
    } catch (e) {
      throw Exception('Error getting directions: $e');
    }
  }

  // Convert ORS response to our format
  Map<String, dynamic> parseDirectionsResponse(Map<String, dynamic> orsResponse) {
    final features = orsResponse['features'] as List?;
    if (features == null || features.isEmpty) {
      throw Exception('No route found - the routing service could not find a path between the specified locations. Please check that the locations are accessible by road.');
    }

    final route = features[0] as Map<String, dynamic>;
    final geometry = route['geometry'] as Map<String, dynamic>?;
    final properties = route['properties'] as Map<String, dynamic>?;
    
    if (geometry == null || properties == null) {
      throw Exception('Invalid route data received from routing service.');
    }
    
    final summary = properties['summary'] as Map<String, dynamic>?;
    final segments = properties['segments'] as List<dynamic>? ?? <dynamic>[];

    if (summary == null) {
      throw Exception('Route summary not available from routing service.');
    }

    // Extract coordinates
    final coordinates = geometry['coordinates'] as List<dynamic>?;
    if (coordinates == null || coordinates.isEmpty) {
      throw Exception('No route coordinates found in the response.');
    }
    
    final routePoints = <LatLng>[];
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
      throw Exception('Error parsing route coordinates: $e');
    }

    if (routePoints.isEmpty) {
      throw Exception('No valid route points could be extracted from the response.');
    }

    // Calculate distances between segments
    final distances = <String>[];
    for (final segment in segments) {
      final segmentMap = segment as Map<String, dynamic>;
      final distance = (segmentMap['distance'] as num).toDouble() / 1000.0;
      distances.add('${distance.toStringAsFixed(1)} km');
    }

    return {
      'route_points': routePoints,
      'total_distance': (summary['distance'] as num).toDouble() / 1000.0,
      'total_duration': (summary['duration'] as num).toDouble(),
      'polyline_data': jsonEncode(coordinates),
      'segment_distances': distances,
    };
  }
}
