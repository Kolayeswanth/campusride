import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import '../config/api_keys.dart';

class LocationIQService {
  static const String _baseUrl = 'https://us1.locationiq.com/v1';
  final Dio _dio = Dio();

  Future<bool> validateApiKey() async {
    if (!ApiKeys.isValidLocationIqKey()) {
      return false;
    }

    try {
      final response = await _dio.get(
        '$_baseUrl/search.php',
        queryParameters: {
          'key': ApiKeys.locationIqApiKey,
          'q': 'Delhi',
          'format': 'json',
          'limit': 1,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      print('LocationIQ API key validation failed: $e');
      return false;
    }
  }

  String get apiKey => ApiKeys.locationIqApiKey;

  // Search for places
  Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    if (!ApiKeys.isValidLocationIqKey()) {
      throw Exception('Invalid LocationIQ API key');
    }

    if (query.trim().isEmpty) {
      return [];
    }

    try {
      final response = await _dio.get(
        '$_baseUrl/search',
        queryParameters: {
          'key': apiKey,
          'q': query.trim(),
          'format': 'json',
          'limit': 10,
          'addressdetails': 1,
          'countrycodes': 'in', // Limit to India for better results
        },
      );

      if (response.statusCode == 200) {
        final results = response.data as List<dynamic>?;
        if (results == null) return [];
        
        return results.map((result) {
          final resultMap = result as Map<String, dynamic>;
          return {
            'display_name': resultMap['display_name'] as String? ?? 'Unknown location',
            'lat': double.tryParse(resultMap['lat']?.toString() ?? '0') ?? 0.0,
            'lng': double.tryParse(resultMap['lon']?.toString() ?? '0') ?? 0.0,
            'type': resultMap['type'] as String? ?? 'unknown',
            'importance': (resultMap['importance'] as num?)?.toDouble() ?? 0.0,
          };
        }).toList();
      } else {
        print('LocationIQ search failed with status: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error searching places: $e');
      return [];
    }
  }

  // Reverse geocoding
  Future<String> reverseGeocode(LatLng location) async {
    if (!ApiKeys.isValidLocationIqKey()) {
      throw Exception('Invalid LocationIQ API key');
    }

    try {
      final response = await _dio.get(
        '$_baseUrl/reverse',
        queryParameters: {
          'key': apiKey,
          'lat': location.latitude,
          'lon': location.longitude,
          'format': 'json',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>?;
        if (data != null && data['display_name'] != null) {
          return data['display_name'] as String;
        }
        return 'Unknown location';
      } else {
        print('LocationIQ reverse geocoding failed with status: ${response.statusCode}');
        return '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
      }
    } catch (e) {
      print('Error reverse geocoding: $e');
      return '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
    }
  }
}
