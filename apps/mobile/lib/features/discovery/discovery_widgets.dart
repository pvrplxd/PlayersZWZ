// discovery_widgets.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../app/app_theme.dart';
import '../../core/ui/pz_controls.dart';
import '../games/game_model.dart';

class SportSymbol extends StatelessWidget {
  const SportSymbol(this.sport, {super.key, this.size = 18, this.color});
  final String sport;
  final double size;
  final Color? color;

  static IconData iconFor(String sport) => switch (sport.toLowerCase()) {
        'football' => PhosphorIconsRegular.soccerBall,
        'basketball' => PhosphorIconsRegular.basketball,
        'badminton' || 'tennis' => PhosphorIconsRegular.tennisBall,
        'cricket' => PhosphorIconsRegular.cricket,
        'skating' => PhosphorIconsRegular.personSimpleRun,
        _ => PhosphorIconsRegular.trophy,
      };

  static IconData boldIconFor(String sport) => switch (sport.toLowerCase()) {
        'football' => PhosphorIconsBold.soccerBall,
        'basketball' => PhosphorIconsBold.basketball,
        'badminton' || 'tennis' => PhosphorIconsBold.tennisBall,
        'cricket' => PhosphorIconsBold.cricket,
        'skating' => PhosphorIconsBold.personSimpleRun,
        _ => PhosphorIconsBold.trophy,
      };

  @override
  Widget build(BuildContext context) {
    final tone = color ?? IconTheme.of(context).color ?? Colors.white;
    return Icon(iconFor(sport), size: size, color: tone);
  }
}

typedef PhotoLoader = Future<Uint8List?> Function(GamePlayer player);

/// Round player photo; initials on a muted tone when there is no photo.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.player,
    this.loader,
    this.size = 22,
    this.ring = AppTheme.surfaceRaised,
  });

  final GamePlayer player;
  final PhotoLoader? loader;
  final double size;
  final Color ring;

  static const _tones = [
    Color(0xFF3A3F2A),
    Color(0xFF2A3540),
    Color(0xFF402F2A),
    Color(0xFF33294A),
    Color(0xFF283F38),
  ];

  @override
  Widget build(BuildContext context) {
    final tone = _tones[player.userId.hashCode.abs() % _tones.length];
    final initials = Center(
      child: Text(player.initials,
          style: TextStyle(
              fontSize: size * .4,
              height: 1,
              letterSpacing: 0,
              fontWeight: FontWeight.w700,
              color: Colors.white)),
    );
    Widget content = initials;
    if (player.hasPhoto && loader != null) {
      content = FutureBuilder<Uint8List?>(
        future: loader!(player),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null) return initials;
          return Image.memory(bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              cacheWidth: (size * 3).round(),
              frameBuilder: (context, child, frame, sync) => AnimatedOpacity(
                    opacity: sync || frame != null ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: child,
                  ));
        },
      );
    }
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(color: ring, shape: BoxShape.circle),
      child: ClipOval(child: ColoredBox(color: tone, child: content)),
    );
  }
}

/// Overlapping player photos with a "+N" counter for the rest.
class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.players,
    required this.total,
    this.loader,
    this.size = 22,
    this.ring = AppTheme.surfaceRaised,
  });

  final List<GamePlayer> players;
  final int total;
  final PhotoLoader? loader;
  final double size;
  final Color ring;

  @override
  Widget build(BuildContext context) {
    final shown = players.take(3).toList();
    final extra = total - shown.length;
    final items = <Widget>[
      for (final player in shown)
        PlayerAvatar(player: player, loader: loader, size: size, ring: ring),
      if (extra > 0)
        Container(
          height: size,
          constraints: BoxConstraints(minWidth: size),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: AppTheme.surfaceHighest,
            borderRadius: BorderRadius.circular(size),
            border: Border.all(color: ring, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text('+$extra',
              style: TextStyle(
                  fontSize: size * .42,
                  height: 1,
                  letterSpacing: 0,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryText)),
        ),
    ];
    final step = size * .68;
    final extraWidth = extra > 0 ? (extra >= 10 ? size + 8 : size) : 0.0;
    final width = shown.isEmpty
        ? extraWidth
        : step * (shown.length - 1) + size + (extra > 0 ? step - size + extraWidth : 0);
    return SizedBox(
      width: width,
      height: size,
      child: Stack(children: [
        for (var i = 0; i < items.length; i++)
          Positioned(left: step * i, top: 0, bottom: 0, child: items[i]),
      ]),
    );
  }
}

/// Map bubble for a game: sport, place, time and fee, players, Open/Full,
/// with a rounded pointer that sits on the exact location.
class GameMapMarker extends StatelessWidget {
  const GameMapMarker({
    super.key,
    required this.game,
    required this.onTap,
    this.loader,
  });

  final Game game;
  final VoidCallback onTap;
  final PhotoLoader? loader;

  static const width = 244.0;
  static const height = 92.0;
  static const _tail = 9.0;
  static const _fill = Color(0xF5161618);

