import 'package:flutter/material.dart';
import '../constants.dart';

/// Utility class for common UI operations
class UIUtils {
  UIUtils._();

  /// Show a snackbar with a message
  static void showSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        action: action,
        backgroundColor: isError ? Colors.red.shade600 : null,
      ),
    );
  }

  /// Show an error dialog
  static Future<void> showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? details,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade600),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (details != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  details,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppConstants.buttonOk),
          ),
        ],
      ),
    );
  }

  /// Get the appropriate icon for a device type
  static IconData getDeviceIcon(String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'android':
        return Icons.tablet_android;
      case 'windows':
        return Icons.desktop_windows;
      case 'ios':
        return Icons.phone_iphone;
      case 'macos':
        return Icons.desktop_mac;
      default:
        return Icons.devices;
    }
  }

  /// Get color for connection status
  static Color getConnectionColor(bool isConnected) {
    return isConnected ? Colors.green : Colors.grey;
  }

  /// Format bytes to human readable string
  static String formatBytes(int bytes, {int decimals = 2}) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (bytes.bitLength - 1) ~/ 10;
    final size = bytes / (1 << (i * 10));
    return '${size.toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  /// Format duration to human readable string
  static String formatDuration(Duration duration) {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds}s';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }
  }

  /// Create a consistent box shadow
  static List<BoxShadow> defaultBoxShadow({
    double opacity = 0.1,
    double blurRadius = 8,
    double spreadRadius = 0,
    Offset offset = const Offset(0, 2),
  }) {
    return [
      BoxShadow(
        color: Colors.black.withOpacity(opacity),
        blurRadius: blurRadius,
        spreadRadius: spreadRadius,
        offset: offset,
      ),
    ];
  }

  /// Create a consistent card decoration
  static BoxDecoration cardDecoration({
    Color? color,
    BorderRadius? borderRadius,
    Border? border,
    List<BoxShadow>? boxShadow,
  }) {
    return BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: borderRadius ?? BorderRadius.circular(8),
      border: border,
      boxShadow: boxShadow ?? defaultBoxShadow(),
    );
  }

  /// Get theme-aware text color
  static Color getTextColor(BuildContext context, {bool isPrimary = false}) {
    final brightness = Theme.of(context).brightness;
    if (isPrimary) {
      return const Color(AppConstants.primaryColorValue);
    }
    return brightness == Brightness.dark 
        ? Colors.white 
        : Colors.black87;
  }

  /// Show a loading overlay
  static void showLoadingOverlay(
    BuildContext context, {
    String? message,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  if (message != null) ...[
                    const SizedBox(height: 16),
                    Text(message),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Hide loading overlay
  static void hideLoadingOverlay(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }
}