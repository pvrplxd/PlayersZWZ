import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:playerszwz/app/playerszwz_app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playerszwz/main.dart';
import 'package:playerszwz/core/widgets/launch_screen.dart';

void main() {
  testWidgets(
      'signed-in launch places identity and spinner below logo without sign-out',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: LaunchScreen(identity: 'Afaq', loading: true)));
    expect(find.text('Afaq'), findsOneWidget);
    expect(find.text('Sign out'), findsNothing);
    expect(tester.getTopLeft(find.byType(CupertinoActivityIndicator)).dy,
        greaterThan(tester.getBottomLeft(find.byType(BrandMark)).dy));
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
