class Bus {
  final String id;
  final String routeId;
  final String registrationNumber;
  final double latitude;
  final double longitude;
  final double heading;
  final bool isActive;
  final DateTime lastUpdated;

  Bus({
    required this.id,
    required this.routeId,
    required this.registrationNumber,
    required this.latitude,
    required this.longitude,
    required this.heading,
    required this.isActive,
    required this.lastUpdated,
  });

  factory Bus.fromJson(Map<String, dynamic> json) {
    return Bus(
      id: json['id'] as String,
      routeId: json['routeId'] as String,
      registrationNumber: json['registrationNumber'] as String,
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      heading: json['heading'] as double,
      isActive: json['isActive'] as bool,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'routeId': routeId,
      'registrationNumber': registrationNumber,
      'latitude': latitude,
      'longitude': longitude,
      'heading': heading,
      'isActive': isActive,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
} 