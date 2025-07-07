import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class Driver {
  final String id;
  final String collegeId;
  final String name;
  final String phone;
  final String license;
  final bool isActive;
  final DateTime createdAt;
  final String? currentRouteId;
  final String? currentBusId;

  const Driver({
    required this.id,
    required this.collegeId,
    required this.name,
    required this.phone,
    required this.license,
    this.isActive = true,
    required this.createdAt,
    this.currentRouteId,
    this.currentBusId,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id'] as String,
      collegeId: json['collegeId'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      license: json['license'] as String,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      currentRouteId: json['currentRouteId'] as String?,
      currentBusId: json['currentBusId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'collegeId': collegeId,
      'name': name,
      'phone': phone,
      'license': license,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'currentRouteId': currentRouteId,
      'currentBusId': currentBusId,
    };
  }

  Driver copyWith({
    String? id,
    String? collegeId,
    String? name,
    String? phone,
    String? license,
    bool? isActive,
    DateTime? createdAt,
    String? currentRouteId,
    String? currentBusId,
  }) {
    return Driver(
      id: id ?? this.id,
      collegeId: collegeId ?? this.collegeId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      license: license ?? this.license,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      currentRouteId: currentRouteId ?? this.currentRouteId,
      currentBusId: currentBusId ?? this.currentBusId,
    );
  }
} 