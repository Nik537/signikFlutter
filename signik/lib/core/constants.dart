/// Application-wide constants for the Signik project
class AppConstants {
  // Prevent instantiation
  AppConstants._();

  // Network Configuration
  static const String defaultBrokerIp = '10.199.177.75';
  static const String localhostIp = '127.0.0.1';
  static const String androidEmulatorHost = '10.0.2.2';
  static const int defaultBrokerPort = 8000;
  static const int defaultWebSocketPort = 9000;
  static const String webSocketPath = '/ws';
  static const String defaultLocalIp = '127.0.0.1';
  
  // Timeouts
  static const Duration heartbeatInterval = Duration(seconds: 10);
  static const Duration deviceRefreshInterval = Duration(seconds: 5);
  static const Duration connectionTestTimeout = Duration(seconds: 2);
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration networkTimeout = Duration(seconds: 30);
  static const Duration heartbeatTimeout = Duration(seconds: 10);
  static const Duration documentUploadTimeout = Duration(minutes: 2);
  
  // Device Names
  static const String defaultDeviceName = 'Signik Device';
  static const String defaultWindowsName = 'Signik Windows PC';
  static const String defaultAndroidName = 'Signik Android Tablet';
  
  // SharedPreferences Keys
  static const String prefBrokerUrl = 'broker_url';
  static const String prefDeviceName = 'device_name';
  
  // File Configuration
  static const String deviceConnectionsFile = 'device_connections.json';
  static const String signedSuffix = '_signed';
  static const String pdfExtension = '.pdf';
  
  // UI Dimensions
  static const double sidebarWidth = 360.0;
  static const double pcListWidth = 300.0;
  static const double signaturePreviewWidth = 300.0;
  static const double signaturePreviewHeight = 200.0;
  static const double pdfThumbnailWidth = 120.0;
  static const double pdfThumbnailHeight = 160.0;
  static const double deviceCardAspectRatio = 1.5;
  static const int deviceGridColumns = 3;
  
  // PDF Configuration
  static const double pdfSignatureScale = 0.1;
  static const double pdfTopMargin = 56.69; // 20mm in points
  static const double pdfRightMargin = 85.04; // 30mm in points
  static const double pdfSignatureHeight = 77.0;
  
  // Colors
  static const int primaryColorValue = 0xFF0066CC;
  static const int backgroundColorValue = 0xFFF5F5F5;
  
  // Status Messages
  static const String statusConnecting = 'Connecting to broker...';
  static const String statusConnected = 'Connected to broker. Waiting for PDF...';
  static const String statusDisconnected = 'Disconnected from broker';
  static const String statusConnectionError = 'Connection error';
  static const String statusWaitingForPdf = 'Waiting for PDF...';
  static const String statusPdfReceived = 'PDF received. Ready to sign.';
  static const String statusSendingSignature = 'Sending signature for review...';
  static const String statusSignatureAccepted = 'Signature accepted! Waiting for next PDF...';
  static const String statusSignatureDeclined = 'Signature declined. Please sign again.';
  static const String statusEmbeddingSignature = 'Embedding signature...';
  static const String statusPdfSigned = 'PDF signed and saved';
  
  // Error Messages
  static const String errorNoDevices = 'No Android devices online';
  static const String errorNoConnectedDevices = 'No connected Android devices available. Check device connections.';
  static const String errorConnectionFailed = 'Connection failed';
  static const String errorDeviceNotRegistered = 'Device not registered';
  static const String errorInvalidPort = 'Please enter a valid port (1-65535)';
  static const String errorInvalidIp = 'Please enter a valid IP address or hostname';
  static const String errorDeviceNameTooShort = 'Device name must be at least 3 characters';
  
  // Success Messages
  static const String successConnectionsSaved = 'Connections saved successfully';
  static const String successSettingsSaved = 'Settings saved. Please restart the app to apply changes.';
  static const String successConnectionTest = 'Connection successful!';
  
  // UI Text
  static const String titleDeviceConnections = 'Device Connection Manager';
  static const String titleAndroidConnections = 'Android Device Connections';
  static const String titleSignedDocuments = 'Signed Documents';
  static const String titleSettings = 'Settings';
  static const String titleBrokerSettings = 'Broker Settings';
  static const String titleDeviceSettings = 'Device Settings';
  
  // Button Labels
  static const String buttonSaveChanges = 'Save Changes';
  static const String buttonRetryConnection = 'Retry Connection';
  static const String buttonTestConnection = 'Test Connection';
  static const String buttonOpenConnectionManager = 'Open Connection Manager';
  static const String buttonManageConnections = 'Manage Connections';
  static const String buttonSaveSettings = 'Save Settings';
  static const String buttonSend = 'Send';
  static const String buttonAccept = 'Accept';
  static const String buttonDecline = 'Decline';
  static const String buttonOk = 'OK';
  static const String buttonCancel = 'Cancel';
  
  // Tooltips
  static const String tooltipRefreshDevices = 'Refresh devices';
  static const String tooltipManageConnections = 'Manage Device Connections';
  static const String tooltipSettings = 'Settings';
  static const String tooltipBack = 'Back';
  static const String tooltipTestConnection = 'Test Connection';
}

/// Enum utility for consistent enum conversions
class EnumUtils {
  static String enumToString<T>(T enumValue) {
    return enumValue.toString().split('.').last;
  }
  
  static T? enumFromString<T>(List<T> enumValues, String value) {
    try {
      return enumValues.firstWhere(
        (e) => enumToString(e).toLowerCase() == value.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }
}