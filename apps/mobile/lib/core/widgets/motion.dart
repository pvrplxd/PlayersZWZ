import 'package:flutter/material.dart';

const motionEase = Cubic(.23, 1, .32, 1);
const pageEase = Cubic(.32, .72, 0, 1);

/// Small directional travel keeps the setup sequence spatially connected.
/// Outgoing pages cannot receive taps or duplicate accessibility announcements.
class MotionSwap extends StatelessWidget {
  const MotionSwap(
      {super.key,
      required this.child,
      this.reverse = false,
      this.fill = false});
  final Widget child;
  final bool reverse;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: Duration(milliseconds: reduced ? 120 : 280),
      reverseDuration: Duration(milliseconds: reduced ? 120 : 200),
      switchInCurve: pageEase,
      switchOutCurve: motionEase,
      layoutBuilder: (current, previous) =>
          Stack(alignment: Alignment.topCenter, children: [
        ...previous.map((page) => fill
            ? Positioned.fill(
                child: IgnorePointer(child: ExcludeSemantics(child: page)))
            : Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(child: ExcludeSemantics(child: page)))),
        if (current != null) current,
      ]),
      transitionBuilder: (page, animation) {
        final incoming = page.key == child.key;
        final travel =
            reduced ? 0.0 : (incoming ? .08 : -.04) * (reverse ? -1 : 1);
        return FadeTransition(
            opacity: animation,
            child: SlideTransition(
                position: Tween(begin: Offset(travel, 0), end: Offset.zero)
                    .animate(animation),
                child: page));
      },
      child: child,
    );
  }
}

/// Pointer feedback only; the actual button keeps its keyboard/semantic action.
class PressFeedback extends StatefulWidget {
  const PressFeedback({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;
  @override
  State<PressFeedback> createState() => _PressFeedbackState();
}

class _PressFeedbackState extends State<PressFeedback> {
  bool _pressed = false;
  Offset? _origin;
  void _set(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: widget.enabled
            ? (event) {
                _origin = event.position;
                _set(true);
              }
            : null,
        onPointerMove: (event) {
          if (_origin != null && (event.position - _origin!).distance > 8) {
            _set(false);
          }
        },
        onPointerUp: (_) {
          _origin = null;
          _set(false);
        },
        onPointerCancel: (_) {
          _origin = null;
          _set(false);
        },
        child: AnimatedScale(
            scale: _pressed &&
                    widget.enabled &&
                    !MediaQuery.disableAnimationsOf(context)
                ? .97
                : 1,
            duration: const Duration(milliseconds: 120),
            curve: motionEase,
            child: widget.child),
      );
}

class SetupProgress extends StatelessWidget {
  const SetupProgress({super.key, required this.step});
  final int step;
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Step $step of 3',
        child: ExcludeSemantics(
            child: SizedBox(
                height: 48,
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: step.toDouble()),
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 250),
                    curve: motionEase,
                    builder: (context, position, _) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, (index) {
                          final active = (1 - (position - index - 1).abs())
                              .clamp(0.0, 1.0);
                          return Container(
                              key: ValueKey('setup-dot-$index'),
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              height: 7,
                              width: 7 + 24 * active,
                              decoration: BoxDecoration(
                                  color: Color.lerp(
                                      Colors.white24, Colors.white, active),
                                  borderRadius: BorderRadius.circular(4)));
                        })),
                  ),
                ))),
      );
}
