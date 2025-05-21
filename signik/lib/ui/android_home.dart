import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  
  bool _isConnected = false;
  String _status = 'Waiting to connect...';
  Uint8List? _pdfBytes;
  Uint8List? _signedPdfBytes;
  String? _currentFileName;
  bool _isSigned = false;

  @override
  void initState() {
    super.initState();
    // Force landscape orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _connectToServer() async {
    final ip = _ipController.text.trim();
    final port = _portController.text.trim();
    
    if (ip.isEmpty) {
      setState(() => _status = 'Please enter Windows app IP address');
      return;
    }

    if (port.isEmpty) {
      setState(() => _status = 'Please enter port number');
      return;
    }

    setState(() => _status = 'Connecting...');
    
    try {
      final wsUrl = 'ws://$ip:$port';
      await _webSocketService.connect(wsUrl);
      _webSocketService.onMessage.listen(_handleMessage);
      setState(() {
        _isConnected = true;
        _status = 'Connected to Windows app';
      });
    } catch (e) {
      setState(() {
        _isConnected = false;
        _status = 'Connection failed: $e';
      });
    }
  }

  void _handleMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data['type'] == 'sendStart') {
        setState(() {
          _currentFileName = data['name'];
          _status = 'Receiving $_currentFileName...';
          _isSigned = false;
          _signedPdfBytes = null;
        });
      } else if (data['type'] == 'signedComplete') {
        setState(() {
          _status = 'Receiving signed PDF...';
        });
      }
    } else if (data is Uint8List) {
      if (_signedPdfBytes == null && _isSigned) {
        setState(() {
          _signedPdfBytes = data;
          _status = 'Signed PDF received';
        });
      } else {
        setState(() {
          _pdfBytes = data;
          _status = 'PDF received. Ready to sign.';
        });
      }
    }
  }

  Future<void> _sendSignature() async {
    if (_pdfBytes == null) return;

    final signatureBytes = await _signatureController.toPngBytes();
    if (signatureBytes == null) {
      setState(() => _status = 'Failed to generate signature');
      return;
    }

    setState(() {
      _status = 'Sending signature...';
      _isSigned = true;
    });
    await _webSocketService.sendData(signatureBytes);
    _signatureController.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isConnected) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Signik - Android'),
        ),
        body: SingleChildScrollView(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextField(
                    controller: _ipController,
                    decoration: const InputDecoration(
                      labelText: 'Windows App IP Address',
                      hintText: 'Enter IP address (e.g., 192.168.1.100)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      hintText: 'Enter port number',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _connectToServer,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(200, 50),
                    ),
                    child: const Text('Connect'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

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
          if (_signedPdfBytes != null) ...[
            Expanded(
              child: SfPdfViewer.memory(
                _signedPdfBytes!,
                canShowScrollHead: false,
                canShowScrollStatus: false,
              ),
            ),
          ] else if (_pdfBytes != null) ...[
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
      floatingActionButton: _pdfBytes != null && !_isSigned
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
    // Reset orientation when leaving
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _webSocketService.dispose();
    _signatureController.dispose();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }
} 