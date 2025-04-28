import 'stop.dart';

class Route {
  final String id;
  final String name;
  final String description;
  final List<Stop> stops;
  final String? polyline;

  Route({
    required this.id,
    required this.name,
    required this.description,
    required this.stops,
    this.polyline,
  });

  factory Route.fromJson(Map<String, dynamic> json) {
    return Route(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      stops: (json['stops'] as List<dynamic>)
          .map((stop) => Stop.fromJson(stop as Map<String, dynamic>))
          .toList(),
      polyline: json['polyline'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'stops': stops.map((stop) => stop.toJson()).toList(),
      'polyline': polyline,
    };
  }
} 