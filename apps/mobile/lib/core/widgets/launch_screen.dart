import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/app_theme.dart';

/// Launch/loading screen. It starts exactly like the native launch screen
/// (bare logo, same size), then the logo eases down and a neon spinner
/// fades in below. The intro plays once per app run.
class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key, this.identity, this.loading = false});

  /// Signed-in name, announced to screen readers only.
  final String? identity;
  final bool loading;

  /// Logo width on the native launch screen (192 pt image, logo ≈ 66% wide).
  static const nativeLogoWidth = 126.0;
  static const settledScale = .64;

  static bool _introPlayed = false;

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
    value: LaunchScreen._introPlayed ? 1 : 0,
  );

  @override
  void initState() {
    super.initState();
    if (!LaunchScreen._introPlayed) {
      LaunchScreen._introPlayed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (MediaQuery.disableAnimationsOf(context)) {
          _intro.value = 1;
        } else {
          // A short hold on the native-matching frame, then ease down.
          Future.delayed(const Duration(milliseconds: 180), () {
            if (mounted) _intro.forward();
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = CurvedAnimation(
        parent: _intro,
        curve: const Interval(0, .62, curve: Curves.easeInOutCubic));
    final loader = CurvedAnimation(
        parent: _intro, curve: const Interval(.5, 1, curve: Curves.easeOut));
    return Scaffold(
      backgroundColor: Colors.black,
      body: Semantics(
        liveRegion: widget.loading,
        label: widget.loading
            ? (widget.identity == null
                ? 'Loading PlayersZWZ'
                : 'Loading your account, signed in as ${widget.identity}')
            : null,
        child: Stack(children: [
          Center(
            child: AnimatedBuilder(
              animation: scale,
              builder: (context, child) => Transform.scale(
                scale: 1 - (1 - LaunchScreen.settledScale) * scale.value,
                child: child,
              ),
              child: SvgPicture.asset(
                'assets/branding/playerszwz-logo.svg',
                width: LaunchScreen.nativeLogoWidth,
                excludeFromSemantics: true,
              ),
            ),
          ),
          if (widget.loading)
            Positioned.fill(
              child: Center(
                child: AnimatedBuilder(
                  animation: loader,
                  builder: (context, child) => Opacity(
                    opacity: loader.value,
                    child: Transform.translate(
                      offset: Offset(0, 74 + 10 * (1 - loader.value)),
                      child: child,
                    ),
                  ),
                  child: const NeonSpinner(),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Thin rotating lime arc with a soft glow and a fading tail.
class NeonSpinner extends StatefulWidget {
  const NeonSpinner({super.key, this.size = 26, this.color = AppTheme.lime});
  final double size;
  final Color color;

  @override
  State<NeonSpinner> createState() => _NeonSpinnerState();
}

class _NeonSpinnerState extends State<NeonSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: SizedBox.square(
          dimension: widget.size,
          child: AnimatedBuilder(
            animation: _spin,
            builder: (context, _) => CustomPaint(
              painter: _ArcPainter(_spin.value, widget.color),
            ),
          ),
        ),
      );
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.t, this.color);
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arc = rect.deflate(2);
    final start = t * 2 * math.pi;
    const sweep = math.pi * 1.35;
    final gradient = SweepGradient(
      startAngle: 0,
      endAngle: sweep,
      colors: [color.withValues(alpha: 0), color],
      transform: GradientRotation(start),
    );
    canvas.drawCircle(
        rect.center,
        arc.width / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = color.withValues(alpha: .1));
    final glow = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final line = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arc, start, sweep, false, glow);
    canvas.drawArc(arc, start, sweep, false, line);
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.t != t || old.color != color;
}
