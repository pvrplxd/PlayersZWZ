import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:playerszwz/core/api_client.dart';
import 'package:playerszwz/features/profile/profile_preferences.dart';

void main() {
  testWidgets('loads and saves profile preferences', (tester) async {
    tester.view.physicalSize = const Size(600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Map<String, dynamic>? saved;
    final api = ApiClient(
      baseUrl: 'https://example.com',
      accessTokenProvider: () async => 'token',
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
              jsonEncode({
                'profile': {
                  'sports': ['Cricket'],
                  'availability': ['Friday'],
                  'radius_km': 10,
                  'bio': 'Weekend games.',
                }
              }),
              200);
        }
        saved = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{"profile":{}}', 200);
      }),
    );
    addTearDown(api.close);

    await tester
        .pumpWidget(MaterialApp(home: ProfilePreferencesScreen(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('Weekend games.'), findsOneWidget);
    expect(find.text('Cricket'), findsWidgets);

    await tester.tap(find.text('Mo'));
    await tester.enterText(find.byType(TextField), 'Available after work.');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!['sports'], ['Cricket']);
    expect(saved!['availability'], ['Monday', 'Friday']);
    expect(saved!['radius_km'], 10);
    expect(saved!['bio'], 'Available after work.');
  });
}
