import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../app/app_theme.dart';
import '../ui/pz_controls.dart';

bool _isIOS(BuildContext context) =>
    Theme.of(context).platform == TargetPlatform.iOS;

/// Phosphor glyph arguments understood by the native views.
Map<String, Object?> glyphArgs(IconData? icon, [String prefix = '']) {
  final g = prefix.isEmpty ? 'glyph' : '${prefix}Glyph';
  final f = prefix.isEmpty ? 'font' : '${prefix}Font';
  return {g: icon?.codePoint ?? 0, f: icon?.fontFamily ?? ''};
}

/// Liquid Glass button. iOS: native `UIGlassEffect` platform view showing the
/// Phosphor [icon]. Other platforms: a frosted Flutter button.
class NativeGlassButton extends StatefulWidget {
  const NativeGlassButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.title,
    this.prominent = false,
    this.width = 44,
    this.height = 44,
    this.iconSize = 17,
  });

  final IconData icon;
  final String label;
  final String? title;
  final bool prominent;
  final double width, height, iconSize;
  final VoidCallback? onTap;

  @override
  State<NativeGlassButton> createState() => _NativeGlassButtonState();
}

class _NativeGlassButtonState extends State<NativeGlassButton> {
  MethodChannel? _channel;

  Map<String, Object?> get _params => {
        ...glyphArgs(widget.icon),
        'title': widget.title ?? '',
        'label': widget.label,
        'prominent': widget.prominent,
        'iconSize': widget.iconSize,
      };

