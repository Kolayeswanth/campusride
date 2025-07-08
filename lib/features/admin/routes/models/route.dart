import 'package:supabase_flutter/supabase_flutter.dart';

class Route {
  final String id;
  final String busNumber;
  final String startLocation;
  final String endLocation;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? collegeId;
  final String? driverId;
  final String? name;
  final String? description;

  Route({
    required this.id,
    required this.busNumber,
    required this.startLocation,
    required this.endLocation,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.collegeId,
    this.driverId,
    this.name,
    this.description,
  });

  factory Route.fromJson(Map<String, dynamic> json) {
    return Route(
      id: json['id'] as String? ?? '',
      busNumber: json['bus_number'] as String? ?? '',
      startLocation: json['start_location'] as String? ?? '',
      endLocation: json['end_location'] as String? ?? '',
      isActive: json['active'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      collegeId: json['college_id'] as String?,
      driverId: json['driver_id'] as String?,
      name: json['name'] as String?,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bus_number': busNumber,
      'start_location': startLocation,
      'end_location': endLocation,
      'active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'college_id': collegeId,
      'driver_id': driverId,
      'name': name,
      'description': description,
    };
  }

  Route copyWith({
    String? id,
    String? busNumber,
    String? startLocation,
    String? endLocation,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? collegeId,
    String? driverId,
  }) {
    return Route(
      id: id ?? this.id,
      busNumber: busNumber ?? this.busNumber,
      startLocation: startLocation ?? this.startLocation,
      endLocation: endLocation ?? this.endLocation,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      collegeId: collegeId ?? this.collegeId,
      driverId: driverId ?? this.driverId,
    );
  }
}

class RouteStop {
  final String name;
  final double latitude;
  final double longitude;
  final int order;
  final int estimatedTimeMinutes;

  RouteStop({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.order,
    required this.estimatedTimeMinutes,
  });

  factory RouteStop.fromJson(Map<String, dynamic> json) {
    return RouteStop(
      name: json['name'] as String,
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      order: json['order'] as int,
      estimatedTimeMinutes: json['estimated_time_minutes'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'order': order,
      'estimated_time_minutes': estimatedTimeMinutes,
    };
  }
} 