import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../../services/websocket_service.dart';
import '../../services/file_service.dart';
import '../../services/pdf_service.dart';
import '../../models/signik_document.dart';
import '../../models/signik_message.dart';
import '../../widgets/status_panel.dart';
import '../../widgets/signed_documents_list.dart';
import '../../widgets/pdf_viewer.dart';

class WindowsHome extends StatefulWidget {
  const WindowsHome({super.key});

  @override
  State<WindowsHome> createState() => _WindowsHomeState();
}

class _WindowsHomeState extends State<WindowsHome> {
  final WebSocketService _webSocketService = WebSocketService();
  late FileService _fileService;
  final PdfService _pdfService = PdfService();
  bool _isConnected = false;
  bool _isDragging = false;
  String _status = 'Waiting for PDF...';
  File? _currentFile;
  Uint8List? _currentPdfBytes;
  final List<SignikDocument> _signedDocuments = [];

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      final documentsDir = Directory('${Platform.environment['USERPROFILE']}\\Documents');
      if (!await documentsDir.exists()) {
        await documentsDir.create(recursive: true);
      }
      _fileService = FileService(watchDirectory: documentsDir.path);
      await _webSocketService.startServer();
      _webSocketService.onConnection.listen((connected) {
        setState(() {
          _isConnected = connected;
          _status = connected ? 'Phone connected' : 'Waiting for phone...';
        });
      });
      _fileService.onFileChanged.listen(_handleFileChanged);
      _webSocketService.onMessage.listen(_handleMessage);
    } catch (e) {
      setState(() {
        _status = 'Error initializing services: $e';
      });
    }
  }

  Future<void> _handleFileChanged(File file) async {
    if (!_isConnected) {
      setState(() => _status = 'Please connect your phone first');
      return;
    }
    setState(() {
      _currentFile = file;
      _status = 'Processing ${file.path}...';
    });
    try {
      final bytes = await _fileService.readFile(file);
      _currentPdfBytes = Uint8List.fromList(bytes);
      final msg = SignikMessage(type: SignikMessageType.sendStart, name: file.path.split(Platform.pathSeparator).last);
      await _webSocketService.sendData(msg);
      await _webSocketService.sendData(_currentPdfBytes!);
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  Future<void> _handleMessage(dynamic data) async {
    if (data is Uint8List && _currentFile != null && _currentPdfBytes != null) {
      setState(() => _status = 'Embedding signature...');
      try {
        final signedPdfBytes = await _pdfService.embedSignature(_currentPdfBytes!, data);
        final signedPath = _fileService.getSignedPath(_currentFile!.path);
        final signedFile = File(signedPath);
        await signedFile.writeAsBytes(signedPdfBytes);
        final doc = _fileService.fileToDocument(signedFile, signed: true);
        setState(() {
          if (!_signedDocuments.any((d) => d.path == doc.path)) {
            _signedDocuments.add(doc);
          }
        });
        final msg = SignikMessage(type: SignikMessageType.signedComplete, name: _currentFile!.path.split(Platform.pathSeparator).last);
        await _webSocketService.sendData(msg);
        await _webSocketService.sendData(signedPdfBytes);
        setState(() => _status = 'PDF signed and saved');
      } catch (e) {
        setState(() => _status = 'Error embedding signature: $e');
      }
    }
  }

  void _openDocument(SignikDocument doc) async {
    final file = File(doc.path);
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
        title: const Text('Signik - Windows'),
        actions: [
          Icon(
            _isConnected ? Icons.phone_android : Icons.phone_android_outlined,
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
                FutureBuilder<String>(
                  future: _webSocketService.getLocalIp(),
                  builder: (context, snapshot) {
                    return StatusPanel(
                      status: _status,
                      ip: snapshot.data,
                      port: _webSocketService.port,
                      connected: _isConnected,
                      hideStatus: true,
                    );
                  },
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
          Container(
            width: 320,
            color: Colors.grey[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
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
    );
  }

  @override
  void dispose() {
    _webSocketService.dispose();
    _fileService.dispose();
    super.dispose();
  }
} 