import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SearchController {
  List<Map<String, dynamic>> searchResults = [];
  List<Map<String, dynamic>> startLocationResults = [];
  bool isSearching = false;
  bool isSearchingStartLocation = false;

  // Search for locations
  Future<List<Map<String, dynamic>>> searchLocation(String query) async {
    if (query.length < 3) return [];

    isSearching = true;

    try {
      final apiKey = dotenv.env['GEOAPIFY_API_KEY'] ?? '';
      final encodedQuery = Uri.encodeComponent(query);

      final response = await http.get(
        Uri.parse(
            'https://api.geoapify.com/v1/geocode/search?text=$encodedQuery&format=json&apiKey=$apiKey'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null) {
          final results = List<Map<String, dynamic>>.from(
            data['results'].map((result) {
              return {
                'name': result['name'] ?? result['formatted'],
                'full_address': result['formatted'],
                'latitude': result['lat'],
                'longitude': result['lon'],
              };
            }),
          );

          searchResults = results;
          isSearching = false;
          return results;
        }
      }

      isSearching = false;
      return [];
    } catch (e) {
      print('Location search error: $e');
      isSearching = false;
      return [];
    }
  }

  // Search for start locations
  Future<List<Map<String, dynamic>>> searchStartLocation(String query) async {
    if (query.length < 3) return [];

    isSearchingStartLocation = true;

    try {
      final apiKey = dotenv.env['GEOAPIFY_API_KEY'] ?? '';
      final encodedQuery = Uri.encodeComponent(query);

      final response = await http.get(
        Uri.parse(
            'https://api.geoapify.com/v1/geocode/search?text=$encodedQuery&format=json&apiKey=$apiKey'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null) {
          final results = List<Map<String, dynamic>>.from(
            data['results'].map((result) {
              return {
                'name': result['name'] ?? result['formatted'],
                'full_address': result['formatted'],
                'latitude': result['lat'],
                'longitude': result['lon'],
              };
            }),
          );

          startLocationResults = results;
          isSearchingStartLocation = false;
          return results;
        }
      }

      isSearchingStartLocation = false;
      return [];
    } catch (e) {
      print('Start location search error: $e');
      isSearchingStartLocation = false;
      return [];
    }
  }

  // Clear search results
  void clearSearchResults() {
    searchResults = [];
    isSearching = false;
  }

  // Clear start location search results
  void clearStartLocationResults() {
    startLocationResults = [];
    isSearchingStartLocation = false;
  }
}