  @override
  Widget build(BuildContext context) {
    final full = game.openSpots <= 0 || game.status == 'full';
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(game.startTime));
    final fee = game.feeAmount == 0 ? 'Free' : 'Rs ${game.feeAmount}';
    final (place, _) = pzSplitPlace(game.locationLabel);
    final onlyHost = game.approvedCount <= 1;
    return Semantics(
      button: true,
      label: '${game.sport} at $place, $time, $fee, '
          '${full ? 'full' : '${game.openSpots} spots open'}, '
          '${game.approvedCount} of ${game.requiredPlayers} players',
      excludeSemantics: true,
      child: PzPressable(
        onTap: onTap,
        scale: .95,
        child: CustomPaint(
          painter: const _BubblePainter(fill: _fill, tail: _tail),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 12, 10 + _tail),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: ShapeDecoration(
                  color: full ? AppTheme.surfaceHighest : AppTheme.lime,
                  shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Icon(SportSymbol.boldIconFor(game.sport),
                    size: 22, color: full ? AppTheme.muted : Colors.black),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(game.sport,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14,
                                height: 1.15,
                                letterSpacing: -.2,
                                fontWeight: FontWeight.w600)),
                      ),
                      _Tag(full: full),
                    ]),
                    const SizedBox(height: 1),
                    Text(place,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, height: 1.2, color: AppTheme.muted)),
                    const SizedBox(height: 5),
                    Row(children: [
                      Expanded(
                        child: Text('$time · $fee',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12,
                                height: 1.1,
                                fontWeight: FontWeight.w600,
                                fontFeatures: [FontFeature.tabularFigures()])),
                      ),
                      if (onlyHost)
                        const Padding(
                          padding: EdgeInsets.only(right: 5),
                          child: Text('Be first',
                              style: TextStyle(
                                  fontSize: 11,
                                  height: 1,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.lime)),
                        ),
                      AvatarStack(
                        players: game.players,
                        total: game.approvedCount,
                        loader: loader,
                        size: 20,
                        ring: const Color(0xFF161618),
                      ),
                    ]),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.full});
  final bool full;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
        decoration: BoxDecoration(
          color: full
              ? AppTheme.surfaceHighest
              : AppTheme.lime.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(full ? 'Full' : 'Open',
            style: TextStyle(
                fontSize: 10.5,
                height: 1.1,
                letterSpacing: .1,
                fontWeight: FontWeight.w700,
                color: full ? AppTheme.muted : AppTheme.lime)),
      );
}

/// Several games too close to show separately at this zoom.
class GameClusterMarker extends StatelessWidget {
  const GameClusterMarker({super.key, required this.games, required this.onTap});
  final List<Game> games;
  final VoidCallback onTap;

  static const width = 132.0;
  static const height = 58.0;

  @override
  Widget build(BuildContext context) {
    final sports = games.map((g) => g.sport).toSet().take(3).toList();
    return Semantics(
      button: true,
      label: '${games.length} games here. Zoom in',
      excludeSemantics: true,
      child: PzPressable(
        onTap: onTap,
        scale: .94,
        child: CustomPaint(
          painter: const _BubblePainter(fill: GameMapMarker._fill, tail: 8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 16),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: 30.0 + (sports.length - 1) * 18,
                height: 34,
                child: Stack(children: [
                  for (var i = 0; i < sports.length; i++)
                    Positioned(
                      left: i * 18.0,
                      top: 2,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppTheme.lime,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF161618), width: 2),
                        ),
                        child: Icon(SportSymbol.boldIconFor(sports[i]),
                            size: 14, color: Colors.black),
                      ),
                    ),
                ]),
              ),
              const SizedBox(width: 8),
              Text('${games.length} games',
                  style: const TextStyle(
                      fontSize: 13, letterSpacing: -.1, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Rounded card with a soft, rounded pointer centred on the bottom edge.
class _BubblePainter extends CustomPainter {
  const _BubblePainter({required this.fill, required this.tail});
  final Color fill;
  final double tail;

  Path _path(Size size) {
    final body = Rect.fromLTWH(0, 0, size.width, size.height - tail);
    final cx = size.width / 2;
    const half = 10.0;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(body, const Radius.circular(20)));
    final pointer = Path()
      ..moveTo(cx - half, body.bottom - 1)
      ..quadraticBezierTo(cx - half * .45, body.bottom, cx - 2.2, size.height - 1.6)
      ..quadraticBezierTo(cx, size.height + .4, cx + 2.2, size.height - 1.6)
      ..quadraticBezierTo(cx + half * .45, body.bottom, cx + half, body.bottom - 1)
      ..close();
    return Path.combine(PathOperation.union, path, pointer);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _path(size);
    canvas.drawShadow(path, Colors.black, 10, false);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .7
          ..color = const Color(0x1FFFFFFF));
  }

  @override
  bool shouldRepaint(_BubblePainter old) => old.fill != fill || old.tail != tail;
}
