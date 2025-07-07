class Stop {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? description;

  Stop({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.description,
  });

  factory Stop.fromJson(Map<String, dynamic> json) {
    return Stop(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
    };
  }
}
