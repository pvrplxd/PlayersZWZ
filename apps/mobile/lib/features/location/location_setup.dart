import 'package:flutter/cupertino.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/material.dart';

import '../../app/playerszwz_app.dart';
import '../../core/api_client.dart';
import '../../core/widgets/setup_frame.dart';
import 'location_service.dart';

class LocationSetup extends StatefulWidget {
  const LocationSetup({
    super.key,
    required this.api,
    required this.location,
    required this.onComplete,
    required this.signOut,
    this.onCancel,
  });

  final ApiClient api;
  final LocationService location;
  final ValueChanged<Area> onComplete;
  final Future<void> Function() signOut;
  final VoidCallback? onCancel;

  @override
  State<LocationSetup> createState() => _LocationSetupState();
}

class _LocationSetupState extends State<LocationSetup> {
  Area? _selected;
  bool _busy = false, _settings = false;
  String? _error;

  Future<void> _locate() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _settings = false;
    });
    try {
      final area = await widget.location.current();
      if (mounted) setState(() => _selected = area);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is LocationFailure
              ? error.message
              : 'Could not find your location. Check Location Services and retry.';
          _settings = error is LocationFailure && error.settings;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continue() async {
    if (_busy) return;
    if (_selected == null) {
      await _locate();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await widget.api.put(
          '/api/v1/me/profile/location',
          body: _selected!.toJson());
      if (response is! Map ||
          response['profile'] is! Map ||
          response['profile']['location'] is! Map) {
        throw const ApiException(0, 'INVALID_RESPONSE',
            'Could not confirm your location. Please retry.');
      }
      if (mounted) widget.onComplete(_selected!);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save your location. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openSettings() async {
    await widget.location.openSettings();
  }

  @override
  Widget build(BuildContext context) => SetupFrame(
        step: 3,
        title: 'Find your\nplaying field.',
        subtitle:
            'Use your current location to find games nearby. We refresh it when you open the app and only use it while you’re using PlayersZWZ.',
        action: _busy
            ? 'Please wait…'
            : _selected == null
                ? 'Use my location'
                : 'Continue',
        onContinue: _busy ? null : _continue,
        onBack: widget.onCancel,
        busy: _busy,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: appSurface,
              borderRadius: BorderRadius.circular(24),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: appAccent.withValues(alpha: .12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(PhosphorIconsRegular.mapPin,
                          color: appAccent, size: 23),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Use my location',
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 5),
                          Text(
                            _selected?.label ?? 'Find your current area',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white60,
                                height: 1.35),
                          ),
                        ],
                      ),
                    ),
                    if (_busy)
                      const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: appAccent))
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 18),
              Semantics(
                liveRegion: true,
                child: Text(_error!,
                    style: const TextStyle(color: appError, height: 1.45)),
              ),
              if (_settings)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _busy ? null : _openSettings,
                    child: const Text('Open Settings'),
                  ),
                ),
            ],
            const SizedBox(height: 22),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(PhosphorIconsRegular.shieldCheck, size: 16, color: Colors.white54),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your location is used to find nearby games. It is not shared as a live map with other players.',
                    style: TextStyle(
                        color: Colors.white54, fontSize: 13, height: 1.45),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}
