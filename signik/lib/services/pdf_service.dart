import 'dart:typed_data';
import 'dart:ui' show Rect;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/signik_document.dart';

class PdfService {
  static const double _signatureMargin = 56.69; // 2 cm in points
  static const double _signatureBottom = 85.04; // 3 cm in points

  Future<Uint8List> embedSignature(Uint8List pdfBytes, Uint8List signatureBytes) async {
    // Load the PDF document
    final PdfDocument document = PdfDocument(inputBytes: pdfBytes);
    
    // Get the last page
    final PdfPage page = document.pages[document.pages.count - 1];
    
    // Load the signature image
    final PdfBitmap signature = PdfBitmap(signatureBytes);
    
    // Calculate signature position
    final double signatureWidth = signature.width.toDouble();
    final double signatureHeight = signature.height.toDouble();
    final double x = page.size.width - signatureWidth - _signatureMargin;
    final double y = _signatureBottom;
    
    // Draw the signature
    page.graphics.drawImage(
      signature,
      Rect.fromLTWH(x, y, signatureWidth, signatureHeight),
    );
    
    // Save the document
    final List<int> signedPdfBytes = await document.save();
    document.dispose();
    
    return Uint8List.fromList(signedPdfBytes);
  }

  SignikDocument createSignedDocument(String originalPath) {
    final dir = originalPath.substring(0, originalPath.lastIndexOf('/'));
    final name = originalPath.split('/').last;
    return SignikDocument(
      name: name,
      path: originalPath,
      status: SignikDocumentStatus.signed,
    );
  }
} 