// This file should not be committed to version control
// Add api_keys.dart to .gitignore
class ApiKeys {
  // Ola Maps API - Primary service for routing, geocoding, and map tiles
  static const String olaMapsApiKey = 'u8bxvlb9ubgP2wKgJyxEY2ya1hYNcvyxFDCpA85y'; // Replace with your actual Ola Maps API key
  
  // MapTiler for fallback map tiles (can be removed if Ola Maps tiles are used)
  static const String mapTilerApiKey = 'X2gh37rGOvC2FnGm7GYy';
  static const String mapLibreStyleUrl = 'https://api.maptiler.com/maps/streets/style.json?key=X2gh37rGOvC2FnGm7GYy';
  
  // Validation methods
  static bool isValidOlaMapsKey() {
    return olaMapsApiKey.isNotEmpty && 
           olaMapsApiKey != 'YOUR_OLA_MAPS_API_KEY_HERE' && 
           olaMapsApiKey.length > 10;
  }
  
  static bool isValidMapTilerKey() {
    return mapTilerApiKey.isNotEmpty && mapTilerApiKey.length > 10;
  }
  
  // Legacy validation methods (deprecated)
  @Deprecated('Use isValidOlaMapsKey() instead')
  static bool isValidOrsKey() {
    return false; // Always return false to force migration to Ola Maps
  }
  
  @Deprecated('Use isValidOlaMapsKey() instead')
  static bool isValidLocationIqKey() {
    return false; // Always return false to force migration to Ola Maps
  }
}
