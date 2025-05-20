import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

class WebSocketService {
  HttpServer? _server;
  WebSocket? _client;
  WebSocket? _connection;
  final _port = 9000;
  final _onMessageController = StreamController<dynamic>.broadcast();
  final _onConnectionController = StreamController<bool>.broadcast();

  Stream<dynamic> get onMessage => _onMessageController.stream;
  Stream<bool> get onConnection => _onConnectionController.stream;

  Future<void> startServer() async {
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      _server!.listen(_handleConnection);
      print('WebSocket server started on ws://${await _getLocalIp()}:$_port');
    } catch (e) {
      print('Failed to start WebSocket server: $e');
      rethrow;
    }
  }

  Future<void> connect(String url) async {
    try {
      _connection = await WebSocket.connect(url);
      _connection!.listen(
        (data) => _onMessageController.add(data),
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
          (data) => _onMessageController.add(data),
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

  Future<void> sendData(dynamic data) async {
    if (_client != null) {
      if (data is List<int>) {
        _client!.add(data);
      } else {
        _client!.add(jsonEncode(data));
      }
    } else if (_connection != null) {
      if (data is List<int>) {
        _connection!.add(data);
      } else {
        _connection!.add(jsonEncode(data));
      }
    }
  }

  Future<String> _getLocalIp() async {
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
} 