import 'package:cloud_firestore/cloud_firestore.dart';

class Driver {
  final String id;
  final String name;
  final String phone;
  final bool isActive;
  final String? currentCollegeId;
  final String? email;
  final String? licenseNumber;
  final String? vehicleNumber;
  final String? vehicleModel;
  final DateTime? lastActive;

  Driver({
    required this.id,
    required this.name,
    required this.phone,
    required this.isActive,
    this.currentCollegeId,
    this.email,
    this.licenseNumber,
    this.vehicleNumber,
    this.vehicleModel,
    this.lastActive,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      isActive: json['is_active'] as bool? ?? true,
      currentCollegeId: json['current_college_id'] as String?,
      email: json['email'] as String?,
      licenseNumber: json['license_number'] as String?,
      vehicleNumber: json['vehicle_number'] as String?,
      vehicleModel: json['vehicle_model'] as String?,
      lastActive: json['last_active'] != null 
          ? DateTime.parse(json['last_active'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'is_active': isActive,
      'current_college_id': currentCollegeId,
      'email': email,
      'license_number': licenseNumber,
      'vehicle_number': vehicleNumber,
      'vehicle_model': vehicleModel,
      'last_active': lastActive?.toIso8601String(),
    };
  }

  Driver copyWith({
    String? id,
    String? name,
    String? phone,
    bool? isActive,
    String? currentCollegeId,
    String? email,
    String? licenseNumber,
    String? vehicleNumber,
    String? vehicleModel,
    DateTime? lastActive,
  }) {
    return Driver(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      isActive: isActive ?? this.isActive,
      currentCollegeId: currentCollegeId ?? this.currentCollegeId,
      email: email ?? this.email,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      lastActive: lastActive ?? this.lastActive,
    );
  }
} 