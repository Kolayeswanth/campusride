import 'package:flutter/material.dart';
import '../models/village_crossing.dart';

class DriverDashboardState extends ChangeNotifier {
  // UI state
  bool isLoading = true;
  bool isTracking = false;
  bool isTripStarted = false;
  bool hasReachedDestination = false;
  String? error;
  String? driverId;
  bool isEditingDriverId = false;
  bool isUIVisible = true;
  bool isManualControl = false;
  bool showStartClearIcon = false;
  bool showDestClearIcon = false;

  // Trip state
  String? tripId;

  // Text controllers
  final TextEditingController startLocationController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();
  final TextEditingController driverIdController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  // Initialize state
  void initialize() {
    driverIdController.text = driverId ?? '';
  }

  // Set loading state
  void setLoading(bool loading) {
    isLoading = loading;
    notifyListeners();
  }

  // Set error state
  void setError(String? errorMessage) {
    error = errorMessage;
    notifyListeners();
  }

  // Set driver ID
  void setDriverId(String id) {
    driverId = id;
    driverIdController.text = id;
    notifyListeners();
  }

  // Toggle driver ID editing
  void toggleDriverIdEditing() {
    isEditingDriverId = !isEditingDriverId;
    notifyListeners();
  }

  // Toggle UI visibility
  void toggleUIVisibility() {
    isUIVisible = !isUIVisible;
    isManualControl = !isUIVisible;
    notifyListeners();
  }

  // Set manual control
  void setManualControl(bool manual) {
    isManualControl = manual;
    notifyListeners();
  }

  // Start trip
  void startTrip(String id) {
    tripId = id;
    isTripStarted = true;
    isTracking = true;
    notifyListeners();
  }

  // End trip
  void endTrip() {
    isTripStarted = false;
    isTracking = false;
    hasReachedDestination = false;
    tripId = null;
    notifyListeners();
  }

  // Set destination reached
  void setDestinationReached(bool reached) {
    hasReachedDestination = reached;
    notifyListeners();
  }

  // Update start location text
  void updateStartLocation(String location) {
    startLocationController.text = location;
    showStartClearIcon = location.isNotEmpty;
    notifyListeners();
  }

  // Update destination text
  void updateDestination(String destination) {
    destinationController.text = destination;
    showDestClearIcon = destination.isNotEmpty;
    notifyListeners();
  }

  // Clear start location
  void clearStartLocation() {
    startLocationController.clear();
    showStartClearIcon = false;
    notifyListeners();
  }

  // Clear destination
  void clearDestination() {
    destinationController.clear();
    showDestClearIcon = false;
    notifyListeners();
  }

  // Handle village crossing
  void handleVillageCrossing(VillageCrossing crossing) {
    // This would be implemented to handle village crossing events
    notifyListeners();
  }

  @override
  void dispose() {
    startLocationController.dispose();
    destinationController.dispose();
    driverIdController.dispose();
    searchController.dispose();
    super.dispose();
  }
}
