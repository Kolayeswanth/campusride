import 'package:supabase_flutter/supabase_flutter.dart';

class Route {
  final String id;
  final String name; // This is now the main name field (was busNumber)
  final Map<String, dynamic> startLocation; // JSONB in the database
  final Map<String, dynamic> endLocation; // JSONB in the database
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? collegeCode; // Changed from collegeId
  final String? driverId;
  
  // Getter for backward compatibility
  String get busNumber => name;
  
  // Getter for backward compatibility
  String? get collegeId => collegeCode;
  
  // Derived getters for location components
  String get startLocationName => startLocation['name'] as String? ?? '';
  double get startLatitude => startLocation['latitude'] as double? ?? 0.0;
  double get startLongitude => startLocation['longitude'] as double? ?? 0.0;
  
  String get endLocationName => endLocation['name'] as String? ?? '';
  double get endLatitude => endLocation['latitude'] as double? ?? 0.0;
  double get endLongitude => endLocation['longitude'] as double? ?? 0.0;

  Route({
    required this.id,
    required this.name,
    required this.startLocation,
    required this.endLocation,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.collegeCode,
    this.driverId,
  });

  factory Route.fromJson(Map<String, dynamic> json) {
    // Handle both old and new schema formats
    Map<String, dynamic> parseLocation(dynamic location, String fallbackName, double? fallbackLat, double? fallbackLng) {
      if (location is Map) {
        return location as Map<String, dynamic>;
      } else if (location is String) {
        // Handle old schema format
        return {
          'name': location,
          'latitude': fallbackLat ?? 0.0,
          'longitude': fallbackLng ?? 0.0
        };
      } else {
        return {
          'name': fallbackName,
          'latitude': fallbackLat ?? 0.0,
          'longitude': fallbackLng ?? 0.0
        };
      }
    }
    
    // Get start location data
    final startLocation = parseLocation(
      json['start_location'], 
      json['start_location'] as String? ?? '',
      json['start_latitude'] as double?,
      json['start_longitude'] as double?
    );
    
    // Get end location data
    final endLocation = parseLocation(
      json['end_location'],
      json['end_location'] as String? ?? '',
      json['end_latitude'] as double?,
      json['end_longitude'] as double?
    );
    
    // Determine the name (prioritize name field, fall back to bus_number)
    final name = json['name'] as String? ?? json['bus_number'] as String? ?? '';
    
    // Determine active status (check both is_active and active fields)
    final isActive = json['is_active'] as bool? ?? json['active'] as bool? ?? false;
    
    // Determine college code/id (check both college_code and college_id fields)
    final collegeCode = json['college_code'] as String? ?? json['college_id'] as String?;
    
    return Route(
      id: json['id'] as String? ?? '',
      name: name,
      startLocation: startLocation,
      endLocation: endLocation,
      isActive: isActive,
      createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] as String? ?? DateTime.now().toIso8601String()),
      collegeCode: collegeCode,
      driverId: json['driver_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'start_location': startLocation,
      'end_location': endLocation,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'college_code': collegeCode,
      'driver_id': driverId,
    };
  }

  Route copyWith({
    String? id,
    String? name,
    Map<String, dynamic>? startLocation,
    Map<String, dynamic>? endLocation,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? collegeCode,
    String? driverId,
  }) {
    return Route(
      id: id ?? this.id,
      name: name ?? this.name,
      startLocation: startLocation ?? this.startLocation,
      endLocation: endLocation ?? this.endLocation,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      collegeCode: collegeCode ?? this.collegeCode,
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