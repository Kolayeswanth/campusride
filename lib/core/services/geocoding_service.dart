import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/logger_util.dart';
import '../constants/map_constants.dart';

class GeocodingService extends ChangeNotifier {
  final String _apiKey;
  final Map<String, String> _crossedVillages = {};
  final Set<String> _notifiedVillages = {};
  final Map<String, latlong2.LatLng> _villageCenters = {};
  
  // Getter for crossed villages
  Map<String, String> get crossedVillages => Map.unmodifiable(_crossedVillages);
  
  GeocodingService() : _apiKey = dotenv.env['MAPTILER_API_KEY'] ?? 'X2gh37rGOvC2FnGm7GYy';
  
  /// Perform reverse geocoding to get location name from coordinates
  Future<Map<String, dynamic>?> reverseGeocode(latlong2.LatLng location) async {
    try {
      final url = 'https://api.maptiler.com/geocoding/${location.longitude},${location.latitude}.json?key=$_apiKey';
      
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
      final features = geocodingResult['features'] as List;
      if (features.isEmpty) return null;
      
      // Look for village, town, city, or hamlet in the place type
      for (final feature in features) {
        final placeType = feature['place_type'] as List;
        final properties = feature['properties'] as Map<String, dynamic>;
        
        if (placeType.contains('place') || 
            placeType.contains('locality') || 
            placeType.contains('neighborhood')) {
          return properties['name'] as String?;
        }
      }
      
      // If no specific place type found, use the most relevant result
      if (features.isNotEmpty) {
        final firstFeature = features.first;
        final properties = firstFeature['properties'] as Map<String, dynamic>;
        return properties['name'] as String?;
      }
      
      return null;
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
      // TODO: Implement actual geocoding service call
      // For now, return a mock village name based on coordinates
      final villageName = _getMockVillageName(location);
      return villageName;
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
      // TODO: Implement actual geocoding service call
      // For now, return mock coordinates
      final center = _getMockVillageCenter(villageName);
      _villageCenters[villageName] = center;
      return center;
    } catch (e) {
      print('Error getting village center: $e');
      // Return a default center if the actual one can't be determined
      return latlong2.LatLng(0, 0);
    }
  }

  // Mock methods for testing
  String? _getMockVillageName(latlong2.LatLng location) {
    // This is a mock implementation
    // In a real app, you would use a geocoding service
    final villages = [
      {'name': 'Village A', 'lat': 12.9716, 'lng': 77.5946},
      {'name': 'Village B', 'lat': 12.9784, 'lng': 77.6408},
      {'name': 'Village C', 'lat': 12.9850, 'lng': 77.6067},
    ];

    for (final village in villages) {
      final distance = const latlong2.Distance().distance(
        location,
        latlong2.LatLng(village['lat'] as double, village['lng'] as double),
      );

      if (distance <= MapConstants.villageDetectionRadius) {
        return village['name'] as String;
      }
    }

    return null;
  }

  latlong2.LatLng _getMockVillageCenter(String villageName) {
    // This is a mock implementation
    // In a real app, you would use a geocoding service
    final villages = {
      'Village A': latlong2.LatLng(12.9716, 77.5946),
      'Village B': latlong2.LatLng(12.9784, 77.6408),
      'Village C': latlong2.LatLng(12.9850, 77.6067),
    };

    return villages[villageName] ?? latlong2.LatLng(0, 0);
  }
}