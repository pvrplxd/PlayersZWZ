import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playerszwz/core/widgets/platform_navigation.dart';
import 'package:playerszwz/core/widgets/setup_frame.dart';
import 'package:playerszwz/features/discovery/explore_screen.dart';
import 'package:playerszwz/features/location/location_service.dart';

void main() {
  testWidgets('Android destinations switch content and preserve the map tab',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark().copyWith(platform: TargetPlatform.android),
        home: ExploreScreen(
            area: const Area(31, 74, 'Lahore', 'manual'),
            name: 'Afaq',
            apiKey: '',
            changeArea: () {},
            signOut: () async {})));
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();
    expect(find.text('Make room for your next game.'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    await tester.tap(find.text('Arenas').last);
    await tester.pumpAndSettle();
    expect(find.text('A place for every game.'), findsOneWidget);
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    expect(find.text('Afaq'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'iPhone creates UIKit navigation and synchronizes selection both ways',
      (tester) async {
    int? viewId;
    final selections = <int>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views,
        (call) async {
      if (call.method == 'create') {
        viewId = (call.arguments as Map)['id'] as int;
        messenger.setMockMethodCallHandler(
            MethodChannel('playerszwz/navigation/$viewId'), (call) async {
          if (call.method == 'select') selections.add(call.arguments as int);
          return null;
        });
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      if (viewId != null) {
        messenger.setMockMethodCallHandler(
            MethodChannel('playerszwz/navigation/$viewId'), null);
      }
    });
    var selected = 0;
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark().copyWith(platform: TargetPlatform.iOS),
        home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
                bottomNavigationBar: PlatformNavigation(
                    selectedIndex: selected,
                    onSelected: (value) =>
                        setState(() => selected = value))))));
    await tester.pumpAndSettle();
    expect(find.byType(UiKitView), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(viewId, isNotNull);
    await messenger.handlePlatformMessage(
        'playerszwz/navigation/$viewId',
        const StandardMethodCodec()
            .encodeMethodCall(const MethodCall('selected', 3)),
        (_) {});
    await tester.pumpAndSettle();
    expect(selected, 3);
    expect(selections.last, 3);
    await messenger.handlePlatformMessage(
        'playerszwz/navigation/$viewId',
        const StandardMethodCodec()
            .encodeMethodCall(const MethodCall('selected', 99)),
        (_) {});
    await tester.pumpAndSettle();
    expect(selected, 3);
  });

  testWidgets('setup action stays reachable above keyboard with large text',
      (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.reset);
    var continued = false;
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: SetupFrame(
            step: 1,
            title: 'Create profile',
            subtitle: 'Choose your username.',
            action: 'Next',
            onContinue: () => continued = true,
            child:
                const Column(children: [SizedBox(height: 200), TextField()]))));
    expect(tester.takeException(), isNull);
    final action = find.byType(FilledButton);
    expect(tester.getBottomLeft(action).dy, lessThanOrEqualTo(667 - 280));
    await tester.tap(find.text('Next'));
    expect(continued, true);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
}
