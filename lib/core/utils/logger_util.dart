import 'package:flutter/foundation.dart';

/// A utility class for logging throughout the application.
/// 
/// This class provides a centralized logging mechanism with different log levels
/// (debug, info, warning, error) and consistent formatting.
class LoggerUtil {
  /// Logs a debug message.
  /// 
  /// Use for detailed information that is useful during development.
  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      print('DEBUG: $message');
      if (error != null) {
        print('Error: $error');
      }
      if (stackTrace != null) {
        print('Stack trace: $stackTrace');
      }
    }
  }

  /// Logs an info message.
  /// 
  /// Use for general information about application flow.
  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      print('INFO: $message');
      if (error != null) {
        print('Error: $error');
      }
      if (stackTrace != null) {
        print('Stack trace: $stackTrace');
      }
    }
  }

  /// Logs a warning message.
  /// 
  /// Use for potentially harmful situations that don't cause the application to fail.
  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      print('WARNING: $message');
      if (error != null) {
        print('Error: $error');
      }
      if (stackTrace != null) {
        print('Stack trace: $stackTrace');
      }
    }
  }

  /// Logs an error message.
  /// 
  /// Use for errors that cause a feature to fail but don't crash the application.
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      print('ERROR: $message');
      if (error != null) {
        print('Error: $error');
      }
      if (stackTrace != null) {
        print('Stack trace: $stackTrace');
      }
    }
  }

  /// Logs a fatal error message.
  /// 
  /// Use for critical errors that might cause the application to crash.
  static void fatal(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      print('FATAL: $message');
      if (error != null) {
        print('Error: $error');
      }
      if (stackTrace != null) {
        print('Stack trace: $stackTrace');
      }
    }
  }
}