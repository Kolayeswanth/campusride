class LocationPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String? name;

  LocationPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.name,
  });

  factory LocationPoint.fromJson(Map<String, dynamic> json) {
    return LocationPoint(
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      timestamp: DateTime.parse(json['timestamp'] as String),
      name: json['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'name': name,
    };
  }
} 