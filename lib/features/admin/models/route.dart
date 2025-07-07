import 'package:flutter/material.dart';

class AdminRoute {
  final String id;
  final String name;
  final List<String> villages;
  final bool isActive;
  final DateTime createdAt;
  final String collegeId;

  const AdminRoute({
    required this.id,
    required this.name,
    required this.villages,
    required this.isActive,
    required this.createdAt,
    required this.collegeId,
  });

  factory AdminRoute.fromJson(Map<String, dynamic> json) {
    return AdminRoute(
      id: json['id'] as String,
      name: json['name'] as String,
      villages: List<String>.from(json['villages'] as List),
      isActive: json['isActive'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      collegeId: json['collegeId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'villages': villages,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'collegeId': collegeId,
    };
  }

  AdminRoute copyWith({
    String? id,
    String? name,
    List<String>? villages,
    bool? isActive,
    DateTime? createdAt,
    String? collegeId,
  }) {
    return AdminRoute(
      id: id ?? this.id,
      name: name ?? this.name,
      villages: villages ?? this.villages,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      collegeId: collegeId ?? this.collegeId,
    );
  }
} 