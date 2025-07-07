class Bus {
  final String id;
  final String name;
  final String routeId;
  final double latitude;
  final double longitude;
  final int capacity;
  final int currentPassengers;
  final bool isActive;
  final DateTime lastUpdated;

  Bus({
    required this.id,
    required this.name,
    required this.routeId,
    required this.latitude,
    required this.longitude,
    required this.capacity,
    required this.currentPassengers,
    required this.isActive,
    required this.lastUpdated,
  });

  factory Bus.fromJson(Map<String, dynamic> json) {
    return Bus(
      id: json['id'] as String,
      name: json['name'] as String,
      routeId: json['route_id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      capacity: json['capacity'] as int,
      currentPassengers: json['current_passengers'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      lastUpdated: DateTime.parse(json['last_updated'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'route_id': routeId,
      'latitude': latitude,
      'longitude': longitude,
      'capacity': capacity,
      'current_passengers': currentPassengers,
      'is_active': isActive,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }

  Bus copyWith({
    String? id,
    String? name,
    String? routeId,
    double? latitude,
    double? longitude,
    int? capacity,
    int? currentPassengers,
    bool? isActive,
    DateTime? lastUpdated,
  }) {
    return Bus(
      id: id ?? this.id,
      name: name ?? this.name,
      routeId: routeId ?? this.routeId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      capacity: capacity ?? this.capacity,
      currentPassengers: currentPassengers ?? this.currentPassengers,
      isActive: isActive ?? this.isActive,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
