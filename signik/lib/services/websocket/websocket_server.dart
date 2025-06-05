import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../../models/signik_message.dart';

/// WebSocket server for accepting connections
class WebSocketServer {
  HttpServer? _httpServer;
  final Set<WebSocket> _clients = {};
  final _messageController = StreamController<ServerMessage>.broadcast();
  final _connectionController = StreamController<ServerConnectionEvent>.broadcast();
  
  bool _disposed = false;

  Stream<ServerMessage> get messages => _messageController.stream;
  Stream<ServerConnectionEvent> get connections => _connectionController.stream;
  bool get isRunning => _httpServer != null;
  int get clientCount => _clients.length;

  /// Start the WebSocket server
  Future<int> start({int port = 0, String? address}) async {
    if (_disposed) {
      throw WebSocketException('Server has been disposed');
    }

    final bindAddress = address != null 
        ? InternetAddress(address) 
        : InternetAddress.anyIPv4;

    _httpServer = await HttpServer.bind(bindAddress, port);
    _httpServer!.listen(_handleRequest);

    return _httpServer!.port;
  }

  /// Stop the server
  Future<void> stop() async {
    // Close all client connections
    for (final client in _clients.toList()) {
      await client.close();
    }
    _clients.clear();

    // Stop the HTTP server
    await _httpServer?.close();
    _httpServer = null;
  }

  /// Broadcast data to all connected clients
  Future<void> broadcast(dynamic data) async {
    final deadClients = <WebSocket>[];
    
    for (final client in _clients) {
      try {
        _sendToClient(client, data);
      } catch (e) {
        deadClients.add(client);
      }
    }

    // Remove dead clients
    for (final client in deadClients) {
      _clients.remove(client);
    }
  }

  /// Send data to a specific client
  Future<void> sendToClient(WebSocket client, dynamic data) async {
    if (!_clients.contains(client)) {
      throw WebSocketException('Client not connected');
    }
    _sendToClient(client, data);
  }

  /// Get server address
  Future<String> getServerAddress() async {
    if (!isRunning) {
      throw WebSocketException('Server not running');
    }

    final interfaces = await NetworkInterface.list();
    for (var interface in interfaces) {
      for (var addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
          return 'ws://${addr.address}:${_httpServer!.port}';
        }
      }
    }
    return 'ws://127.0.0.1:${_httpServer!.port}';
  }

  /// Handle HTTP upgrade requests
  void _handleRequest(HttpRequest request) {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      WebSocketTransformer.upgrade(request).then((WebSocket client) {
        _handleClient(client, request);
      }).catchError((error) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.close();
      });
    } else {
      request.response.statusCode = HttpStatus.forbidden;
      request.response.close();
    }
  }

  /// Handle new WebSocket client
  void _handleClient(WebSocket client, HttpRequest request) {
    _clients.add(client);
    
    final clientInfo = ClientInfo(
      socket: client,
      address: request.connectionInfo?.remoteAddress.address ?? 'unknown',
      port: request.connectionInfo?.remotePort ?? 0,
    );

    _connectionController.add(ServerConnectionEvent(
      type: ConnectionEventType.connected,
      client: clientInfo,
    ));

    client.listen(
      (data) => _handleClientMessage(clientInfo, data),
      onDone: () => _handleClientDisconnect(clientInfo),
      onError: (error) => _handleClientError(clientInfo, error),
      cancelOnError: false,
    );
  }

  /// Handle messages from a client
  void _handleClientMessage(ClientInfo client, dynamic data) {
    dynamic parsedData = data;

    if (data is String) {
      // Try to parse as JSON
      try {
        final json = jsonDecode(data);
        if (json is Map<String, dynamic>) {
          // Try to parse as SignikMessage
          try {
            parsedData = SignikMessage.fromJson(json);
          } catch (_) {
            parsedData = json;
          }
        } else {
          parsedData = json;
        }
      } catch (_) {
        // Keep as string
      }
    } else if (data is List<int>) {
      parsedData = Uint8List.fromList(data);
    }

    _messageController.add(ServerMessage(
      client: client,
      data: parsedData,
    ));
  }

  /// Handle client disconnect
  void _handleClientDisconnect(ClientInfo client) {
    _clients.remove(client.socket);
    _connectionController.add(ServerConnectionEvent(
      type: ConnectionEventType.disconnected,
      client: client,
    ));
  }

  /// Handle client error
  void _handleClientError(ClientInfo client, dynamic error) {
    _connectionController.add(ServerConnectionEvent(
      type: ConnectionEventType.error,
      client: client,
      error: error,
    ));
  }

  /// Send data to a client
  void _sendToClient(WebSocket client, dynamic data) {
    if (data is List<int>) {
      client.add(data);
    } else if (data is SignikMessage) {
      client.add(jsonEncode(data.toJson()));
    } else if (data is Map || data is List) {
      client.add(jsonEncode(data));
    } else if (data is String) {
      client.add(data);
    } else {
      throw ArgumentError('Unsupported data type: ${data.runtimeType}');
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    _disposed = true;
    await stop();
    await _messageController.close();
    await _connectionController.close();
  }
}

/// Client information
class ClientInfo {
  final WebSocket socket;
  final String address;
  final int port;

  ClientInfo({
    required this.socket,
    required this.address,
    required this.port,
  });

  String get identifier => '$address:$port';
}

/// Server message with client info
class ServerMessage {
  final ClientInfo client;
  final dynamic data;

  ServerMessage({
    required this.client,
    required this.data,
  });
}

/// Server connection event
class ServerConnectionEvent {
  final ConnectionEventType type;
  final ClientInfo client;
  final dynamic error;

  ServerConnectionEvent({
    required this.type,
    required this.client,
    this.error,
  });
}

/// Connection event types
enum ConnectionEventType {
  connected,
  disconnected,
  error,
}