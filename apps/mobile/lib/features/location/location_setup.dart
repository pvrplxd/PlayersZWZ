import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../core/widgets/setup_frame.dart';
import '../../app/playerszwz_app.dart';
import '../../core/api_client.dart';
import 'location_service.dart';

class LocationSetup extends StatefulWidget {
  const LocationSetup(
      {super.key,
      required this.api,
      required this.location,
      required this.onComplete,
      required this.signOut,
      this.onCancel});
  final ApiClient api;
  final LocationService location;
  final ValueChanged<Area> onComplete;
  final VoidCallback? onCancel;
  final Future<void> Function() signOut;
  @override
  State<LocationSetup> createState() => _LocationSetupState();
}

class _LocationSetupState extends State<LocationSetup> {
  final _query = TextEditingController();
  Timer? _timer;
  int _revision = 0;
  bool _busy = false, _searching = false, _settings = false;
  String? _error;
  List<Area>? _results;
  Area? _selected;
  @override
  void dispose() {
    _timer?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _search(String value) {
    _timer?.cancel();
    final revision = ++_revision;
    setState(() {
      _selected = null;
      _results = null;
      _error = null;
      _settings = false;
      _searching = value.trim().length >= 3;
    });
    if (!_searching) return;
    _timer = Timer(const Duration(milliseconds: 450), () async {
      try {
        final results = await widget.location.search(value);
        if (mounted && revision == _revision) {
          setState(() => _results = results);
        }
      } catch (error) {
        if (mounted && revision == _revision) {
          setState(() => _error = _message(error));
        }
      } finally {
        if (mounted && revision == _revision) {
          setState(() => _searching = false);
        }
      }
    });
  }

  String _message(Object error) => error is LocationFailure
      ? error.message
      : 'Could not complete that request. Check your connection and retry.';

  Future<void> _gps() async {
    if (_busy) return;
    _timer?.cancel();
    ++_revision;
    setState(() {
      _busy = true;
      _searching = false;
      _error = null;
      _settings = false;
      _selected = null;
      _results = null;
    });
    try {
      final area = await widget.location.current();
      if (mounted) setState(() => _selected = area);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _message(error);
          _settings = error is LocationFailure && error.settings;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy || _selected == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await widget.api
          .put('/api/v1/me/profile/location', body: _selected!.toJson());
      if (response is! Map ||
          response['profile'] is! Map ||
          response['profile']['location'] is! Map ||
          response['profile']['location']['latitude'] != _selected!.latitude ||
          response['profile']['location']['longitude'] !=
              _selected!.longitude) {
        throw const LocationFailure(
            'Could not confirm your saved location. Please retry.');
      }
      if (mounted) widget.onComplete(_selected!);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openSettings() async {
    try {
      if (!await widget.location.openSettings() && mounted) {
        setState(
            () => _error = 'Open Settings manually to change location access.');
      }
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Could not open Settings. You can search manually.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && !_busy) widget.onCancel?.call();
        },
        child: SetupFrame(
          step: 3,
          title: widget.onCancel == null
              ? 'Find your\nplaying field.'
              : 'Change your area',
          subtitle:
              'Choose where you play. Use your location or search for an area — access is optional.',
          action: _busy ? 'Please wait…' : 'Confirm area',
          onContinue: _selected == null ? null : _save,
          onBack: widget.onCancel,
          busy: _busy,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Material(
                color: appSurface,
                borderRadius: BorderRadius.circular(22),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                    onTap: _busy ? null : _gps,
                    child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(children: [
                          Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                  color: appAccent.withValues(alpha: .12),
                                  borderRadius: BorderRadius.circular(15)),
                              child: const Icon(CupertinoIcons.location_fill,
                                  color: appAccent, size: 23)),
                          const SizedBox(width: 16),
                          const Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text('Use my location',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
                                SizedBox(height: 5),
                                Text('Find the area around you',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white54,
                                        height: 1.3)),
                              ])),
                          const SizedBox(width: 8),
                          const Icon(CupertinoIcons.chevron_right,
                              color: Colors.white38, size: 17),
                        ])))),
            const SizedBox(height: 28),
            const Text('OR CHOOSE AN AREA',
                style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w600,
                    color: Colors.white54)),
            const SizedBox(height: 14),
            TextField(
                controller: _query,
                enabled: !_busy,
                onChanged: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: _busy ? null : _search,
                style: const TextStyle(fontSize: 17, letterSpacing: 0),
                decoration: setupInput('Search city or area',
                    prefix: const Icon(CupertinoIcons.search,
                        size: 22, color: Colors.white54))),
            if (_searching || _busy)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: LinearProgressIndicator(
                      color: appAccent,
                      minHeight: 2,
                      backgroundColor: appSurface)),
            if (_results != null && _results!.isEmpty)
              const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Text(
                      'No areas found. Try a nearby city or a different spelling.',
                      style: TextStyle(color: Colors.white70, height: 1.5))),
            if (_results != null) ...[
              const SizedBox(height: 12),
              for (final area in _results!)
                Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 8),
                      leading: const Icon(CupertinoIcons.map_pin_ellipse,
                          color: Colors.white54),
                      title: Text(area.label,
                          style: const TextStyle(fontSize: 16)),
                      selected: identical(area, _selected),
                      selectedColor: appAccent,
                      trailing: Icon(
                          identical(area, _selected)
                              ? CupertinoIcons.checkmark_circle_fill
                              : CupertinoIcons.chevron_right,
                          size: 20,
                          color: identical(area, _selected)
                              ? appAccent
                              : Colors.white38),
                      onTap: _busy
                          ? null
                          : () {
                              FocusScope.of(context).unfocus();
                              setState(() => _selected = area);
                            },
                    )),
              const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Geoapify · © OpenStreetMap contributors',
                      style: TextStyle(fontSize: 11, color: Colors.white54))),
            ],
            if (_selected != null) ...[
              const SizedBox(height: 24),
              Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: const Color(0xFF171C10),
                      borderRadius: BorderRadius.circular(22),
                      border:
                          Border.all(color: appAccent.withValues(alpha: .3))),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(children: [
                          Icon(CupertinoIcons.checkmark_circle_fill,
                              color: appAccent, size: 18),
                          SizedBox(width: 8),
                          Flexible(
                              child: Text('YOUR PLAYING AREA',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: appAccent,
                                      letterSpacing: 1.2,
                                      fontWeight: FontWeight.w600)))
                        ]),
                        const SizedBox(height: 12),
                        Text(_selected!.label,
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                height: 1.3)),
                        const SizedBox(height: 6),
                        const Text('Ready to explore around here.',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 14)),
                      ])),
            ],
            if (_error != null) ...[
              const SizedBox(height: 20),
              Semantics(
                  liveRegion: true,
                  child: Text(_error!,
                      style: const TextStyle(color: appError, height: 1.5))),
              if (!_busy && _query.text.trim().length >= 3)
                Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                        onPressed: () => _search(_query.text),
                        child: const Text('Retry search'))),
            ],
            if (_settings)
              Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                      onPressed: _busy ? null : _openSettings,
                      child: const Text('Open Settings'))),
          ]),
        ),
      );
}
