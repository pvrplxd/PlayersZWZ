export 'create_game_screen.dart' show CreateGameScreen;
import 'dart:async';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'game_navigation_screen.dart';

import '../../app/playerszwz_app.dart';
import '../../core/api_client.dart';
import '../location/location_service.dart';
import '../../app/app_theme.dart';
import '../../core/ui/pz_controls.dart';
import '../discovery/discovery_widgets.dart';
import 'create_game_screen.dart';
import 'game_model.dart';
import 'game_service.dart';


class VenueMapPickerScreen extends StatefulWidget {
  const VenueMapPickerScreen({
    super.key,
    required this.area,
    required this.apiKey,
    required this.location,
  });

  final Area area;
  final String apiKey;
  final LocationService location;

  @override
  State<VenueMapPickerScreen> createState() => _VenueMapPickerScreenState();
}

class _VenueMapPickerScreenState extends State<VenueMapPickerScreen> {
  final MapController _map = MapController();
  late LatLng _center = LatLng(widget.area.latitude, widget.area.longitude);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  Future<void> _usePin() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final area =
          await widget.location.pin(_center.latitude, _center.longitude);
      if (mounted) Navigator.of(context).pop(area);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Could not set this pin. Please retry.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: appBackground,
        appBar: AppBar(
          title: const Text('Place a pin'),
          backgroundColor: appBackground,
          surfaceTintColor: Colors.transparent,
        ),
        body: Stack(children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 16,
              minZoom: 3,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              onTap: (_, point) {
                setState(() => _center = point);
                _map.move(point, _map.camera.zoom);
              },
              onPositionChanged: (camera, gesture) {
                if (gesture) _center = camera.center;
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://maps.geoapify.com/v1/tile/dark-matter/{z}/{x}/{y}.png?apiKey=${Uri.encodeQueryComponent(widget.apiKey)}',
                userAgentPackageName: 'com.playerszwz.app',
                maxNativeZoom: 20,
              ),
            ],
          ),
          IgnorePointer(
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(PhosphorIconsRegular.mapPin,
                    color: appAccent,
                    size: 42,
                    shadows: [
                      Shadow(
                          color: Colors.black87,
                          blurRadius: 8,
                          offset: Offset(0, 2))
                    ]),
                Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                        color: appAccent, shape: BoxShape.circle)),
              ]),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: MediaQuery.paddingOf(context).bottom + 16,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xF21D1D1D),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Colors.white24),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black54,
                      blurRadius: 24,
                      offset: Offset(0, 8))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Choose the exact spot',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),
                  const Text('Move the map until the pin is where you’ll play.',
                      style: TextStyle(color: Colors.white60, height: 1.35)),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: appError)),
                  ],
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: _saving ? null : _usePin,
                    style: FilledButton.styleFrom(
                      backgroundColor: appAccent,
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black))
                        : const Text('Use this location',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 8),
                  const Text('Map data © OpenStreetMap contributors · Geoapify',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: Colors.white54)),
                ],
              ),
            ),
          ),
        ]),
      );
}

class GameDetailsSheet extends StatefulWidget {
  const GameDetailsSheet({
    super.key,
    required this.game,
    required this.service,
    required this.userId,
    required this.apiKey,
    this.onChanged,
  });

  final Game game;
  final GameService service;
  final String userId;
  final String apiKey;
  final VoidCallback? onChanged;

  @override
  State<GameDetailsSheet> createState() => _GameDetailsSheetState();
}

class _GameDetailsSheetState extends State<GameDetailsSheet> {
  late Game _game = widget.game;
  bool _busy = false;
  String? _error;

  bool get _isHost => _game.organizerId == widget.userId;

  Future<void> _act({required bool join}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (join) {
        await widget.service.join(_game.id);
      } else {
        await widget.service.cancel(_game.id);
      }
      unawaited(HapticFeedback.selectionClick());
      final updated = await widget.service.details(_game.id);
      if (!mounted) return;
      setState(() => _game = updated);
      widget.onChanged?.call();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Could not update this game. Please retry.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requests() async {
    if (_busy) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => JoinRequestsSheet(game: _game, service: widget.service),
    );
    if (mounted) {
      try {
        setState(() => _busy = true);
        final updated = await widget.service.details(_game.id);
        if (mounted) setState(() => _game = updated);
        widget.onChanged?.call();
      } catch (_) {
        // The request sheet already reports its own load and update failures.
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  Future<void> _navigate() async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => GameNavigationScreen(game: _game, apiKey: widget.apiKey),
    ));
  }

