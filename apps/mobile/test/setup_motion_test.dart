import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playerszwz/core/widgets/setup_frame.dart';
import 'package:playerszwz/core/widgets/motion.dart';

void main() {
  testWidgets('press feedback releases when a touch becomes a drag',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
                child: PressFeedback(
                    child: FilledButton(
                        onPressed: () {}, child: const Text('Continue')))))));
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(FilledButton)));
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, .97);
    await gesture.moveBy(const Offset(0, 24));
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    await gesture.up();
  });
  for (final reduced in [false, true]) {
    testWidgets(
        'setup transitions reset scroll and respect reduced motion: $reduced',
        (tester) async {
      var step = 1;
      late StateSetter update;
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: child!),
          home: StatefulBuilder(builder: (context, setState) {
            update = setState;
            return SetupFrame(
                step: step,
                title: 'Step $step',
                subtitle: '',
                action: 'Continue',
                onContinue: () {},
                child: step == 1
                    ? const Column(
                        children: [Text('First body'), SizedBox(height: 1200)])
                    : const Text('Second body'));
          })));
      await tester.drag(
          find.byType(SingleChildScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
      update(() => step = 2);
      await tester.pump();
      final slides =
          tester.widgetList<SlideTransition>(find.byType(SlideTransition));
      if (reduced) {
        expect(
            slides.every((slide) => slide.position.value == Offset.zero), true);
      } else {
        expect(
            slides.any((slide) => slide.position.value.dx.abs() > .01), true);
      }
      expect(
          find.ancestor(
              of: find.text('First body'),
              matching: find.byType(IgnorePointer)),
          findsWidgets);
      await tester.pumpAndSettle();
      expect(find.text('First body'), findsNothing);
      expect(find.text('Second body'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
