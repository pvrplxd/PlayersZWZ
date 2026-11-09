import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../app/app_theme.dart';

/// Shared PlayersZWZ controls. Lime marks selection or the primary action only.

const pzLine = AppTheme.line;

bool _reduced(BuildContext context) => MediaQuery.disableAnimationsOf(context);

/// Sentence-case section title with an optional "Optional" tag.
class PzSectionTitle extends StatelessWidget {
  const PzSectionTitle(this.title, {super.key, this.optional = false, this.trailing});
  final String title;
  final bool optional;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        child: Row(children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16, letterSpacing: -.3, fontWeight: FontWeight.w700)),
          if (optional)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text('Optional',
                  style: TextStyle(
                      fontSize: 13, color: AppTheme.muted, fontWeight: FontWeight.w500)),
            ),
          const Spacer(),
          if (trailing != null) trailing!,
        ]),
      );
}

/// Single- or multi-choice pill.
class PzChoicePill extends StatelessWidget {
  const PzChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
    this.compact = false,
    this.fill = AppTheme.surfaceRaised,
  });

  final String label;
  final bool selected, compact;
  final Widget? leading;
  final VoidCallback? onTap;

  /// Unselected background; use [AppTheme.surfaceHighest] inside cards.
  final Color fill;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: PzPressable(
          scale: .94,
          haptic: false,
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          child: AnimatedContainer(
            duration: _reduced(context) ? Duration.zero : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: compact ? 34 : 40,
            padding: EdgeInsets.symmetric(horizontal: compact ? 13 : 15),
            decoration: BoxDecoration(
              color: selected ? AppTheme.lime : fill,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (leading != null) ...[leading!, const SizedBox(width: 7)],
              Text(label,
                  style: TextStyle(
                      fontSize: compact ? 13 : 14,
                      letterSpacing: -.1,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? Colors.black : AppTheme.primaryText)),
            ]),
          ),
        ),
      );
}

/// Ring that fills with a lime tick when selected.
class PzCheckMark extends StatelessWidget {
  const PzCheckMark({super.key, required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: _reduced(context) ? Duration.zero : const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutBack,
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: selected
            ? Container(
                key: const ValueKey(true),
                width: 24,
                height: 24,
                decoration: const BoxDecoration(color: AppTheme.lime, shape: BoxShape.circle),
                child: const Icon(PhosphorIconsBold.check, size: 14, color: Colors.black),
              )
            : Container(
                key: const ValueKey(false),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF48484A), width: 1.5),
                ),
              ),
      );
}

/// Segmented control with a glass thumb (like the iOS 26 tab bar selector).
/// Tap a segment, or drag the thumb; it stretches slightly while held and
/// springs onto the nearest option.
class PzSegmented extends StatefulWidget {
  const PzSegmented({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
    this.icons,
    this.height = 48,
    this.track = AppTheme.surfaceRaised,
  });

  final List<String> options;
  final List<IconData>? icons;
  final int selectedIndex;
  final ValueChanged<int>? onChanged;
  final double height;
  final Color track;

  @override
  State<PzSegmented> createState() => _PzSegmentedState();
}

class _PzSegmentedState extends State<PzSegmented> {
  double? _drag; // thumb left while dragging
  bool _held = false;

  int get _count => widget.options.length;

