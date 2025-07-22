import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

/// Debug utility to test real-time connection and database access
class RealtimeDebugger {
  static final _supabase = Supabase.instance.client;
  
  /// Test basic database connectivity and authentication
  static Future<Map<String, dynamic>> testDatabaseConnection() async {
    final results = <String, dynamic>{};
    
    try {
      // Test 1: Check authentication status
      final user = _supabase.auth.currentUser;
      results['auth_status'] = user != null ? 'authenticated' : 'anonymous';
      results['user_id'] = user?.id;
      results['user_email'] = user?.email;
      
      // Test 2: Try to query driver_trips directly
      final tripsResponse = await _supabase
          .from('driver_trips')
          .select('id, status, bus_number, created_at')
          .limit(5);
      
      results['direct_query_success'] = true;
      results['total_trips'] = tripsResponse.length;
      results['trips_sample'] = tripsResponse;
      
      // Test 3: Try to query active trips specifically
      final activeTripsResponse = await _supabase
          .from('driver_trips')
          .select('id, status, bus_number, route_id')
          .eq('status', 'active')
          .limit(10);
      
      results['active_trips_success'] = true;
      results['active_trips_count'] = activeTripsResponse.length;
      results['active_trips'] = activeTripsResponse;
      
    } catch (e) {
      results['error'] = e.toString();
      results['error_type'] = e.runtimeType.toString();
    }
    
    return results;
  }
  
  /// Test real-time subscription
  static Future<Map<String, dynamic>> testRealtimeSubscription() async {
    final results = <String, dynamic>{};
    
    try {
      // Test real-time subscription setup
      final stream = _supabase
          .from('driver_trips')
          .stream(primaryKey: ['id'])
          .eq('status', 'active');
      
      results['subscription_created'] = true;
      
      // Listen for 5 seconds to see if we get data
      final completer = Completer<List<Map<String, dynamic>>>();
      late StreamSubscription subscription;
      
      final timer = Timer(Duration(seconds: 5), () {
        if (!completer.isCompleted) {
          completer.complete([]);
        }
      });
      
      subscription = stream.listen(
        (data) {
          if (!completer.isCompleted) {
            completer.complete(data);
          }
        },
        onError: (error) {
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
      );
      
      final data = await completer.future;
      subscription.cancel();
      timer.cancel();
      
      results['realtime_data_received'] = true;
      results['realtime_trips_count'] = data.length;
      results['realtime_trips'] = data;
      
    } catch (e) {
      results['realtime_error'] = e.toString();
      results['realtime_error_type'] = e.runtimeType.toString();
    }
    
    return results;
  }
  
  /// Create a test active trip (for debugging only)
  static Future<Map<String, dynamic>> createTestTrip() async {
    final results = <String, dynamic>{};
    
    try {
      // First, get a route to use
      final routesResponse = await _supabase
          .from('routes')
          .select('id, route_name')
          .limit(1);
      
      if (routesResponse.isEmpty) {
        results['error'] = 'No routes found in database';
        return results;
      }
      
      final routeId = routesResponse.first['id'];
      final routeName = routesResponse.first['route_name'];
      
      // Create a test trip
      final testTrip = {
        'driver_id': _supabase.auth.currentUser?.id ?? '00000000-0000-0000-0000-000000000000',
        'route_id': routeId,
        'status': 'active',
        'start_time': DateTime.now().toIso8601String(),
        'bus_number': 'TEST-${DateTime.now().millisecondsSinceEpoch % 1000}',
      };
      
      final response = await _supabase
          .from('driver_trips')
          .insert(testTrip)
          .select()
          .single();
      
      results['test_trip_created'] = true;
      results['test_trip_id'] = response['id'];
      results['test_trip_bus_number'] = response['bus_number'];
      results['test_route_name'] = routeName;
      
    } catch (e) {
      results['create_error'] = e.toString();
      results['create_error_type'] = e.runtimeType.toString();
    }
    
    return results;
  }
  
  /// Clean up test trips
  static Future<Map<String, dynamic>> cleanupTestTrips() async {
    final results = <String, dynamic>{};
    
    try {
      final response = await _supabase
          .from('driver_trips')
          .delete()
          .like('bus_number', 'TEST-%')
          .select();
      
      results['cleanup_success'] = true;
      results['deleted_count'] = response.length;
      
    } catch (e) {
      results['cleanup_error'] = e.toString();
    }
    
    return results;
  }
}

/// Debug screen to test real-time functionality
class RealtimeDebugScreen extends StatefulWidget {
  @override
  _RealtimeDebugScreenState createState() => _RealtimeDebugScreenState();
}

class _RealtimeDebugScreenState extends State<RealtimeDebugScreen> {
  Map<String, dynamic>? _dbTestResults;
  Map<String, dynamic>? _realtimeTestResults;
  bool _isLoading = false;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Real-time Debug Console'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _testDatabaseConnection,
              child: Text('Test Database Connection'),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _testRealtimeSubscription,
              child: Text('Test Real-time Subscription'),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _createTestTrip,
              child: Text('Create Test Active Trip'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _cleanupTestTrips,
              child: Text('Cleanup Test Trips'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
            SizedBox(height: 16),
            if (_isLoading)
              Center(child: CircularProgressIndicator()),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_dbTestResults != null) ...[
                      Text('Database Test Results:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Container(
                        padding: EdgeInsets.all(8),
                        margin: EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(_formatResults(_dbTestResults!)),
                      ),
                    ],
                    if (_realtimeTestResults != null) ...[
                      Text('Real-time Test Results:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Container(
                        padding: EdgeInsets.all(8),
                        margin: EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(_formatResults(_realtimeTestResults!)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _testDatabaseConnection() async {
    setState(() => _isLoading = true);
    try {
      final results = await RealtimeDebugger.testDatabaseConnection();
      setState(() => _dbTestResults = results);
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _testRealtimeSubscription() async {
    setState(() => _isLoading = true);
    try {
      final results = await RealtimeDebugger.testRealtimeSubscription();
      setState(() => _realtimeTestResults = results);
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _createTestTrip() async {
    setState(() => _isLoading = true);
    try {
      final results = await RealtimeDebugger.createTestTrip();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(results['test_trip_created'] == true 
              ? 'Test trip created: ${results['test_trip_bus_number']}'
              : 'Failed to create test trip: ${results['create_error']}'),
          backgroundColor: results['test_trip_created'] == true ? Colors.green : Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _cleanupTestTrips() async {
    setState(() => _isLoading = true);
    try {
      final results = await RealtimeDebugger.cleanupTestTrips();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(results['cleanup_success'] == true 
              ? 'Cleaned up ${results['deleted_count']} test trips'
              : 'Cleanup failed: ${results['cleanup_error']}'),
          backgroundColor: results['cleanup_success'] == true ? Colors.green : Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  String _formatResults(Map<String, dynamic> results) {
    return results.entries.map((e) => '${e.key}: ${e.value}').join('\n');
  }
}
