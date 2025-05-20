import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:io';
import 'dart:convert';
import 'package:signik/services/pdf_service.dart';
import 'package:signik/services/qr_service.dart';
import 'package:signik/ui/qr_display.dart';
import 'package:signik/ui/qr_scanner.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Signik',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? _pdfPath;
  final PdfService _pdfService = PdfService();
  QrService? _qrService;
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    _initializeWebSocket();
  }

  void _initializeWebSocket() {
    final wsUrl = Uri.parse('ws://localhost:8080');
    final channel = IOWebSocketChannel.connect(wsUrl);

    _qrService = QrService(
      channel: channel,
      onConnectionEstablished: (sessionId) {
        setState(() {
          _sessionId = sessionId;
        });
      },
      onMessageReceived: (message) {
        // Handle incoming messages
        print('Received message: $message');
      },
    );
  }

  Future<void> _pickPdf() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        setState(() {
          _pdfPath = result.files.single.path;
        });
      }
    } catch (e) {
      print('Error picking PDF: $e');
    }
  }

  Future<void> _showQrCode() async {
    if (_sessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waiting for connection...')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QrDisplay(data: _sessionId!),
      ),
    );
  }

  Future<void> _scanQrCode() async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QrScanner(
          onCodeScanned: (code) {
            // Handle scanned QR code
            print('Scanned code: $code');
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Signik'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code),
            onPressed: _showQrCode,
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scanQrCode,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (_pdfPath != null) ...[
              Expanded(
                child: SfPdfViewer.file(
                  File(_pdfPath!),
                  onPageChanged: (PdfPageChangedDetails details) {
                    print('Page changed: ${details.newPageNumber}');
                  },
                ),
              ),
            ] else ...[
              const Text(
                'No PDF selected',
                style: TextStyle(fontSize: 20),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickPdf,
        tooltip: 'Pick PDF',
        child: const Icon(Icons.upload_file),
      ),
    );
  }

  @override
  void dispose() {
    _qrService?.dispose();
    super.dispose();
  }
}
