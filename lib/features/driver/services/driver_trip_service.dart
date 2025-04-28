import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'dart:async';

class DriverTripService {
  final Function(bool) onTripStatusChange;
  final Function(double) onCompletionUpdate;
  final Function(bool) onDestinationReached;
  
  Timer? _locationUpdateTimer;
  Timer? _speedUpdateTimer;
  List<latlong2.LatLng> _completedPoints = [];
  double _lastDeviationCheckDistance = 0.0;
  static const double _deviationCheckInterval = 100.0; // meters

  DriverTripService({
    required this.onTripStatusChange,
    required this.onCompletionUpdate,
    required this.onDestinationReached,
  });

  void startTrip() {
    _completedPoints.clear();
    _lastDeviationCheckDistance = 0.0;
    onTripStatusChange(true);
    
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateTripStatus(),
    );
  }

  void stopTrip() {
    _locationUpdateTimer?.cancel();
    _speedUpdateTimer?.cancel();
    _completedPoints.clear();
    onTripStatusChange(false);
  }

  void _updateTripStatus() {
    // This method would be called by the location service
    // to update trip status, completion, and check for destination
  }

  void updateTripProgress(
    Position currentPosition,
    latlong2.LatLng destination,
    List<latlong2.LatLng> routePoints,
  ) {
    _completedPoints.add(latlong2.LatLng(
      currentPosition.latitude,
      currentPosition.longitude,
    ));

    // Calculate completion percentage
    final totalDistance = _calculateTotalRouteDistance(routePoints);
    final traveledDistance = _calculateTraveledDistance();
    final completion = totalDistance > 0 ? (traveledDistance / totalDistance) : 0.0;
    onCompletionUpdate(completion);

    // Check for destination
    final distanceToDestination = Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      destination.latitude,
      destination.longitude,
    );

    if (distanceToDestination < 50) {
      onDestinationReached(true);
      stopTrip();
    }
  }

  double _calculateTotalRouteDistance(List<latlong2.LatLng> routePoints) {
    double totalDistance = 0.0;
    
    if (routePoints.length < 2) return 0.0;
    
    for (int i = 0; i < routePoints.length - 1; i++) {
      final p1 = routePoints[i];
      final p2 = routePoints[i + 1];
      
      totalDistance += Geolocator.distanceBetween(
        p1.latitude, p1.longitude,
        p2.latitude, p2.longitude,
      );
    }
    
    return totalDistance;
  }

  double _calculateTraveledDistance() {
    if (_completedPoints.isEmpty) return 0.0;
    
    double distance = 0.0;
    for (int i = 0; i < _completedPoints.length - 1; i++) {
      final p1 = _completedPoints[i];
      final p2 = _completedPoints[i + 1];
      
      distance += Geolocator.distanceBetween(
        p1.latitude, p1.longitude,
        p2.latitude, p2.longitude,
      );
    }
    
    return distance;
  }

  bool shouldCheckDeviation(double distanceTraveled) {
    if (distanceTraveled - _lastDeviationCheckDistance >= _deviationCheckInterval) {
      _lastDeviationCheckDistance = distanceTraveled;
      return true;
    }
    return false;
  }

  void dispose() {
    _locationUpdateTimer?.cancel();
    _speedUpdateTimer?.cancel();
  }
} 