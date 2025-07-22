import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class FavoritesService {
  static const String _favoritesKey = 'favorite_routes';
  static FavoritesService? _instance;
  static FavoritesService get instance => _instance ??= FavoritesService._();
  
  FavoritesService._();
  
  Set<String> _favoriteRouteIds = <String>{};
  
  /// Initialize the service and load saved favorites
  Future<void> initialize() async {
    await _loadFavorites();
  }
  
  /// Get all favorite route IDs
  Set<String> get favoriteRouteIds => Set.from(_favoriteRouteIds);
  
  /// Check if a route is in favorites
  bool isFavorite(String routeId) {
    return _favoriteRouteIds.contains(routeId);
  }
  
  /// Add a route to favorites
  Future<void> addToFavorites(String routeId) async {
    _favoriteRouteIds.add(routeId);
    await _saveFavorites();
  }
  
  /// Remove a route from favorites
  Future<void> removeFromFavorites(String routeId) async {
    _favoriteRouteIds.remove(routeId);
    await _saveFavorites();
  }
  
  /// Toggle favorite status of a route
  Future<void> toggleFavorite(String routeId) async {
    if (isFavorite(routeId)) {
      await removeFromFavorites(routeId);
    } else {
      await addToFavorites(routeId);
    }
  }
  
  /// Get count of favorite routes
  int get favoriteCount => _favoriteRouteIds.length;
  
  /// Load favorites from local storage
  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = prefs.getString(_favoritesKey);
      
      if (favoritesJson != null) {
        final List<dynamic> favoritesList = jsonDecode(favoritesJson);
        _favoriteRouteIds = favoritesList.map((e) => e.toString()).toSet();
      }
    } catch (e) {
      print('Error loading favorites: $e');
      _favoriteRouteIds = <String>{};
    }
  }
  
  /// Save favorites to local storage
  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = jsonEncode(_favoriteRouteIds.toList());
      await prefs.setString(_favoritesKey, favoritesJson);
    } catch (e) {
      print('Error saving favorites: $e');
    }
  }
  
  /// Clear all favorites
  Future<void> clearAllFavorites() async {
    _favoriteRouteIds.clear();
    await _saveFavorites();
  }
}
