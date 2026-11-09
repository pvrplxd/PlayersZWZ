import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'dart:ui' show ImageFilter;

import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_theme.dart';
import '../../core/native/native_ui.dart';
import '../../core/ui/pz_controls.dart';
import 'game_model.dart';

class GameNavigationScreen extends StatefulWidget {
  const GameNavigationScreen({
    super.key,
    required this.game,
    required this.apiKey,
  });

  final Game game;
  final String apiKey;

  @override
  State<GameNavigationScreen> createState() => _GameNavigationScreenState();
}

class _GameNavigationScreenState extends State<GameNavigationScreen> with TickerProviderStateMixin {
  final _map = MapController();
  late final AnimationController _locationMotion;
  StreamSubscription<Position>? _positionSubscription;
  LatLng? _current;
  LatLng? _motionStart;
  List<LatLng> _route = [];
  List<_RouteStep> _steps = [];
  String? _nextInstruction;
  DateTime? _lastRouteUpdate;
  double? _distanceMeters, _durationSeconds;
  double _headingRadians = 0;
  String? _error;
  bool _loading = true, _navigating = false, _following = true;
  bool _settingsRequired = false;
  String _mode = 'drive';

  /// 0 = route card open, 1 = minimised to a pill.
  late final AnimationController _sheet = AnimationController.unbounded(vsync: this);
  final _cardKey = GlobalKey();
  double get _cardHeight =>
      (_cardKey.currentContext?.findRenderObject() as RenderBox?)?.size.height ?? 340;

