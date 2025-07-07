import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';

class OfflineService {
  static const String _cachedRoutesKey = 'cached_routes';
  static const String _emergencyContactsKey = 'emergency_contacts';
  static const String _offlineMapKey = 'offline_map';

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/offline_data.json');
  }

  // Save route data for offline use
  Future<void> cacheRoute(Map<String, dynamic> routeData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingRoutes = prefs.getStringList(_cachedRoutesKey) ?? [];

      // Check if route already exists
      final routeId = routeData['id'];
      final existingIndex = existingRoutes.indexWhere((route) {
        final decoded = jsonDecode(route);
        return decoded['id'] == routeId;
      });

      final routeJson = jsonEncode(routeData);

      if (existingIndex != -1) {
        existingRoutes[existingIndex] = routeJson;
      } else {
        existingRoutes.add(routeJson);
      }

      await prefs.setStringList(_cachedRoutesKey, existingRoutes);
    } catch (e) {
      print('Error caching route: $e');
    }
  }

  // Get cached route data
  Future<List<Map<String, dynamic>>> getCachedRoutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final routes = prefs.getStringList(_cachedRoutesKey) ?? [];
      return routes
          .map((route) => jsonDecode(route) as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print('Error getting cached routes: $e');
      return [];
    }
  }

  // Save emergency contacts
  Future<void> saveEmergencyContacts(
      List<Map<String, dynamic>> contacts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contactsJson =
          contacts.map((contact) => jsonEncode(contact)).toList();
      await prefs.setStringList(_emergencyContactsKey, contactsJson);
    } catch (e) {
      print('Error saving emergency contacts: $e');
    }
  }

  // Get emergency contacts
  Future<List<Map<String, dynamic>>> getEmergencyContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contacts = prefs.getStringList(_emergencyContactsKey) ?? [];
      return contacts
          .map((contact) => jsonDecode(contact) as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print('Error getting emergency contacts: $e');
      return [];
    }
  }

  // Save offline map region
  Future<void> saveOfflineMapRegion({
    required String regionId,
    required List<LatLng> bounds,
    required String mapStyle,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mapData = {
        'regionId': regionId,
        'bounds': bounds
            .map((point) => {'lat': point.latitude, 'lng': point.longitude})
            .toList(),
        'mapStyle': mapStyle,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await prefs.setString(_offlineMapKey, jsonEncode(mapData));
    } catch (e) {
      print('Error saving offline map region: $e');
    }
  }

  // Get offline map region
  Future<Map<String, dynamic>?> getOfflineMapRegion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mapData = prefs.getString(_offlineMapKey);
      if (mapData != null) {
        return jsonDecode(mapData) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error getting offline map region: $e');
      return null;
    }
  }

  // Check if offline data is available
  Future<bool> hasOfflineData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasRoutes =
          prefs.getStringList(_cachedRoutesKey)?.isNotEmpty ?? false;
      final hasContacts =
          prefs.getStringList(_emergencyContactsKey)?.isNotEmpty ?? false;
      final hasMap = prefs.getString(_offlineMapKey) != null;

      return hasRoutes || hasContacts || hasMap;
    } catch (e) {
      print('Error checking offline data: $e');
      return false;
    }
  }

  // Clear all offline data
  Future<void> clearOfflineData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedRoutesKey);
      await prefs.remove(_emergencyContactsKey);
      await prefs.remove(_offlineMapKey);
    } catch (e) {
      print('Error clearing offline data: $e');
    }
  }
}
