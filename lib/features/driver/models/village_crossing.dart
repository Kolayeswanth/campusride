class VillageCrossing {
  final String name;
  final DateTime timestamp;
  final double latitude;
  final double longitude;

  VillageCrossing({
    required this.name,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory VillageCrossing.fromJson(Map<String, dynamic> json) {
    return VillageCrossing(
      name: json['name'],
      timestamp: DateTime.parse(json['timestamp']),
      latitude: json['latitude'],
      longitude: json['longitude'],
    );
  }

  String get formattedTime {
    return '${_formatHour(timestamp.hour)}:${_formatMinute(timestamp.minute)} ${timestamp.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _formatHour(int hour) {
    final h = hour > 12 ? hour - 12 : hour;
    return h == 0 ? '12' : h.toString();
  }

  String _formatMinute(int minute) {
    return minute.toString().padLeft(2, '0');
  }
}
