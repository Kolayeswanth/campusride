import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A utility class to initialize the database tables in Supabase
class InitDatabase {
  static final _supabase = Supabase.instance.client;

  /// Initialize all required tables for the app
  static Future<void> initializeDatabase(BuildContext context) async {
    try {
      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          title: Text('Initializing Database'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Creating required tables...'),
            ],
          ),
        ),
      );

      // Create user_profiles table
      await _createUserProfilesTable();

      // Create driver_verification table
      await _createDriverVerificationTable();

      // Create buses table with sample data
      await _createBusesTable();

      // Create routes table with sample data
      await _createRoutesTable();

      // Create driver_trips table
      await _createDriverTripsTable();

      // Create bus_locations table
      await _createBusLocationsTable();

      // Close the dialog
      Navigator.of(context).pop();

      // Show success dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Database Initialized'),
          content:
              const Text('All required tables have been created successfully.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      // Close the progress dialog
      Navigator.of(context).pop();

      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Failed to initialize database: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  /// Create user_profiles table
  static Future<void> _createUserProfilesTable() async {
    // Check if table exists
    try {
      await _supabase.rpc('create_user_profiles_table');
    } catch (e) {
      print('Error creating user_profiles table: $e');
      // If RPC doesn't exist, use SQL query directly
      const query = '''
      CREATE TABLE IF NOT EXISTS user_profiles (
        id UUID REFERENCES auth.users(id) PRIMARY KEY,
        email TEXT NOT NULL,
        role TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      );
      ''';

      await _executeSql(query);
    }

    // Apply RLS
    const rlsQuery = '''
    ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
    
    DROP POLICY IF EXISTS "Users can view their own profile" ON user_profiles;
    CREATE POLICY "Users can view their own profile" 
    ON user_profiles FOR SELECT 
    USING (auth.uid() = id);
    
    DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
    CREATE POLICY "Users can update their own profile" 
    ON user_profiles FOR UPDATE 
    USING (auth.uid() = id);
    
    DROP POLICY IF EXISTS "Users can insert their own profile" ON user_profiles;
    CREATE POLICY "Users can insert their own profile" 
    ON user_profiles FOR INSERT 
    WITH CHECK (auth.uid() = id);
    ''';

    await _executeSql(rlsQuery);
  }

  /// Create driver_verification table
  static Future<void> _createDriverVerificationTable() async {
    const query = '''
    CREATE TABLE IF NOT EXISTS driver_verification (
      id SERIAL PRIMARY KEY,
      user_id UUID REFERENCES auth.users(id) NOT NULL,
      driver_id TEXT NOT NULL,
      license_number TEXT NOT NULL,
      is_verified BOOLEAN DEFAULT false,
      verified_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );
    
    ALTER TABLE driver_verification ENABLE ROW LEVEL SECURITY;
    
    DROP POLICY IF EXISTS "Drivers can insert their verification data" ON driver_verification;
    CREATE POLICY "Drivers can insert their verification data" 
    ON driver_verification FOR INSERT 
    WITH CHECK (auth.uid() = user_id);
    
    DROP POLICY IF EXISTS "Drivers can view their verification status" ON driver_verification;
    CREATE POLICY "Drivers can view their verification status" 
    ON driver_verification FOR SELECT 
    USING (auth.uid() = user_id);
    ''';

    await _executeSql(query);
  }

  /// Create buses table
  static Future<void> _createBusesTable() async {
    const query = '''
    CREATE TABLE IF NOT EXISTS buses (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      capacity INTEGER NOT NULL,
      status TEXT DEFAULT 'active',
      created_at TIMESTAMPTZ DEFAULT NOW()
    );
    
    -- Insert sample buses if none exist
    INSERT INTO buses (id, name, capacity, status)
    SELECT 'BUS001', 'Campus Express', 40, 'active'
    WHERE NOT EXISTS (SELECT 1 FROM buses WHERE id = 'BUS001');
    
    INSERT INTO buses (id, name, capacity, status)
    SELECT 'BUS002', 'Science Shuttle', 30, 'active'
    WHERE NOT EXISTS (SELECT 1 FROM buses WHERE id = 'BUS002');
    
    INSERT INTO buses (id, name, capacity, status)
    SELECT 'BUS003', 'Library Link', 25, 'active'
    WHERE NOT EXISTS (SELECT 1 FROM buses WHERE id = 'BUS003');
    ''';

    await _executeSql(query);
  }

  /// Create routes table
  static Future<void> _createRoutesTable() async {
    const query = '''
    CREATE TABLE IF NOT EXISTS routes (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      start_location TEXT NOT NULL,
      end_location TEXT NOT NULL,
      stops JSONB, -- Array of stops with coordinates
      schedule JSONB, -- Schedule information
      created_at TIMESTAMPTZ DEFAULT NOW()
    );
    
    -- Insert sample routes if none exist
    INSERT INTO routes (id, name, start_location, end_location, stops, schedule)
    SELECT 
      'ROUTE001', 
      'Main Campus Loop', 
      'Student Center', 
      'Student Center', 
      '[
        {"name": "Student Center", "lat": 33.7756, "lng": -84.3963},
        {"name": "Library", "lat": 33.7747, "lng": -84.3957},
        {"name": "Science Building", "lat": 33.7765, "lng": -84.3975},
        {"name": "Dormitories", "lat": 33.7738, "lng": -84.3985}
      ]'::jsonb,
      '{
        "weekdays": ["7:00 AM", "8:00 AM", "9:00 AM", "10:00 AM", "11:00 AM", "12:00 PM", "1:00 PM", "2:00 PM", "3:00 PM", "4:00 PM", "5:00 PM"],
        "weekends": ["9:00 AM", "11:00 AM", "1:00 PM", "3:00 PM", "5:00 PM"]
      }'::jsonb
    WHERE NOT EXISTS (SELECT 1 FROM routes WHERE id = 'ROUTE001');
    
    INSERT INTO routes (id, name, start_location, end_location, stops, schedule)
    SELECT 
      'ROUTE002', 
      'Express Shuttle', 
      'North Campus', 
      'South Campus', 
      '[
        {"name": "North Campus", "lat": 33.7780, "lng": -84.3980},
        {"name": "Engineering Building", "lat": 33.7760, "lng": -84.3970},
        {"name": "Student Center", "lat": 33.7756, "lng": -84.3963},
        {"name": "South Campus", "lat": 33.7730, "lng": -84.3960}
      ]'::jsonb,
      '{
        "weekdays": ["7:30 AM", "8:30 AM", "9:30 AM", "10:30 AM", "11:30 AM", "12:30 PM", "1:30 PM", "2:30 PM", "3:30 PM", "4:30 PM"],
        "weekends": ["10:00 AM", "12:00 PM", "2:00 PM", "4:00 PM"]
      }'::jsonb
    WHERE NOT EXISTS (SELECT 1 FROM routes WHERE id = 'ROUTE002');
    ''';

    await _executeSql(query);
  }

  /// Create driver_trips table
  static Future<void> _createDriverTripsTable() async {
    const query = '''
    CREATE TABLE IF NOT EXISTS driver_trips (
      id TEXT PRIMARY KEY,
      driver_id UUID REFERENCES auth.users(id) NOT NULL,
      bus_id TEXT REFERENCES buses(id) NOT NULL,
      route_name TEXT NOT NULL,
      start_time TIMESTAMPTZ NOT NULL,
      end_time TIMESTAMPTZ,
      is_active BOOLEAN DEFAULT true,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );
    
    ALTER TABLE driver_trips ENABLE ROW LEVEL SECURITY;
    
    DROP POLICY IF EXISTS "Drivers can view their own trips" ON driver_trips;
    CREATE POLICY "Drivers can view their own trips" 
    ON driver_trips FOR SELECT 
    USING (auth.uid() = driver_id);
    
    DROP POLICY IF EXISTS "Drivers can insert their own trips" ON driver_trips;
    CREATE POLICY "Drivers can insert their own trips" 
    ON driver_trips FOR INSERT 
    WITH CHECK (auth.uid() = driver_id);
    
    DROP POLICY IF EXISTS "Drivers can update their own trips" ON driver_trips;
    CREATE POLICY "Drivers can update their own trips" 
    ON driver_trips FOR UPDATE 
    USING (auth.uid() = driver_id);
    ''';

    await _executeSql(query);
  }

  /// Create bus_locations table
  static Future<void> _createBusLocationsTable() async {
    const query = '''
    CREATE TABLE IF NOT EXISTS bus_locations (
      id SERIAL PRIMARY KEY,
      bus_id TEXT REFERENCES buses(id) NOT NULL,
      driver_id UUID REFERENCES auth.users(id) NOT NULL,
      latitude DOUBLE PRECISION NOT NULL,
      longitude DOUBLE PRECISION NOT NULL,
      heading DOUBLE PRECISION,
      speed DOUBLE PRECISION,
      timestamp TIMESTAMPTZ DEFAULT NOW()
    );
    
    ALTER TABLE bus_locations ENABLE ROW LEVEL SECURITY;
    
    DROP POLICY IF EXISTS "Drivers can insert bus locations" ON bus_locations;
    CREATE POLICY "Drivers can insert bus locations" 
    ON bus_locations FOR INSERT 
    WITH CHECK (auth.uid() = driver_id);
    
    DROP POLICY IF EXISTS "Anyone can view bus locations" ON bus_locations;
    CREATE POLICY "Anyone can view bus locations" 
    ON bus_locations FOR SELECT 
    USING (true);
    ''';

    await _executeSql(query);
  }

  /// Helper method to execute SQL queries
  static Future<void> _executeSql(String sql) async {
    try {
      await _supabase.from('_dummy_for_sql').select().limit(1);
    } catch (e) {
      // Creating dummy table to use for SQL execution
      await _supabase.rpc('exec_sql', params: {
        'sql': 'CREATE TABLE IF NOT EXISTS _dummy_for_sql (id integer)'
      });
    }

    await _supabase.rpc('exec_sql', params: {'sql': sql});
  }
}