  void _settleSheet(double target, [double velocity = 0]) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _sheet.value = target;
      return;
    }
    _sheet.animateWith(SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 380, damping: 32),
        _sheet.value, target, velocity));
  }

  void _dragSheet(DragUpdateDetails d) {
    final next = _sheet.value + d.delta.dy / _cardHeight;
    // Rubber-band when pulling the open card further up.
    _sheet.value = next < 0 ? next * .35 : next.clamp(-0.1, 1.0);
  }

  void _endSheetDrag(DragEndDetails d) {
    final v = (d.primaryVelocity ?? 0) / _cardHeight;
    final collapse = v > 1.2 || (v > -1.2 && _sheet.value > .35);
    if (collapse != (_sheet.value > .5)) HapticFeedback.lightImpact();
    _settleSheet(collapse ? 1 : 0, v);
  }

  void _toggleSheet() {
    HapticFeedback.lightImpact();
    _settleSheet(_sheet.value > .5 ? 0 : 1);
  }

  Future<void> _share() async {
    final l = MaterialLocalizations.of(context);
    final when = l.formatTimeOfDay(TimeOfDay.fromDateTime(widget.game.startTime));
    final (place, _) = pzSplitPlace(widget.game.locationLabel);
    await pzShare(context,
        text: '${widget.game.sport} at $place · $when',
        url: 'https://www.google.com/maps/search/?api=1&query='
            '${widget.game.latitude},${widget.game.longitude}');
  }
  int _routeRevision = 0;
  LatLng? _lastRouteOrigin;

  LatLng get _destination => LatLng(widget.game.latitude, widget.game.longitude);
  LatLng get _animatedPosition {
    final target = _current;
    final start = _motionStart;
    if (target == null || start == null) return target ?? _destination;
    final t = Curves.easeOutCubic.transform(_locationMotion.value);
    return LatLng(
      start.latitude + (target.latitude - start.latitude) * t,
      start.longitude + (target.longitude - start.longitude) * t,
    );
  }

  @override
  void initState() {
    super.initState();
    _locationMotion = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _locationMotion.addListener(() {
      if (_navigating && _following && _current != null && _motionStart != null) {
        _map.move(_animatedPosition, _map.camera.zoom);
      }
    });
    _begin();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _locationMotion.dispose();
    _sheet.dispose();
    _map.dispose();
    super.dispose();
  }

  Future<void> _begin() async {
    try {
      if (widget.apiKey.isEmpty) throw StateError('Routing is not configured.');
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Turn on Location Services to get directions.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _settingsRequired = true);
        throw StateError('Allow location access in Settings to navigate.');
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        throw StateError('Allow location access while using PlayersZWZ.');
      }
      if (mounted && _settingsRequired) setState(() => _settingsRequired = false);
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      final origin = LatLng(position.latitude, position.longitude);
      setState(() {
        _motionStart = _current ?? origin;
        _current = origin;
      });
      await _loadRoute(origin);
      if (!mounted) return;
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is StateError ? error.message.toString() : 'Could not get your live location. Please retry.';
      });
    }
  }

  void _startNavigation() {
    if (_current == null) return;
    setState(() {
      _navigating = true;
      _following = true;
    });
    _map.move(_current!, 16);
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: Platform.isIOS
            ? AppleSettings(
                accuracy: LocationAccuracy.bestForNavigation,
                activityType: ActivityType.otherNavigation,
                distanceFilter: 5,
                pauseLocationUpdatesAutomatically: false,
              )
            : AndroidSettings(
                accuracy: LocationAccuracy.bestForNavigation,
                distanceFilter: 5,
                intervalDuration: const Duration(seconds: 2),
              ),
      ).listen(_onPosition, onError: (_) {
        if (mounted) setState(() => _error = 'Live location paused. Check location permissions.');
      });
  }

  void _endNavigation() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    setState(() {
      _navigating = false;
      _following = false;
    });
  }

  void _onPosition(Position position) {
    final point = LatLng(position.latitude, position.longitude);
    if (!mounted) return;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final visiblePosition = reduceMotion ? point : _animatedPosition;
    setState(() {
      _motionStart = _current == null ? point : visiblePosition;
      _current = point;
      if (position.speed >= 1 && position.heading.isFinite) {
        _headingRadians = position.heading * math.pi / 180;
      }
    });
    if (reduceMotion) {
      _locationMotion.value = 1;
    } else {
      _locationMotion.forward(from: 0);
    }
    _updateInstruction(point);
    final previous = _lastRouteOrigin;
    final lastUpdate = _lastRouteUpdate;
    if (previous == null ||
        (const Distance().as(LengthUnit.Meter, previous, point) >= 250 &&
            (lastUpdate == null || DateTime.now().difference(lastUpdate) >= const Duration(seconds: 45)))) {
      unawaited(_loadRoute(point));
    }
  }

  Future<void> _loadRoute(LatLng origin) async {
    final revision = ++_routeRevision;
    _lastRouteOrigin = origin;
    try {
      final uri = Uri.https('api.geoapify.com', '/v1/routing', {
        'waypoints': '${origin.latitude},${origin.longitude}|${_destination.latitude},${_destination.longitude}',
        'mode': _mode,
        'type': 'balanced',
        'format': 'geojson',
        'units': 'metric',
        if (_mode == 'drive') 'traffic': 'approximated',
        'details': 'instruction_details',
        'apiKey': widget.apiKey,
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) throw const FormatException('Route unavailable.');
      final body = jsonDecode(response.body);
      if (body is! Map || body['features'] is! List || (body['features'] as List).isEmpty) {
        throw const FormatException('Route unavailable.');
      }
      final feature = (body['features'] as List).first;
      if (feature is! Map || feature['geometry'] is! Map || feature['properties'] is! Map) {
        throw const FormatException('Route unavailable.');
      }
      final geometry = (feature['geometry'] as Map)['coordinates'];
      final properties = feature['properties'] as Map;
      if (geometry is! List || properties['distance'] is! num || properties['time'] is! num) {
        throw const FormatException('Route details are incomplete.');
      }
      final points = <LatLng>[];
      // GeoJSON routes use MultiLineString coordinates: one line per route leg.
      // Flatten leg lines for drawing while preserving the first leg's step indexes.
      final lines = geometry.isNotEmpty && geometry.first is List &&
              (geometry.first as List).isNotEmpty && (geometry.first as List).first is List
          ? geometry
          : [geometry];
      for (final line in lines) {
        if (line is! List) continue;
        for (final item in line) {
          if (item is List && item.length >= 2 && item[0] is num && item[1] is num) {
            points.add(LatLng((item[1] as num).toDouble(), (item[0] as num).toDouble()));
          }
        }
      }
      if (points.length < 2) throw const FormatException('Route geometry is incomplete.');
      if (!mounted || revision != _routeRevision) return;
      final parsedSteps = <_RouteStep>[];
      final legs = properties['legs'];
      if (legs is List && legs.isNotEmpty && legs.first is Map) {
        final rawSteps = (legs.first as Map)['steps'];
        if (rawSteps is List) {
          for (final raw in rawSteps) {
            if (raw is! Map || raw['from_index'] is! num || raw['to_index'] is! num) continue;
            final instruction = raw['instruction'];
            final text = instruction is Map ? instruction['text'] : null;
            if (text is String && text.trim().isNotEmpty) {
              parsedSteps.add(_RouteStep(
                (raw['from_index'] as num).toInt(),
                (raw['to_index'] as num).toInt(),
                text.trim(),
              ));
            }
          }
        }
      }
      setState(() {
        _route = points;
        _steps = parsedSteps;
        _lastRouteUpdate = DateTime.now();
        _distanceMeters = (properties['distance'] as num).toDouble();
        _durationSeconds = (properties['time'] as num).toDouble();
        _error = null;
      });
      _updateInstruction(origin);
      _fitRoute(points);
    } catch (_) {
      if (mounted && revision == _routeRevision) {
        setState(() => _error = _route.isEmpty
            ? 'Could not calculate a route. Check your connection and try again.'
            : 'Route refresh failed. Showing the last route.');
      }
    } finally {
      if (mounted && _loading) setState(() => _loading = false);
    }
  }

  void _updateInstruction(LatLng position) {
    if (_route.isEmpty || _steps.isEmpty) return;
    var closestIndex = 0;
    var closestDistance = double.infinity;
    for (var index = 0; index < _route.length; index++) {
      final distance = const Distance().as(LengthUnit.Meter, position, _route[index]);
      if (distance < closestDistance) {
        closestDistance = distance;
        closestIndex = index;
      }
    }
    _RouteStep? step;
    for (final candidate in _steps) {
      if (candidate.toIndex >= closestIndex) {
        step = candidate;
        break;
      }
    }
    if (step != null && step.instruction != _nextInstruction && mounted) {
      final instruction = step.instruction;
      setState(() => _nextInstruction = instruction);
    }
  }

  void _fitRoute(List<LatLng> points) {
    if (points.isEmpty) return;
    final bounds = LatLngBounds.fromPoints(points);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _map.fitCamera(CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(44, 120, 44, 245),
        maxZoom: 16,
      ));
    });
  }

  String _distanceLabel(double? value) {
    if (value == null) return '—';
    return value >= 1000 ? '${(value / 1000).toStringAsFixed(1)} km' : '${value.round()} m';
  }

  String _durationLabel(double? seconds) {
    if (seconds == null) return '—';
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    return remaining == 0 ? '${hours}h' : '${hours}h ${remaining}m';
  }

  Future<void> _retry() async {
    final current = _current;
    if (current == null) {
      setState(() { _error = null; _loading = true; });
      await _begin();
      return;
    }
    setState(() { _error = null; _loading = true; });
    await _loadRoute(current);
  }

  Future<void> _openSettings() async {
    await Geolocator.openAppSettings();
  }

  /// Hands the route to Google Maps (app if installed, otherwise the web).
  Future<void> _openGoogleMaps() async {
    unawaited(HapticFeedback.lightImpact());
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${_destination.latitude},${_destination.longitude}',
      'travelmode': _mode == 'motorcycle' ? 'two-wheeler' : 'driving',
    });
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps.')));
    }
  }

  void _setMode(String mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    final origin = _current;
    if (origin != null) unawaited(_loadRoute(origin));
  }

  @override
  Widget build(BuildContext context) {
    final current = _current ?? _destination;
    final padding = MediaQuery.paddingOf(context);
    final arrival = _durationSeconds == null
        ? '—'
        : MaterialLocalizations.of(context).formatTimeOfDay(
            TimeOfDay.fromDateTime(DateTime.now()
                .add(Duration(seconds: _durationSeconds!.round()))));
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: Stack(children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
              initialCenter: current,
              initialZoom: 14,
              onPositionChanged: (_, gesture) {
                if (gesture && _following) setState(() => _following = false);
              }),
          children: [
            TileLayer(
              urlTemplate:
                  'https://maps.geoapify.com/v1/tile/dark-matter/{z}/{x}/{y}.png?apiKey=${Uri.encodeQueryComponent(widget.apiKey)}',
              userAgentPackageName: 'com.playerszwz.app',
              maxNativeZoom: 20,
            ),
            if (_route.isNotEmpty)
              PolylineLayer(polylines: [
                Polyline(points: _route, strokeWidth: 10, color: Colors.black54),
                Polyline(points: _route, strokeWidth: 6, color: AppTheme.lime),
              ]),
            AnimatedBuilder(
              animation: _locationMotion,
              builder: (context, _) => MarkerLayer(markers: [
                Marker(
                  point: _destination,
                  width: 48,
                  height: 48,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.lime,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 3),
                    ),
                    child: const Icon(PhosphorIconsFill.flagCheckered,
                        color: Colors.black, size: 20),
                  ),
                ),
                if (_current != null)
                  Marker(
                    point: _animatedPosition,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Colors.black54, blurRadius: 10)
                        ],
                      ),
                      child: Transform.rotate(
                        angle: _headingRadians,
                        child: const Icon(PhosphorIconsFill.navigationArrow,
                            color: Colors.black, size: 17),
                      ),
                    ),
                  ),
              ]),
            ),
          ],
        ),
        // Top scrim keeps the floating controls legible over bright tiles.
        IgnorePointer(
          child: Container(
            height: padding.top + 90,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xCC000000), Color(0x00000000)],
              ),
            ),
          ),
        ),
        Positioned(
          top: padding.top + 8,
          left: 16,
          right: 16,
          child: Column(children: [
            Row(children: [
              NativeGlassButton(
                icon: PhosphorIconsBold.caretLeft,
                label: 'Back',
                iconSize: 18,
                onTap: () => Navigator.of(context).pop(),
              ),
              const Spacer(),
            ]),
            if (_navigating && _nextInstruction != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  decoration: BoxDecoration(
                    color: AppTheme.lime,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Row(children: [
                    const Icon(PhosphorIconsBold.arrowBendUpRight,
                        color: Colors.black, size: 30),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(_nextInstruction!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.black,
                              fontSize: 17,
                              height: 1.2,
                              fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),
              ),
            ],
          ]),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: padding.bottom + 12,
          child: AnimatedBuilder(
            animation: _sheet,
            builder: (context, _) {
              final t = _sheet.value.clamp(0.0, 1.0);
              final drop = _sheet.value * (_cardHeight + 24);
              return Stack(clipBehavior: Clip.none, alignment: Alignment.bottomCenter, children: [
                // Minimised pill.
                IgnorePointer(
                  ignoring: t < .5,
                  child: Opacity(
                    opacity: Curves.easeIn.transform(((t - .45) / .55).clamp(0.0, 1.0)),
                    child: Transform.scale(
                      scale: .9 + .1 * t,
                      child: _RoutePill(
                        title: pzSplitPlace(widget.game.locationLabel).$1,
                        detail: _loading
                            ? 'Finding route…'
                            : '${_durationLabel(_durationSeconds)} · ${_distanceLabel(_distanceMeters)}',
                        onTap: _toggleSheet,
                        onDrag: _dragSheet,
                        onDragEnd: _endSheetDrag,
                      ),
                    ),
                  ),
                ),
                // Route card, draggable down to minimise.
                IgnorePointer(
                  ignoring: t > .5,
                  child: Transform.translate(
                    offset: Offset(0, drop < 0 ? drop : drop),
                    child: Opacity(
                      opacity: 1 - Curves.easeIn.transform((t / .8).clamp(0.0, 1.0)),
                      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                        if (_current != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 4, bottom: 10),
                            child: NativeGlassButton(
                              icon: PhosphorIconsFill.navigationArrow,
                              label: _following ? 'Following you' : 'Center on me',
                              onTap: () {
                                setState(() => _following = true);
                                _map.move(current, 16);
                              },
                            ),
                          ),
                        GestureDetector(
                          onVerticalDragUpdate: _dragSheet,
                          onVerticalDragEnd: _endSheetDrag,
                          child: KeyedSubtree(
                            key: _cardKey,
                            child: _RouteCard(
            destination: widget.game.locationLabel,
            sport: widget.game.sport,
            startTime: widget.game.startTime,
            distance: _distanceLabel(_distanceMeters),
            duration: _durationLabel(_durationSeconds),
            arrival: arrival,
            mode: _mode,
            onModeChanged: _setMode,
            loading: _loading,
            navigating: _navigating,
            error: _error,
            onRetry: _retry,
            onSettings: _settingsRequired ? _openSettings : null,
            onStart: _startNavigation,
            onEnd: _endNavigation,
            onGoogleMaps: _openGoogleMaps,
            onShare: _share,
          ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.destination,
    required this.sport,
    required this.startTime,
    required this.distance,
    required this.duration,
    required this.arrival,
    required this.mode,
    required this.onModeChanged,
    required this.loading,
    required this.navigating,
    required this.error,
    required this.onRetry,
    required this.onSettings,
    required this.onStart,
    required this.onEnd,
    required this.onGoogleMaps,
    required this.onShare,
  });

  final VoidCallback onGoogleMaps, onShare;
  final String destination, sport, distance, duration, arrival, mode;
  final DateTime startTime;
  final bool loading, navigating;
  final String? error;
  final VoidCallback onRetry, onStart, onEnd;
  final VoidCallback? onSettings;
  final ValueChanged<String> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final (place, _) = pzSplitPlace(destination);
    final ready = !loading && distance != '—';
    final card = Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
      decoration: BoxDecoration(
        color: const Color(0xD9131315),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0x1AFFFFFF), width: .5),
      ),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: Padding(padding: EdgeInsets.only(bottom: 12), child: PzGrabber())),
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                    color: AppTheme.lime, shape: BoxShape.circle),
                child: const Icon(PhosphorIconsFill.flagCheckered,
                    color: Colors.black, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(place,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.title3),
                      const SizedBox(height: 2),
                      Text('$sport · ${pzWhen(context, startTime)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.muted)),
                    ]),
              ),
              const SizedBox(width: 8),
              _SmallRound(
                label: 'Share',
                onTap: onShare,
                child: const Icon(PhosphorIconsBold.export, size: 17, color: AppTheme.primaryText),
              ),
              const SizedBox(width: 8),
              _SmallRound(
                label: 'Open in Google Maps',
                onTap: onGoogleMaps,
                child: SvgPicture.asset('assets/brands/google_maps.svg', height: 18),
              ),
            ]),
            if (!navigating) ...[
              const SizedBox(height: 16),
              PzSegmented(
                options: const ['Drive', 'Bike'],
                icons: const [
                  PhosphorIconsBold.car,
                  PhosphorIconsBold.motorcycle
                ],
                height: 44,
                track: const Color(0x14FFFFFF),
                selectedIndex: mode == 'motorcycle' ? 1 : 0,
                onChanged: (i) => onModeChanged(i == 1 ? 'motorcycle' : 'drive'),
              ),
            ],
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                  child: PzStat(
                      value: loading ? '…' : distance, label: 'Distance')),
              Expanded(
                  child: PzStat(
                      value: loading ? '…' : duration, label: 'Time')),
              Expanded(
                  child: PzStat(
                      value: loading ? '…' : arrival, label: 'Arrive at')),
            ]),
            if (error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                decoration: BoxDecoration(
                  color: AppTheme.destructive.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(children: [
                  const Icon(PhosphorIconsFill.warningCircle,
                      size: 17, color: AppTheme.destructive),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(error!,
                          style: const TextStyle(
                              fontSize: 13, height: 1.35))),
                  if (onSettings != null)
                    TextButton(
                        onPressed: onSettings,
                        style: TextButton.styleFrom(
                            foregroundColor: AppTheme.lime),
                        child: const Text('Settings'))
                  else
                    TextButton(
                        onPressed: onRetry,
                        style: TextButton.styleFrom(
                            foregroundColor: AppTheme.lime),
                        child: const Text('Retry')),
                ]),
              ),
            ],
            const SizedBox(height: 16),
            navigating
                ? FilledButton.icon(
                    onPressed: onEnd,
                    icon: const Icon(PhosphorIconsFill.stop, size: 16),
                    label: const Text('End navigation'),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          AppTheme.destructive.withValues(alpha: .16),
                      foregroundColor: AppTheme.destructive,
                      minimumSize: const Size.fromHeight(56),
                      shape: const StadiumBorder(),
                    ),
                  )
                : Row(children: [
                  Expanded(child: FilledButton.icon(
                    onPressed: ready ? onStart : null,
                    icon: loading
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppTheme.muted))
                        : const Icon(PhosphorIconsBold.navigationArrow,
                            size: 17),
                    label: Text(loading ? 'Finding route…' : 'Start'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.lime,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: AppTheme.surfaceRaised,
                      disabledForegroundColor: AppTheme.muted,
                      minimumSize: const Size.fromHeight(56),
                      shape: const StadiumBorder(),
                    ),
                  )),
                ]),
            const SizedBox(height: 10),
            const Text(
                'Times are estimates · © OpenStreetMap contributors · Geoapify',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppTheme.muted, fontSize: 11)),
          ]),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, 10))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), child: card),
      ),
    );
  }
}