  @override
  void didUpdateWidget(NativeGlassButton old) {
    super.didUpdateWidget(old);
    if (old.title != widget.title ||
        old.icon != widget.icon ||
        old.prominent != widget.prominent) {
      _channel?.invokeMethod<void>('update', _params);
    }
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  void _attach(int id) {
    _channel = MethodChannel('playerszwz/glass-button/$id')
      ..setMethodCallHandler((call) async {
        if (call.method == 'tap') widget.onTap?.call();
      });
  }

  @override
  Widget build(BuildContext context) {
    if (_isIOS(context)) {
      return Semantics(
        button: true,
        label: widget.label,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: UiKitView(
            viewType: 'playerszwz/glass-button',
            creationParams: _params,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _attach,
          ),
        ),
      );
    }
    if (widget.title == null || widget.title!.isEmpty) {
      return PzCircleButton(
        icon: widget.icon,
        label: widget.label,
        size: widget.height,
        overMap: true,
        accent: widget.prominent,
        onPressed: widget.onTap,
      );
    }
    final fg = widget.prominent ? Colors.black : AppTheme.primaryText;
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: Material(
        color: widget.prominent ? AppTheme.lime : const Color(0xD91C1C1E),
        shape: const StadiumBorder(side: BorderSide(color: Color(0x26FFFFFF))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(widget.icon, size: widget.iconSize, color: fg),
              const SizedBox(width: 6),
              Text(widget.title!,
                  style: TextStyle(
                      color: fg, fontSize: 15, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// One choice in [NativeSheets.pickOption].
class NativeOption {
  const NativeOption(this.title, {this.subtitle, this.icon});
  final String title;
  final String? subtitle;
  final IconData? icon;
}

/// System sheets: native UIKit sheets on iOS (Liquid Glass on iOS 26),
/// Material bottom sheets and pickers elsewhere.
abstract final class NativeSheets {
  static const _channel = MethodChannel('playerszwz/native-sheets');

  static Future<int?> pickOption(
    BuildContext context, {
    required String title,
    required List<NativeOption> options,
    int? selected,
  }) async {
    if (_isIOS(context)) {
      try {
        return await _channel.invokeMethod<int>('pickOption', {
          'title': title,
          'options': [for (final o in options) o.title],
          'subtitles': [for (final o in options) o.subtitle ?? ''],
          'glyphs': [for (final o in options) o.icon?.codePoint ?? 0],
          'fonts': [for (final o in options) o.icon?.fontFamily ?? ''],
          'selected': selected ?? -1,
        });
      } on MissingPluginException {
        // Fall through to the Flutter sheet.
      } on PlatformException {
        // Fall through to the Flutter sheet.
      }
    }
    if (!context.mounted) return null;
    return showPzSheet<int>(
      context,
      builder: (sheet) => Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(title, style: AppTheme.title2),
          ),
        ),
        Flexible(
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 12), children: [
            for (var i = 0; i < options.length; i++)
              ListTile(
                leading: options[i].icon == null
                    ? null
                    : Icon(options[i].icon,
                        color: i == selected ? AppTheme.lime : AppTheme.primaryText),
                title: Text(options[i].title, style: AppTheme.headline),
                subtitle: options[i].subtitle == null
                    ? null
                    : Text(options[i].subtitle!, style: AppTheme.footnote),
                trailing: i == selected
                    ? const Icon(PhosphorIconsBold.check, color: AppTheme.lime, size: 18)
                    : null,
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(sheet, i);
                },
              ),
          ]),
        ),
      ]),
    );
  }

  static Future<DateTime?> pickDate(
    BuildContext context, {
    required DateTime initial,
    required DateTime first,
    required DateTime last,
    required String title,
  }) async {
    if (_isIOS(context)) {
      try {
        final ms = await _channel.invokeMethod<num>('pickDate', {
          'mode': 'date',
          'title': title,
          'initial': initial.millisecondsSinceEpoch,
          'minimum': first.millisecondsSinceEpoch,
          'maximum': last.millisecondsSinceEpoch,
        });
        return ms == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(ms.round());
      } on MissingPluginException {
        // Fall through.
      } on PlatformException {
        // Fall through.
      }
    }
    if (!context.mounted) return null;
    return showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: first,
        lastDate: last,
        helpText: title);
  }

  static Future<TimeOfDay?> pickTime(
    BuildContext context, {
    required DateTime initial,
    required String title,
  }) async {
    if (_isIOS(context)) {
      try {
        final ms = await _channel.invokeMethod<num>('pickDate', {
          'mode': 'time',
          'title': title,
          'initial': initial.millisecondsSinceEpoch,
          'minuteInterval': 5,
        });
        return ms == null
            ? null
            : TimeOfDay.fromDateTime(
                DateTime.fromMillisecondsSinceEpoch(ms.round()));
      } on MissingPluginException {
        // Fall through.
      } on PlatformException {
        // Fall through.
      }
    }
    if (!context.mounted) return null;
    return showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
        helpText: title);
  }
}

/// Radius control: a glass capsule ("◌ 5 km") that stretches into a thin
/// slider when tapped and shrinks back after the finger lifts.
/// iOS: native Liquid Glass + UISlider. Other platforms: Flutter equivalent.
class NativeRadiusSlider extends StatefulWidget {
  const NativeRadiusSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onExpanded,
    required this.onChanged,
    required this.onCollapsed,
    this.unit = 'km',
  });

  final double value, min, max;
  final String unit;
  final VoidCallback onExpanded;
  final ValueChanged<double> onChanged, onCollapsed;

  static const collapsedWidth = 96.0;
  static const height = 44.0;

  @override
  State<NativeRadiusSlider> createState() => _NativeRadiusSliderState();
}

class _NativeRadiusSliderState extends State<NativeRadiusSlider> {
  MethodChannel? _channel;
  bool _wide = false;
  Timer? _collapse;
  late double _local = widget.value;

