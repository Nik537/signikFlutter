import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/pdf_service.dart';
import '../services/signature_service.dart';

class AndroidHome extends StatefulWidget {
  const AndroidHome({super.key});

  @override
  State<AndroidHome> createState() => _AndroidHomeState();
}

class _AndroidHomeState extends State<AndroidHome> {
  final _pdfService = PdfService();
  final _signatureService = SignatureService();
  WebSocketChannel? _channel;
  bool _isConnected = false;
  String _status = 'Waiting for PDF...';
  Uint8List? _currentPdfBytes;
  String? _currentFileName;

  @override
  void initState() {
    super.initState();
    _connectToServer();
  }

  Future<void> _connectToServer() async {
    try {
      // Try to connect to the Windows app
      final wsUrl = Uri.parse('ws://192.168.1.100:48978');
      _channel = WebSocketChannel.connect(wsUrl);
      
      _channel!.stream.listen(
        (data) {
          if (data is String) {
            final message = jsonDecode(data);
            if (message['type'] == 'sendStart') {
              setState(() {
                _currentFileName = message['name'];
                _status = 'Receiving PDF...';
              });
            } else if (message['type'] == 'signedComplete') {
              setState(() {
                _status = 'PDF signed successfully';
              });
            }
          } else if (data is List<int>) {
            if (_currentFileName == null) {
              setState(() {
                _status = 'Error: Received data before filename';
              });
              return;
            }
            
            _currentPdfBytes = Uint8List.fromList(data);
            _showSignatureDialog();
          }
        },
        onDone: () {
          setState(() {
            _isConnected = false;
            _status = 'Connection lost. Reconnecting...';
          });
          _reconnect();
        },
        onError: (error) {
          print('WebSocket error: $error');
          setState(() {
            _isConnected = false;
            _status = 'Connection error: $error';
          });
          _reconnect();
        },
      );

      setState(() {
        _isConnected = true;
        _status = 'Connected to Windows app';
      });
    } catch (e) {
      print('Error connecting to WebSocket: $e');
      setState(() {
        _isConnected = false;
        _status = 'Connection failed: $e';
      });
      _reconnect();
    }
  }

  void _reconnect() {
    Future.delayed(const Duration(seconds: 5), () {
      if (!_isConnected) {
        _connectToServer();
      }
    });
  }

  Future<void> _showSignatureDialog() async {
    if (_currentPdfBytes == null) return;

    final signature = await _signatureService.getSignature(context);
    if (signature == null) {
      setState(() => _status = 'Signature cancelled');
      return;
    }

    setState(() => _status = 'Sending signature...');
    
    try {
      // Send the signature back to Windows
      _channel?.sink.add(signature);
    } catch (e) {
      setState(() => _status = 'Error sending signature: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Signik - Android'),
        actions: [
          Icon(
            _isConnected ? Icons.computer : Icons.computer_outlined,
            color: _isConnected ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.phone_android,
              size: 64,
              color: _isConnected ? Colors.green : Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _status,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }
} 