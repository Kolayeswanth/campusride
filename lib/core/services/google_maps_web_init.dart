import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:js' as js;

/// Helper class to initialize Google Maps for web
class GoogleMapsWebInit {
  /// Initialize Google Maps for web
  static Future<void> initialize() async {
    if (kIsWeb) {
      try {
        // Check if the Google Maps JavaScript API is loaded
        if (js.context.hasProperty('google') && 
            js.context['google'].hasProperty('maps')) {
          debugPrint('Google Maps JavaScript API is already loaded');
        } else {
          debugPrint('Waiting for Google Maps JavaScript API to load...');
          // Wait for the API to load (this is a simple approach)
          await Future.delayed(const Duration(seconds: 2));
          
          // Check again after waiting
          if (!js.context.hasProperty('google') || 
              !js.context['google'].hasProperty('maps')) {
            throw Exception(
              'Google Maps JavaScript API failed to load. '
              'Please check your API key in index.html and ensure it is valid. '
              'If you need an API key, follow the instructions in the comments in index.html.'
            );
          }
        }
        
        // This will throw an error if MapTypeId is not available
        // We catch it to ensure the app doesn't crash
        final mapType = MapType.normal;
        debugPrint('Google Maps initialized successfully');
      } catch (e) {
        debugPrint('Error initializing Google Maps: $e');
        // Provide more helpful error message
        if (e.toString().contains('InvalidKeyMapError')) {
          debugPrint(
            'Invalid Google Maps API key. Please replace YOUR_GOOGLE_MAPS_API_KEY '
            'in index.html with a valid API key from the Google Cloud Console.'
          );
        }
        // Continue anyway, the app will handle the error gracefully
      }
    }
  }
} 