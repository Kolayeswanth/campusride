import 'package:cloud_firestore/cloud_firestore.dart';

class Driver {
  final String id;
  final String name;
  final String phone;
  final bool isActive;
  final String? currentCollegeId;

  Driver({
    required this.id,
    required this.name,
    required this.phone,
    required this.isActive,
    this.currentCollegeId,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      isActive: json['is_active'] as bool? ?? true,
      currentCollegeId: json['current_college_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'is_active': isActive,
      'current_college_id': currentCollegeId,
    };
  }

  Driver copyWith({
    String? id,
    String? name,
    String? phone,
    bool? isActive,
    String? currentCollegeId,
  }) {
    return Driver(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      isActive: isActive ?? this.isActive,
      currentCollegeId: currentCollegeId ?? this.currentCollegeId,
    );
  }
} 