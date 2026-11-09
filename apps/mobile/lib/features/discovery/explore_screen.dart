// explore_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../../core/widgets/platform_navigation.dart';
import '../profile/profile_photo.dart';
import 'map_motion.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../app/playerszwz_app.dart';
import '../../app/app_theme.dart';
import '../../core/api_client.dart';
import '../location/location_service.dart';
import '../profile/profile_preferences.dart';
import '../../core/native/native_ui.dart';
import '../../core/ui/pz_controls.dart';
import '../profile/profile_screen.dart';
import 'discovery_widgets.dart';
import '../games/activity_screen.dart';
import '../games/game_model.dart';
import '../games/game_screens.dart';
import '../games/game_service.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    super.key,
    required this.area,
    required this.apiKey,
    this.changeArea,
    this.refreshLocation,
    required this.signOut,
    this.api,
    this.tileProvider,
    this.photo,
    this.name = 'Player',
    this.userId = '',
    this.username = '',
  });

  final ProfilePhotoController? photo;
  final String name;
  final String userId;
  final String username;
  final Area area;
  final String apiKey;
  final VoidCallback? changeArea;
  final Future<Area?> Function()? refreshLocation;
  final Future<void> Function() signOut;
  final ApiClient? api;
  final TileProvider? tileProvider;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with TickerProviderStateMixin {
  final _map = MapController();
  late final MapRecenterMotion _cameraMotion;
  Timer? _timeout;
  bool _loading = true, _failed = false, _signingOut = false;
  bool _gamesLoading = true, _loadingMore = false, _refreshingLocation = false;
  bool _locationStale = false;
  bool _offline = false, _radiusActive = false;
  Timer? _offlineRetry;
  bool _freeOnly = false, _spotsOnly = false;
  String? _gamesError, _nextGameCursor, _selectedSport, _selectedTimeWindow;
  double? _selectedRadius;
  double? _draftRadius;
  double _profileRadius = 10;
  List<Game> _games = [];
  int _gamesRevision = 0;
  int _attempt = 0;
  int _activityRevision = 0;
  Map<String, dynamic>? _profileSummary;

  LatLng get _center => LatLng(_area.latitude, _area.longitude);

  String get _locationMode =>
      (_profileSummary?['location_mode'] as String?) ?? 'live';

  Area? get _homeArea {
    final home = _profileSummary?['home_location'];
    if (home is! Map || home['latitude'] is! num || home['longitude'] is! num) {
      return null;
    }
    return Area((home['latitude'] as num).toDouble(),
        (home['longitude'] as num).toDouble(),
        (_profileSummary?['home_label'] as String?) ?? 'Home', 'manual');
  }

  bool get _usingHome => _locationMode == 'home' && _homeArea != null;

  /// Where games are searched from: live device location or saved home.
  Area get _area => _usingHome ? _homeArea! : widget.area;

  static String _shortLabel(String label) {
    if (label.contains(' · ')) return label;
    final parts = label.split(', ');
    return parts.take(2).join(', ');
  }

  void _afterAreaChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.apiKey.isNotEmpty) {
        _cameraMotion.recenter(_center,
            reducedMotion: MediaQuery.disableAnimationsOf(context),
            targetZoom: _zoomForRadius(_radiusValue));
      }
      _loadGames();
    });
  }

  void _toast(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _setLocationMode(String mode) async {
    final api = widget.api;
    final profile = _profileSummary;
    if (api == null || profile == null || mode == _locationMode) return;
    if (mode == 'home' && _homeArea == null) {
      await _setHomeLocation();
      if (_homeArea == null) return;
    }
    final previous = _locationMode;
    setState(() => _profileSummary = {...profile, 'location_mode': mode});
    _afterAreaChange();
    try {
      final response = await api.patch('/api/v1/me/profile', body: {
        'sports': profile['sports'] ?? const [],
        'availability': profile['availability'] ?? const [],
        'radius_km': (profile['radius_km'] as num?)?.round() ?? 10,
        'bio': profile['bio'] ?? '',
        'location_mode': mode,
      });
      if (mounted && response is Map && response['profile'] is Map) {
        setState(() => _profileSummary =
            Map<String, dynamic>.from(response['profile'] as Map));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() =>
          _profileSummary = {...?_profileSummary, 'location_mode': previous});
      _afterAreaChange();
      _toast('Could not switch location. Please retry.');
    }
  }

  Future<void> _setHomeLocation() async {
    final api = widget.api;
    if (api == null) return;
    final location = LocationService(apiKey: widget.apiKey);
    try {
      final area = await Navigator.of(context).push<Area>(MaterialPageRoute(
        builder: (_) => VenueMapPickerScreen(
            area: _homeArea ?? widget.area,
            apiKey: widget.apiKey,
            location: location),
      ));
      if (area == null || !mounted) return;
      final response = await api.put('/api/v1/me/profile/home-location', body: {
        'latitude': area.latitude,
        'longitude': area.longitude,
        'label': area.label,
      });
      if (mounted && response is Map && response['profile'] is Map) {
        setState(() => _profileSummary =
            Map<String, dynamic>.from(response['profile'] as Map));
        if (_usingHome) _afterAreaChange();
      }
    } catch (_) {
      if (mounted) _toast('Could not save your home location. Please retry.');
    } finally {
      location.close();
    }
  }

  final _locationKey = GlobalKey();

  Future<void> _chooseLocation() async {
    final home = _homeArea;
    final anchor = _locationKey.currentContext;
    final choice = await pzMenu(
      context,
      anchor: anchor == null ? Rect.zero : pzRectOf(anchor),
      title: 'Find games near',
      selected: _usingHome ? 1 : 0,
      actions: [
        PzAction('Live location',
            subtitle: _shortLabel(widget.area.label),
            icon: PhosphorIconsFill.navigationArrow),
        PzAction(home == null ? 'Set a default location' : 'Default location',
            subtitle: home == null
                ? 'Plan games near a saved place'
                : _shortLabel(home.label),
            icon: PhosphorIconsFill.house),
      ],
    );
    if (!mounted || choice == null) return;
    if (choice == 0) {
      if (_usingHome) {
        await _setLocationMode('live');
      } else {
        await _refreshLocation();
      }
    } else {
      await _setLocationMode('home');
    }
  }

  @override
  void initState() {
    super.initState();
    _cameraMotion = MapRecenterMotion(map: _map, vsync: this);
    _startTimeout();
    _loadGames();
    _loadProfileSummary();
  }

  @override
  void didUpdateWidget(covariant ExploreScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.area.latitude != widget.area.latitude ||
        oldWidget.area.longitude != widget.area.longitude) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _cameraMotion.recenter(_center,
            reducedMotion: MediaQuery.disableAnimationsOf(context),
            targetZoom: _zoomForRadius(_radiusValue));
        _loadGames();
      });
    }
  }

  Future<void> _loadProfileSummary() async {
    final api = widget.api;
    if (api == null) return;
    try {
      final response = await api.get('/api/v1/me/profile');
      if (!mounted || response is! Map || response['profile'] is! Map) return;
      setState(() => _profileSummary =
          Map<String, dynamic>.from(response['profile'] as Map));
    } catch (_) {}
  }

  Future<void> _editPreferences() async {
    final api = widget.api;
    if (api == null) return;
    unawaited(HapticFeedback.selectionClick());
    final route = Theme.of(context).platform == TargetPlatform.iOS
        ? CupertinoPageRoute<bool>(
            builder: (_) => ProfilePreferencesScreen(api: api))
        : MaterialPageRoute<bool>(
            builder: (_) => ProfilePreferencesScreen(api: api));
    final saved = await Navigator.of(context).push<bool>(route);
    if (saved == true) _loadProfileSummary();
  }

  Future<void> _refreshLocation() async {
    if (_refreshingLocation) return;
    setState(() => _refreshingLocation = true);
    try {
      final area = await widget.refreshLocation?.call();
      if (mounted) setState(() => _locationStale = area == null);
      if (area == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Could not refresh your location. Showing the last one.'),
        ));
      }
      await _loadGames();
    } finally {
      if (mounted) setState(() => _refreshingLocation = false);
    }
  }

  Future<void> _loadGames({bool append = false}) async {
    final api = widget.api;
    if (api == null) return;
    if (append && (_loadingMore || _nextGameCursor == null)) return;
    final revision = append ? _gamesRevision : ++_gamesRevision;
    setState(() {
      if (append) {
        _loadingMore = true;
      } else {
        _gamesLoading = true;
        _gamesError = null;
      }
    });
    try {
      final page = await GameService(api).nearby(
        _area,
        sport: _selectedSport,
        timeWindow: _selectedTimeWindow,
        radiusKm: _selectedRadius,
        cursor: append ? _nextGameCursor : null,
      );
      if (!mounted || revision != _gamesRevision) return;
      setState(() {
        _games = append ? [..._games, ...page.games] : page.games;
        _profileRadius = page.radiusKm;
        _nextGameCursor = page.nextCursor;
        _gamesLoading = false;
        _loadingMore = false;
        _offline = false;
      });
      _offlineRetry?.cancel();
    } on ApiException catch (error) {
      if (mounted && revision == _gamesRevision) {
        final offline = error.code == 'NETWORK_ERROR' || error.code == 'REQUEST_TIMEOUT';
        if (offline) _scheduleOfflineRetry();
        setState(() {
          _offline = offline;
          _gamesError = offline ? null : error.message;
          _gamesLoading = false;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted && revision == _gamesRevision) {
        setState(() {
          _gamesError =
              'Could not load nearby games. Check your connection and retry.';
          _gamesLoading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _createGame() async {
    final api = widget.api;
    if (api == null) return;
    final created = await showModalBottomSheet<Game>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: .78),
        builder: (_) => CreateGameScreen(
            api: api, area: _area, apiKey: widget.apiKey));
    if (created == null || !mounted) return;
    await _loadGames();
    if (mounted) await _showGame(created);
  }

  Future<void> _showGame(Game game) async {
    final api = widget.api;
    if (api == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .5),
      builder: (_) => GameDetailsSheet(
        game: game,
        service: GameService(api),
        userId: widget.userId,
        apiKey: widget.apiKey,
        onChanged: () => _loadGames(),
      ),
    );
    if (mounted) _loadGames();
  }

  /// While offline, quietly retry so the status flips back on its own.
  void _scheduleOfflineRetry() {
    _offlineRetry?.cancel();
    _offlineRetry = Timer(const Duration(seconds: 12), () {
      if (mounted && _offline) _loadGames();
    });
  }

  void _startTimeout() {
    _timeout?.cancel();
    if (widget.apiKey.isNotEmpty) {
      _timeout = Timer(const Duration(seconds: 15), () {
        if (mounted && _loading) {
          setState(() {
            _loading = false;
            _failed = true;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _offlineRetry?.cancel();
    _cameraMotion.dispose();
    _map.dispose();
    super.dispose();
  }

  void _tileStatus(bool failed, int attempt) {
    if (attempt != _attempt || (failed ? _failed : !_loading)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || attempt != _attempt) return;
      if (failed) {
        if (!_failed || _loading) {
          setState(() {
            _failed = true;
            _loading = false;
          });
        }
      } else if (_loading) {
        _timeout?.cancel();
        setState(() => _loading = false);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _retry() {
    setState(() {
      _attempt++;
      _failed = false;
      _loading = true;
    });
    _startTimeout();
  }

  void _setSport(String sport) {
    setState(() {
      _selectedSport = sport == 'All' ? null : sport;
      _games = [];
      _nextGameCursor = null;
    });
    _loadGames();
  }

  void _setTimeWindow(String? value) {
    setState(() {
      _selectedTimeWindow = value;
      _games = [];
      _nextGameCursor = null;
    });
    _loadGames();
  }

  void _setRadius(double value) {
    setState(() {
      _selectedRadius = value;
      _games = [];
      _nextGameCursor = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.apiKey.isEmpty) return;
      _cameraMotion.recenter(
        _center,
        reducedMotion: MediaQuery.disableAnimationsOf(context),
        targetZoom: _zoomForRadius(value),
      );
    });
    _loadGames();
  }

  double _zoomForRadius(double radiusKm) {
    final size = MediaQuery.sizeOf(context);
    // The circle fills ~80% of the screen width, so it stays fully visible.
    final diameter = size.width * .8;
    final latitudeScale = math.cos(_area.latitude * math.pi / 180).abs().clamp(.15, 1.0);
    final metersPerPixelAtZoomZero = 156543.03392 * latitudeScale;
    final zoom = math.log(metersPerPixelAtZoomZero * diameter / (radiusKm * 2000)) / math.ln2;
    return zoom.clamp(9.0, 16.0).toDouble();
  }

  double get _radiusValue => (_draftRadius ?? _selectedRadius ?? _profileRadius)
      .clamp(1.0, _maxRadius)
      .toDouble();

  static const _maxRadius = 25.0;

  void _radiusExpanded() {
    setState(() {
      _radiusActive = true;
      _draftRadius = _radiusValue.roundToDouble();
    });
  }

  void _radiusChanged(double km) {
    if (!mounted) return;
    setState(() => _draftRadius = km);
    if (widget.apiKey.isNotEmpty) _map.move(_center, _zoomForRadius(km));
  }

  void _radiusCollapsed(double km) {
    if (!mounted) return;
    final value = km.roundToDouble();
    setState(() {
      _draftRadius = null;
      _radiusActive = false;
    });
    if (value != (_selectedRadius ?? _profileRadius).roundToDouble()) {
      _setRadius(value);
    }
  }

  List<Game> get _visibleGames => _games.where((game) {
        if (_freeOnly && game.feeAmount > 0) return false;
        if (_spotsOnly && game.openSpots <= 0) return false;
        return true;
      }).toList(growable: false);

  Future<void> _showFilters() async {
    var draftTime = _selectedTimeWindow;
    var draftFree = _freeOnly;
    var draftSpots = _spotsOnly;
    final choice = await showPzSheet<(String?, bool, bool)>(
      context,
      builder: (sheetContext) => StatefulBuilder(builder: (context, setSheetState) {
        Widget toggle(String title, String subtitle, bool value, ValueChanged<bool> onChanged) => MergeSemantics(
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(16, 4, 10, 4),
                title: Text(title, style: AppTheme.headline),
                subtitle: Text(subtitle, style: AppTheme.footnote),
                trailing: Switch.adaptive(
                  value: value,
                  activeTrackColor: AppTheme.lime,
                  activeThumbColor: Colors.white,
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    onChanged(v);
                  },
                ),
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(!value);
                },
              ),
            );
        final changed = draftTime != null || draftFree || draftSpots;
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(child: Text('Filters', style: AppTheme.title1)),
                TextButton(
                  onPressed: changed
                      ? () => setSheetState(() {
                            draftTime = null;
                            draftFree = false;
                            draftSpots = false;
                          })
                      : null,
                  style: TextButton.styleFrom(foregroundColor: AppTheme.lime, disabledForegroundColor: AppTheme.muted),
                  child: const Text('Reset', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 22),
              const PzSectionTitle('Starting'),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final (value, label) in const [(null, 'Any time'), ('24h', 'Next 24 hours'), ('7d', 'Next 7 days')])
                  PzChoicePill(label: label, selected: draftTime == value, onTap: () => setSheetState(() => draftTime = value)),
              ]),
              const SizedBox(height: 26),
              const PzSectionTitle('Only show'),
              const SizedBox(height: 12),
              Material(
                color: const Color(0x0DFFFFFF),
                borderRadius: BorderRadius.circular(22),
                clipBehavior: Clip.antiAlias,
                child: Column(children: [
                  toggle('Free games', 'No entry fee', draftFree, (v) => setSheetState(() => draftFree = v)),
                  const Divider(height: 1, thickness: 1, indent: 16, color: pzLine),
                  toggle('Games with open spots', 'Hide games that are already full', draftSpots, (v) => setSheetState(() => draftSpots = v)),
                ]),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(sheetContext, (draftTime, draftFree, draftSpots)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.lime,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(56),
                  shape: const StadiumBorder(),
                ),
                child: const Text('Show games'),
              ),
            ]),
          ),
        );
      }),
    );
    if (choice == null || !mounted) return;
    setState(() { _freeOnly = choice.$2; _spotsOnly = choice.$3; });
    _setTimeWindow(choice.$1);
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    final ok = await pzConfirm(context,
        title: 'Sign out?',
        message: 'You can sign back in any time with the same account.',
        confirm: 'Sign out',
        cancel: 'Cancel');
    if (!ok || !mounted) return;
    setState(() => _signingOut = true);
    try {
      await widget.signOut();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not sign out. Please retry.')));
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  int _tab = 0;

  /// Lifts Geoapify's dark-matter tiles so streets read without dimming.
  static const _tileLift = ColorFilter.matrix(<double>[
    1.15, 0, 0, 0, 6,
    0, 1.15, 0, 0, 6,
    0, 0, 1.15, 0, 8,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) setState(() => _tab = 0);
      },
      child: Scaffold(
        backgroundColor: appBackground,
        extendBody: true,
        bottomNavigationBar: PlatformNavigation(
            selectedIndex: _tab,
            onSelected: (index) {
              _cameraMotion.stop();
              setState(() {
                _tab = index;
                if (index == 1) _activityRevision++;
              });
            }),
        body: IndexedStack(index: _tab, children: [
          _explore(),
          widget.api == null
              ? _destination(
                  'Activity',
                  PhosphorIconsRegular.lightning,
                  'Your games will show up here.',
                  'Host or join a game to get started.')
              : ActivityScreen(
                  key: ValueKey(_activityRevision),
                  service: GameService(widget.api!),
                  userId: widget.userId,
                  apiKey: widget.apiKey,
                  bottomSpace: _navigationSpace,
                  onCreate: _createGame),
          _destination(
              'Arenas',
              PhosphorIconsRegular.mapTrifold,
              'A place for every game.',
              'Arena discovery and booking will be available in a future update.'),
          ProfileScreen(
            photo: widget.photo,
            name: widget.name,
            username: widget.username,
            area: widget.area,
            api: widget.api,
            profileSummary: _profileSummary,
            profileRadius: _profileRadius,
            isSigningOut: _signingOut,
            navigationSpace: _navigationSpace,
            onEditPreferences: _editPreferences,
            onSignOut: () => _signOut(),
            onLocationModeChanged: widget.api == null ? null : _setLocationMode,
            onSetHome: widget.api == null ? null : _setHomeLocation,
          ),
        ]),
      ),
    );
  }

  double get _navigationSpace => PlatformNavigation.spaceOf(context) + 8;

  /// Status shown in the header pill: (word, colour).
  (String, Color) get _status {
    const warn = Color(0xFFFFA53D);
    if (_offline) return ('Offline', warn);
    if (_refreshingLocation) return ('Updating', AppTheme.muted);
    if (_usingHome) return ('Default', AppTheme.primaryText);
    if (_locationStale) return ('No GPS', warn);
    if (widget.area.source != 'gps') return ('Last known', warn);
    return ('Live', AppTheme.lime);
  }

  bool get _live => _status.$1 == 'Live';

  Widget _locationLine() {
    final (status, color) = _status;
    final label = _shortLabel(_area.label);
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      key: _locationKey,
      button: true,
      label: 'Searching near $label, $status. Change location',
      excludeSemantics: true,
      child: PzPressable(
        onTap: widget.api == null ? null : _chooseLocation,
        scale: .96,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            AnimatedContainer(
              duration: reduce ? Duration.zero : const Duration(milliseconds: 250),
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: color.withValues(alpha: .22), width: .5),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                AnimatedContainer(
                  duration: reduce ? Duration.zero : const Duration(milliseconds: 250),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                AnimatedSwitcher(
                  duration: reduce ? Duration.zero : const Duration(milliseconds: 200),
                  child: Text(status,
                      key: ValueKey(status),
                      style: TextStyle(
                          fontSize: 12,
                          height: 1,
                          letterSpacing: 0,
                          fontWeight: FontWeight.w600,
                          color: color)),
                ),
              ]),
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, letterSpacing: -.15, fontWeight: FontWeight.w500,
                      color: Color(0xE6FFFFFF))),
            ),
            const SizedBox(width: 3),
            const Icon(PhosphorIconsBold.caretDown, size: 11, color: AppTheme.muted),
          ]),
        ),
      ),
    );
  }

  bool get _filtersActive =>
      _freeOnly || _spotsOnly || _selectedTimeWindow != null;

  Future<void> _openCluster(List<Game> games, LatLng center) async {
    final zoom = _map.camera.zoom;
    if (zoom < 16.5) {
      _cameraMotion.recenter(center,
          reducedMotion: MediaQuery.disableAnimationsOf(context),
          targetZoom: math.min(zoom + 2, 17.5));
      return;
    }
    final l = MaterialLocalizations.of(context);
    final choice = await NativeSheets.pickOption(
      context,
      title: '${games.length} games here',
      options: [
        for (final g in games)
          NativeOption(
              '${g.sport} · ${l.formatTimeOfDay(TimeOfDay.fromDateTime(g.startTime))}',
              subtitle: pzSplitPlace(g.locationLabel).$1,
              icon: SportSymbol.boldIconFor(g.sport)),
      ],
    );
    if (choice != null && mounted) _showGame(games[choice]);
  }

  Future<Uint8List?> Function(GamePlayer)? _photoLoaderFor(Game game) {
    final api = widget.api;
    if (api == null) return null;
    return (player) => GameService(api).playerPhoto(game.id, player.userId);
  }

  /// Game bubbles, grouped when they would overlap at the current zoom.
  Widget _gamesLayer() => Builder(builder: (context) {
        final camera = MapCamera.of(context);
        final clusters = <List<Game>>[];
        final anchors = <Offset>[];
        for (final game in _visibleGames) {
          final p = camera.latLngToScreenOffset(LatLng(game.latitude, game.longitude));
          var placed = false;
          for (var i = 0; i < clusters.length; i++) {
            if ((p.dx - anchors[i].dx).abs() < GameMapMarker.width * .85 &&
                (p.dy - anchors[i].dy).abs() < GameMapMarker.height * .9) {
              clusters[i].add(game);
              placed = true;
              break;
            }
          }
          if (!placed) {
            clusters.add([game]);
            anchors.add(p);
          }
        }
        return MarkerLayer(markers: [
          for (final cluster in clusters)
            if (cluster.length == 1)
              Marker(
                point: LatLng(cluster.first.latitude, cluster.first.longitude),
                width: GameMapMarker.width,
                height: GameMapMarker.height,
                alignment: Alignment.topCenter,
                child: _Appear(
                  key: ValueKey(cluster.first.id),
                  child: GameMapMarker(
                    game: cluster.first,
                    loader: _photoLoaderFor(cluster.first),
                    onTap: () => _showGame(cluster.first),
                  ),
                ),
              )
            else
              () {
                final center = LatLng(
                    cluster.map((g) => g.latitude).reduce((a, b) => a + b) / cluster.length,
                    cluster.map((g) => g.longitude).reduce((a, b) => a + b) / cluster.length);
                return Marker(
                  point: center,
                  width: GameClusterMarker.width,
                  height: GameClusterMarker.height,
                  alignment: Alignment.topCenter,
                  child: _Appear(
                    key: ValueKey(cluster.map((g) => g.id).join()),
                    child: GameClusterMarker(
                        games: cluster, onTap: () => _openCluster(cluster, center)),
                  ),
                );
              }(),
        ]);
      });

  Widget _explore() {
    final attempt = _attempt;
    final mapReady = widget.apiKey.isNotEmpty;
    final top = MediaQuery.paddingOf(context).top;
    final bottom = _navigationSpace + 6;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Stack(fit: StackFit.expand, children: [
      Positioned.fill(child: !mapReady
        ? const ColoredBox(color: Color(0xFF0C0C0C), child: Center(child: Text('The map is unavailable right now.', style: TextStyle(color: Colors.white54))))
        : FlutterMap(
            mapController: _map,
            options: MapOptions(
              onPositionChanged: (_, gesture) { if (gesture) _cameraMotion.stop(); },
              initialCenter: _center, initialZoom: _zoomForRadius(_radiusValue), minZoom: 3, maxZoom: 19,
              backgroundColor: const Color(0xFF0C0C0C),
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            ),
            children: [
              TileLayer(
                key: ValueKey(attempt),
                urlTemplate: 'https://maps.geoapify.com/v1/tile/dark-matter/{z}/{x}/{y}.png?apiKey=${Uri.encodeQueryComponent(widget.apiKey)}',
                userAgentPackageName: 'com.playerszwz.app', tileProvider: widget.tileProvider, maxNativeZoom: 20,
                errorTileCallback: (_, error, stack) => _tileStatus(true, attempt),
                tileBuilder: (context, child, tile) => AnimatedBuilder(animation: tile, builder: (context, _) { if (tile.loadFinishedAt != null) _tileStatus(tile.loadError, attempt); return ColorFiltered(colorFilter: _tileLift, child: child); }),
              ),
              // The radius ring only shows while the radius is being changed.
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _radiusActive ? 1 : 0,
                  duration: reduce ? Duration.zero : Duration(milliseconds: _radiusActive ? 180 : 600),
                  curve: Curves.easeOut,
                  child: CircleLayer(circles: [CircleMarker(point: _center, radius: _radiusValue * 1000, useRadiusInMeter: true, color: appAccent.withValues(alpha: .06), borderColor: appAccent.withValues(alpha: .75), borderStrokeWidth: 1.5)]),
                ),
              ),
              MarkerLayer(markers: [
                Marker(point: _center, width: 72, height: 72, child: Semantics(label: _usingHome ? 'Your home: ${_area.label}' : 'Your location: ${_area.label}', child: AreaMarker(live: _live, home: _usingHome))),
              ]),
              _gamesLayer(),
            ],
          )),
      // Short scrim behind the header only. It must be Positioned: this Stack
      // uses StackFit.expand, which stretches unpositioned children (and the
      // gradient) over the whole map.
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: IgnorePointer(
        child: Container(
          height: top + 96,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xB3000000), Color(0x4D000000), Color(0x00000000)],
              stops: [0, .6, 1],
            ),
          ),
        ),
      )),
      Positioned(
        top: top + 6, left: 20, right: 16,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Semantics(
                header: true,
                child: Text('Explore', style: AppTheme.screenTitle(context)),
              ),
              const SizedBox(height: 2),
              _locationLine(),
            ]),
          ),
          if (widget.api != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: NativeGlassButton(
                icon: PhosphorIconsBold.plus,
                label: 'Host a game',
                prominent: true,
                iconSize: 19,
                onTap: _createGame,
              ),
            ),
        ]),
      ),
      if (widget.api != null)
        Positioned(
          top: top + (AppTheme.isCompact(context) ? 82 : 90), left: 16, right: 0,
          child: Row(children: [
            NativeGlassButton(
              icon: PhosphorIconsBold.slidersHorizontal,
              label: _filtersActive ? 'Filters, on' : 'Filters',
              prominent: _filtersActive,
              width: 38,
              height: 38,
              iconSize: 16,
              onTap: _showFilters,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 38,
                child: ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(colors: [Colors.white, Colors.white, Colors.transparent], stops: [0, .88, 1]).createShader(rect),
                  blendMode: BlendMode.dstIn,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(right: 24),
                    children: [
                      for (final sport in const ['All', 'Football', 'Cricket', 'Basketball', 'Badminton', 'Tennis', 'Skating'])
                        Padding(
                          padding: const EdgeInsets.only(right: 6, top: 2, bottom: 2),
                          child: PzChoicePill(
                            label: sport,
                            compact: true,
                            selected: (_selectedSport ?? 'All') == sport,
                            onTap: () => _setSport(sport),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ]),
        ),
      if (widget.api != null)
        Positioned(
          left: 16, right: 16 + 44 + 12, bottom: bottom,
          child: NativeRadiusSlider(
            value: _radiusValue.roundToDouble(),
            min: 1,
            max: _maxRadius,
            onExpanded: _radiusExpanded,
            onChanged: _radiusChanged,
            onCollapsed: _radiusCollapsed,
          ),
        ),
      Positioned(
        right: 16, bottom: bottom,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_games.isNotEmpty && _nextGameCursor != null && !_loadingMore) ...[
            NativeGlassButton(
              icon: PhosphorIconsBold.arrowDown,
              label: 'Load more games',
              onTap: () => _loadGames(append: true),
            ),
            const SizedBox(height: 10),
          ],
          NativeGlassButton(
            icon: PhosphorIconsFill.navigationArrow,
            label: _usingHome ? 'Recenter on home' : 'Recenter on my location',
            onTap: () => _cameraMotion.recenter(_center, reducedMotion: MediaQuery.disableAnimationsOf(context), targetZoom: _zoomForRadius(_radiusValue)),
          ),
        ]),
      ),
      if (mapReady && (_loading || _failed))
        Positioned(
          top: MediaQuery.sizeOf(context).height * .42,
          left: 24,
          right: 24,
          child: Center(
            child: Material(
              color: const Color(0xE8141416),
              shape: const StadiumBorder(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (_loading)
                    const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2, color: appAccent))
                  else
                    const Icon(PhosphorIconsRegular.warningCircle, size: 16, color: Colors.white70),
                  const SizedBox(width: 8),
                  Text(_failed ? 'Map unavailable' : 'Loading map…', style: const TextStyle(fontSize: 13, color: Colors.white70)),
                  if (_failed) TextButton(onPressed: _retry, style: TextButton.styleFrom(foregroundColor: AppTheme.lime), child: const Text('Retry')),
                  if (!_failed) const SizedBox(width: 8),
                ]),
              ),
            ),
          ),
        ),
      if (_gamesError != null && !_gamesLoading)
        Positioned(
          top: top + (AppTheme.isCompact(context) ? 130 : 140), left: 16, right: 16,
          child: Material(
            color: const Color(0xF2141416),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
              child: Row(children: [
                const Icon(PhosphorIconsFill.warningCircle, size: 16, color: AppTheme.destructive),
                const SizedBox(width: 10),
                Expanded(child: Text(_gamesError!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                TextButton(onPressed: _loadGames, style: TextButton.styleFrom(foregroundColor: AppTheme.lime), child: const Text('Retry')),
              ]),
            ),
          ),
        ),
    ]);
  }

  Widget _destination(
          String title, IconData icon, String headline, String description) =>
      SafeArea(
        bottom: false,
        child: CustomScrollView(slivers: [
          SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              sliver: SliverToBoxAdapter(
                  child: Text(title, style: AppTheme.screenTitle(context)))),
          SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                  padding:
                      EdgeInsets.fromLTRB(32, 40, 32, _navigationSpace + 32),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                                color: appSurface,
                                borderRadius: BorderRadius.circular(26)),
                            child: Icon(icon, size: 36, color: appAccent)),
                        const SizedBox(height: 28),
                        Text(headline,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontFamily: 'Archivo', fontSize: 24,
                                letterSpacing: -.6,
                                fontWeight: FontWeight.w800,
                                height: 1.2)),
                        const SizedBox(height: 12),
                        Text(description,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                color: Colors.white54)),
                        const SizedBox(height: 24),
                        TextButton(
                            onPressed: () => setState(() => _tab = 0),
                            child: const Text('Explore your area',
                                style: TextStyle(color: appAccent))),
                      ]))),
        ]),
      );
}

/// Bubbles pop in with a short spring when they first appear.
class _Appear extends StatelessWidget {
  const _Appear({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(
            scale: .7 + .3 * t, alignment: Alignment.bottomCenter, child: child),
      ),
    );
  }
}
