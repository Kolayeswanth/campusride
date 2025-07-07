class College {
  final String id;
  final String name;
  final String address;
  final String code;
  final String? contactPhone;
  final String? contactEmail;
  final String? logoUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  College({
    required this.id,
    required this.name,
    required this.address,
    required this.code,
    this.contactPhone,
    this.contactEmail,
    this.logoUrl,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  factory College.fromJson(Map<String, dynamic> json) {
    final String id = json['id'] as String? ?? '';
    final String name = json['name'] as String? ?? '';
    final String address = json['address'] as String? ?? '';
    final String code = json['code'] as String? ?? '';
    final DateTime createdAt = json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String)
        : DateTime.now();

    return College(
      id: id,
      name: name,
      address: address,
      code: code,
      contactPhone: json['contact_phone'] as String?,
      contactEmail: json['contact_email'] as String?,
      logoUrl: json['logo_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: createdAt,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'code': code,
      'contact_phone': contactPhone,
      'contact_email': contactEmail,
      'logo_url': logoUrl,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  College copyWith({
    String? id,
    String? name,
    String? address,
    String? code,
    String? contactPhone,
    String? contactEmail,
    String? logoUrl,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return College(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      code: code ?? this.code,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      logoUrl: logoUrl ?? this.logoUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
} 