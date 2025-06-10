import 'package:flutter/foundation.dart';

/// Simple logger utility for Signik application
class Logger {
  static const String _prefix = '[Signik]';
  static bool _enableLogs = kDebugMode;

  Logger._();

  /// Enable or disable logging
  static void setLoggingEnabled(bool enabled) {
    _enableLogs = enabled;
  }

  /// Log debug message
  static void debug(String message, {String? tag}) {
    if (_enableLogs) {
      _log('DEBUG', message, tag: tag);
    }
  }

  /// Log info message
  static void info(String message, {String? tag}) {
    if (_enableLogs) {
      _log('INFO', message, tag: tag);
    }
  }

  /// Log warning message
  static void warning(String message, {String? tag}) {
    if (_enableLogs) {
      _log('WARN', message, tag: tag, isWarning: true);
    }
  }

  /// Log error message
  static void error(String message, {String? tag, dynamic error, StackTrace? stackTrace}) {
    if (_enableLogs) {
      _log('ERROR', message, tag: tag, isError: true);
      if (error != null) {
        _log('ERROR', 'Error details: $error', tag: tag, isError: true);
      }
      if (stackTrace != null && kDebugMode) {
        _log('ERROR', 'Stack trace:\n$stackTrace', tag: tag, isError: true);
      }
    }
  }

  /// Log network request
  static void network(String method, String url, {Map<String, dynamic>? headers, dynamic body, String? tag}) {
    if (_enableLogs) {
      final buffer = StringBuffer();
      buffer.writeln('$method $url');
      
      if (headers != null && headers.isNotEmpty) {
        buffer.writeln('Headers: $headers');
      }
      
      if (body != null) {
        buffer.writeln('Body: $body');
      }
      
      _log('NETWORK', buffer.toString(), tag: tag);
    }
  }

  /// Log network response
  static void networkResponse(int statusCode, String url, {dynamic body, String? tag}) {
    if (_enableLogs) {
      final buffer = StringBuffer();
      buffer.writeln('Response $statusCode from $url');
      
      if (body != null) {
        buffer.writeln('Body: $body');
      }
      
      _log('NETWORK', buffer.toString(), tag: tag);
    }
  }

  /// Log WebSocket event
  static void websocket(String event, {dynamic data, String? tag}) {
    if (_enableLogs) {
      final buffer = StringBuffer();
      buffer.writeln('WebSocket event: $event');
      
      if (data != null) {
        buffer.writeln('Data: $data');
      }
      
      _log('WEBSOCKET', buffer.toString(), tag: tag);
    }
  }

  /// Log file operation
  static void file(String operation, String path, {String? tag}) {
    if (_enableLogs) {
      _log('FILE', '$operation: $path', tag: tag);
    }
  }

  /// Log device event
  static void device(String event, String deviceId, {Map<String, dynamic>? details, String? tag}) {
    if (_enableLogs) {
      final buffer = StringBuffer();
      buffer.writeln('Device $deviceId: $event');
      
      if (details != null && details.isNotEmpty) {
        buffer.writeln('Details: $details');
      }
      
      _log('DEVICE', buffer.toString(), tag: tag);
    }
  }

  /// Log PDF operation
  static void pdf(String operation, {Map<String, dynamic>? details, String? tag}) {
    if (_enableLogs) {
      final buffer = StringBuffer();
      buffer.writeln('PDF operation: $operation');
      
      if (details != null && details.isNotEmpty) {
        buffer.writeln('Details: $details');
      }
      
      _log('PDF', buffer.toString(), tag: tag);
    }
  }

  /// Core logging method
  static void _log(String level, String message, {String? tag, bool isError = false, bool isWarning = false}) {
    final timestamp = DateTime.now().toIso8601String();
    final tagPrefix = tag != null ? '[$tag] ' : '';
    final logMessage = '$timestamp $_prefix [$level] $tagPrefix$message';
    
    if (isError) {
      // In debug mode, use debugPrint with error styling
      if (kDebugMode) {
        debugPrint('\x1B[31m$logMessage\x1B[0m'); // Red color
      }
    } else if (isWarning) {
      // In debug mode, use debugPrint with warning styling
      if (kDebugMode) {
        debugPrint('\x1B[33m$logMessage\x1B[0m'); // Yellow color
      }
    } else {
      debugPrint(logMessage);
    }
  }

  /// Create a tagged logger instance
  static TaggedLogger tagged(String tag) {
    return TaggedLogger(tag);
  }
}

/// Logger instance with a specific tag
class TaggedLogger {
  final String tag;

  TaggedLogger(this.tag);

  void debug(String message) => Logger.debug(message, tag: tag);
  void info(String message) => Logger.info(message, tag: tag);
  void warning(String message) => Logger.warning(message, tag: tag);
  void error(String message, {dynamic error, StackTrace? stackTrace}) =>
      Logger.error(message, tag: tag, error: error, stackTrace: stackTrace);
  void network(String method, String url, {Map<String, dynamic>? headers, dynamic body}) =>
      Logger.network(method, url, headers: headers, body: body, tag: tag);
  void networkResponse(int statusCode, String url, {dynamic body}) =>
      Logger.networkResponse(statusCode, url, body: body, tag: tag);
  void websocket(String event, {dynamic data}) =>
      Logger.websocket(event, data: data, tag: tag);
  void file(String operation, String path) =>
      Logger.file(operation, path, tag: tag);
  void device(String event, String deviceId, {Map<String, dynamic>? details}) =>
      Logger.device(event, deviceId, details: details, tag: tag);
  void pdf(String operation, {Map<String, dynamic>? details}) =>
      Logger.pdf(operation, details: details, tag: tag);
}