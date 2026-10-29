import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playerszwz/features/auth/auth_screen.dart';
import 'package:playerszwz/features/auth/auth_service.dart';

class FakeAuth implements AuthService {
  int calls = 0;
  Completer<void>? pending;
  @override
  Future<void> signIn({required String email, required String password}) async {
    calls++;
    await pending?.future;
  }

  @override
  Future<void> createAccount(
          {required String email,
          required String password,
          required String displayName}) =>
      signIn(email: email, password: password);
  @override
  Future<void> signInWithGoogle() => signIn(email: '', password: '');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<void> show(WidgetTester tester, FakeAuth auth,
      {bool create = false,
      double scale = 1,
      Size size = const Size(375, 667)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark().copyWith(
            textTheme:
                ThemeData.dark().textTheme.apply(fontFamily: 'ReferenceSF')),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: RepaintBoundary(
            key: const Key('auth-render'),
            child: AuthScreen(createAccount: create, authService: auth))));
    await tester.pumpAndSettle();
  }

  setUpAll(() async {
    final material = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await material.load();
    final file = File('/System/Library/Fonts/SFNS.ttf');
    if (file.existsSync()) {
      final font = FontLoader('ReferenceSF')
        ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
      await font.load();
    }
  });
  testWidgets('reference and compact form renders', (tester) async {
    for (final size in [const Size(402, 874), const Size(375, 667)]) {
      for (final create in [false, true]) {
        await tester.pumpWidget(const SizedBox());
        await show(tester, FakeAuth(), create: create, size: size);
        if (Platform.isMacOS) {
          await expectLater(
              find.byKey(const Key('auth-render')),
              matchesGoldenFile(
                  'goldens/auth-${size.width.toInt()}-$create.png'));
          if (size.width == 402) {
            final fields = find.byType(TextFormField);
            final values = create
                ? [
                    'Afaq',
                    'Aamir',
                    'afaq@example.com',
                    'password123',
                    'password123'
                  ]
                : ['afaq@example.com', 'password123'];
            for (var index = 0; index < values.length; index++) {
              await tester.enterText(fields.at(index), values[index]);
            }
            FocusManager.instance.primaryFocus?.unfocus();
            await tester.pumpAndSettle();
            await expectLater(find.byKey(const Key('auth-render')),
                matchesGoldenFile('goldens/auth-filled-$create.png'));
          }
        }
      }
    }
  });
  testWidgets('compact signup shows logo and final action without scrolling',
      (tester) async {
    await show(tester, FakeAuth(), create: true);
    expect(find.text('Log in').hitTestable(), findsOneWidget);
    expect(tester.getRect(find.text('Log in')).bottom, lessThanOrEqualTo(667));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'validation blocks request and password toggle has explicit label',
      (tester) async {
    final auth = FakeAuth();
    await show(tester, auth);
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(auth.calls, 0);
    await tester.tap(find.byTooltip('Show Password'));
    await tester.pump();
    expect(find.byTooltip('Hide Password'), findsOneWidget);
  });
  testWidgets(
      'pending request disables fields and shows only one spinner; error unlocks retry',
      (tester) async {
    final auth = FakeAuth()..pending = Completer<void>();
    await show(tester, auth);
    await tester.enterText(
        find.byType(TextFormField).at(0), 'player@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(auth.calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    for (final field
        in tester.widgetList<TextFormField>(find.byType(TextFormField))) {
      expect(field.enabled, false);
    }
    auth.pending!.completeError(Exception('offline'));
    await tester.pumpAndSettle();
    expect(
        find.text('Something went wrong. Please try again.'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull);
  });
  testWidgets('large text remains scrollable', (tester) async {
    await show(tester, FakeAuth(), create: true, scale: 2);
    await tester.ensureVisible(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(find.text('Log in').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
