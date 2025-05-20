import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as path;
import 'package:watcher/watcher.dart';

class FileService {
  final String watchDirectory;
  final _watcher = <Watcher>[];
  final _onFileChangedController = StreamController<File>.broadcast();

  Stream<File> get onFileChanged => _onFileChangedController.stream;

  FileService({required this.watchDirectory}) {
    _setupWatcher();
  }

  void _setupWatcher() {
    final watcher = DirectoryWatcher(watchDirectory);
    _watcher.add(watcher);

    watcher.events.listen((event) {
      if (event.type == ChangeType.ADD || event.type == ChangeType.MODIFY) {
        final file = File(event.path);
        if (path.extension(file.path).toLowerCase() == '.pdf') {
          _onFileChangedController.add(file);
        }
      }
    });
  }

  Future<List<int>> readFile(File file) async {
    return await file.readAsBytes();
  }

  Future<void> writeFile(File file, List<int> bytes) async {
    final signedPath = _getSignedPath(file.path);
    await File(signedPath).writeAsBytes(bytes);
  }

  String _getSignedPath(String originalPath) {
    final dir = path.dirname(originalPath);
    final name = path.basenameWithoutExtension(originalPath);
    final ext = path.extension(originalPath);
    return path.join(dir, '${name}_signed$ext');
  }

  Future<void> dispose() async {
    await _onFileChangedController.close();
  }
} 