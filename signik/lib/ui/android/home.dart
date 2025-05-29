import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:signature/signature.dart';
import '../../services/websocket_service.dart';
import '../../models/signik_message.dart';
import '../../widgets/status_panel.dart';
import '../../widgets/pdf_viewer.dart';

class AndroidHome extends StatefulWidget {
  const AndroidHome({super.key});

  @override
  State<AndroidHome> createState() => _AndroidHomeState();
}

class _AndroidHomeState extends State<AndroidHome> {
  final WebSocketService _webSocketService = WebSocketService();
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController();

  bool _isConnected = false;
  String _status = 'Waiting to connect...';
  Uint8List? _pdfBytes;
  String? _currentFileName;
  bool _isSigned = false;
  bool _expectingPdf = false;

  @override
  void initState() {
    super.initState();
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
    final msg = WebSocketService.tryParseMessage(data);
    if (msg != null) {
      if (msg.type == SignikMessageType.sendStart) {
        setState(() {
          _currentFileName = msg.name;
          _status = 'Receiving ${msg.name}...';
          _isSigned = false;
          _pdfBytes = null;
          _expectingPdf = true;
        });
        return;
      }
    }
    if (data is Uint8List && _expectingPdf) {
      setState(() {
        _pdfBytes = data;
        _status = 'PDF received. Ready to sign.';
        _isSigned = false;
        _expectingPdf = false;
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
    setState(() {
      _status = 'Sending signature...';
      _isSigned = true;
    });
    await _webSocketService.sendData(signatureBytes);
    _signatureController.clear();
    setState(() {
      _pdfBytes = null;
      _status = 'Signature sent! Waiting for next PDF...';
      _expectingPdf = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isConnected) {
      return Scaffold(
        appBar: AppBar(title: const Text('Signik - Android')),
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
                    style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50)),
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
          StatusPanel(status: _status, connected: _isConnected),
          if (_pdfBytes != null) ...[
            Expanded(
              child: Stack(
                children: [
                  // Signature area
                  Positioned.fill(
                    child: Container(
                      color: Colors.white,
                      child: Signature(
                        controller: _signatureController,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  // PDF preview in upper right
                  Positioned(
                    top: 16,
                    right: 16,
                    child: GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            insetPadding: const EdgeInsets.all(16),
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width * 0.8,
                              height: MediaQuery.of(context).size.height * 0.8,
                              child: PdfViewerWidget(pdfBytes: _pdfBytes!),
                            ),
                          ),
                        );
                      },
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 120,
                          height: 160,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: AbsorbPointer(
                              child: PdfViewerWidget(pdfBytes: _pdfBytes!),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.description, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text('Waiting for PDF...', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(_status, style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _pdfBytes != null && !_isSigned
          ? FloatingActionButton.extended(
              onPressed: _sendSignature,
              label: const Text('Send'),
              icon: const Icon(Icons.send),
            )
          : null,
    );
  }

  @override
  void dispose() {
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