import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../app/app_theme.dart';
import '../../app/playerszwz_app.dart';
import '../../core/api_client.dart';
import '../../core/native/native_ui.dart';
import '../../core/ui/pz_controls.dart';
import '../../core/widgets/motion.dart';
import '../discovery/discovery_widgets.dart';
import '../location/location_service.dart';
import 'game_model.dart';
import 'game_screens.dart' show VenueMapPickerScreen;
import 'game_service.dart';
import 'sport_formats.dart';

/// Host or edit a game. Presented as a tall sheet from Explore and game details.
class CreateGameScreen extends StatefulWidget {
  const CreateGameScreen({
    super.key,
    required this.api,
    required this.area,
    required this.apiKey,
    this.initialGame,
  });

  final ApiClient api;
  final Area area;
  final String apiKey;
  final Game? initialGame;

  @override
  State<CreateGameScreen> createState() => _CreateGameScreenState();
}

class _CreateGameScreenState extends State<CreateGameScreen> {
  static const _nativePickers = MethodChannel('playerszwz/native-pickers');
  static const _sports = [
    'Basketball',
    'Badminton',
    'Football',
    'Skating',
    'Cricket',
    'Tennis',
  ];

  late final _location = LocationService(apiKey: widget.apiKey);
  final _query = TextEditingController();
  final _notes = TextEditingController();
  final _fee = TextEditingController();
  Timer? _searchTimer;
  int _searchRevision = 0;
  String _sport = 'Football';
  late Area _selectedArea = widget.area;
  late DateTime _startTime = _defaultStart();
  List<Area> _results = [];
  List<Area> _nearbyPlaces = [];
  bool _searching = false, _saving = false, _loadingPlaces = true;
  String? _error, _placesError, _searchError;
  int _players = 10;
  String _format = 'Futsal 5-a-side';
  int _placesRevision = 0;
  final _scroll = ScrollController();
  bool _scrolled = false, _pickingVenue = true, _paid = false;
  String? _feeError;
  late final String _initialSignature;

  @override
  void initState() {
    super.initState();
    final game = widget.initialGame;
    if (game != null) {
      _sport = game.sport;
      _startTime = game.startTime;
      _selectedArea =
          Area(game.latitude, game.longitude, game.locationLabel, 'manual');
      _players = game.requiredPlayers;
      _format = formatFor(_sport, _players)?.name ?? 'Custom';
      _paid = game.feeAmount > 0;
      _fee.text = game.feeAmount > 0 ? '${game.feeAmount}' : '';
      _pickingVenue = false;
      _notes.text = game.notes;
    }
    _initialSignature = _signature();
    _scroll.addListener(_onScroll);
    _loadNearbyPlaces();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchTimer?.cancel();
    _location.close();
    _query.dispose();
    _notes.dispose();
    _fee.dispose();
    super.dispose();
  }

