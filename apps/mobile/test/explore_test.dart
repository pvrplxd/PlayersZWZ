import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:playerszwz/features/discovery/explore_screen.dart';
import 'package:playerszwz/features/location/location_service.dart';

class FailedTile extends Fake implements TileImage {}

class TestTiles extends TileProvider {
  TestTiles(this.bytes);
  final Uint8List bytes;
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    if (const bool.fromEnvironment('LIVE_MAP_PREVIEW')) {
      final file = File(
          '/private/tmp/playerszwz-live-map/${coordinates.z}-${coordinates.x}-${coordinates.y}.png');
      if (file.existsSync()) return MemoryImage(file.readAsBytesSync());
    }
    return MemoryImage(bytes);
  }
}

void main() {
  const area = Area(31.52, 74.35, 'Gulberg, Lahore', 'manual');
  test('restored location rejects invalid coordinates', () {
    expect(
        Area.fromProfile({
          'location': {'latitude': 999, 'longitude': 74}
        }),
        isNull);
    expect(
        Area.fromProfile({
          'location': {'latitude': 31, 'longitude': 74},
          'location_label': 'Lahore'
        })!
            .label,
        'Lahore');
  });
  testWidgets('missing key shows saved area without network map',
      (tester) async {
    var changed = false;
    await tester.pumpWidget(MaterialApp(
        home: ExploreScreen(
            area: area,
            apiKey: '',
            changeArea: () => changed = true,
            signOut: () async {})));
    expect(find.byType(FlutterMap), findsNothing);
    expect(find.textContaining('unavailable right now'), findsOneWidget);
    await tester.tap(find.byTooltip('Change area'));
    expect(changed, true);
  });
  testWidgets('saved marker, tile loading, recenter and account actions',
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
    final bytes = await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(const Color(0xFF242424), BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(256, 256);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
      picture.dispose();
      image.dispose();
      return bytes;
    });
    var signedOut = false;
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: Color(0xFFD7FF00)),
            textTheme:
                ThemeData.dark().textTheme.apply(fontFamily: 'ReferenceSF')),
        home: ExploreScreen(
            area: area,
            apiKey: 'test-key',
            changeArea: () {},
            signOut: () async => signedOut = true,
            tileProvider: TestTiles(bytes!))));
    await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 800)));
    await tester.pumpAndSettle();
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.mapController!.camera.center.latitude, closeTo(31.52, .001));
    final marker =
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.single;
    expect(marker.point.longitude, 74.35);
    map.mapController!.move(const LatLng(30, 73), 10);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Recenter on saved area'));
    await tester.pump();
    // Complete camera travel before waiting for the final viewport's images.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 800)));
    await tester.pumpAndSettle();
    expect(map.mapController!.camera.center.latitude, closeTo(31.52, .001));
    if (!const bool.fromEnvironment('LIVE_MAP_PREVIEW')) {
      final oldError =
          tester.widget<TileLayer>(find.byType(TileLayer)).errorTileCallback!;
      oldError(FailedTile(), StateError('offline'), StackTrace.current);
      await tester.pump();
      await tester.pump();
      expect(find.text('Retry map'), findsOneWidget);
      await tester.tap(find.text('Retry map'));
      await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 800)));
      await tester.pumpAndSettle();
      oldError(FailedTile(), StateError('stale request'), StackTrace.current);
      await tester.pump();
      await tester.pump();
      expect(find.text('Retry map'), findsNothing);
    }
    if (Platform.isMacOS) {
      await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile(const bool.fromEnvironment('LIVE_MAP_PREVIEW')
              ? 'goldens/explore-live.png'
              : 'goldens/explore-layout.png'));
    }
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(signedOut, true);
    expect(tester.takeException(), isNull);
  });
}
