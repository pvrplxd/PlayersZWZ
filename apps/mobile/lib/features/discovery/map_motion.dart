import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/widgets/motion.dart';

class MapRecenterMotion {
  MapRecenterMotion({required this.map, required TickerProvider vsync}) {
    _animation = AnimationController(
        vsync: vsync, duration: const Duration(milliseconds: 280))
      ..addListener(_tick);
  }
  final MapController map;
  late final AnimationController _animation;
  Offset _from = Offset.zero, _to = Offset.zero;
  double _zoom = 16;
  LatLng? _target;
  void recenter(LatLng target, {required bool reducedMotion}) {
    stop();
    _target = target;
    if (reducedMotion) {
      map.move(target, 16);
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
        _animation.value == 1 ? _target! : center, _zoom + (16 - _zoom) * t);
  }

  void stop() => _animation.stop();
  void dispose() => _animation.dispose();
}

/// A saved-area pin; the halo is decorative, not a GPS-accuracy measurement.
class AreaMarker extends StatelessWidget {
  const AreaMarker({super.key});
  @override
  Widget build(BuildContext context) => Center(
      child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF4285F4).withValues(alpha: .16)),
          child: Center(
              child: Container(
                  width: 19,
                  height: 19,
                  decoration: BoxDecoration(
                      color: const Color(0xFF4285F4),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [
                        BoxShadow(color: Colors.black38, blurRadius: 5)
                      ])))));
}
