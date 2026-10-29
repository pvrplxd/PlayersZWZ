import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

typedef AccessTokenProvider = Future<String?> Function();

class ApiException implements Exception {
  const ApiException(this.statusCode, this.code, this.message);

  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

/// Shared REST client. Firebase token acquisition is injected by the auth layer
/// once Firebase is configured, keeping credentials out of feature screens.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required AccessTokenProvider accessTokenProvider,
    http.Client? client,
    Duration requestTimeout = const Duration(seconds: 20),
  })  : _baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), ''),
        _accessTokenProvider = accessTokenProvider,
        _client = client ?? http.Client(),
        _requestTimeout = requestTimeout;

  final String _baseUrl;
  final AccessTokenProvider _accessTokenProvider;
  final http.Client _client;
  final Duration _requestTimeout;

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    return _send('GET', path, query: query);
  }

  Future<dynamic> post(String path, {Object? body}) async {
    return _send('POST', path, body: body);
  }

  Future<dynamic> put(String path, {Object? body}) async {
    return _send('PUT', path, body: body);
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    return _send('PATCH', path, body: body);
  }

  Future<dynamic> delete(String path) async {
    return _send('DELETE', path);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
  }) async {
    if (_baseUrl.isEmpty) {
      throw const ApiException(0, 'CONFIGURATION_ERROR',
          'API_BASE_URL is missing. Start the app with --dart-define=API_BASE_URL=<url>.');
    }

    final String? token;
    try {
      token = await _accessTokenProvider().timeout(_requestTimeout);
    } on TimeoutException {
      throw const ApiException(0, 'REQUEST_TIMEOUT',
          'The connection took too long. Please try again.');
    }
    if (token == null || token.isEmpty) {
      throw const ApiException(
          401, 'UNAUTHORIZED', 'Sign in again to continue.');
    }
    final uri = Uri.parse('$_baseUrl/${path.replaceFirst(RegExp(r'^/'), '')}')
        .replace(queryParameters: query);
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    headers['Authorization'] = 'Bearer $token';

    late final http.Response response;
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      response = await (() async {
        final streamed = await _client.send(request);
        return http.Response.fromStream(streamed);
      })()
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw const ApiException(0, 'REQUEST_TIMEOUT',
          'The connection took too long. Please try again.');
    } on http.ClientException {
      throw const ApiException(0, 'NETWORK_ERROR',
          'Could not reach the PlayersZWZ API. Check the network and API URL.');
    }

    final dynamic decoded;
    try {
      decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      throw ApiException(response.statusCode, 'INVALID_RESPONSE',
          'The API returned an unreadable response (${response.statusCode}).');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded is Map<String, dynamic> ? decoded['error'] : null;
      final details =
          error is Map<String, dynamic> ? error : const <String, dynamic>{};
      throw ApiException(
        response.statusCode,
        details['code'] as String? ?? 'REQUEST_FAILED',
        details['message'] as String? ??
            'The request failed (${response.statusCode}).',
      );
    }
    return decoded;
  }

  void close() => _client.close();
}
