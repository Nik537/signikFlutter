import 'dart:typed_data';
import 'dart:ui' show Rect;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/signik_document.dart';
import '../core/constants.dart';
import '../core/exceptions/app_exceptions.dart';

/// Service for PDF manipulation and signature embedding
class PdfService {

  /// Embed signature image into PDF document
  Future<Uint8List> embedSignature(Uint8List pdfBytes, Uint8List signatureBytes) async {
    if (pdfBytes.isEmpty) {
      throw ValidationException('PDF bytes cannot be empty');
    }
    if (signatureBytes.isEmpty) {
      throw ValidationException('Signature bytes cannot be empty');
    }
    
    PdfDocument? document;
    
    try {
      // Load the PDF document
      document = PdfDocument(inputBytes: pdfBytes);
      
      if (document.pages.count == 0) {
        throw PdfOperationException('PDF document has no pages');
      }
      
      // Get the last page
      final PdfPage page = document.pages[document.pages.count - 1];
      
      // Load the signature image
      final PdfBitmap signature = PdfBitmap(signatureBytes);
      
      // Calculate signature position and scale down
      final double scale = AppConstants.pdfSignatureScale;
      final double signatureWidth = signature.width.toDouble() * scale;
      final double signatureHeight = AppConstants.pdfSignatureHeight;
      final double x = page.size.width - signatureWidth - AppConstants.pdfRightMargin;
      final double y = page.size.height - signatureHeight - AppConstants.pdfTopMargin;
      
      // Draw the signature
      page.graphics.drawImage(
        signature,
        Rect.fromLTWH(x, y, signatureWidth, signatureHeight),
      );
      
      // Save the document
      final List<int> signedPdfBytes = await document.save();
      
      return Uint8List.fromList(signedPdfBytes);
    } catch (e) {
      if (e is SignikException) rethrow;
      throw PdfOperationException(
        'Failed to embed signature in PDF',
        originalError: e,
      );
    } finally {
      document?.dispose();
    }
  }

  /// Create a SignikDocument model for a signed PDF
  SignikDocument createSignedDocument(String originalPath) {
    if (originalPath.isEmpty) {
      throw ValidationException('Original path cannot be empty');
    }
    
    final pathSeparator = originalPath.contains('/') ? '/' : '\\';
    final dir = originalPath.substring(0, originalPath.lastIndexOf(pathSeparator));
    final name = originalPath.split(pathSeparator).last;
    final now = DateTime.now();
    final id = '${name}_${now.millisecondsSinceEpoch}';
    
    return SignikDocument(
      id: id,
      name: name,
      path: originalPath,
      status: SignikDocumentStatus.signed,
      createdAt: now,
      updatedAt: now,
    );
  }
  
  /// Extract PDF metadata
  Future<Map<String, dynamic>> getPdfMetadata(Uint8List pdfBytes) async {
    if (pdfBytes.isEmpty) {
      throw ValidationException('PDF bytes cannot be empty');
    }
    
    PdfDocument? document;
    
    try {
      document = PdfDocument(inputBytes: pdfBytes);
      
      return {
        'pageCount': document.pages.count,
        'fileSize': pdfBytes.length,
        'lastPageSize': document.pages.count > 0
            ? {
                'width': document.pages[document.pages.count - 1].size.width,
                'height': document.pages[document.pages.count - 1].size.height,
              }
            : null,
      };
    } catch (e) {
      throw PdfOperationException(
        'Failed to extract PDF metadata',
        originalError: e,
      );
    } finally {
      document?.dispose();
    }
  }
} 