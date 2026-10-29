import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../core/widgets/setup_frame.dart';
import '../../core/widgets/motion.dart';
import 'profile_photo.dart';
import 'profile_photo_editor.dart';
import '../../app/playerszwz_app.dart';
import '../../core/api_client.dart';

class ProfileSetup extends StatefulWidget {
  const ProfileSetup(
      {super.key,
      required this.api,
      required this.onComplete,
      required this.signOut,
      required this.name,
      this.photo});
  final ProfilePhotoController? photo;
  final ApiClient api;
  final VoidCallback onComplete;
  final Future<void> Function() signOut;
  final String name;
  @override
  State<ProfileSetup> createState() => _ProfileSetupState();
}

class _ProfileSetupState extends State<ProfileSetup> {
  final _username = TextEditingController();
  final _sports = <String>{};
  Timer? _debounce;
  int _revision = 0;
  bool _checking = false, _available = false, _saving = false;
  int _step = 0;
  bool _reverse = false;
  late final _photo =
      widget.photo ?? ProfilePhotoController(ProfilePhotoService(widget.api));

  @override
  void initState() {
    super.initState();
    if (widget.photo == null) {
      _photo.load();
      _photo.recover();
    }
  }

  String? _message;
  static const _icons = {
    'Basketball': Icons.sports_basketball_rounded,
    'Badminton': Icons.sports_tennis_rounded,
    'Football': Icons.sports_soccer_rounded,
    'Skating': Icons.skateboarding_rounded,
    'Cricket': Icons.sports_cricket_rounded,
    'Tennis': Icons.sports_tennis_rounded,
  };