  Future<void> _leaveGame() async {
    final approved = _game.participation == 'approved';
    final confirmed = await pzConfirm(
      context,
      title: approved ? 'Leave this game?' : 'Cancel your request?',
      message: approved
          ? 'Your spot will open for another player.'
          : 'You can request to join again while the game is open.',
      confirm: approved ? 'Leave game' : 'Cancel request',
      cancel: 'Keep my spot',
    );
    if (confirmed && mounted) await _act(join: false);
  }

  Future<void> _edit() async {
    if (_busy) return;
    final updated = await showModalBottomSheet<Game>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateGameScreen(
        api: widget.service.api,
        area: Area(
            _game.latitude, _game.longitude, _game.locationLabel, 'manual'),
        apiKey: widget.apiKey,
        initialGame: _game,
      ),
    );
    if (updated != null && mounted) {
      setState(() => _game = updated);
      widget.onChanged?.call();
    }
  }

  Future<void> _cancelGame() async {
    if (_busy) return;
    final confirmed = await pzConfirm(
      context,
      title: 'Cancel this game?',
      message:
          'Players will see that this game was cancelled. This cannot be undone.',
      confirm: 'Cancel game',
      cancel: 'Keep game',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.cancelGame(_game.id);
      final updated = await widget.service.details(_game.id);
      if (!mounted) return;
      setState(() => _game = updated);
      widget.onChanged?.call();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Could not cancel this game. Please retry.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool busy = false,
  }) =>
      FilledButton(
        onPressed: _busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.lime,
          foregroundColor: Colors.black,
          disabledBackgroundColor: AppTheme.surfaceHighest,
          disabledForegroundColor: AppTheme.muted,
          minimumSize: const Size.fromHeight(56),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        child: busy
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.black))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
      );

  Widget _secondaryButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool destructive = false,
  }) =>
      FilledButton(
        onPressed: _busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.surfaceRaised,
          foregroundColor:
              destructive ? AppTheme.destructive : AppTheme.primaryText,
          disabledBackgroundColor: AppTheme.surfaceRaised,
          disabledForegroundColor: AppTheme.muted,
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 17),
          const SizedBox(width: 8),
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
      );

  Widget _iconAction({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool destructive = false,
  }) =>
      Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Tooltip(
          message: label,
          child: PzPressScale(child: Material(
            color: destructive
                ? AppTheme.destructive.withValues(alpha: .14)
                : AppTheme.surfaceRaised,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _busy ? null : onPressed,
              child: SizedBox.square(
                dimension: 52,
                child: Icon(icon,
                    size: 19,
                    color: destructive
                        ? AppTheme.destructive
                        : AppTheme.primaryText),
              ),
            ),
          )),
        ),
      );

  Widget _fact(String label, String value) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 5),
          Text(value,
              maxLines: 2,
              style: const TextStyle(
                  fontSize: 15,
                  height: 1.2,
                  letterSpacing: -.3,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ]),
      );

  Widget _factDivider() => Container(
      width: 1, height: 36, margin: const EdgeInsets.symmetric(horizontal: 14), color: pzLine);

  List<Widget> _actions({
    required String status,
    required bool gameOpen,
    required bool canJoin,
    required bool canCancel,
    required String? participation,
  }) {
    final cancelled = _game.status == 'cancelled';
    final directions = _secondaryButton(
      label: 'Directions',
      icon: PhosphorIconsRegular.navigationArrow,
      onPressed: cancelled || widget.apiKey.isEmpty ? null : _navigate,
    );
    if (_isHost) {
      final editable = _game.status == 'open' || _game.status == 'full';
      return [
        _primaryButton(
          label: 'Review join requests',
          icon: PhosphorIconsRegular.usersThree,
          onPressed: cancelled ? null : _requests,
          busy: _busy,
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: directions),
          if (editable) ...[
            const SizedBox(width: 10),
            _iconAction(
                icon: PhosphorIconsRegular.pencilSimple,
                label: 'Edit game',
                onPressed: _edit),
            const SizedBox(width: 10),
            _iconAction(
                icon: PhosphorIconsRegular.trash,
                label: 'Cancel game',
                onPressed: _cancelGame,
                destructive: true),
          ],
        ]),
      ];
    }
    if (participation == 'approved') {
      return [
        _primaryButton(
          label: 'Get directions',
          icon: PhosphorIconsBold.navigationArrow,
          onPressed: cancelled || widget.apiKey.isEmpty ? null : _navigate,
        ),
        if (canCancel) ...[
          const SizedBox(height: 10),
          _secondaryButton(
              label: 'Leave game',
              icon: PhosphorIconsRegular.signOut,
              onPressed: _leaveGame,
              destructive: true),
        ],
      ];
    }
    final joinLabel = !gameOpen
        ? (status == 'Full' ? 'Game is full' : 'Not taking players')
        : switch (participation) {
            'pending' => 'Request sent',
            'rejected' => 'Request again',
            _ => 'Request to join',
          };
    return [
      _primaryButton(
        label: joinLabel,
        icon: participation == 'pending'
            ? PhosphorIconsRegular.hourglassMedium
            : PhosphorIconsBold.userPlus,
        onPressed: canJoin ? () => _act(join: true) : null,
        busy: _busy,
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: directions),
        if (canCancel) ...[
          const SizedBox(width: 10),
          Expanded(
            child: _secondaryButton(
                label: 'Cancel request',
                icon: PhosphorIconsRegular.x,
                onPressed: _leaveGame,
                destructive: true),
          ),
        ],
      ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final participation = _game.participation;
    final gameOpen =
        _game.status == 'open' && _game.startTime.isAfter(DateTime.now());
    final canJoin = gameOpen &&
        _game.openSpots > 0 &&
        (participation == null ||
            participation == 'rejected' ||
            participation == 'cancelled');
    final canCancel = gameOpen &&
        (participation == 'pending' ||
            (participation == 'approved' && !_isHost));
    final status = _game.status == 'cancelled'
        ? 'Cancelled'
        : !_game.startTime.isAfter(DateTime.now())
            ? 'Started'
            : _game.status == 'full' || _game.openSpots == 0
                ? 'Full'
                : _game.status == 'open'
                    ? 'Open'
                    : 'Closed';
    final tone = switch (status) {
      'Open' => PzTone.accent,
      'Cancelled' => PzTone.danger,
      _ => PzTone.neutral,
    };
    final (place, area) = pzSplitPlace(_game.locationLabel);
    final spots = _game.openSpots;
    final hostInitial = _game.organizerName.trim().isEmpty
        ? '?'
        : _game.organizerName.trim()[0].toUpperCase();

    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .9),
      child: PzSheetSurface(child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.only(top: 10, bottom: 6),
            child: PzGrabber(),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              children: [
                Row(children: [
                  PzStatusPill(_game.sport,
                      leading: SportSymbol.iconFor(_game.sport)),
                  const SizedBox(width: 8),
                  PzStatusPill(status, tone: tone),
                  const Spacer(),
                  PzCircleButton(
                    icon: PhosphorIconsBold.x,
                    label: 'Close',
                    size: 36,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ]),
                const SizedBox(height: 16),
                Text(place,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.title1),
                if (area != null) ...[
                  const SizedBox(height: 4),
                  Text(area,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, color: AppTheme.muted)),
                ],
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceRaised,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(children: [
                    _fact('When', pzWhen(context, _game.startTime)),
                    if (_game.distanceKm != null) ...[
                      _factDivider(),
                      _fact('Distance',
                          '${_game.distanceKm!.toStringAsFixed(1)} km'),
                    ],
                    _factDivider(),
                    _fact('Entry',
                        _game.feeAmount == 0 ? 'Free' : 'Rs. ${_game.feeAmount}'),
                  ]),
                ),
                const SizedBox(height: 24),
                PzSectionTitle('Players',
                    trailing: Text(
                        spots == 0
                            ? 'Full'
                            : '$spots ${spots == 1 ? 'spot' : 'spots'} left',
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.muted,
                            fontWeight: FontWeight.w600))),
                const SizedBox(height: 12),
                PzCapacityBar(
                    filled: _game.approvedCount, total: _game.requiredPlayers),
                const SizedBox(height: 8),
                Text(
                    '${_game.approvedCount} of ${_game.requiredPlayers} players have joined',
                    style: const TextStyle(fontSize: 13, color: AppTheme.muted)),
                const SizedBox(height: 24),
                Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                        color: AppTheme.surfaceHighest, shape: BoxShape.circle),
                    child: Text(hostInitial,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Hosted by',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.muted)),
                        const SizedBox(height: 2),
                        Text(_game.organizerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  if (_isHost) const PzStatusPill('You'),
                ]),
                if (_game.notes.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const PzSectionTitle('Note from the host'),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceRaised,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_game.notes,
                        style: const TextStyle(fontSize: 15, height: 1.45)),
                  ),
                ],
                if (_game.feeAmount > 0) ...[
                  const SizedBox(height: 12),
                  const Text('Fees are paid to the host in person.',
                      style: TextStyle(fontSize: 12, color: AppTheme.muted)),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
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
                                  color: AppTheme.destructive, fontSize: 13))),
                    ]),
                  ),
                ),
              ..._actions(
                status: status,
                gameOpen: gameOpen,
                canJoin: canJoin,
                canCancel: canCancel,
                participation: participation,
              ),
            ]),
          ),
        ]),
      )),);
  }
}

