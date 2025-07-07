import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as latlong2;
import 'dart:convert';

class DriverSearchService {
  final Function(List<Map<String, dynamic>>) onSearchResults;
  final Function(String) onError;

  DriverSearchService({
    required this.onSearchResults,
    required this.onError,
  });

  Future<void> searchLocation(String query) async {
    if (query.isEmpty) {
      onSearchResults([]);
      return;
    }

    try {
      final enhancedQuery = '$query, Andhra Pradesh, India';
      final encodedQuery = Uri.encodeComponent(enhancedQuery);
      
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&countrycodes=in&state=Andhra%20Pradesh&limit=10&addressdetails=1');

      final response = await http.get(url, headers: {
        'Accept': 'application/json',
        'User-Agent': 'CampusRide/1.0',
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        if (data.isEmpty) {
          onSearchResults([]);
          return;
        }

        final results = data.map((place) {
          final address = place['address'] as Map<String, dynamic>;
          final city = address['city'] ?? address['town'] ?? address['village'] ?? '';
          final state = address['state'] ?? '';
          final district = address['county'] ?? '';
          
          final displayName = [
            place['name'] ?? '',
            city,
            district,
            state,
          ].where((s) => s.isNotEmpty).join(', ');

          return {
            'name': displayName,
            'full_address': place['display_name'] as String,
            'latitude': double.parse(place['lat']),
            'longitude': double.parse(place['lon']),
            'type': place['type'] ?? 'place',
            'city': city,
            'state': state,
            'district': district,
          };
        }).toList();

        final filteredResults = results.where((result) {
          return result['state'].toString().toLowerCase().contains('andhra pradesh');
        }).toList();

        onSearchResults(filteredResults);
      } else {
        throw Exception('Failed to search location');
      }
    } catch (e) {
      print('Search error: $e');
      onError('Error searching location. Please try again.');
      onSearchResults([]);
    }
  }

  Future<latlong2.LatLng?> getCoordinatesFromAddress(String address) async {
    try {
      final enhancedAddress = '$address, Andhra Pradesh, India';
      final encodedAddress = Uri.encodeComponent(enhancedAddress);
      
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$encodedAddress&format=json&countrycodes=in&state=Andhra%20Pradesh&limit=1');

      final response = await http.get(url, headers: {
        'Accept': 'application/json',
        'User-Agent': 'CampusRide/1.0',
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final place = data.first;
          return latlong2.LatLng(
            double.parse(place['lat']),
            double.parse(place['lon']),
          );
        }
      }
      return null;
    } catch (e) {
      print('Error getting coordinates: $e');
      return null;
    }
  }
}
