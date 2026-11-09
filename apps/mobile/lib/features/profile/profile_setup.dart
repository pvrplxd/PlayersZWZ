import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../core/widgets/setup_frame.dart';
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
    'Basketball': PhosphorIconsRegular.basketball,
    'Badminton': PhosphorIconsRegular.tennisBall,
    'Football': PhosphorIconsRegular.soccerBall,
    'Skating': PhosphorIconsRegular.personSimpleRun,
    'Cricket': PhosphorIconsRegular.cricket,
    'Tennis': PhosphorIconsRegular.tennisBall,
  };

  Widget _usernameField() {
    final suffix = _checking
        ? const SizedBox.square(
            dimension: 17,
            child: CircularProgressIndicator(strokeWidth: 2))
        : _available
            ? const Icon(PhosphorIconsRegular.checkCircle,
                color: appSuccess, size: 21)
            : null;
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return CupertinoTextField(
        controller: _username,
        onChanged: _changed,
        enabled: !_saving,
        autocorrect: false,
        enableSuggestions: false,
        inputFormatters: [LengthLimitingTextInputFormatter(20)],
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _next(),
        style: const TextStyle(fontSize: 17, color: Colors.white),
        placeholder: 'Choose a username',
        placeholderStyle: const TextStyle(color: Colors.white38),
        prefix: const Padding(
          padding: EdgeInsets.only(left: 16, right: 10),
          child: Icon(PhosphorIconsRegular.at, size: 20, color: Colors.white54),
        ),
        suffix: suffix == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(right: 16), child: suffix),
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          color: appSurface,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
              color: _available ? appSuccess : const Color(0x33FFFFFF)),
        ),
      );
    }
    return TextField(
      controller: _username,
      onChanged: _changed,
      enabled: !_saving,
      autocorrect: false,
      enableSuggestions: false,
      maxLength: 20,
      textInputAction: TextInputAction.next,
      onSubmitted: (_) => _next(),
      style: const TextStyle(fontSize: 17, letterSpacing: 0),
      decoration: setupInput(
        'Choose a username',
        prefix: const Icon(PhosphorIconsRegular.at,
            size: 22, color: Colors.white54),
        suffix: suffix == null
            ? null
            : Padding(padding: const EdgeInsets.all(16), child: suffix),
      ),
    );
  }

  Widget _sportChoice(MapEntry<String, IconData> sport) {
    final selected = _sports.contains(sport.key);
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    void toggle() {
      if (_saving) return;
      unawaited(HapticFeedback.selectionClick());
      setState(() {
        selected ? _sports.remove(sport.key) : _sports.add(sport.key);
      });
    }

    if (isIOS) {
      return Semantics(
        selected: selected,
        button: true,
        child: CupertinoButton(
          onPressed: _saving ? null : toggle,
          minSize: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          borderRadius: BorderRadius.circular(22),
          color: selected ? appAccent : appSurface,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(sport.value,
                size: 17, color: selected ? Colors.black : Colors.white70),
            const SizedBox(width: 7),
            Text(sport.key,
                style: TextStyle(
                    color: selected ? Colors.black : Colors.white,
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400)),
          ]),
        ),
      );
    }
    return FilterChip(
      avatar: Icon(sport.value,
          size: 17, color: selected ? Colors.black : Colors.white70),
      label: Text(sport.key),
      selected: selected,
      onSelected: _saving ? null : (_) => toggle(),
      showCheckmark: false,
      side: BorderSide(
          color: selected ? appAccent : Colors.white.withValues(alpha: .15)),
      selectedColor: appAccent,
      backgroundColor: appSurface,
      labelStyle: TextStyle(
          color: selected ? Colors.black : Colors.white,
          fontSize: 13,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
    );
  }

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
                  : 'Create profile',
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
              _usernameField(),
              const SizedBox(height: 12),
              const Text(
                  'Your username is unique to you. Use 3–20 letters, numbers, dots or underscores.',
                  style: TextStyle(
                      color: Colors.white54, fontSize: 13, height: 1.5)),
            ] else ...[
              const Text('Sports',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _icons.entries.map(_sportChoice).toList(),
              ),
            ],
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

