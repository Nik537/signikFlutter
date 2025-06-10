import 'dart:io';
import '../constants.dart';

/// Utility class for network-related operations
class NetworkUtils {
  NetworkUtils._();

  /// Converts HTTP URL to WebSocket URL
  static String httpToWebSocket(String url) {
    return url.replaceFirst(RegExp(r'https?://'), 'ws://');
  }

  /// Converts WebSocket URL to HTTP URL
  static String webSocketToHttp(String url) {
    return url.replaceFirst(RegExp(r'wss?://'), 'http://');
  }

  /// Builds a WebSocket URL with the given components
  static String buildWebSocketUrl(String host, int port, String path) {
    return 'ws://$host:$port$path';
  }

  /// Gets the local IP address of the device
  static Future<String> getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
      return AppConstants.defaultLocalIp;
    } catch (e) {
      return AppConstants.defaultLocalIp;
    }
  }

  /// Validates if a string is a valid IP address
  static bool isValidIpAddress(String ip) {
    final ipRegex = RegExp(
      r'^(\d{1,3}\.){3}\d{1,3}$'
    );
    
    if (!ipRegex.hasMatch(ip)) return false;
    
    final parts = ip.split('.');
    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) return false;
    }
    
    return true;
  }

  /// Validates if a string is a valid hostname
  static bool isValidHostname(String hostname) {
    final hostnameRegex = RegExp(
      r'^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'
    );
    return hostnameRegex.hasMatch(hostname);
  }

  /// Validates if a port number is valid
  static bool isValidPort(int port) {
    return port >= 1 && port <= 65535;
  }

  /// Parses a URL and extracts host and port
  static ({String host, int port}) parseUrl(String url) {
    final uri = Uri.parse(url);
    return (host: uri.host, port: uri.hasPort ? uri.port : 80);
  }

  /// Removes trailing path from URL
  static String removePathFromUrl(String url, String path) {
    if (url.endsWith(path)) {
      return url.substring(0, url.length - path.length);
    }
    return url;
  }
  
  /// Validates if a string is a valid WebSocket URL
  static bool isValidWebSocketUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'ws' || uri.scheme == 'wss');
    } catch (_) {
      return false;
    }
  }
}