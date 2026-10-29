import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:playerszwz/core/api_client.dart';
import 'package:playerszwz/features/profile/profile_setup.dart';
import 'package:playerszwz/features/profile/profile_photo.dart';
import 'package:playerszwz/core/widgets/motion.dart';

class NoLostPhoto extends ProfilePhotoPicker {
  @override
  Future<Uint8List?> recover() async => null;
}

void main() {
  testWidgets('availability, sports, conflict recovery and successful save',
      (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
    var completed = false;
    var saves = 0;
    final api = ApiClient(
        baseUrl: 'https://example.com',
        accessTokenProvider: () async => 'token',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/photo')) {
            return http.Response('{"photo":null}', 200);
          }
          if (request.method == 'GET') {
            return http.Response(
                jsonEncode({
                  'username': request.url.queryParameters['username'],
                  'available': true
                }),
                200);
          }
          saves++;
          if (saves == 1) {
            return http.Response(
                '{"error":{"code":"USERNAME_TAKEN","message":"Taken"}}', 409);
          }
          expect(jsonDecode(request.body)['sports'], ['Cricket']);
          return http.Response('{"profile":{"setup_complete":true}}', 200);
        }));
    addTearDown(api.close);
    final photo =
        ProfilePhotoController(ProfilePhotoService(api), picker: NoLostPhoto());
    addTearDown(photo.dispose);
    await photo.load();
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark().copyWith(
            textTheme:
                ThemeData.dark().textTheme.apply(fontFamily: 'ReferenceSF')),
        home: ProfileSetup(
            photo: photo,
            api: api,
            name: 'Afaq',
            onComplete: () => completed = true,
            signOut: () async {})));
    Future<void> chooseName(String name) async {
      await tester.enterText(find.byType(TextField), name);
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Next'));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }

    await tester.pumpAndSettle();
    await expectLater(find.byType(Scaffold),
        matchesGoldenFile('goldens/profile-username.png'));
    expect(find.text('Sign out'), findsNothing);
    expect(tester.getCenter(find.byType(SetupProgress)).dx, closeTo(201, 1));
    expect(tester.getBottomLeft(find.byType(SetupProgress)).dy,
        lessThan(tester.getTopLeft(find.byType(FilledButton)).dy));
    await chooseName('afaq');
    expect(find.textContaining('selected'), findsNothing);
    await tester.tap(find.text('Cricket'));
    await tester.pumpAndSettle();
    await expectLater(
        find.byType(Scaffold), matchesGoldenFile('goldens/profile-sports.png'));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(375, 667);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getBottomLeft(find.byType(FilledButton)).dy,
        lessThanOrEqualTo(667));
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.view.physicalSize = const Size(402, 874);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(completed, false);
    expect(find.text('That username was just taken. Choose another.'),
        findsOneWidget);
    await chooseName('afaq_2');
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(completed, true);
    expect(saves, 2);
    expect(tester.takeException(), isNull);
  });
}