  void _select(int i) {
    if (widget.onChanged == null || i == widget.selectedIndex) return;
    HapticFeedback.selectionClick();
    widget.onChanged!(i);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = _reduced(context);
    final compact = MediaQuery.sizeOf(context).height < 700;
    final height = compact ? widget.height - 4 : widget.height;
    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: widget.track,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0x0FFFFFFF), width: .6),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth / _count;
        final restLeft = width * widget.selectedIndex;
        final left = _drag ?? restLeft;
        final hovered = ((left + width / 2) / width).floor().clamp(0, _count - 1);
        final enabled = widget.onChanged != null;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _held = true) : null,
          onTapCancel: () => setState(() => _held = false),
          onTapUp: enabled
              ? (d) {
                  setState(() => _held = false);
                  _select((d.localPosition.dx / width).floor().clamp(0, _count - 1));
                }
              : null,
          onHorizontalDragStart: enabled
              ? (d) => setState(() {
                    _held = true;
                    _drag = restLeft;
                  })
              : null,
          onHorizontalDragUpdate: enabled
              ? (d) {
                  final next = ((_drag ?? restLeft) + d.delta.dx)
                      .clamp(0.0, constraints.maxWidth - width);
                  final before = (((_drag ?? restLeft) + width / 2) / width).floor();
                  final after = ((next + width / 2) / width).floor();
                  if (before != after) HapticFeedback.selectionClick();
                  setState(() => _drag = next);
                }
              : null,
          onHorizontalDragEnd: enabled
              ? (_) {
                  final target = hovered;
                  setState(() {
                    _drag = null;
                    _held = false;
                  });
                  if (target != widget.selectedIndex) widget.onChanged!(target);
                }
              : null,
          child: Stack(children: [
            AnimatedPositioned(
              duration: reduce || _drag != null
                  ? Duration.zero
                  : const Duration(milliseconds: 480),
              curve: pzSpring,
              left: left,
              top: 0,
              bottom: 0,
              width: width,
              child: AnimatedScale(
                scale: _held ? 1.06 : 1,
                duration: Duration(milliseconds: reduce ? 0 : 200),
                curve: Curves.easeOut,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(99)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x3DFFFFFF), Color(0x1FFFFFFF)],
                    ),
                    border: Border.fromBorderSide(
                        BorderSide(color: Color(0x2EFFFFFF), width: .7)),
                    boxShadow: [
                      BoxShadow(
                          color: Color(0x59000000),
                          blurRadius: 10,
                          offset: Offset(0, 3)),
                    ],
                  ),
                ),
              ),
            ),
            Row(children: [
              for (var i = 0; i < _count; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == widget.selectedIndex,
                    label: widget.options[i],
                    excludeSemantics: true,
                    onTap: enabled ? () => _select(i) : null,
                    child: Center(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (widget.icons != null) ...[
                          Icon(widget.icons![i],
                              size: 16,
                              color: i == hovered
                                  ? AppTheme.lime
                                  : const Color(0xD9FFFFFF)),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 180),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: compact ? 13 : 14,
                              letterSpacing: -.1,
                              fontWeight: i == hovered ? FontWeight.w600 : FontWeight.w500,
                              color: !enabled
                                  ? AppTheme.muted
                                  : i == hovered
                                      ? AppTheme.lime
                                      : const Color(0xD9FFFFFF),
                            ),
                            child: Text(widget.options[i],
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
            ]),
          ]),
        );
      }),
    );
  }
}

/// Round icon button. [overMap] adds a frosted backdrop for use over the map.
class PzCircleButton extends StatelessWidget {
  const PzCircleButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = 44,
    this.overMap = false,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final double size;
  final bool overMap, accent;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: accent
          ? AppTheme.lime
          : overMap
              ? const Color(0xB8141416)
              : AppTheme.surfaceRaised,
      shape: CircleBorder(
          side: overMap && !accent
              ? const BorderSide(color: Color(0x26FFFFFF))
              : BorderSide.none),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox.square(
          dimension: size,
          child: Icon(icon, size: size * .42, color: accent ? Colors.black : AppTheme.primaryText),
        ),
      ),
    );
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: PzPressScale(scale: .92, child: overMap && !accent
            ? ClipOval(
                child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14), child: button))
            : button),
      ),
    );
  }
}

enum PzTone { accent, neutral, danger }

/// Small status label, e.g. "Open", "Full", "Hosting".
class PzStatusPill extends StatelessWidget {
  const PzStatusPill(this.label, {super.key, this.tone = PzTone.neutral, this.leading});
  final String label;
  final PzTone tone;
  final IconData? leading;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      PzTone.accent => (AppTheme.lime, Colors.black),
      PzTone.danger => (AppTheme.destructive.withValues(alpha: .16), AppTheme.destructive),
      PzTone.neutral => (AppTheme.surfaceHighest, AppTheme.primaryText),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (leading != null) ...[Icon(leading, size: 13, color: fg), const SizedBox(width: 5)],
        Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// Segmented capacity bar: one segment per player up to 12, else continuous.
class PzCapacityBar extends StatelessWidget {
  const PzCapacityBar({
    super.key,
    required this.filled,
    required this.total,
    this.color = AppTheme.lime,
    this.track = AppTheme.surfaceHighest,
  });

