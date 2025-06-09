import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../models/signik_device.dart';
import '../../models/signik_document.dart';
import '../../models/signik_message.dart';
import '../../services/file_service.dart';
import '../../services/pdf_service.dart';
import '../../services/connection_manager_refactored.dart';
import '../../widgets/pdf_viewer.dart';
import '../../widgets/signed_documents_list.dart';
import '../../widgets/device_selection_dialog.dart';
import '../base/base_home_screen.dart';
import '../components/connection_status_widget.dart';
import '../components/pdf_drop_zone.dart';
import '../components/device_list_widget.dart';
import 'device_connection_tab.dart';

/// Refactored Windows home screen
class WindowsHomeRefactored extends BaseHomeScreen {
  const WindowsHomeRefactored({super.key});

  @override
  State<WindowsHomeRefactored> createState() => _WindowsHomeRefactoredState();
}

class _WindowsHomeRefactoredState extends BaseHomeScreenState<WindowsHomeRefactored> 
    with TickerProviderStateMixin {
  late TabController _tabController;
  late FileService _fileService;
  final PdfService _pdfService = PdfService();
  
  // Document state
  File? _currentFile;
  Uint8List? _currentPdfBytes;
  String? _currentDocId;
  final List<SignikDocument> _signedDocuments = [];
  
  // UI state
  String _pdfStatus = 'Waiting for PDF...';

  @override
  String get deviceName => 'Signik Windows PC';
  
  @override
  DeviceType get deviceType => DeviceType.windows;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeFileService();
  }

  Future<void> _initializeFileService() async {
    try {
      final documentsDir = Directory('${Platform.environment['USERPROFILE']}\\Documents');
      if (!await documentsDir.exists()) {
        await documentsDir.create(recursive: true);
      }
      _fileService = FileService(watchDirectory: documentsDir.path);
      _fileService.onFileChanged.listen(_handleFileChanged);
    } catch (e) {
      debugPrint('Error initializing file service: $e');
    }
  }

  @override
  void onConnectionStateChanged(ConnectionState state) {
    super.onConnectionStateChanged(state);
    if (state == ConnectionState.connected) {
      setState(() => _pdfStatus = 'Waiting for PDF...');
    }
  }

  @override
  void onMessage(dynamic message) {
    if (message is SignikMessage) {
      _handleSignikMessage(message);
    }
  }

  @override
  void onBinaryData(List<int> data) {
    // Windows primarily sends PDFs, not receives them
    // But this could handle signed PDFs sent back if needed
  }

  Future<void> _handleFileChanged(File file) async {
    if (!isConnected) {
      setState(() => _pdfStatus = 'Not connected to broker');
      return;
    }

    await refreshOnlineDevices();
    
    final androidDevices = onlineDevices
        .where((d) => d.deviceType == DeviceType.android && d.isOnline)
        .toList();
    
    if (androidDevices.isEmpty) {
      setState(() => _pdfStatus = 'No Android devices online');
      return;
    }
    
    setState(() {
      _currentFile = file;
      _pdfStatus = 'Processing ${file.path.split(Platform.pathSeparator).last}...';
    });
    
    try {
      // Read PDF
      final bytes = await _fileService.readFile(file);
      _currentPdfBytes = Uint8List.fromList(bytes);
      
      final fileName = file.path.split(Platform.pathSeparator).last;
      
      // Select target device
      final targetDevice = await _selectTargetDevice(androidDevices, fileName);
      if (targetDevice == null) {
        setState(() => _pdfStatus = 'Send cancelled');
        return;
      }
      
      // Send to device
      await _sendPdfToDevice(targetDevice, fileName, bytes);
      
    } catch (e) {
      setState(() => _pdfStatus = 'Error: $e');
    }
  }

  Future<SignikDevice?> _selectTargetDevice(
    List<SignikDevice> devices, 
    String documentName,
  ) async {
    if (devices.length == 1) {
      return devices.first;
    }
    
    return showDialog<SignikDevice>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DeviceSelectionDialog(
        devices: devices,
        documentName: documentName,
      ),
    );
  }

  Future<void> _sendPdfToDevice(
    SignikDevice device, 
    String fileName, 
    List<int> pdfData,
  ) async {
    setState(() => _pdfStatus = 'Sending to ${device.name}...');
    
    // Enqueue document
    final docId = await brokerService.enqueueDocument(
      fileName,
      brokerService.deviceId!,
      pdfData: pdfData,
    );
    _currentDocId = docId;
    
    // Send message
    final message = SignikMessage(
      type: SignikMessageType.sendStart,
      name: fileName,
      docId: docId,
      deviceId: device.id,
    );
    
    await connectionManager.sendMessage(message);
    await connectionManager.sendBinaryData(pdfData);
    
    setState(() => _pdfStatus = 'Sent to ${device.name}');
  }

  Future<void> _handleSignikMessage(SignikMessage message) async {
    switch (message.type) {
      case SignikMessageType.signaturePreview:
        await _handleSignaturePreview(message);
        break;
      default:
        // Other message types
        break;
    }
  }

  Future<void> _handleSignaturePreview(SignikMessage message) async {
    if (message.data == null) return;
    
    final signatureBytes = Uint8List.fromList(List<int>.from(message.data));
    
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SignaturePreviewDialog(
        signatureBytes: signatureBytes,
      ),
    );
    
    if (accepted == true) {
      await _acceptSignature(message, signatureBytes);
    } else {
      await _declineSignature(message);
    }
  }

  Future<void> _acceptSignature(
    SignikMessage message, 
    Uint8List signatureBytes,
  ) async {
    // Send acceptance
    await connectionManager.sendMessage(SignikMessage(
      type: SignikMessageType.signatureAccepted,
      docId: message.docId,
    ));
    
    // Embed signature
    if (_currentFile != null && _currentPdfBytes != null) {
      setState(() => _pdfStatus = 'Embedding signature...');
      
      try {
        final signedPdfBytes = await _pdfService.embedSignature(
          _currentPdfBytes!,
          signatureBytes,
        );
        
        // Save signed PDF
        final signedPath = _fileService.getSignedPath(_currentFile!.path);
        final signedFile = File(signedPath);
        await signedFile.writeAsBytes(signedPdfBytes);
        
        // Add to signed documents
        final doc = _fileService.fileToDocument(signedFile, signed: true);
        setState(() {
          if (!_signedDocuments.any((d) => d.path == doc.path)) {
            _signedDocuments.add(doc);
          }
          _pdfStatus = 'PDF signed and saved';
        });
        
        // Send completion message
        await connectionManager.sendMessage(SignikMessage(
          type: SignikMessageType.signedComplete,
          name: _currentFile!.path.split(Platform.pathSeparator).last,
          docId: message.docId,
        ));
        await connectionManager.sendBinaryData(signedPdfBytes);
        
      } catch (e) {
        setState(() => _pdfStatus = 'Error embedding signature: $e');
      }
    }
  }

  Future<void> _declineSignature(SignikMessage message) async {
    await connectionManager.sendMessage(SignikMessage(
      type: SignikMessageType.signatureDeclined,
      docId: message.docId,
    ));
    setState(() => _pdfStatus = 'Signature declined');
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
        child: SizedBox(
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
        title: const Text('Signik - Windows'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.picture_as_pdf), text: 'PDF Signing'),
            Tab(icon: Icon(Icons.devices), text: 'Device Connections'),
          ],
        ),
        actions: [
          ConnectionStatusWidget(
            isConnected: isConnected,
            statusMessage: statusMessage,
            deviceCount: onlineDevices.length,
            onRefresh: refreshOnlineDevices,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPdfSigningTab(),
          DeviceConnectionTab(
            connectionManager: connectionManager,
          ),
        ],
      ),
    );
  }

  Widget _buildPdfSigningTab() {
    return Row(
      children: [
        // Main content area
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: PdfDropZone(
              onFileDropped: _handleFileChanged,
              status: _pdfStatus,
              isEnabled: isConnected,
            ),
          ),
        ),
        
        // Sidebar
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(
              left: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Column(
            children: [
              // Online devices
              Expanded(
                flex: 1,
                child: DeviceListWidget(
                  devices: onlineDevices,
                  title: 'Online Android Devices',
                  emptyMessage: 'No Android devices online',
                ),
              ),
              
              const Divider(height: 1),
              
              // Signed documents
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Signed Documents',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Expanded(
                      child: SignedDocumentsList(
                        documents: _signedDocuments,
                        onOpen: _openDocument,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fileService.dispose();
    super.dispose();
  }
}

/// Signature preview dialog
class SignaturePreviewDialog extends StatelessWidget {
  final Uint8List signatureBytes;

  const SignaturePreviewDialog({
    super.key,
    required this.signatureBytes,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Signature Preview'),
      content: Container(
        width: 300,
        height: 200,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            signatureBytes,
            fit: BoxFit.contain,
          ),
        ),
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
    );
  }
}