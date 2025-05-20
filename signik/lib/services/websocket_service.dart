import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:network_info_plus/network_info_plus.dart';

class WebSocketService {
  HttpServer? _server;
  WebSocket? _socket;
  final _connectionController = StreamController<bool>.broadcast();
  final _messageController = StreamController<dynamic>.broadcast();
  final _info = NetworkInfo();
  String? _localIp;

  Stream<bool> get onConnection => _connectionController.stream;
  Stream<dynamic> get onMessage => _messageController.stream;

  Future<void> startServer() async {
    try {
      // Get the local IP address
      _localIp = await _info.getWifiIP();
      if (_localIp == null) {
        throw Exception('Could not determine local IP address');
      }

      // Start the server
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 48978);
      print('WebSocket server started on $_localIp:48978');

      // Handle incoming connections
      _server!.listen((HttpRequest request) {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          WebSocketTransformer.upgrade(request).then((WebSocket ws) {
            _handleConnection(ws);
          });
        }
      });

      _connectionController.add(false);
    } catch (e) {
      print('Error starting WebSocket server: $e');
      _connectionController.addError(e);
      rethrow;
    }
  }

  void _handleConnection(WebSocket ws) {
    _socket = ws;
    _connectionController.add(true);

    ws.listen(
      (data) {
        try {
          if (data is String) {
            _messageController.add(jsonDecode(data));
          } else {
            _messageController.add(data);
          }
        } catch (e) {
          print('Error handling message: $e');
        }
      },
      onDone: () {
        _socket = null;
        _connectionController.add(false);
      },
      onError: (error) {
        print('WebSocket error: $error');
        _socket = null;
        _connectionController.add(false);
      },
    );
  }

  Future<void> sendData(dynamic data) async {
    if (_socket == null) {
      throw Exception('No active connection');
    }

    try {
      if (data is Map) {
        _socket!.add(jsonEncode(data));
      } else {
        _socket!.add(data);
      }
    } catch (e) {
      print('Error sending data: $e');
      rethrow;
    }
  }

  String? get localIp => _localIp;

  void dispose() {
    _socket?.close();
    _server?.close();
    _connectionController.close();
    _messageController.close();
  }
} 