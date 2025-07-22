import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/driver.dart';
import 'package:flutter/foundation.dart';

class DriverService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final String _table = 'drivers';
  
  List<Driver> _drivers = [];
  bool _isLoading = false;
  String? _error;

  List<Driver> get drivers => _drivers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Get all drivers regardless of college
  Future<void> getAllDrivers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from(_table)
          .select()
          .order('created_at', ascending: false);

      _drivers = response.map((data) => Driver.fromJson(data)).toList();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get drivers for a specific college
  List<Driver> getDriversForCollege(String collegeId) {
    return _drivers.where((driver) => driver.currentCollegeId == collegeId).toList();
  }

  // Load drivers
  Future<void> loadDrivers(String collegeId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _supabase
          .from(_table)
          .select()
          .eq('current_college_id', collegeId)
          .order('created_at', ascending: false);

      _drivers = response.map((data) => Driver.fromJson(data)).toList();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get all drivers
  Stream<List<Driver>> getDrivers() {
    return _supabase
        .from(_table)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((events) {
      return events.map((event) => Driver.fromJson(event)).toList();
    });
  }

  // Get a single driver by ID
  Future<Driver?> getDriver(String id) async {
    final response = await _supabase
        .from(_table)
        .select()
        .eq('id', id)
        .single();
    
    if (response != null) {
      return Driver.fromJson(response);
    }
    return null;
  }

  // Add a new driver
  Future<String> addDriver(Driver driver) async {
    final response = await _supabase
        .from(_table)
        .insert(driver.toJson())
        .select()
        .single();
    
    await loadDrivers(driver.currentCollegeId!);
    return response['id'] as String;
  }

  // Update a driver
  Future<void> updateDriver({
    required String id,
    required String name,
    required String phone,
    required bool isActive,
    required String? currentCollegeId,
  }) async {
    await _supabase
        .from(_table)
        .update({
          'name': name,
          'phone': phone,
          'is_active': isActive,
          'current_college_id': currentCollegeId,
        })
        .eq('id', id);

    // Since we updated the driver, reload the list to reflect changes
    if (currentCollegeId != null) {
      await loadDrivers(currentCollegeId);
    }
  }

  // Delete a driver
  Future<void> deleteDriver(String id) async {
    await _supabase
        .from(_table)
        .delete()
        .eq('id', id);
    
    _drivers.removeWhere((driver) => driver.id == id);
    notifyListeners();
  }

  // Toggle driver active status
  Future<void> toggleDriverStatus(String id, bool isActive) async {
    await _supabase
        .from(_table)
        .update({'is_active': isActive})
        .eq('id', id);
    
    final index = _drivers.indexWhere((driver) => driver.id == id);
    if (index != -1) {
      _drivers[index] = _drivers[index].copyWith(isActive: isActive);
      notifyListeners();
    }
  }

  // Update driver's current route
  Future<void> updateDriverRoute(String id, String? routeId) async {
    await _supabase
        .from(_table)
        .update({'current_route_id': routeId})
        .eq('id', id);
  }

  // Update driver's current college
  Future<void> updateDriverCollege(String id, String? collegeId) async {
    await _supabase
        .from(_table)
        .update({'current_college_id': collegeId})
        .eq('id', id);
  }

  // Update driver's last active timestamp
  Future<void> updateLastActive(String id) async {
    await _supabase
        .from(_table)
        .update({'last_active': DateTime.now().toIso8601String()})
        .eq('id', id);
  }
}