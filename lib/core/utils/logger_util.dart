import 'package:logger/logger.dart';

/// A utility class for logging throughout the application.
/// 
/// This class provides a centralized logging mechanism with different log levels
/// (debug, info, warning, error) and consistent formatting.
class LoggerUtil {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );

  /// Logs a debug message.
  /// 
  /// Use for detailed information that is useful during development.
  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// Logs an info message.
  /// 
  /// Use for general information about application flow.
  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// Logs a warning message.
  /// 
  /// Use for potentially harmful situations that don't cause the application to fail.
  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// Logs an error message.
  /// 
  /// Use for errors that cause a feature to fail but don't crash the application.
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Logs a fatal error message.
  /// 
  /// Use for critical errors that might cause the application to crash.
  static void fatal(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }
}