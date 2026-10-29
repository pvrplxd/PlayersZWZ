import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:playerszwz/core/api_client.dart';
import 'package:playerszwz/features/profile/profile_photo.dart';
import 'package:playerszwz/features/profile/profile_photo_editor.dart';

class TestPicker extends ProfilePhotoPicker {
  Uint8List? candidate;
  @override
  Future<Uint8List?> choose() async => candidate;
  @override
  Future<Uint8List?> recover() async => candidate;
}

void main() {
  // This minimal header is enough for transport tests, never a UI image fixture.
  final oldPhoto = Uint8List.fromList([255, 216, 255, 1]);
  final newPhoto = Uint8List.fromList([255, 216, 255, 2]);
  test('Android recovered selection waits for explicit confirmation', () async {
    var requests = 0;
    final api = ApiClient(baseUrl: 'https://example.com', accessTokenProvider: () async => 'token', client: MockClient((_) async { requests++; return http.Response('{"photo":null}', 200); }));
    addTearDown(api.close);
    final controller = ProfilePhotoController(ProfilePhotoService(api), picker: TestPicker()..candidate = newPhoto);
    addTearDown(controller.dispose);
    await controller.recover();
    expect(controller.recovered, newPhoto);
    expect(controller.bytes, isNull);
    expect(requests, 0);
    controller.discardRecovered();
    expect(controller.recovered, isNull);
  });
  test(
      'photo persists across controllers; failed replacement retains confirmed photo',
      () async {
    Uint8List? saved = oldPhoto;
    bool fail = true;
    final api = ApiClient(
        baseUrl: 'https://example.com',
        accessTokenProvider: () async => 'token',
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer token');
          if (request.method == 'PUT') {
            if (fail) {
              return http.Response(
                  '{"error":{"code":"DATABASE_UNAVAILABLE"}}', 503);
            }
            saved = base64Decode(jsonDecode(request.body)['image']);
          }
          if (request.method == 'DELETE') saved = null;
          return http.Response(
              jsonEncode({
                'photo': saved == null
                    ? null
                    : {
                        'image': base64Encode(saved!),
                        'content_type': 'image/jpeg'
                      }
              }),
              200);
        }));
    addTearDown(api.close);
    final controller =
        ProfilePhotoController(ProfilePhotoService(api), picker: TestPicker());
    addTearDown(controller.dispose);
    await controller.load();
    expect(controller.bytes, oldPhoto);
    expect(await controller.save(newPhoto), false);
    expect(controller.bytes, oldPhoto);
    fail = false;
    expect(await controller.save(newPhoto), true);
    final restored =
        ProfilePhotoController(ProfilePhotoService(api), picker: TestPicker());
    addTearDown(restored.dispose);
    await restored.load();
    expect(restored.bytes, newPhoto);
    expect(await restored.remove(), true);
    expect(restored.bytes, isNull);
  });

  test(
      'duplicate writes are blocked and late responses after disposal do not notify',
      () async {
    final response = Completer<http.Response>();
    var writes = 0, notifications = 0;
    final api = ApiClient(
        baseUrl: 'https://example.com',
        accessTokenProvider: () async => 'token',
        client: MockClient((request) {
          writes++;
          return response.future;
        }));
    addTearDown(api.close);
    final controller =
        ProfilePhotoController(ProfilePhotoService(api), picker: TestPicker())
          ..addListener(() => notifications++);
    final pending = controller.save(newPhoto);
    expect(await controller.save(oldPhoto), false);
    controller.dispose();
    response.complete(http.Response(
        jsonEncode({
          'photo': {
            'image': base64Encode(newPhoto),
            'content_type': 'image/jpeg'
          }
        }),
        200));
    expect(await pending, false);
    expect(writes, 1);
    expect(notifications, 1);
  });

  testWidgets('picker cancellation does not upload or alter the profile',
      (tester) async {
    var requests = 0;
    final api = ApiClient(
        baseUrl: 'https://example.com',
        accessTokenProvider: () async => 'token',
        client: MockClient((_) async {
          requests++;
          return http.Response('{"photo":null}', 200);
        }));
    addTearDown(api.close);
    final controller =
        ProfilePhotoController(ProfilePhotoService(api), picker: TestPicker());
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ProfilePhotoEditor(controller: controller, name: 'Player'))));
    await tester.tap(find.text('Add profile photo'));
    await tester.pumpAndSettle();
    expect(requests, 0);
    expect(find.text('Use photo'), findsNothing);
    expect(controller.bytes, isNull);
  });

  testWidgets(
      'selected photo requires confirmation; failure keeps preview for retry',
      (tester) async {
    final data = File('test/fixtures/avatar.jpg').readAsBytesSync();
    var writes = 0;
    final api = ApiClient(
        baseUrl: 'https://example.com',
        accessTokenProvider: () async => 'token',
        client: MockClient((request) async {
          writes++;
          if (writes == 1) {
            return http.Response(
                '{"error":{"code":"DATABASE_UNAVAILABLE"}}', 503);
          }
          return http.Response(
              jsonEncode({
                'photo': {
                  'image': base64Encode(data),
                  'content_type': 'image/jpeg'
                }
              }),
              200);
        }));
    addTearDown(api.close);
    final controller = ProfilePhotoController(ProfilePhotoService(api),
        picker: TestPicker()..candidate = data);
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ProfilePhotoEditor(controller: controller, name: 'Player'))));
    await tester.tap(find.text('Add profile photo'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    await tester.tap(find.text('Use photo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not save your photo'), findsWidgets);
    expect(controller.bytes, isNull);
    await tester.tap(find.text('Use photo'));
    await tester.pumpAndSettle();
    expect(controller.bytes, data);
    expect(find.text('Your profile photo'), findsNothing);
    expect(find.text('Change profile photo'), findsOneWidget);
  });
}
