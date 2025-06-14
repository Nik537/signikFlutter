import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:signature/signature.dart';
import '../../services/connection_manager.dart' as cm;
import '../../services/app_config.dart';
import '../../models/signik_message.dart';
import '../../widgets/status_panel.dart';
import '../../widgets/pdf_viewer.dart';

class AndroidHome extends StatefulWidget {
  const AndroidHome({super.key});

  @override
  State<AndroidHome> createState() => _AndroidHomeState();
}

class _AndroidHomeState extends State<AndroidHome> {
  final cm.ConnectionManager _connectionManager = cm.ConnectionManager();
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  bool _isConnected = false;
  String _status = 'Connecting to broker...';
  Uint8List? _pdfBytes;
  String? _currentFileName;
  String? _currentDocId;
  bool _isSigned = false;
  bool _expectingPdf = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _connectToBroker();
  }

  Future<void> _connectToBroker() async {
    setState(() => _status = 'Connecting to broker...');
    try {
      await _connectionManager.connect(deviceName: 'Signik Android Tablet');
      
      // Listen to connection state
      _connectionManager.connectionState.listen((state) {
        setState(() {
          _isConnected = state == cm.ConnectionState.connected;
          switch (state) {
            case cm.ConnectionState.connecting:
              _status = 'Connecting to broker...';
              break;
            case cm.ConnectionState.connected:
              _status = 'Connected to broker. Waiting for PDF...';
              break;
            case cm.ConnectionState.disconnected:
              _status = 'Disconnected from broker';
              _isConnected = false;
              break;
            case cm.ConnectionState.error:
              _status = 'Connection error';
              _isConnected = false;
              break;
          }
        });
      });
      
      // Listen to messages
      _connectionManager.messages.listen(_handleMessage);
      
      // Listen to raw data (PDF bytes)
      _connectionManager.rawData.listen((data) {
        if (_expectingPdf) {
          setState(() {
            _pdfBytes = data;
            _status = 'PDF received. Ready to sign.';
            _isSigned = false;
            _expectingPdf = false;
          });
        }
      });
    } catch (e) {
      setState(() {
        _isConnected = false;
        _status = 'Connection failed: $e';
      });
    }
  }

  void _handleMessage(SignikMessage msg) {
    if (msg.type == SignikMessageType.sendStart) {
      setState(() {
        _currentFileName = msg.name;
        _currentDocId = msg.docId;
        _status = 'Receiving ${msg.name}...';
        _isSigned = false;
        _pdfBytes = null;
        _expectingPdf = true;
      });
      return;
    }
    
    if (msg.type == SignikMessageType.signatureAccepted) {
      setState(() {
        _status = 'Signature accepted! Waiting for next PDF...';
        _pdfBytes = null;
        _isSigned = false;
        _currentDocId = null;
      });
      return;
    }
    
    if (msg.type == SignikMessageType.signatureDeclined) {
      setState(() {
        _status = 'Signature declined. Please sign again.';
        _isSigned = false;
      });
      _signatureController.clear();
      return;
    }
  }

  Future<void> _sendSignature() async {
    if (_pdfBytes == null || _currentDocId == null) return;
    
    final signatureBytes = await _signatureController.toPngBytes();
    if (signatureBytes == null) {
      setState(() => _status = 'Failed to generate signature');
      return;
    }
    
    setState(() {
      _status = 'Sending signature for review...';
      _isSigned = true;
    });
    
    final previewMsg = SignikMessage(
      type: SignikMessageType.signaturePreview,
      data: signatureBytes,
      docId: _currentDocId,
    );
    await _connectionManager.sendMessage(previewMsg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Signik - Android'),
        actions: [
          Icon(
            _isConnected ? Icons.hub : Icons.hub_outlined,
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
          ] else if (!_isConnected)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text('Connecting to broker...', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text('Broker: ${AppConfig.brokerUrl}', style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _connectToBroker,
                      child: const Text('Retry Connection'),
                    ),
                  ],
                ),
              ),
            )
          else
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
    _connectionManager.dispose();
    _signatureController.dispose();
    super.dispose();
  }
} 