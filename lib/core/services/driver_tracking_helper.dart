import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// This helper fixes the issue with the profiles table name and structure
class DriverTrackingHelper {
  static Future<void> fixProfileQuery() async {
    try {
      // Get all drivers that need to be tracked
      final supabase = Supabase.instance.client;
      final drivers = await supabase
          .from('drivers')
          .select('id, user_id')
          .limit(100);
          
      // For each driver, ensure we can get their profile from the correct table
      for (final driver in drivers) {
        try {
          await supabase
              .from('profiles')
              .select('id, email, display_name')
              .eq('id', driver['user_id'])
              .limit(1);
        } catch (e) {
          debugPrint('Could not fetch profile for driver ${driver['user_id']}: $e');
          
          // If needed, create or update the user profile entry
          try {
            await supabase.from('profiles').upsert({
              'id': driver['user_id'],
              'email': 'driver_${driver['id']}@example.com', // Placeholder
              'role': 'driver',
              'display_name': 'Driver ${driver['id']}' // Default name
            });
            debugPrint('Created profile for driver ${driver['user_id']}');
          } catch (e) {
            debugPrint('Failed to create profile for driver ${driver['user_id']}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error in fixProfileQuery: $e');
    }
  }
}