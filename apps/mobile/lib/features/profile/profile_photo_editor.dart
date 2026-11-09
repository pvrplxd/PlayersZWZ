import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/playerszwz_app.dart';
import '../../core/widgets/motion.dart';
import '../../core/ui/pz_controls.dart';
import 'photo_crop_screen.dart';
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
        child: Icon(PhosphorIconsRegular.user,
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
      this.enabled = true,
      this.compact = false});
  final ProfilePhotoController controller;
  final String name;
  final bool enabled;
  final bool compact;
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
        setState(() => _pickError = error is FormatException
            ? error.message
            : error is PlatformException && error.code.contains('access')
                ? 'Photo access is unavailable. Allow access in Settings, then try again.'
                : 'Could not open that photo. Try another JPEG or PNG image.');
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  /// Crop, then save. Cancelling discards a recovered photo.
  Future<void> _preview(Uint8List candidate) async {
    final route = Theme.of(context).platform == TargetPlatform.iOS
        ? CupertinoPageRoute<bool>(
            fullscreenDialog: true,
            builder: (_) => PhotoCropScreen(
                bytes: candidate, onSave: widget.controller.save))
        : MaterialPageRoute<bool>(
            fullscreenDialog: true,
            builder: (_) => PhotoCropScreen(
                bytes: candidate, onSave: widget.controller.save));
    final saved = await Navigator.of(context).push<bool>(route);
    if (saved != true) widget.controller.discardRecovered();
  }

  /// With a photo: Change or Remove. Without: pick straight away.
  Future<void> _tapAvatar(BuildContext anchorContext) async {
    if (widget.controller.bytes == null) return _choose();
    final choice = await pzMenu(anchorContext,
        anchor: pzRectOf(anchorContext),
        title: 'Profile photo',
        actions: const [
          PzAction('Change photo', icon: PhosphorIconsRegular.image),
          PzAction('Remove photo',
              icon: PhosphorIconsRegular.trash, destructive: true),
        ]);
    if (!mounted) return;
    if (choice == 0) await _choose();
    if (choice == 1) await _removePhoto();
  }

  Future<void> _removePhoto() async {
    if (widget.controller.busy) return;
    final confirmed = await pzConfirm(context,
        title: 'Remove profile photo?',
        message: 'Other players will see your initials instead.',
        confirm: 'Remove photo',
        cancel: 'Keep photo');
    if (confirmed == true && mounted) {
      await widget.controller.remove();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final enabled = widget.enabled && !controller.busy && !_picking;
        if (widget.compact) {
          return Column(mainAxisSize: MainAxisSize.min, children: [
            PressFeedback(
                enabled: enabled,
                child: Builder(builder: (anchor) => TextButton(
                    onPressed: enabled ? () => _tapAvatar(anchor) : null,
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero, minimumSize: Size.zero),
                    child: SizedBox.square(
                        dimension: 92,
                        child: Stack(children: [
                          ProfileAvatar(
                              name: widget.name,
                              bytes: controller.bytes,
                              size: 92),
                          Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                      color: appAccent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.black, width: 3)),
                                  child: controller.busy || _picking
                                      ? const Padding(
                                          padding: EdgeInsets.all(6),
                                          child: CircularProgressIndicator(
                                              color: Colors.black,
                                              strokeWidth: 2))
                                      : const Icon(PhosphorIconsRegular.camera,
                                          size: 14, color: Colors.black))),
                        ]))))),
            if (controller.recovered != null)
              TextButton(
                  onPressed: enabled
                      ? () => _preview(controller.recovered!)
                      : null,
                  child: const Text('Review recovered photo')),
            if (_pickError != null || controller.error != null)
              Column(children: [
                Text(_pickError ?? controller.error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: appError)),
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
              ]),
          ]);
        }
        return Column(mainAxisSize: MainAxisSize.min, children: [
          PressFeedback(
              enabled: enabled,
              child: Builder(builder: (anchor) => TextButton(
                  onPressed: enabled ? () => _tapAvatar(anchor) : null,
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
                                      : const Icon(PhosphorIconsRegular.plus,
                                          size: 18, color: Colors.black))),
                        ])),
                    const SizedBox(height: 10),
                    Text(
                        controller.bytes == null
                            ? 'Add profile photo'
                            : 'Change profile photo',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                  ])))),
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
