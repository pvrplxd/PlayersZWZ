import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../app/app_theme.dart';
import '../../core/widgets/motion.dart';

class MapRecenterMotion {
  MapRecenterMotion({required this.map, required TickerProvider vsync}) {
    _animation = AnimationController(
        vsync: vsync, duration: const Duration(milliseconds: 420))
      ..addListener(_tick);
  }
  final MapController map;
  late final AnimationController _animation;
  Offset _from = Offset.zero, _to = Offset.zero;
  double _zoom = 16;
  double _targetZoom = 16;
  LatLng? _target;
  void recenter(LatLng target, {required bool reducedMotion, double targetZoom = 16}) {
    stop();
    _target = target;
    _targetZoom = targetZoom;
    if (reducedMotion) {
      map.move(target, targetZoom);
      return;
    }
    final camera = map.camera;
    _zoom = camera.zoom;
    _from = camera.projectAtZoom(camera.center, 0);
    _to = camera.projectAtZoom(target, 0);
    final world = camera.getWorldWidthAtZoom(0);
    // Cross the date line by the shortest route, not across the whole world.
    if (world > 0 && (_to.dx - _from.dx).abs() > world / 2) {
      _to = Offset(_to.dx + (_to.dx > _from.dx ? -world : world), _to.dy);
    }
    _animation.forward(from: 0);
  }

  void _tick() {
    if (_target == null) return;
    final t = pageEase.transform(_animation.value);
    final point = map.camera.unprojectAtZoom(Offset.lerp(_from, _to, t)!, 0);
    final center = LatLng(point.latitude, (point.longitude + 180) % 360 - 180);
    map.move(
        _animation.value == 1 ? _target! : center,
        _zoom + (_targetZoom - _zoom) * t);
  }

  void stop() => _animation.stop();
  void dispose() => _animation.dispose();
}

/// The user's position. Live: lime dot with a soft repeating pulse.
/// Home or stale: still dot. Pulse stops when Reduce Motion is on.
class AreaMarker extends StatefulWidget {
  const AreaMarker({super.key, this.live = true, this.home = false});
  final bool live, home;

  @override
  State<AreaMarker> createState() => _AreaMarkerState();
}

class _AreaMarkerState extends State<AreaMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(AreaMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final animate = widget.live && !MediaQuery.disableAnimationsOf(context);
    if (animate && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!animate && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.home
        ? Colors.white
        : widget.live
            ? AppTheme.lime
            : const Color(0xFFFFA53D);
    return Center(
      child: Stack(alignment: Alignment.center, children: [
        if (widget.live)
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final t = Curves.easeOut.transform(_pulse.value);
              return Container(
                width: 18 + 44 * t,
                height: 18 + 44 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: .32 * (1 - t)),
                ),
              );
            },
          ),
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: widget.home ? AppTheme.surfaceHighest : color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: widget.home
              ? const Icon(PhosphorIconsFill.house, size: 10, color: Colors.white)
              : null,
        ),
      ]),
    );
  }
}