  @override
  void dispose() {
    _debounce?.cancel();
    _username.dispose();
    if (widget.photo == null) _photo.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _debounce?.cancel();
    final revision = ++_revision;
    final name = value.trim().toLowerCase();
    setState(() {
      _available = false;
      _message = null;
      _checking = RegExp(r'^[a-z0-9][a-z0-9_.]{2,19}$').hasMatch(name);
    });
    if (!_checking) return;
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final result = await widget.api
            .get('/api/v1/usernames/availability', query: {'username': name});
        if (!mounted || revision != _revision) return;
        setState(() {
          _available = result is Map &&
              result['username'] == name &&
              result['available'] == true;
          _message = _available
              ? 'Username available'
              : 'That username is already taken.';
        });
      } catch (_) {
        if (!mounted || revision != _revision) return;
        setState(() => _message = 'Could not check. Tap Retry to check again.');
      } finally {
        if (mounted && revision == _revision) setState(() => _checking = false);
      }
    });
  }

  Future<void> _save() async {
    if (_saving || _sports.isEmpty) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final result = await widget.api.put('/api/v1/me/profile', body: {
        'username': _username.text.trim().toLowerCase(),
        'sports': _sports.toList(),
      });
      if (result is! Map ||
          result['profile'] is! Map ||
          result['profile']['setup_complete'] != true) {
        throw const ApiException(
            0, 'INVALID_RESPONSE', 'Could not confirm profile saving.');
      }
      if (mounted) {
        widget.onComplete();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (error is ApiException && error.code == 'USERNAME_TAKEN') {
          _reverse = true;
          _step = 0;
          _available = false;
          _message = 'That username was just taken. Choose another.';
        } else {
          _message =
              'Could not save your profile. Your choices are kept; please retry.';
        }
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _back() => setState(() {
        _reverse = true;
        _step = 0;
        _message = null;
      });

  void _next() {
    if (!_available || _checking || _saving) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _reverse = false;
      _step = 1;
      _message = null;
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _step == 1 && !_saving) _back();
        },
        child: SetupFrame(
          step: _step + 1,
          reverse: _reverse,
          title: _step == 0 ? 'Create profile' : 'Pick your sports',
          subtitle:
              _step == 0 ? '' : 'Choose at least one sport to get started.',
          action: _saving
              ? 'Saving…'
              : _step == 0
                  ? 'Next'
                  : 'Continue',
          onBack: _step == 1 ? _back : null,
          busy: _saving,
          onContinue: (_step == 0 ? !_available : _sports.isEmpty)
              ? null
              : _step == 0
                  ? _next
                  : _save,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_step == 0) ...[
              Center(
                  child: ProfilePhotoEditor(
                      controller: _photo,
                      name: widget.name,
                      enabled: !_saving)),
              const SizedBox(height: 28),
              const Text('Username',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70)),
              const SizedBox(height: 10),
              TextField(
                  controller: _username,
                  onChanged: _changed,
                  enabled: !_saving,
                  autocorrect: false,
                  enableSuggestions: false,
                  maxLength: 20,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _next(),
                  style: const TextStyle(
                      fontSize: 17,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w400),
                  decoration: setupInput('Choose a username',
                      prefix: const Icon(CupertinoIcons.at,
                          size: 22, color: Colors.white54),
                      suffix: _checking
                          ? const Padding(
                              padding: EdgeInsets.all(18),
                              child: SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)))
                          : _available
                              ? const Icon(CupertinoIcons.checkmark_circle_fill,
                                  color: appSuccess, size: 22)
                              : null)),
              const SizedBox(height: 12),
              const Text(
                  'Your username is unique to you. Use 3–20 letters, numbers, dots or underscores.',
                  style: TextStyle(
                      color: Colors.white54, fontSize: 13, height: 1.5)),
            ] else
              LayoutBuilder(builder: (context, box) {
                final large = MediaQuery.textScalerOf(context).scale(16) > 24;
                return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _icons.entries.map((sport) {
                      final selected = _sports.contains(sport.key);
                      final color =
                          selected ? appAccent : const Color(0xFFB6B6B6);
                      return SizedBox(
                        width: large ? box.maxWidth : (box.maxWidth - 12) / 2,
                        child: PressFeedback(
                            enabled: !_saving,
                            child: Semantics(
                                selected: selected,
                                child: AnimatedContainer(
                                  duration:
                                      MediaQuery.disableAnimationsOf(context)
                                          ? Duration.zero
                                          : const Duration(milliseconds: 160),
                                  curve: Curves.easeOutCubic,
                                  decoration: BoxDecoration(
                                      color: selected
                                          ? const Color(0xFF222619)
                                          : appSurface,
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                          color: selected
                                              ? appAccent
                                              : Colors.transparent)),
                                  child: Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(24),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(24),
                                      onTap: _saving
                                          ? null
                                          : () {
                                              HapticFeedback.selectionClick();
                                              setState(() {
                                                selected
                                                    ? _sports.remove(sport.key)
                                                    : _sports.add(sport.key);
                                              });
                                            },
                                      child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              12, 12, 12, 18),
                                          child: Column(children: [
                                            Align(
                                                alignment: Alignment.topRight,
                                                child: Icon(
                                                    selected
                                                        ? CupertinoIcons
                                                            .checkmark_circle_fill
                                                        : CupertinoIcons.circle,
                                                    color: selected
                                                        ? appAccent
                                                        : Colors.white24,
                                                    size: 17)),
                                            sport.key == 'Badminton'
                                                ? CustomPaint(
                                                    size: const Size(40, 40),
                                                    painter:
                                                        _ShuttlePainter(color))
                                                : Icon(sport.value,
                                                    size: 40, color: color),
                                            const SizedBox(height: 12),
                                            Text(sport.key,
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                    color: color)),
                                          ])),
                                    ),
                                  ),
                                ))),
                      );
                    }).toList());
              }),
            if (_message != null) ...[
              const SizedBox(height: 16),
              Semantics(
                  liveRegion: true,
                  child: Text(_message!,
                      style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: _available && _step == 0
                              ? appSuccess
                              : appError))),
              if (_step == 0 && !_available && !_checking)
                Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                        onPressed: () => _changed(_username.text),
                        child: const Text('Retry'))),
            ],
          ]),
        ),
      );
}

class _ShuttlePainter extends CustomPainter {
  const _ShuttlePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final outline = Path()
      ..moveTo(14, 29)
      ..lineTo(5, 6)
      ..quadraticBezierTo(20, 0, 35, 6)
      ..lineTo(26, 29)
      ..close();
    canvas.drawPath(outline, paint);
    canvas.drawLine(const Offset(12, 5), const Offset(17, 29), paint);
    canvas.drawLine(const Offset(20, 4), const Offset(20, 29), paint);
    canvas.drawLine(const Offset(28, 5), const Offset(23, 29), paint);
    canvas.drawLine(const Offset(10, 18), const Offset(30, 18), paint);
    paint.style = PaintingStyle.fill;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(14, 28, 12, 10), const Radius.circular(5)),
        paint);
  }

  @override
  bool shouldRepaint(_ShuttlePainter oldDelegate) => oldDelegate.color != color;
}
