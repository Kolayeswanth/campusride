import 'package:flutter/foundation.dart';
import 'location_point.dart';

class DriverLocation {
  final String driverId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? speed; // in km/h
  final double? heading; // in degrees
  final List<LocationPoint> routePoints;

  DriverLocation({
    required this.driverId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.speed,
    this.heading,
    this.routePoints = const [],
  });

  factory DriverLocation.fromJson(Map<String, dynamic> json) {
    return DriverLocation(
      driverId: json['driverId'] as String,
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      timestamp: DateTime.parse(json['timestamp'] as String),
      speed: json['speed'] as double?,
      heading: json['heading'] as double?,
      routePoints: (json['routePoints'] as List<dynamic>?)
          ?.map((e) => LocationPoint.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'driverId': driverId,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'speed': speed,
      'heading': heading,
      'routePoints': routePoints.map((e) => e.toJson()).toList(),
    };
  }

  DriverLocation copyWith({
    String? driverId,
    double? latitude,
    double? longitude,
    DateTime? timestamp,
    double? speed,
    double? heading,
    List<LocationPoint>? routePoints,
  }) {
    return DriverLocation(
      driverId: driverId ?? this.driverId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      routePoints: routePoints ?? this.routePoints,
    );
  }
} 