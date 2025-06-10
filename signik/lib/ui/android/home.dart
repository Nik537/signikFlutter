import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';
import '../../services/connection_manager.dart' as cm;
import '../../services/app_config.dart';
import '../../models/signik_message.dart';
import '../../widgets/status_panel.dart';
import '../../widgets/pdf_viewer.dart';
import 'settings_screen.dart';

class AndroidHome extends StatefulWidget {
  const AndroidHome({super.key});

  @override
  State<AndroidHome> createState() => _AndroidHomeState();
}

class _AndroidHomeState extends State<AndroidHome> {
  late cm.ConnectionManager _connectionManager;
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
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeConnection();
    });
  }

  Future<void> _initializeConnection() async {
    _connectionManager = Provider.of<cm.ConnectionManager>(context, listen: false);
    
    // Always set up listeners first
    _setupListeners();
    
    // Check if already connected
    if (_connectionManager.isConnected) {
      setState(() {
        _isConnected = true;
        _status = 'Connected to broker. Waiting for PDF...';
        _isInitialized = true;
      });
      // Start device refresh if not already started
      _connectionManager.startDeviceRefresh();
      return;
    }
    
    // Connect if not already connected
    setState(() => _status = 'Connecting to broker...');
    try {
      // Use saved device name or default
      final deviceName = AppConfig.deviceName.isNotEmpty 
          ? AppConfig.deviceName 
          : 'Signik Android Tablet';
      
      await _connectionManager.connect(deviceName: deviceName);
      // Start device refresh
      _connectionManager.startDeviceRefresh();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _isConnected = false;
        _status = 'Connection failed: $e';
        _isInitialized = true;
      });
    }
  }
  
  void _setupListeners() {
    // Listen to connection state
    _connectionManager.connectionState.listen((state) {
      if (mounted) {
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
      }
    });
    
    // Listen to messages
    _connectionManager.messages.listen(_handleMessage);
    
    // Listen to raw data (PDF bytes)
    _connectionManager.rawData.listen((data) {
      if (_expectingPdf && mounted) {
        setState(() {
          _pdfBytes = data;
          _status = 'PDF received. Ready to sign.';
          _isSigned = false;
          _expectingPdf = false;
        });
      }
    });
  }

  void _handleMessage(SignikMessage msg) {
    if (msg.type == SignikMessageType.sendStart) {
      // Clear signature pad for new document
      _signatureController.clear();
      
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
      // Clear signature pad after acceptance
      _signatureController.clear();
      
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
    return Consumer<cm.ConnectionManager>(
      builder: (context, connectionManager, child) {
        // Update connection state based on provider
        if (_isInitialized && connectionManager.isConnected != _isConnected) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _isConnected = connectionManager.isConnected;
              if (_isConnected) {
                _status = 'Connected to broker. Waiting for PDF...';
              }
            });
          });
        }
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('Signik - Android'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                  
                  // If settings were changed, show restart reminder
                  if (result == true && mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Restart Required'),
                        content: const Text('Please restart the app for the new settings to take effect.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  }
                },
                tooltip: 'Settings',
              ),
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
          ] else if (!_isInitialized)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (!_isConnected)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Not connected to broker', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text('Broker: ${AppConfig.brokerUrl}', style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _initializeConnection,
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
      },
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
    _signatureController.dispose();
    super.dispose();
  }
} 