import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playerszwz/features/onboarding/onboarding_screen.dart';

void main() {
  Future<void> show(WidgetTester tester,
      {Future<void> Function()? google,
      VoidCallback? email,
      VoidCallback? login,
      double scale = 1,
      bool reducedMotion = true,
      Size size = const Size(402, 874)}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark().copyWith(
            textTheme:
                ThemeData.dark().textTheme.apply(fontFamily: 'ReferenceSF')),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: reducedMotion),
            child: child!),
        home: RepaintBoundary(
            key: const Key('screen'),
            child: OnboardingScreen(
                onGoogleSignIn: google ?? () async {},
                onEmailSignUp: email ?? () {},
                onLogin: login ?? () {}))));
    await tester.runAsync(() async {
      final context = tester.element(find.byType(OnboardingScreen));
      for (final name in ['welcome', 'nearby', 'arenas', 'matchmaking']) {
        await precacheImage(AssetImage('assets/onboarding/$name.png'), context);
      }
      await precacheImage(
          const AssetImage('assets/branding/google-icon.png'), context);
    });
    await tester.pumpAndSettle();
  }

  setUpAll(() async {
    // Local reference render uses the installed Apple system font when available.
    final material = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await material.load();
    final font = File('/System/Library/Fonts/SFNS.ttf');
    if (font.existsSync()) {
      final loader = FontLoader('ReferenceSF')
        ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
      await loader.load();
    }
  });

  testWidgets('indicator follows a partial swipe and reverses with the finger',
      (tester) async {
    await show(tester, reducedMotion: false);
    double width(int i) =>
        tester.getSize(find.byKey(ValueKey('onboarding-dot-$i'))).width;
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(PageView)));
    await gesture.moveBy(const Offset(-110, 0));
    await tester.pump();
    final first = width(0);
    expect(first, greaterThan(7));
    expect(first, lessThan(31));
    expect(width(1), greaterThan(7));
    await gesture.moveBy(const Offset(50, 0));
    await tester.pump();
    expect(width(0), greaterThan(first));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('375x667 keeps footer visible and fixed while swiping',
      (tester) async {
    await show(tester, size: const Size(375, 667));
    final login = find.text('Log In');
    final before = tester.getRect(login);
    expect(before.bottom, lessThanOrEqualTo(667));
    expect(login.hitTestable(), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-350, 0));
    await tester.pumpAndSettle();
    expect(tester.getRect(login), before);
    expect(find.text('Continue with Google').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(find.byKey(const Key('screen')),
        matchesGoldenFile('goldens/compact-onboarding.png'));
  });

  testWidgets('all four pages render and email/login actions work',
      (tester) async {
    var email = 0;
    var login = 0;
    await show(tester, email: () => email++, login: () => login++);
    await tester.tap(find.text('Sign up with email'));
    await tester.tap(find.text('Log In'));
    expect(email, 1);
    expect(login, 1);
    for (var page = 0; page < 4; page++) {
      expect(tester.takeException(), isNull);
      // These local reference images use macOS's installed SF font.
      // Other platforms still run the interaction and overflow assertions.
      await tester.pumpAndSettle();
      if (Platform.isMacOS) {
        await expectLater(find.byKey(const Key('screen')),
            matchesGoldenFile('goldens/onboarding-$page.png'));
      }
      if (page < 3) {
        await tester.tap(
            find.bySemanticsLabel('Page ${page + 1} of 4. Next introduction'));
        await tester.pumpAndSettle();
      }
    }
    expect(find.text('AI-powered\nmatchmaking'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets(
      'pending sign-in blocks duplicate and other actions; failure allows retry',
      (tester) async {
    final pending = Completer<void>();
    var attempts = 0;
    var email = 0;
    await show(tester,
        google: () {
          attempts++;
          return pending.future;
        },
        email: () => email++);
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    await tester.tap(find.text('Continue with Google'));
    await tester.tap(find.text('Sign up with email'));
    expect(attempts, 1);
    expect(email, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.completeError(Exception('offline'));
    await tester.pumpAndSettle();
    expect(
        find.text('Something went wrong. Please try again.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.text('Sign up with email'));
    expect(email, 1);
  });

  testWidgets('small screen and large text remain scrollable without overflow',
      (tester) async {
    var login = 0;
    await show(tester,
        size: const Size(320, 568), scale: 2, login: () => login++);
    await tester.scrollUntilVisible(find.text('Log In'), 200,
        scrollable: find
            .descendant(
                of: find.byType(SingleChildScrollView).first,
                matching: find.byType(Scrollable))
            .first);
    await tester.tap(find.text('Log In'));
    expect(login, 1);
    expect(tester.takeException(), isNull);
  });
}
