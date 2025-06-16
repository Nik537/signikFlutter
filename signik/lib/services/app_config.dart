import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../core/constants.dart';
import '../core/utils/network_utils.dart';

/// Application configuration manager
class AppConfig {
  static String _brokerUrl = 'http://${AppConstants.defaultBrokerIp}:${AppConstants.defaultBrokerPort}';
  static String _deviceName = AppConstants.defaultDeviceName;
  
  // Email configuration
  static String _emailRecipient = 'lolcat774@gmail.com';
  static String _emailUsername = 'signik.sender@gmail.com';
  static String _emailPassword = 'zrtlrcvbgbpjzqbk';
  static String _emailSmtpHost = 'smtp.gmail.com';
  static int _emailSmtpPort = 587;
  static bool _emailEnabled = true;

  static String get brokerUrl => _brokerUrl;
  static String get deviceName => _deviceName;
  static String get emailRecipient => _emailRecipient;
  static String get emailUsername => _emailUsername;
  static String get emailPassword => _emailPassword;
  static String get emailSmtpHost => _emailSmtpHost;
  static int get emailSmtpPort => _emailSmtpPort;
  static bool get emailEnabled => _emailEnabled;

  static void setBrokerUrl(String url) {
    _brokerUrl = url;
  }

  static void setDeviceName(String name) {
    _deviceName = name;
  }
  
  static void setEmailConfig({
    String? recipient,
    String? username,
    String? password,
    String? smtpHost,
    int? smtpPort,
    bool? enabled,
  }) {
    if (recipient != null) _emailRecipient = recipient;
    if (username != null) _emailUsername = username;
    if (password != null) _emailPassword = password;
    if (smtpHost != null) _emailSmtpHost = smtpHost;
    if (smtpPort != null) _emailSmtpPort = smtpPort;
    if (enabled != null) _emailEnabled = enabled;
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
      
      // Load email settings
      _emailRecipient = prefs.getString('email_recipient') ?? 'lolcat774@gmail.com';
      _emailUsername = prefs.getString('email_username') ?? 'signik.sender@gmail.com';
      _emailPassword = prefs.getString('email_password') ?? 'zrtlrcvbgbpjzqbk';
      _emailSmtpHost = prefs.getString('email_smtp_host') ?? 'smtp.gmail.com';
      _emailSmtpPort = prefs.getInt('email_smtp_port') ?? 587;
      _emailEnabled = prefs.getBool('email_enabled') ?? true;
    }
  }
  
  static Future<void> saveEmailSettings() async {
    if (Platform.isAndroid || Platform.isIOS || Platform.isWindows) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('email_recipient', _emailRecipient);
      await prefs.setString('email_username', _emailUsername);
      await prefs.setString('email_password', _emailPassword);
      await prefs.setString('email_smtp_host', _emailSmtpHost);
      await prefs.setInt('email_smtp_port', _emailSmtpPort);
      await prefs.setBool('email_enabled', _emailEnabled);
    }
  }
} 