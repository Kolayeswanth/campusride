import 'package:supabase_flutter/supabase_flutter.dart';

class Bus {
  final String id;
  final String busNumber;
  final int capacity;
  final double? lastLocationLatitude;
  final double? lastLocationLongitude;
  final DateTime? lastLocationUpdatedAt;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Bus({
    required this.id,
    required this.busNumber,
    required this.capacity,
    this.lastLocationLatitude,
    this.lastLocationLongitude,
    this.lastLocationUpdatedAt,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Bus.fromJson(Map<String, dynamic> json) {
    return Bus(
      id: json['id'] as String,
      busNumber: json['bus_number'] as String,
      capacity: json['capacity'] as int,
      lastLocationLatitude: json['last_location_latitude'] as double?,
      lastLocationLongitude: json['last_location_longitude'] as double?,
      lastLocationUpdatedAt: json['last_location_updated_at'] != null
          ? DateTime.parse(json['last_location_updated_at'] as String)
          : null,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bus_number': busNumber,
      'capacity': capacity,
      'last_location_latitude': lastLocationLatitude,
      'last_location_longitude': lastLocationLongitude,
      'last_location_updated_at': lastLocationUpdatedAt?.toIso8601String(),
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Bus copyWith({
    String? id,
    String? busNumber,
    int? capacity,
    double? lastLocationLatitude,
    double? lastLocationLongitude,
    DateTime? lastLocationUpdatedAt,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Bus(
      id: id ?? this.id,
      busNumber: busNumber ?? this.busNumber,
      capacity: capacity ?? this.capacity,
      lastLocationLatitude: lastLocationLatitude ?? this.lastLocationLatitude,
      lastLocationLongitude: lastLocationLongitude ?? this.lastLocationLongitude,
      lastLocationUpdatedAt: lastLocationUpdatedAt ?? this.lastLocationUpdatedAt,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
} 