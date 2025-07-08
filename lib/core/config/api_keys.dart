// This file should not be committed to version control
// Add api_keys.dart to .gitignore
class ApiKeys {
  // MapTiler for map tiles and styling
  static const String mapTilerApiKey = 'X2gh37rGOvC2FnGm7GYy';
  static const String mapLibreStyleUrl = 'https://api.maptiler.com/maps/streets/style.json?key=X2gh37rGOvC2FnGm7GYy';
  
  // OpenRouteService for routing
  static const String orsApiKey = '5b3ce3597851110001cf6248a0ac0e4cb1ac489fa0857d1c6fc7203e';
  
  // LocationIQ for geocoding
  static const String locationIqApiKey = 'pk.fae7bd442f3fe268d3f1bec213a2c6d6';
  
  // Validation methods
  static bool isValidMapTilerKey() {
    return mapTilerApiKey.isNotEmpty && mapTilerApiKey.length > 10;
  }
  
  static bool isValidOrsKey() {
    return orsApiKey.isNotEmpty && orsApiKey.length > 10;
  }
  
  static bool isValidLocationIqKey() {
    return locationIqApiKey.startsWith('pk.') && locationIqApiKey.length > 20;
  }
}
