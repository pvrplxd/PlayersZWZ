import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../app/app_theme.dart';
import '../../core/ui/pz_controls.dart';

/// Full-screen circular crop: pinch to zoom, drag to position.
/// Returns a square PNG (512 px, the size the API stores) of the area inside the circle.
class PhotoCropScreen extends StatefulWidget {
  const PhotoCropScreen({super.key, required this.bytes, required this.onSave});

  final Uint8List bytes;

  /// Uploads the cropped image; return true when saved.
  final Future<bool> Function(Uint8List cropped) onSave;

  static const output = 512;

  @override
  State<PhotoCropScreen> createState() => _PhotoCropScreenState();
}

class _PhotoCropScreenState extends State<PhotoCropScreen> {
  final _transform = TransformationController();
  ui.Image? _image;
  double _viewport = 0, _cover = 1;
  bool _saving = false, _failed = false;

  @override
  void initState() {
    super.initState();
    decodeImageFromList(widget.bytes).then((image) {
      if (mounted) setState(() => _image = image);
    }, onError: (_) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _transform.dispose();
    _image?.dispose();
    super.dispose();
  }

  /// Scales the image so it just covers the circle, centred.
  void _reset(double viewport) {
    final image = _image!;
    _viewport = viewport;
    _cover = viewport / (image.width < image.height ? image.width : image.height);
    final w = image.width * _cover, h = image.height * _cover;
    _transform.value = Matrix4.identity()
      ..translateByDouble(-(w - viewport) / 2, -(h - viewport) / 2, 0, 1);
  }

  Future<Uint8List> _crop() async {
    final image = _image!;
    final m = _transform.value;
    final scale = m.getMaxScaleOnAxis();
    final tx = m.getTranslation().x, ty = m.getTranslation().y;
    final side = _viewport / scale / _cover;
    final src = Rect.fromLTWH((-tx / scale) / _cover, (-ty / scale) / _cover, side, side);
    const out = PhotoCropScreen.output;
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
        image,
        src,
        Rect.fromLTWH(0, 0, out.toDouble(), out.toDouble()),
        Paint()..filterQuality = FilterQuality.high);
    final picture = recorder.endRecording();
    final cropped = await picture.toImage(out, out);
    picture.dispose();
    final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
    cropped.dispose();
    return data!.buffer.asUint8List();
  }

  Future<void> _save() async {
    if (_saving || _image == null) return;
    setState(() => _saving = true);
    try {
      final cropped = await _crop();
      final ok = await widget.onSave(cropped);
      if (!mounted) return;
      if (ok) {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not save your photo. Please retry.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(children: [
        SizedBox(height: padding.top + 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(foregroundColor: AppTheme.primaryText),
              child: const Text('Cancel'),
            ),
            const Expanded(
              child: Text('Move and scale',
                  textAlign: TextAlign.center, style: AppTheme.headline),
            ),
            TextButton(
              onPressed: _image == null || _saving ? null : _save,
              style: TextButton.styleFrom(
                  foregroundColor: AppTheme.lime,
                  disabledForegroundColor: AppTheme.muted),
              child: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.lime))
                  : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            final viewport = (constraints.maxWidth - 40)
                .clamp(160.0, constraints.maxHeight - 40)
                .toDouble();
            final image = _image;
            if (_failed) {
              return const PzEmptyState(
                icon: PhosphorIconsRegular.imageBroken,
                title: 'Couldn’t open that photo',
                message: 'Try another JPEG or PNG image.',
              );
            }
            if (image == null) {
              return const Center(
                  child: CircularProgressIndicator(color: AppTheme.lime));
            }
            if (viewport != _viewport) _reset(viewport);
            return Center(
              child: SizedBox.square(
                dimension: viewport,
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned.fill(
                    child: InteractiveViewer(
                      transformationController: _transform,
                      constrained: false,
                      minScale: 1,
                      maxScale: 6,
                      boundaryMargin: EdgeInsets.zero,
                      clipBehavior: Clip.none,
                      child: SizedBox(
                        width: image.width * _cover,
                        height: image.height * _cover,
                        child: RawImage(image: image, fit: BoxFit.fill),
                      ),
                    ),
                  ),
                  // Dim everything outside the circle; thin ring on the edge.
                  Positioned(
                    left: -viewport,
                    top: -viewport,
                    width: viewport * 3,
                    height: viewport * 3,
                    child: IgnorePointer(
                      child: CustomPaint(painter: _CircleMask(viewport)),
                    ),
                  ),
                ]),
              ),
            );
          }),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, padding.bottom + 24),
          child: const Text('Pinch to zoom · drag to move',
              textAlign: TextAlign.center, style: AppTheme.footnote),
        ),
      ]),
    );
  }
}

class _CircleMask extends CustomPainter {
  _CircleMask(this.viewport);
  final double viewport;

  @override
  void paint(Canvas canvas, Size size) {
    final circle = Rect.fromLTWH(viewport, viewport, viewport, viewport);
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(circle);
    canvas.drawPath(path, Paint()..color = const Color(0xB3000000));
    canvas.drawOval(
        circle,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0x99FFFFFF));
  }

  @override
  bool shouldRepaint(_CircleMask old) => old.viewport != viewport;
}
