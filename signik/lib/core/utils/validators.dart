import '../constants.dart';

/// Utility class for common validation operations
class Validators {
  Validators._();

  /// Validate IP address
  static String? validateIpAddress(String? value) {
    if (value == null || value.isEmpty) {
      return 'IP address is required';
    }

    // Check for localhost aliases
    if (value == 'localhost' || value == 'localhost.localdomain') {
      return null;
    }

    // Validate IP format
    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (!ipRegex.hasMatch(value)) {
      return AppConstants.errorInvalidIp;
    }

    // Validate each octet
    final parts = value.split('.');
    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) {
        return AppConstants.errorInvalidIp;
      }
    }

    return null;
  }

  /// Validate hostname
  static String? validateHostname(String? value) {
    if (value == null || value.isEmpty) {
      return 'Hostname is required';
    }

    final hostnameRegex = RegExp(
      r'^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'
    );

    if (!hostnameRegex.hasMatch(value)) {
      return 'Invalid hostname format';
    }

    return null;
  }

  /// Validate IP or hostname
  static String? validateIpOrHostname(String? value) {
    if (value == null || value.isEmpty) {
      return 'IP address or hostname is required';
    }

    // Try IP validation first
    final ipError = validateIpAddress(value);
    if (ipError == null) return null;

    // Try hostname validation
    final hostnameError = validateHostname(value);
    if (hostnameError == null) return null;

    return AppConstants.errorInvalidIp;
  }

  /// Validate port number
  static String? validatePort(String? value) {
    if (value == null || value.isEmpty) {
      return 'Port is required';
    }

    final port = int.tryParse(value);
    if (port == null || port < 1 || port > 65535) {
      return AppConstants.errorInvalidPort;
    }

    return null;
  }

  /// Validate device name
  static String? validateDeviceName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Device name is required';
    }

    if (value.length < 3) {
      return AppConstants.errorDeviceNameTooShort;
    }

    if (value.length > 50) {
      return 'Device name must be 50 characters or less';
    }

    // Check for valid characters
    final validNameRegex = RegExp(r'^[a-zA-Z0-9\s\-_]+$');
    if (!validNameRegex.hasMatch(value)) {
      return 'Device name can only contain letters, numbers, spaces, hyphens, and underscores';
    }

    return null;
  }

  /// Validate file path
  static String? validateFilePath(String? value) {
    if (value == null || value.isEmpty) {
      return 'File path is required';
    }

    // Check for invalid characters in path
    final invalidChars = RegExp(r'[<>"|?*]');
    if (invalidChars.hasMatch(value)) {
      return 'File path contains invalid characters';
    }

    return null;
  }

  /// Validate PDF file
  static String? validatePdfFile(String? value) {
    if (value == null || value.isEmpty) {
      return 'PDF file is required';
    }

    if (!value.toLowerCase().endsWith(AppConstants.pdfExtension)) {
      return 'File must be a PDF';
    }

    return validateFilePath(value);
  }

  /// Validate email (for future use)
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    );

    if (!emailRegex.hasMatch(value)) {
      return 'Invalid email format';
    }

    return null;
  }

  /// Validate URL
  static String? validateUrl(String? value) {
    if (value == null || value.isEmpty) {
      return 'URL is required';
    }

    try {
      final uri = Uri.parse(value);
      if (!uri.hasScheme || !uri.hasAuthority) {
        return 'Invalid URL format';
      }
    } catch (_) {
      return 'Invalid URL format';
    }

    return null;
  }

  /// Validate WebSocket URL
  static String? validateWebSocketUrl(String? value) {
    if (value == null || value.isEmpty) {
      return 'WebSocket URL is required';
    }

    try {
      final uri = Uri.parse(value);
      if (!uri.hasScheme || (uri.scheme != 'ws' && uri.scheme != 'wss')) {
        return 'WebSocket URL must start with ws:// or wss://';
      }
      if (!uri.hasAuthority) {
        return 'Invalid WebSocket URL format';
      }
    } catch (_) {
      return 'Invalid WebSocket URL format';
    }

    return null;
  }

  /// Validate non-empty string
  static String? validateNotEmpty(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validate minimum length
  static String? validateMinLength(String? value, int minLength, String fieldName) {
    if (value == null || value.length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }
    return null;
  }

  /// Validate maximum length
  static String? validateMaxLength(String? value, int maxLength, String fieldName) {
    if (value != null && value.length > maxLength) {
      return '$fieldName must be $maxLength characters or less';
    }
    return null;
  }

  /// Validate number range
  static String? validateNumberRange(String? value, int min, int max, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }

    final number = int.tryParse(value);
    if (number == null) {
      return '$fieldName must be a number';
    }

    if (number < min || number > max) {
      return '$fieldName must be between $min and $max';
    }

    return null;
  }
}