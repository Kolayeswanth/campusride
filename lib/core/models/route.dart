import 'package:latlong2/latlong.dart';

/// Model for a Bus Route Stop
class RouteStop {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int sequence;

  RouteStop({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.sequence,
  });

  factory RouteStop.fromJson(Map<String, dynamic> json) {
    return RouteStop(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      sequence: json['sequence'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'sequence': sequence,
    };
  }

  /// Get the position as a LatLng
  LatLng get position => LatLng(latitude, longitude);
}

/// Model for a Bus Route Path Point
class RoutePathPoint {
  final double latitude;
  final double longitude;
  final int sequence;

  RoutePathPoint({
    required this.latitude,
    required this.longitude,
    required this.sequence,
  });

  factory RoutePathPoint.fromJson(Map<String, dynamic> json) {
    return RoutePathPoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      sequence: json['sequence'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'sequence': sequence,
    };
  }

  /// Get the position as a LatLng
  LatLng get position => LatLng(latitude, longitude);
}

/// Model for a Bus Route
class BusRoute {
  final String id;
  final String name;
  final String description;
  final double startLat;
  final double startLng;
  final double endLat;
  final double endLng;
  final List<RouteStop> stops;
  final List<RoutePathPoint> pathPoints;
  final bool isActive;
  final int estimatedDuration; // in minutes
  final int distanceInMeters;

  BusRoute({
    required this.id,
    required this.name,
    required this.description,
    required this.startLat,
    required this.startLng,
    required this.endLat,
    required this.endLng,
    this.stops = const [],
    this.pathPoints = const [],
    required this.isActive,
    this.estimatedDuration = 0,
    this.distanceInMeters = 0,
  });

  factory BusRoute.fromJson(Map<String, dynamic> json) {
    final List<RouteStop> stops = [];
    if (json['stops'] != null) {
      for (final stop in json['stops']) {
        stops.add(RouteStop.fromJson(stop));
      }
    }

    final List<RoutePathPoint> pathPoints = [];
    if (json['path_points'] != null) {
      for (final point in json['path_points']) {
        pathPoints.add(RoutePathPoint.fromJson(point));
      }
    }

    return BusRoute(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      startLat: (json['start_lat'] as num?)?.toDouble() ?? 0.0,
      startLng: (json['start_lng'] as num?)?.toDouble() ?? 0.0,
      endLat: (json['end_lat'] as num?)?.toDouble() ?? 0.0,
      endLng: (json['end_lng'] as num?)?.toDouble() ?? 0.0,
      stops: stops,
      pathPoints: pathPoints,
      isActive: json['is_active'] as bool? ?? true,
      estimatedDuration: json['estimated_duration'] as int? ?? 0,
      distanceInMeters: json['distance_in_meters'] as int? ?? 0,
    );
  }

  /// Get the route start position as a LatLng
  LatLng get startPosition => LatLng(startLat, startLng);

  /// Get the route end position as a LatLng
  LatLng get endPosition => LatLng(endLat, endLng);

  /// Get the list of stop points as LatLng
  List<LatLng> get stopPoints {
    return stops.map((stop) => stop.position).toList();
  }

  /// Get the full path as a list of LatLng
  List<LatLng> get path {
    final sortedPoints = List<RoutePathPoint>.from(pathPoints);
    sortedPoints.sort((a, b) => a.sequence.compareTo(b.sequence));
    return sortedPoints.map((point) => point.position).toList();
  }

  /// Get the estimated duration as a formatted string (e.g. "30 min")
  String get formattedDuration {
    if (estimatedDuration < 60) {
      return '$estimatedDuration min';
    } else {
      final hours = estimatedDuration ~/ 60;
      final minutes = estimatedDuration % 60;
      if (minutes == 0) {
        return '$hours hr';
      } else {
        return '$hours hr $minutes min';
      }
    }
  }

  /// Get the distance as a formatted string (e.g. "5.2 km")
  String get formattedDistance {
    if (distanceInMeters < 1000) {
      return '$distanceInMeters m';
    } else {
      final km = distanceInMeters / 1000.0;
      return '${km.toStringAsFixed(1)} km';
    }
  }
}
