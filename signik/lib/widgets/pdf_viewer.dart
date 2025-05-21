import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfViewerWidget extends StatelessWidget {
  final Uint8List pdfBytes;
  const PdfViewerWidget({super.key, required this.pdfBytes});

  @override
  Widget build(BuildContext context) {
    return SfPdfViewer.memory(
      pdfBytes,
      canShowScrollHead: false,
      canShowScrollStatus: false,
    );
  }
} 