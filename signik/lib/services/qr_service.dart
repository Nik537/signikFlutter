import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class QrService {
  final WebSocketChannel channel;
  final Function(String) onConnectionEstablished;
  final Function(String) onMessageReceived;

  QrService({
    required this.channel,
    required this.onConnectionEstablished,
    required this.onMessageReceived,
  }) {
    _listenToMessages();
  }

  void _listenToMessages() {
    channel.stream.listen(
      (message) {
        final data = jsonDecode(message);
        if (data['type'] == 'connection_established') {
          onConnectionEstablished(data['session_id']);
        } else if (data['type'] == 'message') {
          onMessageReceived(data['content']);
        }
      },
      onError: (error) {
        print('WebSocket error: $error');
      },
      onDone: () {
        print('WebSocket connection closed');
      },
    );
  }

  void sendMessage(String message) {
    channel.sink.add(jsonEncode({
      'type': 'message',
      'content': message,
    }));
  }

  void dispose() {
    channel.sink.close();
  }
} 