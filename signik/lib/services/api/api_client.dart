import 'dart:convert';
import 'package:http/http.dart' as http;

/// Base API client for HTTP communication
class ApiClient {
  final String baseUrl;
  final http.Client _httpClient;

  ApiClient({required this.baseUrl, http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// GET request
  Future<Map<String, dynamic>> get(String endpoint,
      {Map<String, String>? queryParams}) async {
    final uri = _buildUri(endpoint, queryParams);
    final response = await _httpClient.get(uri, headers: _headers);
    return _handleResponse(response);
  }

  /// POST request
  Future<Map<String, dynamic>> post(String endpoint,
      {Map<String, dynamic>? body}) async {
    final uri = _buildUri(endpoint);
    final response = await _httpClient.post(
      uri,
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  /// PUT request
  Future<Map<String, dynamic>> put(String endpoint,
      {Map<String, dynamic>? body}) async {
    final uri = _buildUri(endpoint);
    final response = await _httpClient.put(
      uri,
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  /// DELETE request
  Future<Map<String, dynamic>> delete(String endpoint) async {
    final uri = _buildUri(endpoint);
    final response = await _httpClient.delete(uri, headers: _headers);
    return _handleResponse(response);
  }

  /// Build URI with optional query parameters
  Uri _buildUri(String endpoint, [Map<String, String>? queryParams]) {
    final url = '$baseUrl$endpoint';
    return Uri.parse(url).replace(queryParameters: queryParams);
  }

  /// Default headers
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// Handle HTTP response
  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return {};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    // Handle error responses
    Map<String, dynamic>? errorBody;
    try {
      errorBody = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      // Body is not JSON
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: errorBody?['detail'] ?? response.body,
      response: errorBody,
    );
  }

  void dispose() {
    _httpClient.close();
  }
}

/// API Exception class
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, dynamic>? response;

  ApiException({
    required this.statusCode,
    required this.message,
    this.response,
  });

  @override
  String toString() => 'ApiException($statusCode): $message';
}