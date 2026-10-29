import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiConfig {
  const ApiConfig._();

  static const _productionBaseUrl = 'https://playerszwz.vercel.app';
  static const _baseUrlOverride = String.fromEnvironment('API_BASE_URL');
  static const _geoapifyApiKeyOverride =
      String.fromEnvironment('GEOAPIFY_API_KEY');

  static String get baseUrl =>
      _baseUrlOverride.isEmpty ? _productionBaseUrl : _baseUrlOverride;
  static String _geoapifyApiKey = _geoapifyApiKeyOverride;
  static String get geoapifyApiKey => _geoapifyApiKey;

  /// Loads the public map key from the PlayersZWZ API. Build-time defines
  /// remain available for local development, but are not needed for releases.
  static Future<void> loadRuntimeConfig({http.Client? client}) async {
    if (_geoapifyApiKeyOverride.isNotEmpty) return;
    final ownClient = client == null;
    final requestClient = client ?? http.Client();
    try {
      final response = await requestClient
          .get(Uri.parse('$baseUrl/api/v1/mobile-config'))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return;
      final decoded = jsonDecode(response.body);
      final key = decoded is Map<String, dynamic>
          ? decoded['geoapify_api_key']
          : null;
      if (key is String && key.trim().isNotEmpty) {
        _geoapifyApiKey = key.trim();
      }
    } catch (_) {
      // Account access remains available if optional map configuration is down.
    } finally {
      if (ownClient) requestClient.close();
    }
  }
}
