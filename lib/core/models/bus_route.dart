class BusRoute {
  final String id;
  final String name;
  final String? description;
  final List<Map<String, double>> pathPoints;
  final List<Map<String, dynamic>> stops;
  final bool isActive;

  BusRoute({
    required this.id,
    required this.name,
    this.description,
    required this.pathPoints,
    required this.stops,
    this.isActive = true,
  });

  factory BusRoute.fromJson(Map<String, dynamic> json) {
    return BusRoute(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      pathPoints: List<Map<String, double>>.from(
        json['path_points']?.map((x) => Map<String, double>.from(x)) ?? [],
      ),
      stops: List<Map<String, dynamic>>.from(
        json['stops']?.map((x) => Map<String, dynamic>.from(x)) ?? [],
      ),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'path_points': pathPoints,
      'stops': stops,
      'is_active': isActive,
    };
  }
}
