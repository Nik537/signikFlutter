import 'package:flutter/material.dart';
import '../models/signik_document.dart';
import 'dart:typed_data';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:io';

class SignedDocumentsList extends StatelessWidget {
  final List<SignikDocument> documents;
  final void Function(SignikDocument) onOpen;
  const SignedDocumentsList({super.key, required this.documents, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: documents.length,
      itemBuilder: (context, index) {
        final doc = documents[index];
        return ListTile(
          title: Text(doc.name),
          onTap: () => onOpen(doc),
          leading: const Icon(Icons.picture_as_pdf),
        );
      },
    );
  }
} 