class _RouteStep {
  const _RouteStep(this.fromIndex, this.toIndex, this.instruction);
  final int fromIndex, toIndex;
  final String instruction;
}

class _SmallRound extends StatelessWidget {
  const _SmallRound({required this.label, required this.onTap, required this.child});
  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: PzPressable(
          onTap: onTap,
          scale: .9,
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0x1FFFFFFF),
              shape: BoxShape.circle,
            ),
            child: child,
          ),
        ),
      );
}

/// Minimised route: a frosted pill near the bottom; tap or drag up to open.
class _RoutePill extends StatelessWidget {
  const _RoutePill({
    required this.title,
    required this.detail,
    required this.onTap,
    required this.onDrag,
    required this.onDragEnd,
  });

  final String title, detail;
  final VoidCallback onTap;
  final GestureDragUpdateCallback onDrag;
  final GestureDragEndCallback onDragEnd;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Route to $title, $detail. Show route',
        excludeSemantics: true,
        child: GestureDetector(
          onVerticalDragUpdate: onDrag,
          onVerticalDragEnd: onDragEnd,
          child: PzPressable(
            onTap: onTap,
            scale: .96,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  height: 60,
                  padding: const EdgeInsets.fromLTRB(8, 8, 18, 8),
                  decoration: BoxDecoration(
                    color: const Color(0xD9131315),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: const Color(0x1AFFFFFF), width: .5),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                          color: AppTheme.lime, shape: BoxShape.circle),
                      child: const Icon(PhosphorIconsFill.flagCheckered,
                          size: 18, color: Colors.black),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.headline),
                          Text(detail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.footnote),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(PhosphorIconsBold.caretUp, size: 15, color: AppTheme.muted),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}
