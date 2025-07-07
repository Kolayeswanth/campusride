import 'package:http/http.dart' as http;
import 'dart:convert';

class MapService {
  final String _apiKey;
  final String _baseUrl = 'https://api.openrouteservice.org/v2';

  MapService(this._apiKey);

  Future<Map<String, dynamic>> getRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/directions/driving-car/geojson'),
      headers: {
        'Authorization': _apiKey,
        'Content-Type': 'application/json',
        'Accept': 'application/json, application/geo+json, application/gpx+xml, img/png; charset=utf-8',
      },
      body: jsonEncode({
        'coordinates': [
          [startLng, startLat],
          [endLng, endLat],
        ],
        'instructions': true,
        'preference': 'fastest',
        'units': 'm',
        'language': 'en',
        'geometry_simplify': true,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch route: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> searchLocation(String query) async {
    final response = await http.get(
      Uri.parse('https://api.openrouteservice.org/geocode/autocomplete?api_key=$_apiKey&text=$query&boundary.country=IND&boundary.region=Andhra Pradesh'),
      headers: {
        'Accept': 'application/json, application/geo+json, application/gpx+xml, img/png; charset=utf-8',
      },
    );

    print('OpenRouteService Geocode API Status Code: ${response.statusCode}');
    print('OpenRouteService Geocode API Response Body: ${response.body}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to search location: ${response.body}');
    }
  }
} 