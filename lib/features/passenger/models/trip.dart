import 'bus.dart';
import 'route.dart';

class Trip {
  final String id;
  final Bus bus;
  final Route route;
  final DateTime startTime;
  final DateTime? endTime;
  final bool isActive;
  final int currentStopIndex;
  final int passengerCount;

  Trip({
    required this.id,
    required this.bus,
    required this.route,
    required this.startTime,
    this.endTime,
    required this.isActive,
    required this.currentStopIndex,
    required this.passengerCount,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] as String,
      bus: Bus.fromJson(json['bus'] as Map<String, dynamic>),
      route: Route.fromJson(json['route'] as Map<String, dynamic>),
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      isActive: json['isActive'] as bool,
      currentStopIndex: json['currentStopIndex'] as int,
      passengerCount: json['passengerCount'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bus': bus.toJson(),
      'route': route.toJson(),
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'isActive': isActive,
      'currentStopIndex': currentStopIndex,
      'passengerCount': passengerCount,
    };
  }
} 