  void _search(String value) {
    _searchTimer?.cancel();
    final revision = ++_searchRevision;
    if (value.trim().length < 3) {
      setState(() {
        _results = [];
        _searching = false;
        _searchError = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
      _searchError = null;
      _results = [];
    });
    _searchTimer = Timer(const Duration(milliseconds: 400), () async {
      try {
        final found = await _location.searchVenue(value);
        if (mounted && revision == _searchRevision) {
          setState(() => _results = found);
        }
      } catch (_) {
        if (mounted && revision == _searchRevision) {
          setState(() => _searchError = 'Search failed. Please retry.');
        }
      } finally {
        if (mounted && revision == _searchRevision) {
          setState(() => _searching = false);
        }
      }
    });
  }

  Future<void> _loadNearbyPlaces() async {
    final revision = ++_placesRevision;
    setState(() {
      _loadingPlaces = true;
      _placesError = null;
    });
    try {
      final places = await _location.nearbySportsPlaces(widget.area, _sport);
      if (mounted && revision == _placesRevision) {
        setState(() => _nearbyPlaces = places);
      }
    } catch (_) {
      if (mounted && revision == _placesRevision) {
        setState(() {
          _nearbyPlaces = [];
          _placesError = 'Could not load nearby places. Search or drop a pin.';
        });
      }
    } finally {
      if (mounted && revision == _placesRevision) {
        setState(() => _loadingPlaces = false);
      }
    }
  }

  Future<void> _pinOnMap() async {
    final area = await Navigator.of(context).push<Area>(MaterialPageRoute(
      builder: (_) => VenueMapPickerScreen(
        area: _selectedArea,
        apiKey: widget.apiKey,
        location: _location,
      ),
    ));
    if (area == null || !mounted) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _selectedArea = area;
      _pickingVenue = false;
      _query.clear();
      _results = [];
      _searchError = null;
      _searchRevision++;
    });
  }

  /// Shows the tick on the chosen row first, then collapses the list.
  void _selectVenue(Area area) {
    unawaited(HapticFeedback.selectionClick());
    FocusScope.of(context).unfocus();
    setState(() => _selectedArea = area);
    Future<void>.delayed(
        _reduceMotion ? Duration.zero : const Duration(milliseconds: 360), () {
      if (!mounted || !_sameArea(area, _selectedArea)) return;
      setState(() {
        _pickingVenue = false;
        _query.clear();
        _results = [];
        _searchError = null;
        _searchRevision++;
      });
    });
  }

  Future<void> _chooseDate() async {
    final now = DateTime.now();
    late final DateTime? date;
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      date = await NativeSheets.pickDate(context,
          title: 'Game date',
          initial: _startTime.isBefore(now) ? now : _startTime,
          first: DateTime(now.year, now.month, now.day),
          last: now.add(const Duration(days: 90)));
    } else if (Theme.of(context).platform == TargetPlatform.android) {
      try {
        date = await _chooseAndroidDate(now);
      } on MissingPluginException {
        date = await _chooseMaterialDate(now);
      } on PlatformException {
        date = await _chooseMaterialDate(now);
      }
    } else {
      date = await _chooseMaterialDate(now);
    }
    if (date == null || !mounted) return;
    unawaited(HapticFeedback.selectionClick());
    final candidate = DateTime(
        date.year, date.month, date.day, _startTime.hour, _startTime.minute);
    setState(() {
      _startTime = candidate.isAfter(now)
          ? candidate
          : now.add(const Duration(hours: 1));
      _error = null;
    });
  }

  Future<void> _chooseTime() async {
    late final TimeOfDay? time;
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      time = await NativeSheets.pickTime(context,
          title: 'Start time', initial: _startTime);
    } else if (Theme.of(context).platform == TargetPlatform.android) {
      try {
        time = await _chooseAndroidTime();
      } on MissingPluginException {
        time = await _chooseMaterialTime();
      } on PlatformException {
        time = await _chooseMaterialTime();
      }
    } else {
      time = await _chooseMaterialTime();
    }
    if (time == null || !mounted) return;
    unawaited(HapticFeedback.selectionClick());
    final candidate = DateTime(_startTime.year, _startTime.month,
        _startTime.day, time.hour, time.minute);
    if (!candidate.isAfter(DateTime.now())) {
      setState(() => _error = 'Choose a time in the future.');
      return;
    }
    setState(() {
      _startTime = candidate;
      _error = null;
    });
  }

  Future<DateTime?> _chooseAndroidDate(DateTime now) async {
    final initial = _startTime.isBefore(now) ? now : _startTime;
    final result = await _nativePickers.invokeMapMethod<String, dynamic>(
      'date',
      {
        'year': initial.year,
        'month': initial.month,
        'day': initial.day,
        'minimumMillis':
            DateTime(now.year, now.month, now.day).millisecondsSinceEpoch,
        'maximumMillis': DateTime(now.year, now.month, now.day)
            .add(const Duration(days: 365))
            .millisecondsSinceEpoch,
      },
    );
    if (result == null) return null;
    return DateTime(
      (result['year'] as num).toInt(),
      (result['month'] as num).toInt(),
      (result['day'] as num).toInt(),
    );
  }

  Future<TimeOfDay?> _chooseAndroidTime() async {
    final result = await _nativePickers.invokeMapMethod<String, dynamic>(
      'time',
      {'hour': _startTime.hour, 'minute': _startTime.minute},
    );
    if (result == null) return null;
    return TimeOfDay(
      hour: (result['hour'] as num).toInt(),
      minute: (result['minute'] as num).toInt(),
    );
  }

  Future<DateTime?> _chooseMaterialDate(DateTime now) => showDatePicker(
        context: context,
        initialDate: _startTime.isBefore(now) ? now : _startTime,
        firstDate: now,
        lastDate: now.add(const Duration(days: 365)),
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: appAccent,
              onPrimary: Colors.black,
              surface: appSurface,
            ),
          ),
          child: child!,
        ),
      );

  Future<TimeOfDay?> _chooseMaterialTime() => showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_startTime),
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: appAccent,
              onPrimary: Colors.black,
              surface: appSurface,
            ),
          ),
          child: child!,
        ),
      );

  // ---------------------------------------------------------------------------
  // State helpers
  // ---------------------------------------------------------------------------

  static DateTime _defaultStart() {
    final t = DateTime.now().add(const Duration(minutes: 60));
    final base = DateTime(t.year, t.month, t.day, t.hour, t.minute);
    final step = t.minute % 30 == 0 ? 0 : 30 - t.minute % 30;
    return base.add(Duration(minutes: step));
  }

  String _signature() =>
      '$_sport|$_startTime|${_selectedArea.latitude},${_selectedArea.longitude}'
      '|$_players|$_paid|${_fee.text}|${_notes.text}';

  bool get _dirty => _signature() != _initialSignature;

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);


  void _onScroll() {
    final scrolled = _scroll.hasClients && _scroll.offset > 4;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
  }

  void _setSport(String sport) {
    if (_saving || sport == _sport) return;
    unawaited(HapticFeedback.selectionClick());
    final first = sportFormats[sport]?.first;
    setState(() {
      _sport = sport;
      if (first != null) {
        _format = first.name;
        _players = first.players;
      } else {
        _format = 'Custom';
      }
    });
    _loadNearbyPlaces();
  }

  void _setPlayers(int value, {String format = 'Custom'}) {
    if (_saving || value < 2 || value > 40) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _players = value;
      _format = format;
    });
  }

  void _setPaid(bool paid) {
    if (_saving || paid == _paid) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _paid = paid;
      _feeError = null;
    });
  }

  bool _sameArea(Area a, Area b) =>
      (a.latitude - b.latitude).abs() < 1e-6 &&
      (a.longitude - b.longitude).abs() < 1e-6;

  /// Splits "Place · City" or "Street, Area, City" into a title and a subtitle.
  (String, String?) _splitLabel(String label) {
    for (final separator in [' · ', ', ']) {
      final index = label.indexOf(separator);
      if (index > 0) {
        return (
          label.substring(0, index).trim(),
          label.substring(index + separator.length).trim()
        );
      }
    }
    return (label, null);
  }

  String _relativeStart() {
    final diff = _startTime.difference(DateTime.now());
    if (diff.isNegative) return 'This time has already passed';
    final now = DateTime.now();
    final days = DateTime(_startTime.year, _startTime.month, _startTime.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    if (days == 0) {
      final h = diff.inHours, m = diff.inMinutes % 60;
      if (h == 0) return 'Starts in $m min';
      return m == 0 ? 'Starts in $h h' : 'Starts in $h h $m min';
    }
    if (days == 1) return 'Starts tomorrow';
    return 'Starts in $days days';
  }

  String _summary(MaterialLocalizations l) {
    final time = l.formatTimeOfDay(TimeOfDay.fromDateTime(_startTime));
    final fee = _paid && (_fee.text.trim().isNotEmpty)
        ? 'Rs. ${_fee.text.trim()}'
        : 'Free';
    return '$_sport · ${l.formatShortMonthDay(_startTime)}, $time · '
        '$_players players · $fee';
  }

  Future<void> _attemptClose() async {
    if (_saving) return;
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await pzConfirm(context,
        title: 'Discard this game?',
        message: 'Your changes will not be saved.',
        confirm: 'Discard',
        cancel: 'Keep editing');
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _create() async {
    if (_saving) return;
    if (!_startTime.isAfter(DateTime.now())) {
      setState(() => _error = 'Choose a time in the future.');
      return;
    }
    var feeAmount = 0;
    if (_paid) {
      final parsed = int.tryParse(_fee.text.trim());
      if (parsed == null || parsed <= 0 || parsed > 100000) {
        setState(() => _feeError =
            'Enter an amount from Rs. 1 to Rs. 100,000, or choose Free.');
        return;
      }
      feeAmount = parsed;
    }
    setState(() {
      _saving = true;
      _error = null;
      _feeError = null;
    });
    try {
      final service = GameService(widget.api);
      final game = widget.initialGame == null
          ? await service.create(
              sport: _sport,
              startTime: _startTime,
              location: _selectedArea,
              requiredPlayers: _players,
              feeAmount: feeAmount,
              notes: _notes.text,
            )
          : await service.update(
              id: widget.initialGame!.id,
              sport: _sport,
              startTime: _startTime,
              location: _selectedArea,
              requiredPlayers: _players,
              feeAmount: feeAmount,
              notes: _notes.text,
            );
      unawaited(HapticFeedback.mediumImpact());
      if (mounted) Navigator.of(context).pop(game);
    } on ApiException catch (error) {
      unawaited(HapticFeedback.heavyImpact());
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      unawaited(HapticFeedback.heavyImpact());
      if (mounted) {
        setState(() => _error = 'Could not host the game. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Layout
  // ---------------------------------------------------------------------------

  static const _line = Color(0xFF262626);
  static const _motion = Duration(milliseconds: 260);

  Duration get _duration => _reduceMotion ? Duration.zero : _motion;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final l = MaterialLocalizations.of(context);
    final editing = widget.initialGame != null;
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _attemptClose();
      },
      child: AnimatedPadding(
        duration: _reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: (media.size.height - media.viewInsets.bottom) * .94,
            decoration: const ShapeDecoration(
              color: AppTheme.surface,
              shape: RoundedSuperellipseBorder(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(AppTheme.radiusSheet)),
                side: BorderSide(color: Color(0x24FFFFFF), width: 1),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: Column(children: [
                _header(editing),
                AnimatedOpacity(
                  opacity: _scrolled ? 1 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: const Divider(height: 1, thickness: 1, color: _line),
                ),
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                    children: [
                      _section('Sport', first: true, child: _sportField()),
                      _section('When', child: _whenTiles(l)),
                      _section('Where', child: _venueSection()),
                      _section('Players', child: _playersCard()),
                      _section('Entry fee', child: _feeSection()),
                      _section('Note', optional: true, child: _noteField()),
                    ],
                  ),
                ),
                _footer(editing, l),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(bool editing) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 14, 14),
        child: Column(children: [
          Container(
            width: 38,
            height: 5,
            decoration: BoxDecoration(
                color: const Color(0xFF3A3A3C),
                borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(editing ? 'Edit game' : 'Host a game',
                        style: const TextStyle(
                            fontFamily: 'Archivo', fontSize: 28,
                            height: 1.05,
                            letterSpacing: -.6,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                      editing
                          ? 'Players see your changes right away.'
                          : 'Set the basics. Players request to join.',
                      style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.muted,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Semantics(
              button: true,
              label: 'Close',
              child: PzPressScale(child: Material(
                color: AppTheme.surfaceRaised,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _saving ? null : _attemptClose,
                  child: const SizedBox.square(
                    dimension: 40,
                    child: Icon(PhosphorIconsBold.x, size: 17),
                  ),
                ),
              )),
            ),
          ]),
        ]),
      );

  Widget _section(String title,
          {required Widget child, bool optional = false, bool first = false}) =>
      Padding(
        padding: EdgeInsets.only(top: first ? 10 : 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(
            header: true,
            child: Row(children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 16,
                      letterSpacing: -.3,
                      fontWeight: FontWeight.w700)),
              if (optional)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Text('Optional',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.muted,
                          fontWeight: FontWeight.w500)),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          child,
        ]),
      );

  Widget _card({required Widget child, EdgeInsets padding = EdgeInsets.zero}) =>
      Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: AppTheme.surfaceRaised,
          borderRadius: BorderRadius.circular(22),
        ),
        child: child,
      );

  // Sport ---------------------------------------------------------------------

  final _sportKey = GlobalKey();

  Future<void> _chooseSport() async {
    if (_saving) return;
    final anchorContext = _sportKey.currentContext;
    final index = await pzMenu(
      context,
      anchor: anchorContext == null ? Rect.zero : pzRectOf(anchorContext),
      title: 'Choose a sport',
      selected: _sports.indexOf(_sport),
      actions: [
        for (final sport in _sports)
          PzAction(sport,
              subtitle: (sportFormats[sport] ?? const [])
                  .map((f) => f.name)
                  .join(' · '),
              icon: SportSymbol.iconFor(sport)),
      ],
    );
    if (index != null && mounted) _setSport(_sports[index]);
  }

  Widget _sportField() => Semantics(
        key: _sportKey,
        button: true,
        label: 'Sport, $_sport. Change',
        excludeSemantics: true,
        child: PzPressScale(child: Material(
          color: AppTheme.surfaceRaised,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _chooseSport,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                      color: AppTheme.lime, shape: BoxShape.circle),
                  child: Center(
                      child: SportSymbol(_sport, size: 19, color: Colors.black)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_sport,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                const Icon(PhosphorIconsRegular.caretUpDown,
                    size: 18, color: AppTheme.muted),
              ]),
            ),
          ),
        )),
      );

  // When ----------------------------------------------------------------------

  Widget _whenTiles(MaterialLocalizations l) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: _tile(
              label: 'Date',
              icon: PhosphorIconsRegular.calendarBlank,
              value: l.formatMediumDate(_startTime),
              onTap: _chooseDate,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _tile(
              label: 'Time',
              icon: PhosphorIconsRegular.clock,
              value: l.formatTimeOfDay(TimeOfDay.fromDateTime(_startTime)),
              onTap: _chooseTime,
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(_relativeStart(),
              style: const TextStyle(fontSize: 13, color: AppTheme.muted)),
        ),
      ]);

  Widget _tile({
    required String label,
    required IconData icon,
    required String value,
    required VoidCallback onTap,
  }) =>
      Semantics(
        button: true,
        label: '$label, $value',
        excludeSemantics: true,
        child: PzPressScale(child: Material(
          color: AppTheme.surfaceRaised,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _saving ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 13, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(icon, size: 15, color: AppTheme.muted),
                    const SizedBox(width: 6),
                    Text(label,
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.muted,
                            fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 6),
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()])),
                ],
              ),
            ),
          ),
        )),
      );

  // Where ---------------------------------------------------------------------

  Widget _venueSection() => AnimatedSize(
        duration: _duration,
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: _duration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, if (current != null) current],
          ),
          child: _pickingVenue
              ? KeyedSubtree(
                  key: const ValueKey('picker'), child: _venuePicker())
              : KeyedSubtree(
                  key: const ValueKey('selected'), child: _selectedVenue()),
        ),
      );

  Widget _selectedVenue() {
    final (title, subtitle) = _splitLabel(_selectedArea.label);
    return _card(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      child: Row(children: [
        TweenAnimationBuilder<double>(
          key: ValueKey(_selectedArea.label),
          tween: Tween(begin: _reduceMotion ? 1 : .4, end: 1),
          duration: const Duration(milliseconds: 420),
          curve: Curves.elasticOut,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
                color: AppTheme.lime, shape: BoxShape.circle),
            child: const Icon(PhosphorIconsBold.check,
                color: Colors.black, size: 20),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16,
                      letterSpacing: -.3,
                      fontWeight: FontWeight.w700)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.muted)),
              ],
            ],
          ),
        ),
        TextButton(
          onPressed: _saving
              ? null
              : () {
                  unawaited(HapticFeedback.selectionClick());
                  setState(() => _pickingVenue = true);
                },
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.primaryText,
            backgroundColor: AppTheme.surfaceHighest,
            shape: const StadiumBorder(),
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            textStyle:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          child: const Text('Change'),
        ),
      ]),
    );
  }

  Widget _venuePicker() {
    final query = _query.text.trim();
    final searching = query.length >= 3;
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          child: Row(children: [
            const Icon(PhosphorIconsRegular.magnifyingGlass,
                size: 18, color: AppTheme.muted),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _query,
                enabled: !_saving,
                onChanged: _search,
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  hintText: 'Search a court, park or address',
                ),
              ),
            ),
            if (_searching)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.lime)),
              )
            else if (query.isNotEmpty)
              IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  _query.clear();
                  _search('');
                },
                icon: const Icon(PhosphorIconsFill.xCircle,
                    size: 18, color: AppTheme.muted),
              )
            else
              const SizedBox(height: 40),
          ]),
        ),
        const Divider(height: 1, thickness: 1, color: _line),
        if (searching) ...[
          for (final result in _results)
            _venueOption(result, icon: PhosphorIconsRegular.mapPinSimple),
          if (!_searching && _results.isEmpty)
            _message(_searchError ?? 'No matches. Try another name or drop a pin.'),
        ] else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 2),
            child: Row(children: [
              Expanded(
                child: Text('Nearby for $_sport',
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w600)),
              ),
              if (!_loadingPlaces)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Refresh nearby places',
                  onPressed: _saving ? null : _loadNearbyPlaces,
                  icon: const Icon(PhosphorIconsRegular.arrowClockwise,
                      size: 17, color: AppTheme.muted),
                )
              else
                const SizedBox(height: 40),
            ]),
          ),
          _venueOption(widget.area,
              title: 'Your location',
              icon: PhosphorIconsRegular.navigationArrow),
          if (_loadingPlaces)
            for (var i = 0; i < 3; i++) _skeletonRow()
          else if (_nearbyPlaces.isEmpty)
            _message(_placesError ?? 'No sports places found nearby yet.')
          else
            for (final place in _nearbyPlaces.take(5))
              _venueOption(place, icon: PhosphorIconsRegular.mapTrifold),
        ],
        const Divider(height: 1, thickness: 1, color: _line),
        PzPressScale(child: InkWell(
          onTap: _saving ? null : _pinOnMap,
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(22)),
          child: const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 14, 16),
            child: Row(children: [
              Icon(PhosphorIconsRegular.pushPinSimple, size: 19, color: AppTheme.lime),
              SizedBox(width: 12),
              Expanded(
                child: Text('Drop a pin on the map',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              Icon(PhosphorIconsRegular.caretRight,
                  size: 16, color: AppTheme.muted),
            ]),
          ),
        )),
      ]),
    );
  }

  Widget _venueOption(Area area, {String? title, required IconData icon}) {
    final (name, detail) = _splitLabel(area.label);
    final selected = _sameArea(area, _selectedArea);
    return Semantics(
      button: true,
      selected: selected,
      child: PzPressScale(child: InkWell(
        onTap: _saving ? null : () => _selectVenue(area),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 16, 10),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.surfaceHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  size: 17,
                  color: selected ? AppTheme.lime : AppTheme.primaryText),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title ?? name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  if ((title != null ? area.label : detail) != null)
                    Text(title != null ? area.label : detail!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.muted)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            PzCheckMark(selected: selected),
          ]),
        ),
      )),
    );
  }

  Widget _skeletonRow() => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.surfaceHighest,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bar(150),
                  const SizedBox(height: 7),
                  _bar(90),
                ]),
          ),
        ]),
      );

  Widget _bar(double width) => Container(
        width: width,
        height: 10,
        decoration: BoxDecoration(
          color: AppTheme.surfaceHighest,
          borderRadius: BorderRadius.circular(5),
        ),
      );

  Widget _message(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Text(text,
            style: const TextStyle(fontSize: 13, color: AppTheme.muted)),
      );

  // Players -------------------------------------------------------------------

  Widget _playersCard() => _card(
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Semantics(
                label: '$_players players including you',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSwitcher(
                      duration: _reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 160),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                            scale: Tween(begin: .85, end: 1.0)
                                .animate(animation),
                            child: child),
                      ),
                      child: Text('$_players',
                          key: ValueKey(_players),
                          style: const TextStyle(
                              fontFamily: 'Archivo', fontSize: 34,
                              height: 1,
                              letterSpacing: -.6,
                              fontWeight: FontWeight.w800,
                              fontFeatures: [FontFeature.tabularFigures()])),
                    ),
                    const SizedBox(height: 4),
                    const Text('players, including you',
                        style: TextStyle(fontSize: 13, color: AppTheme.muted)),
                  ],
                ),
              ),
            ),
            _stepButton(
              icon: PhosphorIconsBold.minus,
              tooltip: 'Remove a player',
              onPressed: _players > 2 ? () => _setPlayers(_players - 1) : null,
            ),
            const SizedBox(width: 10),
            _stepButton(
              icon: PhosphorIconsBold.plus,
              tooltip: 'Add a player',
              onPressed: _players < 40 ? () => _setPlayers(_players + 1) : null,
            ),
          ]),
          if ((sportFormats[_sport] ?? const []).isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, thickness: 1, color: _line),
            for (final local in const [true, false])
              if ((sportFormats[_sport] ?? const [])
                  .any((f) => f.local == local)) ...[
                const SizedBox(height: 14),
                Text(local ? 'Local formats' : 'Standard',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final format in sportFormats[_sport]!
                      .where((f) => f.local == local))
                    PzChoicePill(
                      label: '${format.name} · ${format.players}',
                      compact: true,
                      selected: _format == format.name,
                      onTap: _saving
                          ? null
                          : () => _setPlayers(format.players,
                              format: format.name),
                    ),
                ]),
              ],
          ],
        ]),
      );

  Widget _stepButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) =>
      IconButton(
        tooltip: tooltip,
        onPressed: _saving ? null : onPressed,
        style: IconButton.styleFrom(
          backgroundColor: AppTheme.surfaceHighest,
          foregroundColor: AppTheme.primaryText,
          disabledBackgroundColor: AppTheme.surfaceHighest.withValues(alpha: .4),
          disabledForegroundColor: AppTheme.muted,
          minimumSize: const Size(48, 48),
          shape: const CircleBorder(),
        ),
        icon: Icon(icon, size: 18),
      );

  // Fee -----------------------------------------------------------------------

  Widget _feeSection() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        PzSegmented(
          options: const ['Free', 'Paid'],
          selectedIndex: _paid ? 1 : 0,
          onChanged: _saving ? null : (index) => _setPaid(index == 1),
        ),
        AnimatedSize(
          duration: _duration,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !_paid
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceRaised,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _feeError != null
                              ? AppTheme.destructive
                              : Colors.transparent),
                    ),
                    child: Row(children: [
                      const Text('Rs',
                          style: TextStyle(
                              fontFamily: 'Archivo', fontSize: 28,
                              letterSpacing: -.4,
                              color: AppTheme.muted,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _fee,
                          enabled: !_saving,
                          autofocus: _fee.text.isEmpty,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          maxLength: 6,
                          onChanged: (_) => setState(() => _feeError = null),
                          style: const TextStyle(
                              fontFamily: 'Archivo', fontSize: 28,
                              letterSpacing: -.4,
                              fontWeight: FontWeight.w700,
                              fontFeatures: [FontFeature.tabularFigures()]),
                          decoration: const InputDecoration(
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            counterText: '',
                            hintText: '0',
                            hintStyle: TextStyle(color: Color(0xFF5A5A5E)),
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const Text('per player',
                          style: TextStyle(
                              fontSize: 13, color: AppTheme.muted)),
                    ]),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Semantics(
            liveRegion: _feeError != null,
            child: Text(
                _feeError ??
                    (_paid
                        ? 'Collected in person. PlayersZWZ doesn’t handle payments.'
                        : 'Anyone can join without paying.'),
                style: TextStyle(
                    fontSize: 13,
                    color: _feeError != null
                        ? AppTheme.destructive
                        : AppTheme.muted)),
          ),
        ),
      ]);

  // Note ----------------------------------------------------------------------

  Widget _noteField() => _card(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: TextField(
          controller: _notes,
          enabled: !_saving,
          maxLength: 280,
          minLines: 3,
          maxLines: 6,
          onChanged: (_) => setState(() {}),
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(fontSize: 15, height: 1.4),
          decoration: const InputDecoration(
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            hintText: 'Kit colours, parking, skill level…',
            contentPadding: EdgeInsets.only(top: 12),
          ),
        ),
      );

  // Footer --------------------------------------------------------------------

  Widget _footer(bool editing, MaterialLocalizations l) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: _line)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Semantics(
                liveRegion: true,
                child: Row(children: [
                  const Icon(PhosphorIconsFill.warningCircle,
                      size: 16, color: AppTheme.destructive),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                        style: const TextStyle(
                            color: AppTheme.destructive, fontSize: 13)),
                  ),
                ]),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(_summary(l),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppTheme.muted)),
            ),
          PressFeedback(
            enabled: !_saving,
            child: FilledButton(
              onPressed: _saving ? null : _create,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.lime,
                foregroundColor: Colors.black,
                disabledBackgroundColor: AppTheme.lime.withValues(alpha: .55),
                disabledForegroundColor: Colors.black,
                minimumSize: const Size.fromHeight(56),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                    fontSize: 17, letterSpacing: -.2, fontWeight: FontWeight.w700),
              ),
              child: _saving
                  ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                              color: Colors.black, strokeWidth: 2)),
                      const SizedBox(width: 10),
                      Text(editing ? 'Saving…' : 'Hosting…'),
                    ])
                  : Text(editing ? 'Save changes' : 'Host game'),
            ),
          ),
        ]),
      );
}