  final int filled, total;
  final Color color, track;

  @override
  Widget build(BuildContext context) {
    final safeTotal = total <= 0 ? 1 : total;
    final fraction = (filled / safeTotal).clamp(0.0, 1.0);
    return Semantics(
      label: '$filled of $total players',
      excludeSemantics: true,
      child: SizedBox(
        height: 8,
        child: safeTotal <= 12
            ? Row(children: [
                for (var i = 0; i < safeTotal; i++)
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: i == safeTotal - 1 ? 0 : 4),
                      decoration: BoxDecoration(
                        color: i < filled ? color : track,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
              ])
            : ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: Stack(children: [
                  Container(color: track),
                  FractionallySizedBox(widthFactor: fraction, child: Container(color: color)),
                ]),
              ),
      ),
    );
  }
}

/// Big value over a small label, used in metric strips.
class PzStat extends StatelessWidget {
  const PzStat({super.key, required this.value, required this.label});
  final String value, label;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 22,
                  height: 1.1,
                  letterSpacing: -.4,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()])),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.muted)),
        ],
      );
}

/// Grabber shown at the top of sheets.
class PzGrabber extends StatelessWidget {
  const PzGrabber({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: 38,
        height: 5,
        decoration: BoxDecoration(
            color: const Color(0xFF3A3A3C), borderRadius: BorderRadius.circular(3)),
      );
}

/// Splits "Place · City" or "Street, Area, City" into a title and a subtitle.
(String, String?) pzSplitPlace(String label) {
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

/// "Today", "Tomorrow" or a medium date, followed by the time.
String pzWhen(BuildContext context, DateTime start) {
  final l = MaterialLocalizations.of(context);
  final now = DateTime.now();
  final time = l.formatTimeOfDay(TimeOfDay.fromDateTime(start));
  final day = DateUtils.isSameDay(start, now)
      ? 'Today'
      : DateUtils.isSameDay(start, now.add(const Duration(days: 1)))
          ? 'Tomorrow'
          : l.formatMediumDate(start);
  return '$day · $time';
}

/// "In 1 h 57 min", "In 3 days", "Starting now".
String pzCountdown(DateTime start) {
  final diff = start.difference(DateTime.now());
  if (diff.inMinutes <= 0) return 'Starting now';
  if (diff.inDays >= 1) return 'In ${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'}';
  final h = diff.inHours, m = diff.inMinutes % 60;
  if (h == 0) return 'In $m min';
  return m == 0 ? 'In $h h' : 'In $h h $m min';
}

/// Empty or error state with an icon, title, message and optional action.
class PzEmptyState extends StatelessWidget {
  const PzEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title, message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                  color: AppTheme.surfaceRaised, shape: BoxShape.circle),
              child: Icon(icon, size: 26, color: AppTheme.lime),
            ),
            const SizedBox(height: 18),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18, letterSpacing: -.4, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, height: 1.4, color: AppTheme.muted)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.surfaceRaised,
                  foregroundColor: AppTheme.primaryText,
                  minimumSize: const Size(0, 44),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ]),
        ),
      );
}

/// Press feedback used on every tappable card and control: a quick spring
/// scale-down with a light haptic, released on lift or cancel.
class PzPressable extends StatefulWidget {
  const PzPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = .97,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap, onLongPress;
  final double scale;
  final bool haptic;

  @override
  State<PzPressable> createState() => _PzPressableState();
}

class _PzPressableState extends State<PzPressable> {
  bool _down = false;

  void _set(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.lightImpact();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              _set(false);
              HapticFeedback.mediumImpact();
              widget.onLongPress!();
            },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: _reduced(context)
            ? Duration.zero
            : Duration(milliseconds: _down ? 110 : 260),
        curve: _down ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

/// Dark frosted sheet surface shared by every Flutter sheet, matching the
/// native iOS 26 dark glass sheets.
class PzSheetSurface extends StatelessWidget {
  const PzSheetSurface({super.key, required this.child, this.solid = false});
  final Widget child;

