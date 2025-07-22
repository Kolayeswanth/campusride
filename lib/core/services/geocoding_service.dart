import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/logger_util.dart';

class GeocodingService extends ChangeNotifier {
  final String? _apiKey;
  final Map<String, String> _crossedVillages = {};
  final Set<String> _notifiedVillages = {};
  final Map<String, latlong2.LatLng> _villageCenters = {};
  final String _baseUrl = 'https://api.locationiq.com/v1';
  
  // Getter for crossed villages
  Map<String, String> get crossedVillages => Map.unmodifiable(_crossedVillages);
  
  GeocodingService() : _apiKey = dotenv.env['LOCATIONIQ_API_KEY'];
  
  /// Perform reverse geocoding to get location name from coordinates
  Future<Map<String, dynamic>?> reverseGeocode(latlong2.LatLng location) async {
    try {
      final url = '$_baseUrl/reverse?key=$_apiKey&lat=${location.latitude}&lon=${location.longitude}&format=json';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        LoggerUtil.error('Reverse geocoding failed', 
            'Status: ${response.statusCode}, Body: ${response.body}');
        return null;
      }
    } catch (e) {
      LoggerUtil.error('Error during reverse geocoding', e);
      return null;
    }
  }
  
  /// Extract village or city name from geocoding result
  String? extractLocationName(Map<String, dynamic> geocodingResult) {
    try {
      final address = geocodingResult['address'] as Map<String, dynamic>?;
      if (address == null) return null;
      
      // Prioritize village, town, city, then other components
      return address['village'] ?? address['town'] ?? address['city'] ?? address['hamlet'] ?? address['county'] ?? address['state'] ?? address['country'] ?? geocodingResult['display_name'];
    } catch (e) {
      print('Error extracting location name: $e');
      return null;
    }
  }
  
  /// Check if the user has crossed a new village/city
  Future<String?> checkCrossedVillage(latlong2.LatLng location) async {
    try {
      final geocodingResult = await reverseGeocode(location);
      if (geocodingResult == null) return null;
      
      final villageName = extractLocationName(geocodingResult);
      if (villageName == null || villageName.isEmpty) return null;
      
      // Check if this is a new village that hasn't been notified yet
      if (!_notifiedVillages.contains(villageName)) {
        final timestamp = DateTime.now();
        final formattedTime = '${_formatHour(timestamp.hour)}:${_formatMinute(timestamp.minute)} ${timestamp.hour >= 12 ? 'PM' : 'AM'}';
        
        // Add to crossed villages with timestamp
        _crossedVillages[villageName] = formattedTime;
        _notifiedVillages.add(villageName);
        
        notifyListeners();
        return villageName;
      }
      
      return null;
    } catch (e) {
      print('Error checking crossed village: $e');
      return null;
    }
  }
  
  /// Clear the list of crossed villages
  void clearCrossedVillages() {
    _crossedVillages.clear();
    _notifiedVillages.clear();
    notifyListeners();
  }
  
  /// Format hour to ensure 12-hour format
  String _formatHour(int hour) {
    final h = hour > 12 ? hour - 12 : hour;
    return h.toString().padLeft(2, '0');
  }
  
  /// Format minute to ensure two digits
  String _formatMinute(int minute) {
    return minute.toString().padLeft(2, '0');
  }

  /// Get the village name for a given location
  Future<String?> getVillageName(latlong2.LatLng location) async {
    try {
      final geocodingResult = await reverseGeocode(location);
      return extractLocationName(geocodingResult ?? {});
    } catch (e) {
      print('Error getting village name: $e');
      return null;
    }
  }

  /// Get the center coordinates of a village
  Future<latlong2.LatLng> getVillageCenter(String villageName) async {
    if (_villageCenters.containsKey(villageName)) {
      return _villageCenters[villageName]!;
    }

    try {
      final results = await searchLocation(villageName);
      if (results.isNotEmpty) {
        final location = results.first;
        final coordinates = location['center'] as List<double>;
        final center = latlong2.LatLng(coordinates[1], coordinates[0]);
        _villageCenters[villageName] = center;
        return center;
      }
      // Return a default center if the actual one can't be determined
      return latlong2.LatLng(0, 0);
    } catch (e) {
      print('Error getting village center: $e');
      // Return a default center if the actual one can't be determined
      return latlong2.LatLng(0, 0);
    }
  }

  Future<List<Map<String, dynamic>>> searchLocation(String query) async {
    if (query.isEmpty) return [];

    if (_apiKey == null) {
      LoggerUtil.error('LocationIQ API key not found', '');
      return [];
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/autocomplete.php?key=$_apiKey&q=$query&limit=5&format=json'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // LocationIQ autocomplete returns a list of results
        if (data is List) {
          return data.map((item) => {
            'place_name': item['display_name'],
            'text': item['display_name'], // Use display_name for primary text as well
            'center': [double.parse(item['lon']), double.parse(item['lat'])],
          }).toList();
        }
      } else {
        LoggerUtil.error('LocationIQ search failed', 
            'Status: ${response.statusCode}, Body: ${response.body}');
      }
      return []; // Return empty list if data is not a list or status code is not 200
    } catch (e) {
      print('Error searching location: $e');
      return [];
    }
  }
}