import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../models/signik_message.dart';

class WebSocketService {
  HttpServer? _server;
  WebSocket? _client;
  WebSocket? _connection;
  final _port = 9000;
  final _onMessageController = StreamController<dynamic>.broadcast();
  final _onConnectionController = StreamController<bool>.broadcast();

  Stream<dynamic> get onMessage => _onMessageController.stream;
  Stream<bool> get onConnection => _onConnectionController.stream;
  int get port => _port;

  Future<void> startServer() async {
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      _server!.listen(_handleConnection);
      print('WebSocket server started on ws://${await getLocalIp()}:$_port');
    } catch (e) {
      print('Failed to start WebSocket server: $e');
      rethrow;
    }
  }

  Future<void> connect(String url) async {
    try {
      _connection = await WebSocket.connect(url);
      _connection!.listen(
        (data) => _handleIncomingData(data),
        onDone: () {
          _connection = null;
          _onConnectionController.add(false);
        },
        onError: (error) {
          print('WebSocket error: $error');
          _connection = null;
          _onConnectionController.add(false);
        },
      );
      _onConnectionController.add(true);
    } catch (e) {
      print('Failed to connect to WebSocket: $e');
      rethrow;
    }
  }

  void _handleConnection(HttpRequest request) {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      WebSocketTransformer.upgrade(request).then((WebSocket ws) {
        _client = ws;
        _onConnectionController.add(true);
        
        ws.listen(
          (data) => _handleIncomingData(data),
          onDone: () {
            _client = null;
            _onConnectionController.add(false);
          },
          onError: (error) {
            print('WebSocket error: $error');
            _client = null;
            _onConnectionController.add(false);
          },
        );
      });
    }
  }

  void _handleIncomingData(dynamic data) {
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

  Future<void> sendData(dynamic data) async {
    if (_client != null) {
      if (data is List<int>) {
        _client!.add(data);
      } else if (data is SignikMessage) {
        _client!.add(jsonEncode(data.toJson()));
      } else {
        _client!.add(jsonEncode(data));
      }
    } else if (_connection != null) {
      if (data is List<int>) {
        _connection!.add(data);
      } else if (data is SignikMessage) {
        _connection!.add(jsonEncode(data.toJson()));
      } else {
        _connection!.add(jsonEncode(data));
      }
    }
  }

  Future<String> getLocalIp() async {
    final interfaces = await NetworkInterface.list();
    for (var interface in interfaces) {
      for (var addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
          return addr.address;
        }
      }
    }
    return '127.0.0.1';
  }

  Future<void> dispose() async {
    await _onMessageController.close();
    await _onConnectionController.close();
    await _client?.close();
    await _connection?.close();
    await _server?.close();
  }

  static SignikMessage? tryParseMessage(dynamic data) {
    if (data is String) {
      try {
        final json = jsonDecode(data);
        if (json is Map<String, dynamic>) {
          return SignikMessage.fromJson(json);
        }
      } catch (_) {}
    } else if (data is SignikMessage) {
      return data;
    }
    return null;
  }
} 