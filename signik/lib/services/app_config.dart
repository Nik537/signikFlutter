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
} 