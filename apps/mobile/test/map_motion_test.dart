import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:playerszwz/features/discovery/map_motion.dart';

void main() {
  testWidgets(
      'recenter moves progressively, can stop and respects reduced motion',
      (tester) async {
    final map = MapController();
    final motion = MapRecenterMotion(map: map, vsync: tester);
    addTearDown(motion.dispose);
    addTearDown(map.dispose);
    await tester.pumpWidget(MaterialApp(
        home: FlutterMap(
            mapController: map,
            options: const MapOptions(
                initialCenter: LatLng(30, 73), initialZoom: 10),
            children: const [])));
    const target = LatLng(31.52, 74.35);
    motion.recenter(target, reducedMotion: false);
    expect(map.camera.center.latitude, closeTo(30, .001));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(map.camera.center.latitude, greaterThan(30));
    expect(map.camera.center.latitude, lessThan(31.52));
    motion.stop();
    final stopped = map.camera.center;
    await tester.pump(const Duration(milliseconds: 500));
    expect(map.camera.center, stopped);
    motion.recenter(target, reducedMotion: false);
    await tester.pumpAndSettle();
    expect(map.camera.center.latitude, closeTo(31.52, .001));
    expect(map.camera.zoom, 16);
    map.move(const LatLng(30, 73), 10);
    motion.recenter(target, reducedMotion: true);
    expect(map.camera.center, target);
    expect(map.camera.zoom, 16);
  });

  testWidgets('recenter takes the short path across the date line',
      (tester) async {
    final map = MapController();
    final motion = MapRecenterMotion(map: map, vsync: tester);
    addTearDown(motion.dispose);
    addTearDown(map.dispose);
    await tester.pumpWidget(MaterialApp(
        home: FlutterMap(
            mapController: map,
            options: const MapOptions(
                initialCenter: LatLng(0, 179), initialZoom: 10),
            children: const [])));
    motion.recenter(const LatLng(0, -179), reducedMotion: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(map.camera.center.longitude.abs(), greaterThan(179));
    await tester.pumpAndSettle();
    expect(map.camera.center.longitude, -179);
  });
}
