import 'package:supabase/supabase.dart';
import 'dart:io';

/// Script to fix database schema issues
/// Run this with: dart run fix_database.dart
Future<void> main() async {
  print('Starting database schema fix...');
  
  // Get environment variables
  final supabaseUrl = Platform.environment['SUPABASE_URL'] ?? 
                     'https://lraiyjinbsjloqjvlqwl.supabase.co';
  final supabaseKey = Platform.environment['SUPABASE_ANON_KEY'] ?? 
                     'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxyYWl5amluYnNqbG9xanZscXdsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQzNDkyODgsImV4cCI6MjA1OTkyNTI4OH0.RvfjSaZSmX0EOmvvYOMOFeZ2x1pmg69hyeWNyOo4smE';
  
  // Initialize Supabase
  final supabase = SupabaseClient(supabaseUrl, supabaseKey);
  
  try {
    // First, let's check the current colleges table structure
    print('Checking colleges table structure...');
    final collegesResponse = await supabase.from('colleges').select('*').limit(5);
    print('Colleges data: $collegesResponse');
    
    // 1. Ensure colleges table has data
    print('Checking colleges table...');
    final collegesCountResponse = await supabase.from('colleges').select('id').limit(1);
    
    if (collegesCountResponse.isEmpty) {
      print('Inserting sample colleges...');
      // Check what type of ID the colleges table expects
      try {
        await supabase.from('colleges').insert([
          {'name': 'University of California, Berkeley', 'city': 'Berkeley', 'state': 'CA'},
        ]);
        print('Sample college inserted successfully');
      } catch (e) {
        print('Error inserting college: $e');
        // Try with integer ID
        try {
          await supabase.from('colleges').insert([
            {'id': 1, 'name': 'University of California, Berkeley', 'city': 'Berkeley', 'state': 'CA'},
          ]);
          print('Sample college with integer ID inserted successfully');
        } catch (e2) {
          print('Error inserting college with integer ID: $e2');
        }
      }
    } else {
      print('Colleges table already has data');
    }
    
    // Get the first college ID to use as default
    final firstCollegeResponse = await supabase.from('colleges').select('id').limit(1);
    final firstCollegeId = firstCollegeResponse.isNotEmpty ? firstCollegeResponse[0]['id'] : null;
    print('First college ID: $firstCollegeId (type: ${firstCollegeId.runtimeType})');
    
    // 2. Check if any profiles are missing college_id
    print('Checking profiles table...');
    final profilesResponse = await supabase
        .from('profiles')
        .select('id, college_id')
        .isFilter('college_id', null);
    
    if (profilesResponse.isNotEmpty && firstCollegeId != null) {
      print('Found ${profilesResponse.length} profiles without college_id. Updating...');
      for (final profile in profilesResponse) {
        await supabase
            .from('profiles')
            .update({'college_id': firstCollegeId})
            .eq('id', profile['id']);
      }
      print('Updated profiles with default college_id');
    } else {
      print('All profiles have college_id set or no default college available');
    }
    
    // 3. Update any 'unknown' roles to 'user'
    print('Updating unknown roles to user...');
    await supabase
        .from('profiles')
        .update({'role': 'user'})
        .eq('role', 'unknown');
    
    print('Database schema fix completed successfully!');
    
  } catch (e) {
    print('Error during database fix: $e');
  }
}
