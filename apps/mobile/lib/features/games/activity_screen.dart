import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_theme.dart';
import '../../core/api_client.dart';
import '../../core/native/native_ui.dart';
import '../../core/ui/pz_controls.dart';
import '../discovery/discovery_widgets.dart';
import 'game_model.dart';
import 'game_screens.dart';
import 'game_service.dart';
import 'game_navigation_screen.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({
    super.key,
    required this.service,
    required this.userId,
    required this.apiKey,
    this.bottomSpace = 0,
    this.onCreate,
  });

  /// Opens Host a game; returns once the sheet closes.
  final Future<void> Function()? onCreate;

  final GameService service;
  final String userId;
  final String apiKey;

  /// Space reserved for the app's tab bar below the list.
  final double bottomSpace;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  static const _tabs = ['Upcoming', 'Hosting', 'Past'];
  int _tab = 0;
  Map<String, List<Game>> _activity = const {};
  bool _loading = true;
  String? _error;

  /// Past games hidden by swiping, for this session.
  final _hidden = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await widget.service.activity();
      if (mounted) setState(() => _activity = data);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Could not load your activity. Please retry.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Game> get _upcoming {
    final games = [
      ...?_activity['hosted'],
      ...?_activity['joined'],
    ]
        .where((game) =>
            game.status != 'cancelled' &&
            game.startTime.isAfter(DateTime.now()))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return games;
  }

  List<Game> get _games => switch (_tab) {
        0 => _upcoming,
        1 => (_activity['hosted'] ?? const [])
            .where((game) =>
                game.status != 'cancelled' &&
                game.startTime.isAfter(DateTime.now()))
            .toList(),
        _ => (_activity['history'] ?? const [])
            .where((game) => !_hidden.contains(game.id))
            .toList(),
      };

  bool _hosting(Game game) =>
      game.participation == 'hosted' || game.organizerId == widget.userId;

  Future<void> _leaveOrCancel(Game game) async {
    final hosting = _hosting(game);
    final pending = game.participation == 'pending';
    final ok = await pzConfirm(
      context,
      title: hosting
          ? 'Cancel this game?'
          : pending
              ? 'Cancel your request?'
              : 'Leave this game?',
      message: hosting
          ? 'Players will see that this game was cancelled. This cannot be undone.'
          : pending
              ? 'You can request to join again while the game is open.'
              : 'Your spot will open for another player.',
      confirm: hosting
          ? 'Cancel game'
          : pending
              ? 'Cancel request'
              : 'Leave game',
      cancel: hosting ? 'Keep game' : 'Keep my spot',
    );
    if (!ok || !mounted) return;
    try {
      if (hosting) {
        await widget.service.cancelGame(game.id);
      } else {
        await widget.service.cancel(game.id);
      }
      unawaited(HapticFeedback.mediumImpact());
      await _load(quiet: true);
    } on ApiException catch (error) {
      _toast(error.message);
    } catch (_) {
      _toast('Could not update this game. Please retry.');
    }
  }

  /// Tap-and-hold menu: native glass action sheet on iOS.
  Future<void> _menu(Game game, Rect anchor) async {
    final past = _tab == 2 || game.status == 'cancelled';
    final hosting = _hosting(game);
    final items = <(PzAction, VoidCallback)>[
      (const PzAction('Details', icon: PhosphorIconsRegular.info), () => _open(game)),
      if (!past && widget.apiKey.isNotEmpty)
        (const PzAction('Directions', icon: PhosphorIconsRegular.navigationArrow),
            () => _navigate(game)),
      if (!past)
        (
          PzAction(
              hosting
                  ? 'Cancel game'
                  : game.participation == 'pending'
                      ? 'Cancel request'
                      : 'Leave game',
              icon: hosting ? PhosphorIconsRegular.xCircle : PhosphorIconsRegular.signOut,
              destructive: true),
          () => _leaveOrCancel(game)
        )
      else
        (const PzAction('Hide from Past', icon: PhosphorIconsRegular.eyeSlash, destructive: true),
            () => setState(() => _hidden.add(game.id))),
    ];
    final (place, _) = pzSplitPlace(game.locationLabel);
    final choice = await pzMenu(context,
        anchor: anchor,
        title: '${game.sport} · $place',
        actions: [for (final i in items) i.$1]);
    if (choice != null && mounted) items[choice].$2();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _create() async {
    await widget.onCreate?.call();
    if (mounted) await _load(quiet: true);
  }

  void _selectTab(int index) {
    if (index == _tab) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _tab = index);
  }

  String _statusFor(Game game) {
    if (game.status == 'cancelled') return 'Cancelled';
    if (_tab == 1 || game.participation == 'hosted') return 'Hosting';
    if (_tab == 2) return 'Played';
    return switch (game.participation) {
      'pending' => 'Request sent',
      'approved' => 'Joined',
      'rejected' => 'Declined',
      'cancelled' => 'Left',
      _ => game.status == 'full' ? 'Full' : 'Open',
    };
  }

  Future<void> _open(Game game) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .5),
      builder: (_) => GameDetailsSheet(
        game: game,
        service: widget.service,
        userId: widget.userId,
        apiKey: widget.apiKey,
        onChanged: _load,
      ),
    );
  }

  void _navigate(Game game) {
    if (widget.apiKey.isEmpty) return;
    Navigator.of(context).push(CupertinoPageRoute<void>(
      builder: (_) => GameNavigationScreen(game: game, apiKey: widget.apiKey),
    ));
  }

  Widget _activityTabs() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: PzSegmented(
          options: _tabs,
          selectedIndex: _tab,
          height: 44,
          onChanged: _selectTab,
        ),
      );

  PzTone _toneFor(String status) => switch (status) {
        'Joined' => PzTone.accent,
        'Cancelled' || 'Declined' || 'Left' => PzTone.danger,
        _ => PzTone.neutral,
      };

  String _feeLabel(Game game) =>
      game.feeAmount == 0 ? 'Free' : 'Rs. ${game.feeAmount}';

  Widget _upcomingHero(Game game) {
    final (place, area) = pzSplitPlace(game.locationLabel);
    final soon = game.startTime.difference(DateTime.now()).inMinutes <= 60;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: AppTheme.lime,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.black, borderRadius: BorderRadius.circular(99)),
            child: Text('Next up · ${_statusFor(game)}',
                style: const TextStyle(
                    color: AppTheme.lime,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
          const Spacer(),
          if (soon) ...[
            Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: Colors.black, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          Text(pzCountdown(game.startTime),
              style: const TextStyle(
                  color: Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ]),
        const SizedBox(height: 22),
        Row(children: [
          SportSymbol(game.sport, size: 16, color: Colors.black),
          const SizedBox(width: 6),
          Text(game.sport,
              style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        Text(place,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.black,
                fontFamily: 'Archivo', fontSize: 28,
                height: 1.08,
                letterSpacing: -.6,
                fontWeight: FontWeight.w800)),
        if (area != null) ...[
          const SizedBox(height: 2),
          Text(area,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 12),
        Text(pzWhen(context, game.startTime),
            style: const TextStyle(
                color: Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 18),
        PzCapacityBar(
          filled: game.approvedCount,
          total: game.requiredPlayers,
          color: Colors.black,
          track: Colors.black.withValues(alpha: .14),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Text('${game.approvedCount} of ${game.requiredPlayers} joined',
              style: const TextStyle(
                  color: Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          Text(
              game.feeAmount == 0
                  ? 'Free'
                  : 'Rs. ${game.feeAmount} / player',
              style: const TextStyle(
                  color: Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
            child: FilledButton(
              onPressed: () => _open(game),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: .1),
                foregroundColor: Colors.black,
                minimumSize: const Size(0, 48),
                shape: const StadiumBorder(),
                textStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              child: const Text('Details'),
            ),
          ),
          if (widget.apiKey.isNotEmpty) ...[
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _navigate(game),
                icon: const Icon(PhosphorIconsBold.navigationArrow, size: 16),
                label: const Text('Directions'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: AppTheme.lime,
                  minimumSize: const Size(0, 48),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ]),
      ]),
    );
  }

  Widget _activityCard(Game game) {
    final (place, _) = pzSplitPlace(game.locationLabel);
    final status = _statusFor(game);
    final past = _tab == 2 || game.status == 'cancelled';
    final hosting = _hosting(game);
    final fill = game.requiredPlayers <= 0
        ? 0.0
        : (game.approvedCount / game.requiredPlayers).clamp(0.0, 1.0);
    final card = Builder(builder: (cardContext) => PzCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
      onTap: () => _open(game),
      onLongPress: () => _menu(game, pzRectOf(cardContext)),
      child: Column(children: [
        Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: ShapeDecoration(
              color: past
                  ? AppTheme.surfaceHighest
                  : AppTheme.lime.withValues(alpha: .13),
              shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Icon(SportSymbol.boldIconFor(game.sport),
                size: 21, color: past ? AppTheme.muted : AppTheme.lime),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(place,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.headline),
                const SizedBox(height: 2),
                Text('${game.sport} · ${pzWhen(context, game.startTime)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.footnote),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PzStatusPill(status, tone: _toneFor(status)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: Stack(children: [
                Container(height: 4, color: AppTheme.surfaceHighest),
                FractionallySizedBox(
                  widthFactor: fill,
                  child: Container(
                      height: 4, color: past ? AppTheme.muted : AppTheme.lime),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 12),
          Text('${game.approvedCount}/${game.requiredPlayers}',
              style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w500,
                  fontFeatures: [FontFeature.tabularFigures()])),
          const SizedBox(width: 10),
          Text(_feeLabel(game),
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ]),
    ));

    return PzSwipeAction(
      key: ValueKey('swipe-${game.id}'),
      label: past
          ? 'Hide'
          : hosting
              ? 'Cancel'
              : 'Leave',
      icon: past
          ? PhosphorIconsBold.eyeSlash
          : hosting
              ? PhosphorIconsBold.xCircle
              : PhosphorIconsBold.signOut,
      color: past ? const Color(0xFF3A3A3E) : AppTheme.destructive,
      onAction: () async {
        if (past) {
          HapticFeedback.mediumImpact();
          setState(() => _hidden.add(game.id));
        } else {
          await _leaveOrCancel(game);
        }
      },
      child: card,
    );
  }

  Widget _content() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.lime));
    }
    if (_error != null) {
      return PzEmptyState(
        icon: PhosphorIconsRegular.wifiSlash,
        title: 'Couldn’t load activity',
        message: _error!,
        actionLabel: 'Try again',
        onAction: _load,
      );
    }
    final games = _games;
    if (games.isEmpty) {
      return PzEmptyState(
        icon: switch (_tab) {
          1 => PhosphorIconsRegular.flag,
          2 => PhosphorIconsRegular.clockCounterClockwise,
          _ => PhosphorIconsRegular.lightning,
        },
        title: switch (_tab) {
          0 => 'No games coming up',
          1 => 'You’re not hosting yet',
          _ => 'No past games',
        },
        message: switch (_tab) {
          0 => 'Join a game on Explore or host your own.',
          1 => 'Tap + on Explore to host a game nearby.',
          _ => 'Games you’ve played will show up here.',
        },
      );
    }
    return RefreshIndicator.adaptive(
      color: AppTheme.lime,
      onRefresh: () => _load(quiet: true),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: EdgeInsets.fromLTRB(20, 16, 20, widget.bottomSpace + 20),
        itemCount: games.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _StaggerIn(
          index: index,
          child: _tab == 0 && index == 0
              ? _upcomingHero(games.first)
              : _activityCard(games[index]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        bottom: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 14, 18),
            child: Row(children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text('Activity', style: AppTheme.screenTitle(context)),
                ),
              ),
              if (widget.onCreate != null)
                NativeGlassButton(
                  icon: PhosphorIconsBold.plus,
                  label: 'Host a game',
                  prominent: true,
                  iconSize: 19,
                  onTap: _create,
                ),
            ]),
          ),
          _activityTabs(),
          Expanded(
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              child: KeyedSubtree(
                  key: ValueKey('$_tab-$_loading-${_error != null}'),
                  child: _content()),
            ),
          ),
        ]),
      );
}

/// List rows rise in with a short stagger on first build.
class _StaggerIn extends StatelessWidget {
  const _StaggerIn({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context) || index > 8) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + index * 45),
      curve: Interval(index * .08 / (1 + index * .08), 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
      ),
    );
  }
}
