import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as path;
import 'package:watcher/watcher.dart';
import '../models/signik_document.dart';
import '../core/constants.dart';
import '../core/exceptions/app_exceptions.dart';

/// Service for watching and managing PDF files on Windows
class FileService {
  final String watchDirectory;
  final _watcher = <Watcher>[];
  final _onFileChangedController = StreamController<File>.broadcast();
  bool _disposed = false;

  Stream<File> get onFileChanged => _onFileChangedController.stream;

  FileService({required this.watchDirectory}) {
    _validateDirectory();
    _setupWatcher();
  }
  
  /// Validate that the watch directory exists and is accessible
  void _validateDirectory() {
    final dir = Directory(watchDirectory);
    if (!dir.existsSync()) {
      throw FileOperationException(
        'Watch directory does not exist',
        details: 'Path: $watchDirectory',
      );
    }
  }

  /// Set up file watcher for PDF files
  void _setupWatcher() {
    try {
      final watcher = DirectoryWatcher(watchDirectory);
      _watcher.add(watcher);

      watcher.events.listen(
        (event) {
          if (_disposed) return;
          
          if (event.type == ChangeType.ADD || event.type == ChangeType.MODIFY) {
            final file = File(event.path);
            if (path.extension(file.path).toLowerCase() == AppConstants.pdfExtension) {
              _onFileChangedController.add(file);
            }
          }
        },
        onError: (error) {
          print('File watcher error: $error');
        },
      );
    } catch (e) {
      throw FileOperationException(
        'Failed to set up file watcher',
        details: 'Directory: $watchDirectory',
        originalError: e,
      );
    }
  }

  /// Read file contents as bytes
  Future<List<int>> readFile(File file) async {
    if (!await file.exists()) {
      throw FileOperationException(
        'File does not exist',
        details: 'Path: ${file.path}',
      );
    }
    
    try {
      return await file.readAsBytes();
    } catch (e) {
      throw FileOperationException(
        'Failed to read file',
        details: 'Path: ${file.path}',
        originalError: e,
      );
    }
  }

  /// Write signed PDF file
  Future<void> writeFile(File file, List<int> bytes) async {
    if (bytes.isEmpty) {
      throw ValidationException('Cannot write empty file');
    }
    
    try {
      final signedPath = getSignedPath(file.path);
      final signedFile = File(signedPath);
      
      // Ensure directory exists
      final dir = signedFile.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      await signedFile.writeAsBytes(bytes);
    } catch (e) {
      if (e is SignikException) rethrow;
      throw FileOperationException(
        'Failed to write signed file',
        details: 'Path: ${file.path}',
        originalError: e,
      );
    }
  }

  /// Get path for signed version of PDF
  String getSignedPath(String originalPath) {
    // Get the SignikSignedDocuments path
    final documentsPath = Platform.environment['USERPROFILE'] ?? '';
    final signikOutputPath = path.join(documentsPath, 'Documents', 'SignikSignedDocuments');
    
    // Ensure output directory exists
    final outputDir = Directory(signikOutputPath);
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }
    
    final name = path.basenameWithoutExtension(originalPath);
    final ext = path.extension(originalPath);
    return path.join(signikOutputPath, '$name${AppConstants.signedSuffix}$ext');
  }

  /// Dispose of resources
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    
    await _onFileChangedController.close();
    // Note: DirectoryWatcher doesn't have a dispose method
  }

  /// Convert a file to SignikDocument model
  SignikDocument fileToDocument(File file, {bool signed = false}) {
    // Generate a simple ID from file path and timestamp
    final id = '${path.basename(file.path)}_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();
    
    return SignikDocument(
      id: id,
      name: path.basename(file.path),
      path: file.path,
      status: signed ? SignikDocumentStatus.signed : SignikDocumentStatus.queued,
      createdAt: now,
      updatedAt: now,
    );
  }
  
  /// Check if a file is a PDF
  static bool isPdfFile(String filePath) {
    return path.extension(filePath).toLowerCase() == AppConstants.pdfExtension;
  }
  
  /// Get all PDF files in the watch directory
  Future<List<File>> getPdfFiles() async {
    try {
      final dir = Directory(watchDirectory);
      final files = await dir.list().toList();
      
      return files
          .whereType<File>()
          .where((file) => isPdfFile(file.path))
          .toList();
    } catch (e) {
      throw FileOperationException(
        'Failed to list PDF files',
        details: 'Directory: $watchDirectory',
        originalError: e,
      );
    }
  }
} 