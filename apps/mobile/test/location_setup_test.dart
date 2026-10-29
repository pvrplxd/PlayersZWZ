import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:playerszwz/core/api_client.dart';
import 'package:playerszwz/features/location/location_service.dart';
import 'package:playerszwz/features/location/location_setup.dart';

class TestLocations extends LocationService {
  TestLocations() : super(apiKey: '');
  @override
  Future<Area> current() async =>
      throw const LocationFailure('Choose an area manually.', settings: true);
  @override
  Future<List<Area>> search(String text) async =>
      [const Area(31.52, 74.35, 'Gulberg, Lahore', 'manual')];
}

void main() {
  test('search encodes input and filters invalid coordinates', () async {
    final service = LocationService(
        apiKey: 'test-key',
        client: MockClient((request) async {
          expect(request.url.queryParameters['text'], 'Lahore & area');
          expect(request.url.queryParameters['format'], 'json');
          return http.Response(
              jsonEncode({
                'results': [
                  {'lat': 31.52, 'lon': 74.35, 'formatted': 'Lahore'},
                  {'lat': 999, 'lon': 74, 'formatted': 'Invalid'}
                ]
              }),
              200);
        }));
    addTearDown(service.close);
    final results = await service.search('Lahore & area');
    expect(results.length, 1);
    expect(results.first.source, 'manual');
  });

  test('manual search reports missing configuration', () async {
    final service = LocationService(apiKey: '');
    addTearDown(service.close);
    await expectLater(
        service.search('Lahore'), throwsA(isA<LocationFailure>()));
  });

  testWidgets(
      'permission denial falls back to manual selection and retry preserves area',
      (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (Platform.isMacOS) {
      final font = FontLoader('ReferenceSF')
        ..addFont(Future.value(ByteData.sublistView(
            File('/System/Library/Fonts/SFNS.ttf').readAsBytesSync())));
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      final cupertino = FontLoader('packages/cupertino_icons/CupertinoIcons')
        ..addFont(rootBundle
            .load('packages/cupertino_icons/assets/CupertinoIcons.ttf'));
      await cupertino.load();
    }
    var saves = 0;
    var done = false;
    final api = ApiClient(
        baseUrl: 'https://example.com',
        accessTokenProvider: () async => 'token',
        client: MockClient((request) async {
          saves++;
          if (saves == 1) {
            return http.Response(
                '{"error":{"code":"DATABASE_UNAVAILABLE","message":"Retry"}}',
                503);
          }
          final body = jsonDecode(request.body);
          expect(body['source'], 'manual');
          return http.Response(
              jsonEncode({
                'profile': {
                  'location': {
                    'latitude': body['latitude'],
                    'longitude': body['longitude']
                  }
                }
              }),
              200);
        }));
    final locations = TestLocations();
    addTearDown(api.close);
    addTearDown(locations.close);
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark().copyWith(
            textTheme:
                ThemeData.dark().textTheme.apply(fontFamily: 'ReferenceSF')),
        home: LocationSetup(
            api: api,
            location: locations,
            signOut: () async {},
            onComplete: (_) => done = true)));
    await tester.pumpAndSettle();
    if (Platform.isMacOS) {
      await expectLater(find.byType(Scaffold),
          matchesGoldenFile('goldens/location-setup.png'));
    }
    await tester.tap(find.text('Use my location'));
    await tester.pumpAndSettle();
    expect(find.text('Choose an area manually.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Gulberg');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gulberg, Lahore'));
    await tester.pumpAndSettle();
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(375, 667);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.view.physicalSize = const Size(402, 874);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Confirm area'));
    await tester.tap(find.text('Confirm area'));
    await tester.pumpAndSettle();
    expect(done, false);
    expect(find.text('Gulberg, Lahore'), findsWidgets);
    await tester.ensureVisible(find.text('Confirm area'));
    await tester.tap(find.text('Confirm area'));
    await tester.pumpAndSettle();
    expect(done, true);
    expect(saves, 2);
    expect(tester.takeException(), isNull);
  });
}
