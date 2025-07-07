import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:provider/provider.dart';
import '../../../core/services/trip_service.dart';
import '../models/village_crossing.dart';
import '../../../core/constants/map_constants.dart';

class VillageTrackingController {
  Set<String> passedVillages = {};
  List<VillageCrossing> villageCrossings = [];
  Timer? villageCheckTimer;
  static const double villageCheckInterval = 500.0; // meters
  double lastVillageCheckDistance = 0.0;
  bool showVillageCrossingLog = false;

  // Callback for when a village is crossed
  final Function(VillageCrossing) onVillageCrossed;

  VillageTrackingController({required this.onVillageCrossed});

  // Check if the driver has crossed a village boundary
  Future<void> checkVillageCrossing(Position currentPosition,
      double distanceTraveled, BuildContext context) async {
    // Only check every 500 meters to avoid too frequent checks
    if (distanceTraveled - lastVillageCheckDistance < villageCheckInterval) {
      return;
    }
    lastVillageCheckDistance = distanceTraveled;

    try {
      // Use the TripService to get the village name and center
      final tripService = Provider.of<TripService>(context, listen: false);
      final latLng =
          latlong2.LatLng(currentPosition.latitude, currentPosition.longitude);
      final villageName = await tripService.getVillageName(latLng);
      if (villageName == null) return;
      final villageCenter = await tripService.getVillageCenter(villageName);
      if (villageCenter == null) return;
      final distance =
          const latlong2.Distance().distance(latLng, villageCenter);
      if (distance > MapConstants.villageDetectionRadius) return;
      if (passedVillages.contains(villageName)) return;

      // Add to passed villages set
      passedVillages.add(villageName);

      // Create a village crossing record
      final now = DateTime.now();
      final crossing = VillageCrossing(
        name: villageName,
        timestamp: now,
        latitude: currentPosition.latitude,
        longitude: currentPosition.longitude,
      );

      // Add to the list of crossings
      villageCrossings.add(crossing);

      // Notify listeners
      onVillageCrossed(crossing);
    } catch (e) {
      print('Error checking village crossing: $e');
    }
  }

  // Save village crossing to trip data
  Future<void> saveCrossingToTripData(
      VillageCrossing crossing, String? tripId) async {
    if (tripId == null) return;

    try {
      // This would be implemented to save the crossing to the trip data
      // For example, using a TripService to update the trip record
    } catch (e) {
      print('Error saving village crossing: $e');
    }
  }

  // Toggle village crossing log visibility
  void toggleVillageCrossingLog() {
    showVillageCrossingLog = !showVillageCrossingLog;
  }

  // Calculate traveled distance
  double calculateTraveledDistance(List<latlong2.LatLng> completedPoints) {
    if (completedPoints.isEmpty) return 0.0;

    double distance = 0.0;
    for (int i = 0; i < completedPoints.length - 1; i++) {
      distance += Geolocator.distanceBetween(
        completedPoints[i].latitude,
        completedPoints[i].longitude,
        completedPoints[i + 1].latitude,
        completedPoints[i + 1].longitude,
      );
    }

    return distance;
  }

  // Clear village tracking data
  void clearVillageTrackingData() {
    passedVillages.clear();
    villageCrossings.clear();
    lastVillageCheckDistance = 0.0;
  }

  // Dispose resources
  void dispose() {
    villageCheckTimer?.cancel();
  }
}
