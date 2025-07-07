import 'package:flutter/foundation.dart';
import '../models/driver.dart';

class DriverService extends ChangeNotifier {
  // Using a map to store drivers by collegeId for easier access
  final Map<String, List<Driver>> _driversByCollege = {};
  bool _isLoading = false;
  String? _error;

  // Getter to get drivers for a specific college
  List<Driver> getDriversForCollege(String collegeId) {
    return _driversByCollege[collegeId] ?? [];
  }

  bool get isLoading => _isLoading;
  String? get error => _error;

  // Method to load drivers for a specific college
  Future<void> loadDrivers(String collegeId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Simulate API call to fetch drivers for a college
      await Future.delayed(const Duration(seconds: 1));

      // Sample data for drivers (replace with actual data fetching)
      final List<Driver> fetchedDrivers = [
        Driver(
          id: 'driver1',
          collegeId: collegeId,
          name: 'John Doe',
          phone: '+91 9876543210',
          license: 'DL12345',
          createdAt: DateTime.now(),
        ),
        Driver(
          id: 'driver2',
          collegeId: collegeId,
          name: 'Jane Smith',
          phone: '+91 9876543211',
          license: 'DL67890',
          isActive: false,
          createdAt: DateTime.now(),
        ),
      ];

      _driversByCollege[collegeId] = fetchedDrivers;

    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Method to add a new driver
  Future<void> addDriver(Driver driver) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Simulate API call to add driver
      await Future.delayed(const Duration(seconds: 1));
      
      // Add driver to the list for the specific college
      _driversByCollege.update(
        driver.collegeId,
        (list) { list.add(driver); return list; },
        ifAbsent: () => [driver],
      );

    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Method to update an existing driver
  Future<void> updateDriver(Driver driver) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Simulate API call to update driver
      await Future.delayed(const Duration(seconds: 1));

      // Find and update the driver
      final List<Driver>? collegeDrivers = _driversByCollege[driver.collegeId];
      if (collegeDrivers != null) {
        final index = collegeDrivers.indexWhere((d) => d.id == driver.id);
        if (index != -1) {
          collegeDrivers[index] = driver;
        }
      }

    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Method to delete a driver
  Future<void> deleteDriver(String collegeId, String driverId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Simulate API call to delete driver
      await Future.delayed(const Duration(seconds: 1));

      // Remove driver
      _driversByCollege[collegeId]?.removeWhere((d) => d.id == driverId);

    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Method to toggle driver active status (example)
  Future<void> toggleDriverStatus(String collegeId, String driverId, bool isActive) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Simulate API call to update driver status
      await Future.delayed(const Duration(seconds: 1));

      // Find and update the driver status
      final List<Driver>? collegeDrivers = _driversByCollege[collegeId];
      if (collegeDrivers != null) {
        final index = collegeDrivers.indexWhere((d) => d.id == driverId);
        if (index != -1) {
          collegeDrivers[index] = collegeDrivers[index].copyWith(isActive: isActive);
        }
      }

    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
} 