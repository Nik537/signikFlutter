import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:provider/provider.dart';
import '../../services/connection_manager.dart' as cm;
import '../../services/file_service.dart';
import '../../services/pdf_service.dart';
import '../../services/app_config.dart';
import '../../services/device_connections_service.dart';
import '../../models/signik_document.dart';
import '../../models/signik_message.dart';
import '../../models/signik_device.dart';
import '../../widgets/status_panel.dart';
import '../../widgets/signed_documents_list.dart';
import '../../widgets/pdf_viewer.dart';
import '../../widgets/device_selection_dialog.dart';
import '../../widgets/sidebar_with_tabs.dart';
import '../../services/email_service.dart';
import '../../services/app_config.dart';

class WindowsHome extends StatefulWidget {
  const WindowsHome({super.key});

  @override
  State<WindowsHome> createState() => _WindowsHomeState();
}

class _WindowsHomeState extends State<WindowsHome> with TickerProviderStateMixin {
  late cm.ConnectionManager _connectionManager;
  late FileService _fileService;
  final PdfService _pdfService = PdfService();
  final EmailService _emailService = EmailService();
  DeviceConnectionsService? _connectionsService;
  bool _isConnected = false;
  bool _isDragging = false;
  String _status = 'Connecting to broker...';
  File? _currentFile;
  Uint8List? _currentPdfBytes;
  String? _currentDocId;
  final List<SignikDocument> _signedDocuments = [];
  List<SignikDevice> _onlineDevices = [];
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServices();
    });
  }

  Future<void> _initializeServices() async {
    try {
      // Load app configuration including email settings
      await AppConfig.loadFromPreferences();
      
      // Get connection manager from provider
      _connectionManager = Provider.of<cm.ConnectionManager>(context, listen: false);
      
      final documentsDir = Directory('${Platform.environment['USERPROFILE']}\\Documents');
      if (!await documentsDir.exists()) {
        await documentsDir.create(recursive: true);
      }
      _fileService = FileService(watchDirectory: documentsDir.path);
      
      // Initialize device connections service
      _connectionsService = DeviceConnectionsService();
      await _connectionsService!.loadConnections();
      
      // Connect to broker
      await _connectionManager.connect(deviceName: 'Signik Windows PC');
      
      // Start device refresh
      _connectionManager.startDeviceRefresh();
      
      setState(() {
        _isInitialized = true;
      });
      
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
              _refreshOnlineDevices();
              break;
            case cm.ConnectionState.disconnected:
              _status = 'Disconnected from broker';
              break;
            case cm.ConnectionState.error:
              _status = 'Connection error';
              break;
          }
        });
      });
      
      // Listen to messages
      _connectionManager.messages.listen(_handleMessage);
      
      // Listen to raw data (signed PDFs from Android)
      _connectionManager.rawData.listen((data) {
        // Handle incoming signed PDFs if needed
        // For now, Windows primarily sends PDFs
      });
      
      // Listen to file changes
      _fileService.onFileChanged.listen(_handleFileChanged);
    } catch (e) {
      setState(() {
        _status = 'Error initializing services: $e';
      });
    }
  }

  Future<void> _refreshOnlineDevices() async {
    try {
      print('Fetching devices from broker...');
      final devices = await _connectionManager.getOnlineDevices();
      print('Received ${devices.length} devices from broker:');
      for (final device in devices) {
        print('  - ${device.name} (${device.deviceType}) - Online: ${device.isOnline}');
      }
      
      setState(() {
        _onlineDevices = devices;
      });
      
      // Also print filtered Android devices
      final onlineAndroidDevices = _onlineDevices.where((d) => d.deviceType == DeviceType.android && d.isOnline).toList();
      print('Filtered to ${onlineAndroidDevices.length} online Android devices:');
      for (final device in onlineAndroidDevices) {
        print('  - ${device.name} (${device.deviceType}) - Online: ${device.isOnline}');
      }
    } catch (e) {
      print('Error fetching devices: $e');
    }
  }
  
  List<SignikDevice> _getAvailableAndroidDevices() {
    final currentPcId = _connectionManager.deviceId;
    if (currentPcId == null) return [];
    
    final connectedDeviceIds = _connectionsService?.getConnectedDevices(currentPcId) ?? [];
    return _onlineDevices.where((device) => 
      device.deviceType == DeviceType.android && 
      device.isOnline &&
      connectedDeviceIds.contains(device.id)
    ).toList();
  }

  Future<void> _handleFileChanged(File file) async {
    // Refresh online devices
    await _refreshOnlineDevices();
    
    final availableAndroidDevices = _getAvailableAndroidDevices();
    
    if (availableAndroidDevices.isEmpty) {
      setState(() => _status = 'No connected Android devices available. Check device connections.');
      
      // Offer to open device connections screen
      final shouldOpenConnections = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No Connected Devices'),
          content: const Text('There are no Android devices connected to this PC. Would you like to manage device connections?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Manage Connections'),
            ),
          ],
        ),
      );
      
      // Device connections can now be managed in the sidebar tab
      return;
    }
    
    setState(() {
      _currentFile = file;
      _status = 'Processing ${file.path}...';
    });
    
    try {
      final bytes = await _fileService.readFile(file);
      _currentPdfBytes = Uint8List.fromList(bytes);
      
      final fileName = file.path.split(Platform.pathSeparator).last;
      
      // Show device selection dialog if multiple devices, or auto-select if only one
      SignikDevice? targetDevice;
      
      if (availableAndroidDevices.length == 1) {
        targetDevice = availableAndroidDevices.first;
      } else {
        // Show device selection dialog
        targetDevice = await showDialog<SignikDevice>(
          context: context,
          barrierDismissible: false,
          builder: (context) => DeviceSelectionDialog(
            devices: availableAndroidDevices,
            documentName: fileName,
          ),
        );
      }
      
      if (targetDevice == null) {
        // User cancelled
        setState(() => _status = 'Send cancelled. Waiting for PDF...');
        return;
      }
      
      setState(() => _status = 'Sending to ${targetDevice!.name}...');
      
      // Enqueue document with broker
      final docId = await _connectionManager.enqueueDocument(
        fileName,
        pdfData: bytes,
      );
      _currentDocId = docId;
      
      final msg = SignikMessage(
        type: SignikMessageType.sendStart,
        name: fileName,
        docId: docId,
        deviceId: targetDevice.id, // Pass target device ID
      );
      await _connectionManager.sendMessage(msg);
      await _connectionManager.sendRawData(_currentPdfBytes!);
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  Future<void> _handleMessage(SignikMessage msg) async {
    if (msg.type == SignikMessageType.signaturePreview && msg.data != null) {
      // Show preview dialog and wait for user action
      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Signature Preview'),
          content: SizedBox(
            width: 300,
            height: 200,
            child: Image.memory(Uint8List.fromList(List<int>.from(msg.data))),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Decline'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Accept'),
            ),
          ],
        ),
      );
      
      if (accepted == true) {
        // Send accepted message
        final acceptMsg = SignikMessage(
          type: SignikMessageType.signatureAccepted,
          docId: msg.docId,
        );
        await _connectionManager.sendMessage(acceptMsg);
        
        // Embed the signature
        if (_currentFile != null && _currentPdfBytes != null) {
          setState(() => _status = 'Embedding signature...');
          try {
            final signedPdfBytes = await _pdfService.embedSignature(
              _currentPdfBytes!,
              Uint8List.fromList(List<int>.from(msg.data))
            );
            
            final signedPath = _fileService.getSignedPath(_currentFile!.path);
            final signedFile = File(signedPath);
            await signedFile.writeAsBytes(signedPdfBytes);
            
            final doc = _fileService.fileToDocument(signedFile, signed: true);
            setState(() {
              if (!_signedDocuments.any((d) => d.path == doc.path)) {
                _signedDocuments.add(doc);
              }
            });
            
            final completeMsg = SignikMessage(
              type: SignikMessageType.signedComplete,
              name: _currentFile!.path.split(Platform.pathSeparator).last,
              docId: msg.docId,
            );
            await _connectionManager.sendMessage(completeMsg);
            await _connectionManager.sendRawData(signedPdfBytes);
            
            setState(() => _status = 'PDF signed and saved. Sending email...');
            
            // Send email with signed document
            try {
              await _emailService.sendSignedDocument(
                documentName: signedPath.split(Platform.pathSeparator).last,
                pdfBytes: signedPdfBytes,
              );
              setState(() => _status = 'PDF signed, saved, and emailed to lolcat774@gmail.com');
            } catch (emailError) {
              setState(() => _status = 'PDF signed and saved. Email failed: $emailError');
              // Log error but don't fail the entire operation
              print('Email error: $emailError');
            }
          } catch (e) {
            setState(() => _status = 'Error embedding signature: $e');
          }
        }
      } else {
        // Send declined message
        final declineMsg = SignikMessage(
          type: SignikMessageType.signatureDeclined,
          docId: msg.docId,
        );
        await _connectionManager.sendMessage(declineMsg);
        setState(() => _status = 'Signature declined. Waiting for new signature...');
      }
    }
  }

  void _openDocument(SignikDocument doc) async {
    if (doc.path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document path not available')),
      );
      return;
    }
    
    final file = File(doc.path!);
    final bytes = await file.readAsBytes();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 600,
          height: 800,
          child: PdfViewerWidget(pdfBytes: bytes),
        ),
      ),
    );
  }
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Signik - Windows'),
            const SizedBox(width: 16),
            if (_isConnected)
              Chip(
                label: Text('${_onlineDevices.length} device${_onlineDevices.length != 1 ? 's' : ''} online'),
                backgroundColor: Colors.green.withOpacity(0.2),
              ),
          ],
        ),
        actions: [
          if (_isConnected)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshOnlineDevices,
              tooltip: 'Refresh devices',
            ),
          Icon(
            _isConnected ? Icons.hub : Icons.hub_outlined,
            color: _isConnected ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              children: [
                StatusPanel(
                  status: _status,
                  ip: 'Broker Mode',
                  port: 0,
                  connected: _isConnected,
                  hideStatus: true,
                ),
                Expanded(
                  child: DropTarget(
                    onDragDone: (details) {
                      for (final file in details.files) {
                        if (file.path.toLowerCase().endsWith('.pdf')) {
                          _handleFileChanged(File(file.path));
                        }
                      }
                    },
                    onDragEntered: (details) {
                      setState(() => _isDragging = true);
                    },
                    onDragExited: (details) {
                      setState(() => _isDragging = false);
                    },
                    child: Container(
                      color: _isDragging ? Colors.blue.withOpacity(0.1) : null,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.upload_file,
                              size: 64,
                              color: _isDragging ? Colors.blue : Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _isDragging ? 'Drop PDF here' : 'Drag and drop PDF here',
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
                  ),
                ),
              ],
            ),
          ),
          if (_isInitialized && _connectionsService != null)
            Consumer<cm.ConnectionManager>(
              builder: (context, connectionManager, _) => SidebarWithTabs(
                signedDocuments: _signedDocuments,
                onOpenDocument: _openDocument,
                connectionsService: _connectionsService!,
                onConnectionsChanged: _refreshOnlineDevices,
              ),
            )
          else
            Container(
              width: 360,
              color: Colors.grey[50],
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _connectionManager.stopDeviceRefresh();
      _fileService.dispose();
    }
    super.dispose();
  }
} 