class JoinRequestsSheet extends StatefulWidget {
  const JoinRequestsSheet(
      {super.key, required this.game, required this.service});
  final Game game;
  final GameService service;

  @override
  State<JoinRequestsSheet> createState() => _JoinRequestsSheetState();
}

class _JoinRequestsSheetState extends State<JoinRequestsSheet> {
  List<GameJoinRequest>? _requests;
  final Set<String> _reviewing = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final requests = await widget.service.requests(widget.game.id);
      if (mounted) setState(() => _requests = requests);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Could not load requests. Please retry.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _review(GameJoinRequest request, bool approve) async {
    if (_reviewing.contains(request.id) || _loading) return;
    setState(() {
      _reviewing.add(request.id);
      _error = null;
    });
    try {
      if (!approve) {
        final confirmed = await _confirmReject(request);
        if (confirmed != true || !mounted) return;
      }
      await widget.service.review(request.id, approve: approve);
      unawaited(HapticFeedback.mediumImpact());
      if (mounted) {
        setState(() {
          _requests =
              _requests?.where((pending) => pending.id != request.id).toList();
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not update that request.');
    } finally {
      if (mounted) setState(() => _reviewing.remove(request.id));
    }
  }

  Future<bool?> _confirmReject(GameJoinRequest request) => pzConfirm(context,
      title: 'Decline this request?',
      message: '${request.name} will need to request again to join.',
      confirm: 'Decline',
      cancel: 'Keep request');

  @override
  Widget build(BuildContext context) {
    final count = _requests?.length ?? 0;
    final (place, _) = pzSplitPlace(widget.game.locationLabel);
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .85),
      child: PzSheetSurface(child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
              padding: EdgeInsets.only(top: 10), child: PzGrabber()),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 14, 4),
            child: Row(children: [
              const Text('Join requests',
                  style: TextStyle(
                      fontFamily: 'Archivo', fontSize: 24,
                      letterSpacing: -.6,
                      fontWeight: FontWeight.w800)),
              if (count > 0) ...[
                const SizedBox(width: 10),
                PzStatusPill('$count', tone: PzTone.accent),
              ],
              const Spacer(),
              PzCircleButton(
                icon: PhosphorIconsBold.x,
                label: 'Close',
                size: 36,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${widget.game.sport} · $place',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: AppTheme.muted)),
            ),
          ),
          if (_loading)
            const SizedBox(
                height: 180,
                child: Center(
                    child: CircularProgressIndicator(color: AppTheme.lime)))
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: PzEmptyState(
                icon: PhosphorIconsRegular.wifiSlash,
                title: 'Couldn’t load requests',
                message: _error!,
                actionLabel: 'Try again',
                onAction: _load,
              ),
            )
          else if (count == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: PzEmptyState(
                icon: PhosphorIconsRegular.userPlus,
                title: 'No requests yet',
                message:
                    'When players ask to join this game, they’ll show up here for you to approve.',
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: count,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _requestCard(_requests![index]),
              ),
            ),
        ]),
      )),);
  }

  Widget _requestCard(GameJoinRequest request) {
    final reviewing = _reviewing.contains(request.id);
    final sport = widget.game.sport;
    final roles = request.roles[sport] ?? const <String>[];
    final level = request.levels[sport];
    final detail = [
      if (roles.isNotEmpty) roles.join(' · '),
      if (level != null) level,
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
                color: AppTheme.surfaceHighest, shape: BoxShape.circle),
            child: Text(
                request.name.trim().isEmpty
                    ? '?'
                    : request.name.trim()[0].toUpperCase(),
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(request.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                  detail.isNotEmpty
                      ? '$sport · $detail'
                      : request.sports.isEmpty
                          ? 'Player'
                          : 'Plays ${request.sports.join(', ')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppTheme.muted)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: _reviewAction(
              approve: false,
              enabled: !reviewing && !_loading,
              busy: false,
              onPressed: () => _review(request, false),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _reviewAction(
              approve: true,
              enabled: !reviewing && !_loading,
              busy: reviewing,
              onPressed: () => _review(request, true),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _reviewAction({
    required bool approve,
    required bool enabled,
    required bool busy,
    required VoidCallback onPressed,
  }) =>
      FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: approve ? AppTheme.lime : AppTheme.surfaceHighest,
          foregroundColor: approve ? Colors.black : AppTheme.primaryText,
          disabledBackgroundColor:
              (approve ? AppTheme.lime : AppTheme.surfaceHighest)
                  .withValues(alpha: .5),
          minimumSize: const Size.fromHeight(46),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        child: busy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.black))
            : Text(approve ? 'Approve' : 'Decline'),
      );
}
