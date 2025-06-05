import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../../models/signik_message.dart';

/// WebSocket client for connecting to remote servers
class WebSocketClient {
  WebSocket? _socket;
  final _messageController = StreamController<dynamic>.broadcast();
  final _connectionController = StreamController<ConnectionState>.broadcast();
  
  Timer? _reconnectTimer;
  String? _lastUrl;
  bool _disposed = false;
  int _reconnectAttempts = 0;
  final int maxReconnectAttempts = 5;
  final Duration reconnectDelay = const Duration(seconds: 5);

  Stream<dynamic> get messages => _messageController.stream;
  Stream<ConnectionState> get connectionState => _connectionController.stream;
  bool get isConnected => _socket != null && _socket!.readyState == WebSocket.open;

  /// Connect to a WebSocket server
  Future<void> connect(String url) async {
    if (_disposed) return;
    
    _lastUrl = url;
    _connectionController.add(ConnectionState.connecting);
    
    try {
      _socket = await WebSocket.connect(url);
      _reconnectAttempts = 0;
      _connectionController.add(ConnectionState.connected);
      
      _socket!.listen(
        _handleMessage,
        onDone: _handleDisconnect,
        onError: _handleError,
        cancelOnError: false,
      );
    } catch (e) {
      _handleError(e);
    }
  }

  /// Send data through the WebSocket
  Future<void> send(dynamic data) async {
    if (!isConnected) {
      throw WebSocketException('Not connected to server');
    }

    if (data is List<int>) {
      _socket!.add(data);
    } else if (data is SignikMessage) {
      _socket!.add(jsonEncode(data.toJson()));
    } else if (data is Map || data is List) {
      _socket!.add(jsonEncode(data));
    } else if (data is String) {
      _socket!.add(data);
    } else {
      throw ArgumentError('Unsupported data type: ${data.runtimeType}');
    }
  }

  /// Send JSON message
  Future<void> sendJson(Map<String, dynamic> json) async {
    await send(jsonEncode(json));
  }

  /// Send SignikMessage
  Future<void> sendMessage(SignikMessage message) async {
    await send(message);
  }

  /// Send binary data
  Future<void> sendBinary(List<int> data) async {
    await send(data);
  }

  /// Disconnect from the server
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    await _socket?.close();
    _socket = null;
    _connectionController.add(ConnectionState.disconnected);
  }

  /// Handle incoming messages
  void _handleMessage(dynamic data) {
    if (data is String) {
      // Try to parse as JSON
      try {
        final json = jsonDecode(data);
        if (json is Map<String, dynamic>) {
          // Try to parse as SignikMessage
          try {
            final message = SignikMessage.fromJson(json);
            _messageController.add(message);
          } catch (_) {
            // Not a SignikMessage, forward as Map
            _messageController.add(json);
          }
        } else {
          _messageController.add(json);
        }
      } catch (_) {
        // Not JSON, forward as string
        _messageController.add(data);
      }
    } else if (data is List<int>) {
      // Binary data
      _messageController.add(Uint8List.fromList(data));
    } else {
      // Unknown type
      _messageController.add(data);
    }
  }

  /// Handle disconnection
  void _handleDisconnect() {
    _socket = null;
    _connectionController.add(ConnectionState.disconnected);
    _attemptReconnect();
  }

  /// Handle errors
  void _handleError(dynamic error) {
    _connectionController.add(ConnectionState.error);
    
    if (error is SocketException) {
      _attemptReconnect();
    }
  }

  /// Attempt to reconnect
  void _attemptReconnect() {
    if (_disposed || _lastUrl == null) return;
    
    if (_reconnectAttempts < maxReconnectAttempts) {
      _reconnectAttempts++;
      _connectionController.add(ConnectionState.reconnecting);
      
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(reconnectDelay, () {
        if (!_disposed && _lastUrl != null) {
          connect(_lastUrl!);
        }
      });
    } else {
      _connectionController.add(ConnectionState.failed);
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    await disconnect();
    await _messageController.close();
    await _connectionController.close();
  }
}

/// Connection states
enum ConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
  failed,
}

/// WebSocket exception
class WebSocketException implements Exception {
  final String message;
  
  WebSocketException(this.message);
  
  @override
  String toString() => 'WebSocketException: $message';
}