  /// Full-height sheets are opaque, like the system's large detent.
  final bool solid;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.vertical(top: Radius.circular(AppTheme.radiusSheet));
    // A full 1 pt edge (not a top-only hairline): visible on 2x screens such
    // as iPhone SE, and it follows the rounded corners.
    final body = DecoratedBox(
      decoration: ShapeDecoration(
        color: solid ? AppTheme.surface : const Color(0xD9131315),
        shape: const RoundedSuperellipseBorder(
          borderRadius: radius,
          side: BorderSide(color: Color(0x24FFFFFF), width: 1),
        ),
      ),
      child: child,
    );
    return ClipRSuperellipse(
      borderRadius: radius,
      child: solid
          ? body
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 36, sigmaY: 36), child: body),
    );
  }
}

/// Modal sheet with the shared frosted style, grabber and safe area.
Future<T?> showPzSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool expand = false,
  bool solid = false,
  Color? barrierColor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: .5),
    builder: (sheetContext) => PzSheetSurface(
      solid: solid,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.only(top: 8), child: PzGrabber()),
            if (expand) Expanded(child: builder(sheetContext)) else Flexible(child: builder(sheetContext)),
          ],
        ),
      ),
    ),
  );
}

/// Card surface: darker grey, hairline edge, continuous corners.
class PzCard extends StatelessWidget {
  const PzCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.color = AppTheme.surfaceRaised,
    this.onTap,
    this.onLongPress,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final VoidCallback? onTap, onLongPress;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: ShapeDecoration(
        color: color,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: Color(0x0FFFFFFF), width: .5),
        ),
      ),
      // Lets ListTiles and ink inside the card paint above its fill.
      child: Material(type: MaterialType.transparency, child: child),
    );
    if (onTap == null && onLongPress == null) return card;
    return PzPressable(onTap: onTap, onLongPress: onLongPress, child: card);
  }
}

/// Channel for native iOS sheets, alerts and share.
const pzNativeSheets = MethodChannel('playerszwz/native-sheets');

/// One row of [pzActions].
class PzAction {
  const PzAction(this.label, {this.icon, this.destructive = false, this.subtitle});
  final String label;
  final String? subtitle;
  final IconData? icon;
  final bool destructive;
}

/// Global rect of [context]'s render box, for anchoring menus.
Rect pzRectOf(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return Rect.zero;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// Compact menu anchored to [anchor] (Files-app style). iOS: system UIMenu
/// with Liquid Glass. Elsewhere: a Material popup menu at the same spot.
Future<int?> pzMenu(
  BuildContext context, {
  required Rect anchor,
  required List<PzAction> actions,
  String? title,
  int? selected,
}) async {
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    try {
      return await pzNativeSheets.invokeMethod<int>('menu', {
        'title': title ?? '',
        'x': anchor.left,
        'y': anchor.top,
        'width': anchor.width,
        'height': anchor.height,
        'actions': [for (final a in actions) a.label],
        'subtitles': [for (final a in actions) a.subtitle ?? ''],
        'destructive': [for (final a in actions) a.destructive],
        'glyphs': [for (final a in actions) a.icon?.codePoint ?? 0],
        'fonts': [for (final a in actions) a.icon?.fontFamily ?? ''],
        'selected': selected ?? -1,
      });
    } on MissingPluginException {
      // Fall through.
    } on PlatformException {
      // Fall through.
    }
    if (!context.mounted) return null;
  }
  HapticFeedback.mediumImpact();
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  return showMenu<int>(
    context: context,
    color: const Color(0xF21C1C1F),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: Color(0x1FFFFFFF)),
    ),
    position: RelativeRect.fromRect(anchor, Offset.zero & overlay.size),
    items: [
      for (var i = 0; i < actions.length; i++)
        PopupMenuItem<int>(
          value: i,
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(actions[i].label,
                    style: AppTheme.bodyText.copyWith(
                        color: actions[i].destructive
                            ? AppTheme.destructive
                            : AppTheme.primaryText)),
                if (actions[i].subtitle != null)
                  Text(actions[i].subtitle!, style: AppTheme.caption),
              ]),
            ),
            if (i == selected)
              const Icon(PhosphorIconsBold.check, size: 16, color: AppTheme.lime)
            else if (actions[i].icon != null)
              Icon(actions[i].icon,
                  size: 18,
                  color: actions[i].destructive
                      ? AppTheme.destructive
                      : AppTheme.primaryText),
          ]),
        ),
    ],
  );
}

