import 'package:latlong2/latlong.dart';

class BusInfo {
  final String busId;
  final String driverId;
  final LatLng currentLocation;
  final String destination;
  final String estimatedTime;
  final String estimatedDistance;
  final bool isActive;
  final String routeNumber;
  final int availableSeats;
  final DateTime lastUpdated;
  final String? routeId;

  // Additional properties for the new bus tracking system
  final String? busNumber;
  final String? tripId;
  final LatLng? lastLocation;
  final DateTime? lastUpdateTime;
  final String? routeName;
  final String? fromDestination;
  final String? toDestination;

  BusInfo({
    required this.busId,
    required this.driverId,
    required this.currentLocation,
    required this.destination,
    required this.estimatedTime,
    required this.estimatedDistance,
    required this.isActive,
    required this.routeNumber,
    required this.availableSeats,
    required this.lastUpdated,
    this.routeId,
    this.busNumber,
    this.tripId,
    this.lastLocation,
    this.lastUpdateTime,
    this.routeName,
    this.fromDestination,
    this.toDestination,
  });

  // Factory constructor for new bus tracking system
  factory BusInfo.fromActiveTrip({
    required String busNumber,
    required String routeId,
    required String? driverId,
    required String? tripId,
    required bool isActive,
    required LatLng? lastLocation,
    required DateTime lastUpdateTime,
    required String routeName,
    String? fromDestination,
    String? toDestination,
  }) {
    return BusInfo(
      busId: tripId ?? '',
      driverId: driverId ?? '',
      currentLocation: lastLocation ?? LatLng(0, 0),
      destination: toDestination ?? routeName,
      estimatedTime: '',
      estimatedDistance: '',
      isActive: isActive,
      routeNumber: busNumber,
      availableSeats: 0,
      lastUpdated: lastUpdateTime,
      routeId: routeId,
      busNumber: busNumber,
      tripId: tripId,
      lastLocation: lastLocation,
      lastUpdateTime: lastUpdateTime,
      routeName: routeName,
      fromDestination: fromDestination,
      toDestination: toDestination,
    );
  }

  factory BusInfo.fromJson(Map<String, dynamic> json) {
    return BusInfo(
      busId: json['id'] ?? json['bus_id'] ?? '',
      driverId: json['driver_id'] ?? '',
      currentLocation:
          LatLng(json['latitude'] ?? 0.0, json['longitude'] ?? 0.0),
      destination: json['destination'] ?? '',
      estimatedTime: json['estimated_time'] ?? '',
      estimatedDistance: json['estimated_distance'] ?? '',
      isActive: json['is_active'] ?? false,
      routeNumber: json['route_number'] ?? '',
      availableSeats: json['available_seats'] ?? 0,
      lastUpdated: json['last_updated'] != null
          ? DateTime.parse(json['last_updated'])
          : DateTime.now(),
      routeId: json['route_id'],
      busNumber: json['bus_number'],
      tripId: json['trip_id'],
      routeName: json['route_name'],
      fromDestination: json['from_destination'],
      toDestination: json['to_destination'],
    );
  }
}
