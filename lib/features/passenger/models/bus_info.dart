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
  });

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
    );
  }
}