/// Action sheet: native glass sheet on iOS, frosted Flutter sheet elsewhere.
Future<int?> pzActions(BuildContext context,
    {String? title, required List<PzAction> actions}) async {
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    try {
      return await pzNativeSheets.invokeMethod<int>('actions', {
        'title': title ?? '',
        'actions': [for (final a in actions) a.label],
        'destructive': [for (final a in actions) a.destructive],
      });
    } on MissingPluginException {
      // Fall through.
    } on PlatformException {
      // Fall through.
    }
    if (!context.mounted) return null;
  }
  HapticFeedback.mediumImpact();
  return showPzSheet<int>(
    context,
    builder: (sheet) => Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Text(title, style: AppTheme.footnote, textAlign: TextAlign.center),
          ),
        for (var i = 0; i < actions.length; i++)
          ListTile(
            leading: actions[i].icon == null
                ? null
                : Icon(actions[i].icon,
                    color: actions[i].destructive
                        ? AppTheme.destructive
                        : AppTheme.primaryText),
            title: Text(actions[i].label,
                style: AppTheme.headline.copyWith(
                    color: actions[i].destructive
                        ? AppTheme.destructive
                        : AppTheme.primaryText)),
            onTap: () => Navigator.pop(sheet, i),
          ),
      ]),
    ),
  );
}

/// System share sheet on iOS; copies to the clipboard elsewhere.
Future<void> pzShare(BuildContext context, {required String text, String? url}) async {
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    try {
      await pzNativeSheets.invokeMethod<bool>('share', {'text': text, 'url': url});
      return;
    } on MissingPluginException {
      // Fall through.
    } on PlatformException {
      // Fall through.
    }
  }
  await Clipboard.setData(ClipboardData(text: url == null ? text : '$text\n$url'));
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Link copied')));
  }
}

/// Confirm dialog: native iOS 26 glass alert, Material dialog elsewhere.
Future<bool> pzConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirm,
  String cancel = 'Not now',
  bool destructive = true,
}) async {
  final ios = Theme.of(context).platform == TargetPlatform.iOS;
  if (ios) {
    try {
      // iOS 26 system alert: Liquid Glass with a highlighted confirm button.
      return await pzNativeSheets.invokeMethod<bool>('confirm', {
            'title': title,
            'message': message,
            'confirm': confirm,
            'cancel': cancel,
            'destructive': destructive,
          }) ==
          true;
    } on MissingPluginException {
      // Fall through to the Flutter dialog.
    } on PlatformException {
      // Fall through to the Flutter dialog.
    }
    if (!context.mounted) return false;
  }
  final result = ios
      ? await showCupertinoDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (dialog) => CupertinoTheme(
            data: const CupertinoThemeData(
                brightness: Brightness.dark, primaryColor: AppTheme.lime),
            child: CupertinoAlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                CupertinoDialogAction(
                    onPressed: () => Navigator.pop(dialog, false),
                    child: Text(cancel)),
                CupertinoDialogAction(
                    isDestructiveAction: destructive,
                    onPressed: () => Navigator.pop(dialog, true),
                    child: Text(confirm)),
              ],
            ),
          ),
        )
      : await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialog, false),
                  child: Text(cancel)),
              TextButton(
                  onPressed: () => Navigator.pop(dialog, true),
                  style: TextButton.styleFrom(
                      foregroundColor:
                          destructive ? AppTheme.destructive : AppTheme.lime),
                  child: Text(confirm)),
            ],
          ),
        );
  return result == true;
}

/// Swipe left to reveal one action (iOS Mail style). A long swipe runs it.
/// The row springs back when released short of the threshold.
class PzSwipeAction extends StatefulWidget {
  const PzSwipeAction({
    super.key,
    required this.child,
    required this.label,
    required this.icon,
    required this.onAction,
    this.color = AppTheme.destructive,
    this.radius = 22,
  });

  final Widget child;
  final String label;
  final IconData icon;
  final Color color;
  final double radius;

  /// Return true when the action finished (the row then stays closed).
  final Future<void> Function() onAction;

