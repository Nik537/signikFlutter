import 'dart:convert';
import '../../models/signik_document.dart';
import 'api_client.dart';

/// API service for document-related operations
class DocumentApi {
  final ApiClient _apiClient;

  DocumentApi({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Enqueue a document for signing
  Future<String> enqueueDocument({
    required String name,
    required String windowsDeviceId,
    List<int>? pdfData,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'windows_device_id': windowsDeviceId,
    };

    if (pdfData != null) {
      body['pdf_data'] = base64Encode(pdfData);
    }

    final response = await _apiClient.post('/enqueue_doc', body: body);
    return response['doc_id'];
  }

  /// Get list of documents
  Future<List<SignikDocument>> getDocuments({
    SignikDocumentStatus? status,
  }) async {
    final queryParams = <String, String>{};
    if (status != null) {
      queryParams['status'] = documentStatusToString(status);
    }

    final response =
        await _apiClient.get('/documents', queryParams: queryParams);
    final documents = response['documents'] as List<dynamic>;
    return documents.map((json) => SignikDocument.fromJson(json)).toList();
  }

  /// Convert document status to string
  String documentStatusToString(SignikDocumentStatus status) {
    switch (status) {
      case SignikDocumentStatus.queued:
        return 'queued';
      case SignikDocumentStatus.sent:
        return 'sent';
      case SignikDocumentStatus.signed:
        return 'signed';
      case SignikDocumentStatus.declined:
        return 'declined';
      case SignikDocumentStatus.deferred:
        return 'deferred';
      case SignikDocumentStatus.delivered:
        return 'delivered';
      default:
        return 'error';
    }
  }
}