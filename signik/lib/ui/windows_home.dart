import 'dart:io';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../services/websocket_service.dart';
import '../services/file_service.dart';

class WindowsHome extends StatefulWidget {
  const WindowsHome({super.key});

  @override
  State<WindowsHome> createState() => _WindowsHomeState();
}

class _WindowsHomeState extends State<WindowsHome> {
  final _webSocketService = WebSocketService();
  late final FileService _fileService;
  bool _isConnected = false;
  bool _isDragging = false;
  String _status = 'Waiting for PDF...';

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // Get the user's documents directory for watching
    final documentsDir = Directory('${Platform.environment['USERPROFILE']}\\Documents');
    _fileService = FileService(watchDirectory: documentsDir.path);

    // Start WebSocket server
    await _webSocketService.startServer();

    // Listen for connections
    _webSocketService.onConnection.listen((connected) {
      setState(() {
        _isConnected = connected;
        _status = connected ? 'Phone connected' : 'Waiting for phone...';
      });
    });

    // Listen for file changes
    _fileService.onFileChanged.listen(_handleFileChanged);
  }

  Future<void> _handleFileChanged(File file) async {
    if (!_isConnected) {
      setState(() => _status = 'Please connect your phone first');
      return;
    }

    setState(() => _status = 'Processing ${file.path}...');
    
    try {
      final bytes = await _fileService.readFile(file);
      await _webSocketService.sendData({
        'type': 'sendStart',
        'name': file.path.split(Platform.pathSeparator).last,
      });
      await _webSocketService.sendData(bytes);
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
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
      body: DropTarget(
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
    );
  }

  @override
  void dispose() {
    _webSocketService.dispose();
    _fileService.dispose();
    super.dispose();
  }
} 