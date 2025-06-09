import 'dart:io';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';

/// Reusable PDF drop zone widget
class PdfDropZone extends StatefulWidget {
  final void Function(File file) onFileDropped;
  final String status;
  final bool isEnabled;

  const PdfDropZone({
    super.key,
    required this.onFileDropped,
    required this.status,
    this.isEnabled = true,
  });

  @override
  State<PdfDropZone> createState() => _PdfDropZoneState();
}

class _PdfDropZoneState extends State<PdfDropZone> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return DropTarget(
      onDragDone: widget.isEnabled ? _handleDragDone : null,
      onDragEntered: widget.isEnabled ? (_) => _setDragging(true) : null,
      onDragExited: widget.isEnabled ? (_) => _setDragging(false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _getBackgroundColor(isDarkMode),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _getBorderColor(),
            width: 2,
            style: _isDragging ? BorderStyle.solid : BorderStyle.none,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  transform: Matrix4.identity()
                    ..scale(_isDragging ? 1.1 : 1.0),
                  child: Icon(
                    _getIcon(),
                    size: 80,
                    color: _getIconColor(),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _getTitle(),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: _getTextColor(),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.status,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: _getTextColor().withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                if (widget.isEnabled) ...[
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _selectFile,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Browse Files'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleDragDone(DropDoneDetails details) {
    _setDragging(false);
    
    for (final file in details.files) {
      if (file.path.toLowerCase().endsWith('.pdf')) {
        widget.onFileDropped(File(file.path));
        break; // Only handle first PDF
      }
    }
  }

  void _setDragging(bool value) {
    setState(() => _isDragging = value);
  }

  Future<void> _selectFile() async {
    // This would typically use file_picker package
    // For now, just show a message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('File picker not implemented yet'),
      ),
    );
  }

  Color _getBackgroundColor(bool isDarkMode) {
    if (!widget.isEnabled) {
      return Colors.grey.shade200;
    }
    if (_isDragging) {
      return Colors.blue.shade50;
    }
    return isDarkMode ? Colors.grey.shade900 : Colors.grey.shade50;
  }

  Color _getBorderColor() {
    if (!widget.isEnabled) return Colors.grey.shade400;
    return _isDragging ? Colors.blue : Colors.grey.shade300;
  }

  IconData _getIcon() {
    if (_isDragging) return Icons.file_download;
    if (!widget.isEnabled) return Icons.block;
    return Icons.upload_file;
  }

  Color _getIconColor() {
    if (!widget.isEnabled) return Colors.grey.shade400;
    if (_isDragging) return Colors.blue;
    return Colors.grey.shade600;
  }

  Color _getTextColor() {
    if (!widget.isEnabled) return Colors.grey.shade600;
    return Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
  }

  String _getTitle() {
    if (!widget.isEnabled) return 'Drop Zone Disabled';
    if (_isDragging) return 'Drop PDF Here';
    return 'Drag & Drop PDF';
  }
}