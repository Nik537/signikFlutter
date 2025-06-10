import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../models/signik_message.dart';
import '../core/constants.dart';
import '../core/exceptions/app_exceptions.dart';
import '../core/utils/network_utils.dart';

/// Service for handling WebSocket communication
/// Note: This service is deprecated in favor of broker-based communication
/// Kept for backward compatibility
class WebSocketService {
  HttpServer? _server;
  WebSocket? _client;
  WebSocket? _connection;
  final _port = AppConstants.defaultWebSocketPort;
  final _onMessageController = StreamController<dynamic>.broadcast();
  final _onConnectionController = StreamController<bool>.broadcast();
  bool _disposed = false;

  Stream<dynamic> get onMessage => _onMessageController.stream;
  Stream<bool> get onConnection => _onConnectionController.stream;
  int get port => _port;
  bool get isConnected => _client != null || _connection != null;

  /// Start WebSocket server (Windows mode)
  Future<void> startServer() async {
    if (_disposed) {
      throw WebSocketException('Cannot start server: service is disposed');
    }
    
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      _server!.listen(_handleConnection);
      final localIp = await NetworkUtils.getLocalIpAddress();
      print('WebSocket server started on ws://$localIp:$_port');
    } on SocketException catch (e) {
      throw WebSocketException(
        'Failed to start WebSocket server on port $_port',
        details: 'Port may be in use or insufficient permissions',
        originalError: e,
      );
    } catch (e) {
      throw WebSocketException(
        'Unexpected error starting WebSocket server',
        originalError: e,
      );
    }
  }

  /// Connect to WebSocket server (Android mode)
  Future<void> connect(String url) async {
    if (_disposed) {
      throw WebSocketException('Cannot connect: service is disposed');
    }
    
    if (!NetworkUtils.isValidWebSocketUrl(url)) {
      throw ValidationException('Invalid WebSocket URL: $url');
    }
    
    try {
      _connection = await WebSocket.connect(url)
          .timeout(AppConstants.connectionTimeout);
      
      _connection!.listen(
        (data) => _handleIncomingData(data),
        onDone: () {
          _connection = null;
          if (!_disposed) {
            _onConnectionController.add(false);
          }
        },
        onError: (error) {
          print('WebSocket error: $error');
          _connection = null;
          if (!_disposed) {
            _onConnectionController.add(false);
          }
        },
      );
      
      if (!_disposed) {
        _onConnectionController.add(true);
      }
    } on SocketException catch (e) {
      throw WebSocketException(
        'Failed to connect to WebSocket at $url',
        details: 'Check if the server is running and accessible',
        originalError: e,
      );
    } on TimeoutException {
      throw WebSocketException(
        'Connection timeout',
        details: 'Failed to connect to $url within ${AppConstants.connectionTimeout.inSeconds} seconds',
      );
    } catch (e) {
      throw WebSocketException(
        'Unexpected error during WebSocket connection',
        originalError: e,
      );
    }
  }

  /// Handle incoming WebSocket connections
  void _handleConnection(HttpRequest request) {
    if (_disposed) return;
    
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      WebSocketTransformer.upgrade(request).then((WebSocket ws) {
        _client = ws;
        if (!_disposed) {
          _onConnectionController.add(true);
        }
        
        ws.listen(
          (data) => _handleIncomingData(data),
          onDone: () {
            _client = null;
            if (!_disposed) {
              _onConnectionController.add(false);
            }
          },
          onError: (error) {
            print('WebSocket error: $error');
            _client = null;
            if (!_disposed) {
              _onConnectionController.add(false);
            }
          },
        );
      }).catchError((error) {
        print('Failed to upgrade connection: $error');
      });
    }
  }

  /// Handle incoming data from WebSocket
  void _handleIncomingData(dynamic data) {
    if (_disposed) return;
    
    // Handle both string (JSON) and binary data
    if (data is String) {
      // Try to parse as JSON message
      try {
        final json = jsonDecode(data);
        if (json is Map<String, dynamic>) {
          final message = SignikMessage.fromJson(json);
          _onMessageController.add(message);
          return;
        }
      } catch (_) {
        // Not a JSON message, forward as raw string
        _onMessageController.add(data);
      }
    } else if (data is List<int>) {
      // Binary data (PDF bytes)
      _onMessageController.add(Uint8List.fromList(data));
    } else {
      // Unknown data type, forward as-is
      _onMessageController.add(data);
    }
  }

  /// Send data through WebSocket connection
  Future<void> sendData(dynamic data) async {
    if (_disposed) {
      throw WebSocketException('Cannot send data: service is disposed');
    }
    
    final socket = _client ?? _connection;
    if (socket == null) {
      throw WebSocketException('No active WebSocket connection');
    }
    
    try {
      if (data is List<int>) {
        socket.add(data);
      } else if (data is SignikMessage) {
        socket.add(jsonEncode(data.toJson()));
      } else {
        socket.add(jsonEncode(data));
      }
    } catch (e) {
      throw WebSocketException(
        'Failed to send data through WebSocket',
        originalError: e,
      );
    }
  }

  /// Get local IP address (deprecated, use NetworkUtils instead)
  @Deprecated('Use NetworkUtils.getLocalIpAddress() instead')
  Future<String> getLocalIp() async {
    return NetworkUtils.getLocalIpAddress();
  }

  /// Dispose of all resources
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    
    await _onMessageController.close();
    await _onConnectionController.close();
    
    try {
      await _client?.close();
    } catch (e) {
      print('Error closing client WebSocket: $e');
    }
    
    try {
      await _connection?.close();
    } catch (e) {
      print('Error closing connection WebSocket: $e');
    }
    
    try {
      await _server?.close();
    } catch (e) {
      print('Error closing WebSocket server: $e');
    }
  }

  /// Try to parse data as SignikMessage
  static SignikMessage? tryParseMessage(dynamic data) {
    if (data is String) {
      try {
        final json = jsonDecode(data);
        if (json is Map<String, dynamic>) {
          return SignikMessage.fromJson(json);
        }
      } catch (_) {
        // Not a valid JSON message
      }
    } else if (data is SignikMessage) {
      return data;
    }
    return null;
  }
} 