  @override
  State<PzSwipeAction> createState() => _PzSwipeActionState();
}

class _PzSwipeActionState extends State<PzSwipeAction>
    with SingleTickerProviderStateMixin {
  static const _reveal = 92.0;
  late final AnimationController _c = AnimationController.unbounded(vsync: this);
  double _width = 1;
  bool _passed = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _settle(double target, [double velocity = 0]) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = target;
      return;
    }
    _c.animateWith(SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 420, damping: 34),
        _c.value, target, velocity));
  }

  void _update(DragUpdateDetails d) {
    var next = _c.value + d.delta.dx;
    if (next > 0) next = next * .25; // resist dragging right
    final limit = -_width * .85;
    if (next < limit) next = limit + (next - limit) * .3;
    _c.value = next;
    final passed = -_c.value > _width * .55;
    if (passed != _passed) {
      _passed = passed;
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _end(DragEndDetails d) async {
    final v = d.primaryVelocity ?? 0;
    if (_passed || v < -1600) {
      _passed = false;
      _settle(-_reveal);
      await _run();
    } else if (-_c.value > _reveal * .5 || v < -400) {
      _settle(-_reveal, v);
    } else {
      _settle(0, v);
    }
  }

  Future<void> _run() async {
    await widget.onAction();
    if (mounted) _settle(0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      _width = constraints.maxWidth;
      return GestureDetector(
        onHorizontalDragUpdate: _update,
        onHorizontalDragEnd: _end,
        child: AnimatedBuilder(
          animation: _c,
          child: widget.child,
          builder: (context, child) {
            final offset = _c.value.clamp(-_width, _width * .3);
            final open = (-offset).clamp(0.0, _width);
            return Stack(children: [
              if (open > 0)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: _run,
                      child: Container(
                        width: open,
                        decoration: ShapeDecoration(
                          color: widget.color,
                          shape: RoundedSuperellipseBorder(
                              borderRadius: BorderRadius.circular(widget.radius)),
                        ),
                        alignment: open > _reveal ? Alignment.centerLeft : Alignment.center,
                        padding: EdgeInsets.only(left: open > _reveal ? 22 : 0),
                        child: Opacity(
                          opacity: (open / _reveal).clamp(0.0, 1.0),
                          child: Semantics(
                            button: true,
                            label: widget.label,
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(widget.icon, size: 20, color: Colors.white),
                              const SizedBox(height: 4),
                              Text(widget.label,
                                  maxLines: 1,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Transform.translate(
                offset: Offset(offset - (open > 0 ? 8 * (open / _width) : 0), 0),
                child: child,
              ),
            ]);
          },
        ),
      );
    });
  }
}

/// Press-scale only (no tap handling), for wrapping existing InkWells.
/// Uses raw pointers so it never competes with the child's gestures, and
/// releases as soon as the finger moves (e.g. starts scrolling).
class PzPressScale extends StatefulWidget {
  const PzPressScale({super.key, required this.child, this.scale = .975});
  final Widget child;
  final double scale;

  @override
  State<PzPressScale> createState() => _PzPressScaleState();
}

class _PzPressScaleState extends State<PzPressScale> {
  bool _down = false;
  Offset? _origin;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (e) {
          _origin = e.position;
          _set(true);
        },
        onPointerMove: (e) {
          if (_origin != null && (e.position - _origin!).distance > 8) _set(false);
        },
        onPointerUp: (_) => _set(false),
        onPointerCancel: (_) => _set(false),
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: _reduced(context)
              ? Duration.zero
              : Duration(milliseconds: _down ? 110 : 260),
          curve: _down ? Curves.easeOut : Curves.easeOutBack,
          child: widget.child,
        ),
      );
}

/// Slightly underdamped spring as a curve: a quick settle with a small
/// overshoot, used for cards that morph open and closed.
class PzSpring extends Curve {
  const PzSpring({this.damping = .74, this.frequency = 11});
  final double damping, frequency;

  @override
  double transformInternal(double t) {
    final w = frequency;
    final z = damping;
    final wd = w * math.sqrt(1 - z * z);
    return 1 -
        math.exp(-z * w * t) * (math.cos(wd * t) + (z * w / wd) * math.sin(wd * t));
  }
}

const pzSpring = PzSpring();
