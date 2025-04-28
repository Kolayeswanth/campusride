import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
  });

  factory BusInfo.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    GeoPoint geoPoint = data['currentLocation'] as GeoPoint;
    
    return BusInfo(
      busId: doc.id,
      driverId: data['driverId'] ?? '',
      currentLocation: LatLng(geoPoint.latitude, geoPoint.longitude),
      destination: data['destination'] ?? '',
      estimatedTime: data['estimatedTime'] ?? '',
      estimatedDistance: data['estimatedDistance'] ?? '',
      isActive: data['isActive'] ?? false,
      routeNumber: data['routeNumber'] ?? '',
      availableSeats: data['availableSeats'] ?? 0,
      lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
    );
  }
} 