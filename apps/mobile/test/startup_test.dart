import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playerszwz/main.dart';
import 'package:playerszwz/core/widgets/launch_screen.dart';

void main() {
  testWidgets(
      'signed-in launch places identity and spinner below logo without sign-out',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(
            theme: ThemeData(platform: TargetPlatform.iOS),
            home: const LaunchScreen(identity: 'Afaq', loading: true)));
    // The plain launch screen announces the identity to screen readers only.
    expect(find.byWidgetPredicate((w) => w is Semantics && (w.properties.label ?? '').contains('signed in as Afaq')), findsOneWidget);
    expect(find.text('Sign out'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(tester.getCenter(find.byType(NeonSpinner)).dy,
        greaterThan(tester.getCenter(find.byType(SvgPicture)).dy));
  });
  const ready = MaterialApp(home: Text('Ready'));

  testWidgets('paints loading before initialization and initializes only once',
      (tester) async {
    final pending = Completer<void>();
    var calls = 0;
    var loadingWasPainted = false;
    Future<void> initialize() {
      calls++;
      loadingWasPainted = find.byType(LaunchScreen).evaluate().isNotEmpty;
      return pending.future;
    }

    // Widget tests do not rasterize frames; verify the rendered loading tree
    // is present when the post-frame initializer runs instead.
    await tester.pumpWidget(StartupApp(
      initializeServices: initialize,
      child: ready,
    ));
    expect(loadingWasPainted, isTrue);
    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester
        .pumpWidget(StartupApp(initializeServices: initialize, child: ready));
    expect(calls, 1);
    pending.complete();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Ready'), findsOneWidget);
  });

  testWidgets('service failure shows startup error instead of entering the app',
      (tester) async {
    await tester.pumpWidget(StartupApp(
      initializeServices: () async => throw StateError('Test service failure'),
      child: ready,
    ));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('PlayersZWZ could not start'), findsOneWidget);
    expect(find.text('Ready'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
