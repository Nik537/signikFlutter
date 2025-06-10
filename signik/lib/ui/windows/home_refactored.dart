import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:provider/provider.dart';
import '../../services/connection_manager.dart' as cm;
import '../../services/file_service.dart';
import '../../services/pdf_service.dart';
import '../../services/device_connections_service.dart';
import '../../models/signik_document.dart';
import '../../models/signik_message.dart';
import '../../models/signik_device.dart';
import '../../widgets/status_panel.dart';
import '../../widgets/signed_documents_list.dart';
import '../../widgets/pdf_viewer.dart';
import '../../widgets/device_selection_dialog.dart';
import '../../widgets/sidebar_with_tabs.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/connection_status_indicator.dart';
import '../../core/constants.dart';
import '../../core/exceptions/app_exceptions.dart';

/// Refactored Windows home screen with improved code organization
class WindowsHomeRefactored extends StatefulWidget {
  const WindowsHomeRefactored({super.key});

  @override
  State<WindowsHomeRefactored> createState() => _WindowsHomeRefactoredState();
}

class _WindowsHomeRefactoredState extends State<WindowsHomeRefactored> 
    with TickerProviderStateMixin {
  // Dependencies
  late cm.ConnectionManager _connectionManager;
  late FileService _fileService;
  final PdfService _pdfService = PdfService();
  DeviceConnectionsService? _connectionsService;

  // State variables
  bool _isConnected = false;
  bool _isDragging = false;
  String _status = AppConstants.statusConnecting;
  bool _isInitialized = false;

  // Current operation state
  File? _currentFile;
  Uint8List? _currentPdfBytes;
  String? _currentDocId;
  
  // Collections
  final List<SignikDocument> _signedDocuments = [];
  List<SignikDevice> _onlineDevices = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServices();
    });
  }

  // ===== Initialization Methods =====

  Future<void> _initializeServices() async {
    try {
      _connectionManager = Provider.of<cm.ConnectionManager>(context, listen: false);
      
      await _setupFileService();
      await _setupConnectionsService();
      await _connectToBroker();
      _setupListeners();
      
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _status = 'Error initializing services: $e';
        _isInitialized = true;
      });
    }
  }

  Future<void> _setupFileService() async {
    final documentsDir = Directory('${Platform.environment['USERPROFILE']}\\Documents');
    if (!await documentsDir.exists()) {
      await documentsDir.create(recursive: true);
    }
    _fileService = FileService(watchDirectory: documentsDir.path);
  }

  Future<void> _setupConnectionsService() async {
    _connectionsService = DeviceConnectionsService();
    await _connectionsService!.loadConnections();
  }

  Future<void> _connectToBroker() async {
    await _connectionManager.connect(deviceName: AppConstants.defaultWindowsName);
    _connectionManager.startDeviceRefresh();
  }

  void _setupListeners() {
    // Connection state listener
    _connectionManager.connectionState.listen(_handleConnectionStateChange);
    
    // Message listener
    _connectionManager.messages.listen(_handleMessage);
    
    // Raw data listener
    _connectionManager.rawData.listen(_handleRawData);
    
    // File change listener
    _fileService.onFileChanged.listen(_handleFileChanged);
  }

  // ===== Event Handlers =====

  void _handleConnectionStateChange(cm.ConnectionState state) {
    setState(() {
      _isConnected = state == cm.ConnectionState.connected;
      switch (state) {
        case cm.ConnectionState.connecting:
          _status = AppConstants.statusConnecting;
          break;
        case cm.ConnectionState.connected:
          _status = AppConstants.statusConnected;
          _refreshOnlineDevices();
          break;
        case cm.ConnectionState.disconnected:
          _status = AppConstants.statusDisconnected;
          break;
        case cm.ConnectionState.error:
          _status = AppConstants.statusConnectionError;
          break;
      }
    });
  }

  void _handleRawData(Uint8List data) {
    // Handle incoming signed PDFs if needed
    // For now, Windows primarily sends PDFs
  }

  // ===== Device Management Methods =====

  Future<void> _refreshOnlineDevices() async {
    try {
      final devices = await _connectionManager.getOnlineDevices();
      setState(() {
        _onlineDevices = devices;
      });
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

  // ===== File Handling Methods =====

  Future<void> _handleFileChanged(File file) async {
    await _refreshOnlineDevices();
    
    final availableDevices = _getAvailableAndroidDevices();
    
    if (!await _validateDeviceAvailability(availableDevices)) {
      return;
    }
    
    setState(() {
      _currentFile = file;
      _status = 'Processing ${file.path}...';
    });
    
    try {
      final bytes = await _fileService.readFile(file);
      _currentPdfBytes = Uint8List.fromList(bytes);
      
      final targetDevice = await _selectTargetDevice(availableDevices, file);
      if (targetDevice == null) {
        setState(() => _status = 'Send cancelled. Waiting for PDF...');
        return;
      }
      
      await _sendPdfToDevice(targetDevice, file, bytes);
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  Future<bool> _validateDeviceAvailability(List<SignikDevice> devices) async {
    if (devices.isEmpty) {
      setState(() => _status = AppConstants.errorNoConnectedDevices);
      
      final shouldOpenConnections = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No Connected Devices'),
          content: const Text('There are no Android devices connected to this PC. Would you like to manage device connections?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(AppConstants.buttonCancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(AppConstants.buttonManageConnections),
            ),
          ],
        ),
      );
      
      // Device connections can now be managed in the sidebar tab
      return false;
    }
    return true;
  }

  Future<SignikDevice?> _selectTargetDevice(
    List<SignikDevice> availableDevices,
    File file,
  ) async {
    final fileName = file.path.split(Platform.pathSeparator).last;
    
    if (availableDevices.length == 1) {
      return availableDevices.first;
    }
    
    return await showDialog<SignikDevice>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DeviceSelectionDialog(
        devices: availableDevices,
        documentName: fileName,
      ),
    );
  }

  Future<void> _sendPdfToDevice(
    SignikDevice targetDevice,
    File file,
    List<int> bytes,
  ) async {
    setState(() => _status = 'Sending to ${targetDevice.name}...');
    
    final fileName = file.path.split(Platform.pathSeparator).last;
    final docId = await _connectionManager.enqueueDocument(
      fileName,
      pdfData: bytes,
    );
    _currentDocId = docId;
    
    final msg = SignikMessage(
      type: SignikMessageType.sendStart,
      name: fileName,
      docId: docId,
      deviceId: targetDevice.id,
    );
    await _connectionManager.sendMessage(msg);
    await _connectionManager.sendRawData(_currentPdfBytes!);
  }

  // ===== Message Handling Methods =====

  Future<void> _handleMessage(SignikMessage msg) async {
    switch (msg.type) {
      case SignikMessageType.signaturePreview:
        if (msg.data != null) {
          await _handleSignaturePreview(msg);
        }
        break;
      default:
        // Handle other message types if needed
        break;
    }
  }

  Future<void> _handleSignaturePreview(SignikMessage msg) async {
    final accepted = await _showSignaturePreviewDialog(msg.data);
    
    if (accepted == true) {
      await _processSignatureAcceptance(msg);
    } else {
      await _processSignatureDecline(msg);
    }
  }

  Future<bool?> _showSignaturePreviewDialog(dynamic signatureData) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Signature Preview'),
        content: SizedBox(
          width: AppConstants.signaturePreviewWidth,
          height: AppConstants.signaturePreviewHeight,
          child: Image.memory(Uint8List.fromList(List<int>.from(signatureData))),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppConstants.buttonDecline),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppConstants.buttonAccept),
          ),
        ],
      ),
    );
  }

  Future<void> _processSignatureAcceptance(SignikMessage msg) async {
    final acceptMsg = SignikMessage(
      type: SignikMessageType.signatureAccepted,
      docId: msg.docId,
    );
    await _connectionManager.sendMessage(acceptMsg);
    
    if (_currentFile != null && _currentPdfBytes != null) {
      await _embedSignatureInPdf(msg.data, msg.docId);
    }
  }

  Future<void> _processSignatureDecline(SignikMessage msg) async {
    final declineMsg = SignikMessage(
      type: SignikMessageType.signatureDeclined,
      docId: msg.docId,
    );
    await _connectionManager.sendMessage(declineMsg);
    setState(() => _status = AppConstants.statusSignatureDeclined);
  }

  Future<void> _embedSignatureInPdf(dynamic signatureData, String? docId) async {
    setState(() => _status = AppConstants.statusEmbeddingSignature);
    
    try {
      final signedPdfBytes = await _pdfService.embedSignature(
        _currentPdfBytes!,
        Uint8List.fromList(List<int>.from(signatureData))
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
        docId: docId,
      );
      await _connectionManager.sendMessage(completeMsg);
      await _connectionManager.sendRawData(signedPdfBytes);
      
      setState(() => _status = AppConstants.statusPdfSigned);
    } catch (e) {
      setState(() => _status = 'Error embedding signature: $e');
    }
  }

  // ===== UI Helper Methods =====

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

  // ===== Build Method =====

  @override
  Widget build(BuildContext context) {
    return Consumer<cm.ConnectionManager>(
      builder: (context, connectionManager, child) {
        if (_isInitialized && connectionManager.isConnected != _isConnected) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _isConnected = connectionManager.isConnected;
              if (_isConnected) {
                _status = AppConstants.statusConnected;
              }
            });
          });
        }
        
        return Scaffold(
          appBar: _buildAppBar(),
          body: Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildMainContent(),
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
                  width: AppConstants.sidebarWidth,
                  color: Colors.grey[50],
                  child: const LoadingWidget(),
                ),
            ],
          ),
        );
      },
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
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
            tooltip: AppConstants.tooltipRefreshDevices,
          ),
        ConnectionHubIcon(isConnected: _isConnected),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        StatusPanel(
          status: _status,
          ip: 'Broker Mode',
          port: 0,
          connected: _isConnected,
          hideStatus: true,
        ),
        Expanded(
          child: _buildDropTarget(),
        ),
      ],
    );
  }

  Widget _buildDropTarget() {
    return DropTarget(
      onDragDone: (details) {
        for (final file in details.files) {
          if (file.path.toLowerCase().endsWith(AppConstants.pdfExtension)) {
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