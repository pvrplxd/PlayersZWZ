import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:playerszwz/core/config/api_config.dart';

void main() {
  test('runtime configuration loads the map key from the API', () async {
    await ApiConfig.loadRuntimeConfig(
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/mobile-config');
        return http.Response(jsonEncode({'geoapify_api_key': 'runtime-key'}), 200);
      }),
    );

    expect(ApiConfig.baseUrl, 'https://playerszwz.vercel.app');
    expect(ApiConfig.geoapifyApiKey, 'runtime-key');
  });
}
