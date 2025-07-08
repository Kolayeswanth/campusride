import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// This class provides utility methods to fix database inconsistencies
class DatabaseFixer {
  static final SupabaseClient _supabase = Supabase.instance.client;
  
  /// Call this method at app startup to ensure database is consistent
  static Future<void> fixDatabaseIssues() async {
    await _ensureUserProfilesExist();
  }
  
  /// Ensures that all referenced user profiles exist in the database
  static Future<void> _ensureUserProfilesExist() async {
    try {
      debugPrint('DatabaseFixer: Ensuring user profiles exist...');
      
      // Get all drivers first
      final driversResponse = await _supabase
          .from('drivers')
          .select('id, name, phone, user_id');
          
      if (driversResponse.isEmpty) {
        debugPrint('DatabaseFixer: No drivers found to check profiles for');
        return;
      }
      
      // For each driver, make sure their user profile exists
      for (final driver in driversResponse) {
        final userId = driver['user_id'];
        if (userId == null) {
          debugPrint('DatabaseFixer: Driver ${driver['id']} has no user_id');
          continue;
        }
        
        try {
          // Try to get the user profile
          final profile = await _supabase
              .from('user_profiles')
              .select()
              .eq('id', userId)
              .maybeSingle();
              
          // If profile doesn't exist, create it
          if (profile == null) {
            debugPrint('DatabaseFixer: Creating missing profile for user $userId');
            await _supabase.from('user_profiles').insert({
              'id': userId,
              'email': 'driver_${driver['id']}@example.com', // Placeholder
              'role': 'driver',
              'name': driver['name'] ?? 'Driver ${driver['id']}' // Use driver name if available
            });
          }
        } catch (e) {
          debugPrint('DatabaseFixer: Error ensuring profile for user $userId: $e');
        }
      }
      
      debugPrint('DatabaseFixer: User profile check completed');
    } catch (e) {
      debugPrint('DatabaseFixer: Error fixing database issues: $e');
    }
  }
}