  @override
  void didUpdateWidget(NativeRadiusSlider old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _channel?.invokeMethod<void>('update', widget.value);
      if (!_wide) _local = widget.value;
    }
  }

  @override
  void dispose() {
    _collapse?.cancel();
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  void _attach(int id) {
    _channel = MethodChannel('playerszwz/glass-slider/$id')
      ..setMethodCallHandler((call) async {
        switch (call.method) {
          case 'expanded':
          case 'willExpand':
            if (mounted) widget.onExpanded();
            return null;
          case 'valueChanged':
            final v = call.arguments;
            if (v is num) widget.onChanged(v.toDouble());
            return null;
          case 'collapsed':
            final v = call.arguments;
            if (!mounted) return null;
            widget.onCollapsed(v is num ? v.toDouble() : widget.value);
            return null;
        }
        return null;
      });
  }

  // Android / fallback ------------------------------------------------------

  void _fallbackExpand() {
    HapticFeedback.lightImpact();
    setState(() {
      _wide = true;
      _local = widget.value;
    });
    widget.onExpanded();
    _scheduleCollapse(const Duration(seconds: 3));
  }

  void _scheduleCollapse(Duration after) {
    _collapse?.cancel();
    _collapse = Timer(after, _fallbackCollapse);
  }

  void _fallbackCollapse() {
    _collapse?.cancel();
    if (!mounted || !_wide) return;
    setState(() => _wide = false);
    widget.onCollapsed(_local.roundToDouble());
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final full = constraints.maxWidth;
      if (_isIOS(context)) {
        // Always full width: iOS animates the capsule inside this view.
        // (Resizing a platform view mid-animation is not reliable.)
        return SizedBox(
            width: full,
            height: NativeRadiusSlider.height,
            child: UiKitView(
              viewType: 'playerszwz/glass-slider',
              creationParams: {
                ...glyphArgs(PhosphorIconsBold.circleDashed),
                'value': widget.value,
                'min': widget.min,
                'max': widget.max,
                'unit': widget.unit,
                'collapsedWidth': NativeRadiusSlider.collapsedWidth,
                'label': 'Search radius',
              },
              creationParamsCodec: const StandardMessageCodec(),
              onPlatformViewCreated: _attach,
            ),
          );
      }
      final reduce = MediaQuery.disableAnimationsOf(context);
      final km = (_wide ? _local : widget.value).round();
      return Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          button: !_wide,
          slider: _wide,
          label: 'Search radius',
          value: '$km ${widget.unit}',
          child: PzPressable(
            scale: _wide ? 1 : .95,
            haptic: false,
            onTap: _wide ? _fallbackCollapse : _fallbackExpand,
            child: AnimatedContainer(
              duration: reduce ? Duration.zero : const Duration(milliseconds: 420),
              curve: Curves.easeOutBack,
              width: _wide ? full : NativeRadiusSlider.collapsedWidth,
              height: NativeRadiusSlider.height,
              clipBehavior: Clip.antiAlias,
              decoration: const ShapeDecoration(
                color: Color(0xCC1A1A1D),
                shape: StadiumBorder(side: BorderSide(color: Color(0x26FFFFFF), width: .5)),
              ),
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                minWidth: full,
                maxWidth: full,
                child: Row(children: [
                  const SizedBox(width: 13),
                  const Icon(PhosphorIconsBold.circleDashed, size: 17, color: AppTheme.primaryText),
                  const SizedBox(width: 7),
                  SizedBox(
                    width: 52,
                    child: Text('$km ${widget.unit}',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()])),
                  ),
                  Expanded(
                    child: AnimatedOpacity(
                      opacity: _wide ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          activeTrackColor: AppTheme.lime,
                          inactiveTrackColor: const Color(0x2EFFFFFF),
                          thumbColor: Colors.white,
                          overlayShape: SliderComponentShape.noOverlay,
                        ),
                        child: Slider(
                          value: _local.clamp(widget.min, widget.max),
                          min: widget.min,
                          max: widget.max,
                          onChangeStart: (_) => _collapse?.cancel(),
                          onChangeEnd: (_) => _scheduleCollapse(const Duration(milliseconds: 1400)),
                          onChanged: !_wide
                              ? null
                              : (v) {
                                  if (v.round() != _local.round()) {
                                    HapticFeedback.selectionClick();
                                    widget.onChanged(v.roundToDouble());
                                  }
                                  setState(() => _local = v);
                                },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ]),
              ),
            ),
          ),
        ),
      );
    });
  }
}
