import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/playerszwz_app.dart';
import '../../core/widgets/motion.dart';
import 'profile_photo.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar(
      {super.key, required this.name, this.bytes, this.size = 122});
  final String name;
  final Uint8List? bytes;
  final double size;
  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
        color: appSurface,
        alignment: Alignment.center,
        child: Icon(CupertinoIcons.person,
            size: size * .42, color: Colors.white38));
    return SizedBox.square(
        dimension: size,
        child: ClipOval(
            child: bytes == null
                ? placeholder
                : Image.memory(bytes!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    semanticLabel: '$name’s profile photo',
                    errorBuilder: (_, error, stack) => placeholder)));
  }
}

class ProfilePhotoEditor extends StatefulWidget {
  const ProfilePhotoEditor(
      {super.key,
      required this.controller,
      required this.name,
      this.enabled = true});
  final ProfilePhotoController controller;
  final String name;
  final bool enabled;
  @override
  State<ProfilePhotoEditor> createState() => _ProfilePhotoEditorState();
}

class _ProfilePhotoEditorState extends State<ProfilePhotoEditor> {
  bool _picking = false;
  String? _pickError;

  Future<void> _choose() async {
    if (_picking || widget.controller.busy) return;
    setState(() {
      _picking = true;
      _pickError = null;
    });
    try {
      final candidate = await widget.controller.picker.choose();
      if (mounted) setState(() => _picking = false);
      if (mounted && candidate != null) await _preview(candidate);
    } catch (error) {
      if (mounted) {
        setState(() => _pickError = error is PlatformException &&
                error.code.contains('access')
            ? 'Photo access is unavailable. Allow access in Settings, then try again.'
            : 'Could not open that photo. Try another JPEG or PNG image.');
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _preview(Uint8List candidate) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: appSurface,
      builder: (sheetContext) => ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) => PopScope(
              canPop: !widget.controller.busy,
              child: SafeArea(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * .85),
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('Your profile photo',
                            style: TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 24),
                        ProfileAvatar(
                            name: widget.name, bytes: candidate, size: 184),
                        const SizedBox(height: 20),
                        const Text('This is how other players will see you.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white60)),
                        if (widget.controller.error != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Semantics(
                                  liveRegion: true,
                                  child: Text(widget.controller.error!,
                                      style:
                                          const TextStyle(color: appError)))),
                        const SizedBox(height: 24),
                        FilledButton(
                            onPressed: widget.controller.busy
                                ? null
                                : () async {
                                    if (await widget.controller
                                            .save(candidate) &&
                                        sheetContext.mounted) {
                                      HapticFeedback.lightImpact();
                                      Navigator.pop(sheetContext);
                                    }
                                  },
                            style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                minimumSize: const Size.fromHeight(52)),
                            child: Text(widget.controller.busy
                                ? 'Saving photo…'
                                : 'Use photo')),
                        TextButton(
                            onPressed: widget.controller.busy
                                ? null
                                : () {
                                    widget.controller.discardRecovered();
                                    Navigator.pop(sheetContext);
                                  },
                            child: const Text('Cancel')),
                      ])),
                ),
              ))),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final enabled = widget.enabled && !controller.busy && !_picking;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          PressFeedback(
              enabled: enabled,
              child: TextButton(
                  onPressed: enabled ? _choose : null,
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.all(4),
                      foregroundColor: Colors.white70),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox.square(
                        dimension: 126,
                        child: Stack(children: [
                          ProfileAvatar(
                              name: widget.name, bytes: controller.bytes),
                          Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                      color: appAccent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.black, width: 3)),
                                  child: controller.busy || _picking
                                      ? const Padding(
                                          padding: EdgeInsets.all(8),
                                          child: CircularProgressIndicator(
                                              color: Colors.black,
                                              strokeWidth: 2))
                                      : const Icon(CupertinoIcons.plus,
                                          size: 18, color: Colors.black))),
                        ])),
                    const SizedBox(height: 10),
                    Text(
                        controller.bytes == null
                            ? 'Add profile photo'
                            : 'Change profile photo',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                  ]))),
          if (controller.bytes != null)
            TextButton(
                onPressed: enabled ? () => controller.remove() : null,
                child: const Text('Remove photo',
                    style: TextStyle(fontSize: 13, color: Colors.white54))),
          if (controller.recovered != null)
            TextButton(
                onPressed:
                    enabled ? () => _preview(controller.recovered!) : null,
                child: const Text('Review recovered photo')),
          if (_pickError != null || controller.error != null) ...[
            Text(_pickError ?? controller.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: appError, height: 1.4)),
            TextButton(
                onPressed: enabled
                    ? () {
                        if (_pickError != null) {
                          _choose();
                        } else {
                          controller.load();
                        }
                      }
                    : null,
                child: const Text('Retry photo')),
          ],
        ]);
      });
}
