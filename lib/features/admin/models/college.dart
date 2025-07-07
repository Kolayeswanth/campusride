class College {
  final String id;
  final String name;
  final String location;
  final String code;
  final DateTime createdAt;
  final bool isActive;

  College({
    required this.id,
    required this.name,
    required this.location,
    required this.code,
    required this.createdAt,
    this.isActive = true,
  });

  factory College.fromJson(Map<String, dynamic> json) {
    return College(
      id: json['id'] as String,
      name: json['name'] as String,
      location: json['location'] as String,
      code: json['code'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'code': code,
      'created_at': createdAt.toIso8601String(),
      'is_active': isActive,
    };
  }
} 