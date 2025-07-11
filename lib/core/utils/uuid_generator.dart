import 'dart:math';

/// Simple UUID v4 generator for route IDs
/// 
/// Generates a unique identifier in the format:
/// xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
/// 
/// Where:
/// - x is any hexadecimal digit
/// - y is one of 8, 9, A, or B
/// - 4 indicates the UUID version
class UuidGenerator {
  static final Random _random = Random();
  
  /// Generates a UUID v4 string
  /// 
  /// Returns a string in the format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
  /// 
  /// Example: "f47ac10b-58cc-4372-a567-0e02b2c3d479"
  static String generate() {
    return '${_generateHex(8)}-${_generateHex(4)}-4${_generateHex(3)}-${_generateY()}${_generateHex(3)}-${_generateHex(12)}';
  }
  
  /// Generates a simple route ID in the format: route_[timestamp]_[random]
  /// 
  /// This is an alternative to UUID v4 for route IDs that are more readable
  /// 
  /// Example: "route_1641234567890_1234"
  static String generateRouteId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = _random.nextInt(9999) + 1000; // 4-digit random number
    return 'route_${timestamp}_$random';
  }
  
  /// Generates a hex string of the specified length
  static String _generateHex(int length) {
    const chars = '0123456789abcdef';
    return List.generate(length, (index) => chars[_random.nextInt(16)]).join();
  }
  
  /// Generates a Y character for UUID v4 (8, 9, A, or B)
  static String _generateY() {
    const yChars = '89ab';
    return yChars[_random.nextInt(4)];
  }
  
  /// Validates if a string is a valid UUID v4 format
  /// 
  /// Returns true if the string matches the UUID v4 pattern
  static bool isValidUuid(String uuid) {
    final regex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$', 
                          caseSensitive: false);
    return regex.hasMatch(uuid);
  }
  
  /// Validates if a string is a valid route ID format
  /// 
  /// Returns true if the string matches the route_[timestamp]_[random] pattern
  static bool isValidRouteId(String routeId) {
    final regex = RegExp(r'^route_\d{13}_\d{4}$');
    return regex.hasMatch(routeId);
  }
}
