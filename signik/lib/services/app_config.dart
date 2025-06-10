import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class AppConfig {
  static String _brokerUrl = 'http://10.199.177.75:8000';
  static String _deviceName = 'Signik Device';

  static String get brokerUrl => _brokerUrl;
  static String get deviceName => _deviceName;

  static void setBrokerUrl(String url) {
    _brokerUrl = url;
  }

  static void setDeviceName(String name) {
    _deviceName = name;
  }

  static String getWebSocketUrl() {
    return _brokerUrl.replaceFirst('http', 'ws');
  }
  
  static Future<void> loadFromPreferences() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('broker_url');
      final savedName = prefs.getString('device_name');
      
      if (savedUrl != null) {
        // Convert ws:// to http:// and remove any /ws path
        String cleanUrl = savedUrl.replaceFirst('ws://', 'http://');
        // Remove /ws if it exists at the end
        if (cleanUrl.endsWith('/ws')) {
          cleanUrl = cleanUrl.substring(0, cleanUrl.length - 3);
        }
        _brokerUrl = cleanUrl;
      }
      
      if (savedName != null) {
        _deviceName = savedName;
      } else if (Platform.isAndroid) {
        _deviceName = 'Signik Android Tablet';
      }
    }
  }
} 