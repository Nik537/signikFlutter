import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../core/constants.dart';
import '../core/utils/network_utils.dart';

/// Application configuration manager
class AppConfig {
  static String _brokerUrl = 'http://${AppConstants.defaultBrokerIp}:${AppConstants.defaultBrokerPort}';
  static String _deviceName = AppConstants.defaultDeviceName;

  static String get brokerUrl => _brokerUrl;
  static String get deviceName => _deviceName;

  static void setBrokerUrl(String url) {
    _brokerUrl = url;
  }

  static void setDeviceName(String name) {
    _deviceName = name;
  }

  static String getWebSocketUrl() {
    return NetworkUtils.httpToWebSocket(_brokerUrl);
  }
  
  static Future<void> loadFromPreferences() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(AppConstants.prefBrokerUrl);
      final savedName = prefs.getString(AppConstants.prefDeviceName);
      
      if (savedUrl != null) {
        // Convert ws:// to http:// and remove any /ws path
        String cleanUrl = NetworkUtils.webSocketToHttp(savedUrl);
        cleanUrl = NetworkUtils.removePathFromUrl(cleanUrl, AppConstants.webSocketPath);
        _brokerUrl = cleanUrl;
      }
      
      if (savedName != null) {
        _deviceName = savedName;
      } else if (Platform.isAndroid) {
        _deviceName = AppConstants.defaultAndroidName;
      }
    }
  }
} 