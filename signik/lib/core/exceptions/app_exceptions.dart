/// Base exception class for Signik application
abstract class SignikException implements Exception {
  final String message;
  final String? details;
  final dynamic originalError;

  const SignikException(this.message, {this.details, this.originalError});

  @override
  String toString() {
    final buffer = StringBuffer('$runtimeType: $message');
    if (details != null) {
      buffer.write('\nDetails: $details');
    }
    if (originalError != null) {
      buffer.write('\nOriginal error: $originalError');
    }
    return buffer.toString();
  }
}

/// Exception thrown when network operations fail
class NetworkException extends SignikException {
  const NetworkException(String message, {String? details, dynamic originalError})
      : super(message, details: details, originalError: originalError);
}

/// Exception thrown when WebSocket operations fail
class WebSocketException extends SignikException {
  const WebSocketException(String message, {String? details, dynamic originalError})
      : super(message, details: details, originalError: originalError);
}

/// Exception thrown when device registration fails
class DeviceRegistrationException extends SignikException {
  const DeviceRegistrationException(String message, {String? details, dynamic originalError})
      : super(message, details: details, originalError: originalError);
}

/// Exception thrown when file operations fail
class FileOperationException extends SignikException {
  const FileOperationException(String message, {String? details, dynamic originalError})
      : super(message, details: details, originalError: originalError);
}

/// Exception thrown when PDF operations fail
class PdfOperationException extends SignikException {
  const PdfOperationException(String message, {String? details, dynamic originalError})
      : super(message, details: details, originalError: originalError);
}

/// Exception thrown when connection operations fail
class ConnectionException extends SignikException {
  const ConnectionException(String message, {String? details, dynamic originalError})
      : super(message, details: details, originalError: originalError);
}

/// Exception thrown when configuration is invalid
class ConfigurationException extends SignikException {
  const ConfigurationException(String message, {String? details, dynamic originalError})
      : super(message, details: details, originalError: originalError);
}

/// Exception thrown when validation fails
class ValidationException extends SignikException {
  final Map<String, String>? fieldErrors;

  const ValidationException(
    String message, {
    this.fieldErrors,
    String? details,
    dynamic originalError,
  }) : super(message, details: details, originalError: originalError);
}