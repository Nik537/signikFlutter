import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:signature/signature.dart';
import '../services/websocket_service.dart';

class AndroidHome extends StatefulWidget {
  const AndroidHome({super.key});

  @override
  State<AndroidHome> createState() => _AndroidHomeState();
}

class _AndroidHomeState extends State<AndroidHome> {
  final _webSocketService = WebSocketService();
  final _signatureController = SignatureController(
    penStrokeWidth: 5,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  
  bool _isConnected = false;
  String _status = 'Connecting...';
  Uint8List? _pdfBytes;
  String? _currentFileName;

  @override
  void initState() {
    super.initState();
    _initializeWebSocket();
  }

  Future<void> _initializeWebSocket() async {
    // TODO: Implement QR code scanning or UDP broadcast discovery
    // For now, hardcode the WebSocket URL
    const wsUrl = 'ws://192.168.1.100:9000'; // Replace with actual PC IP
    
    try {
      await _webSocketService.connect(wsUrl);
      _webSocketService.onMessage.listen(_handleMessage);
      setState(() {
        _isConnected = true;
        _status = 'Connected to PC';
      });
    } catch (e) {
      setState(() {
        _status = 'Connection failed: $e';
      });
    }
  }

  void _handleMessage(dynamic data) {
    if (data is Map<String, dynamic> && data['type'] == 'sendStart') {
      setState(() {
        _currentFileName = data['name'];
        _status = 'Receiving $_currentFileName...';
      });
    } else if (data is Uint8List) {
      setState(() {
        _pdfBytes = data;
        _status = 'PDF received. Ready to sign.';
      });
    }
  }

  Future<void> _sendSignature() async {
    if (_pdfBytes == null) return;

    final signatureBytes = await _signatureController.toPngBytes();
    if (signatureBytes == null) {
      setState(() => _status = 'Failed to generate signature');
      return;
    }

    setState(() => _status = 'Sending signature...');
    await _webSocketService.sendData(signatureBytes);
    _signatureController.clear();
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
      body: Column(
        children: [
          if (_pdfBytes != null) ...[
            Expanded(
              child: SfPdfViewer.memory(
                _pdfBytes!,
                canShowScrollHead: false,
                canShowScrollStatus: false,
              ),
            ),
            const Divider(height: 1),
            Container(
              height: 200,
              color: Colors.white,
              child: Signature(
                controller: _signatureController,
                backgroundColor: Colors.white,
              ),
            ),
          ] else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.description,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Waiting for PDF...',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _pdfBytes != null
          ? FloatingActionButton.extended(
              onPressed: _sendSignature,
              label: const Text('Sign & Send'),
              icon: const Icon(Icons.send),
            )
          : null,
    );
  }

  @override
  void dispose() {
    _webSocketService.dispose();
    _signatureController.dispose();
    super.dispose();
  }
} 