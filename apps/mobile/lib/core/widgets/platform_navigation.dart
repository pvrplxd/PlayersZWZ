import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../app/app_theme.dart';
import '../native/native_ui.dart';

/// Four-destination app navigation.
///
/// iOS: a real UIKit `UITabBar` (platform view), so iOS 26 draws the system
/// Liquid Glass material, VoiceOver and Reduce Transparency itself.
/// Android: a Material 3 `NavigationBar` with labels on every destination.
class PlatformNavigation extends StatefulWidget {
  const PlatformNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _iosBarHeight = 64.0;
  static const _androidBarHeight = 72.0;

  static const _destinations = <(IconData, IconData, String)>[
    (PhosphorIconsRegular.compass, PhosphorIconsFill.compass, 'Explore'),
    (PhosphorIconsRegular.lightning, PhosphorIconsFill.lightning, 'Activity'),
    (PhosphorIconsRegular.mapTrifold, PhosphorIconsFill.mapTrifold, 'Arenas'),
    (PhosphorIconsRegular.user, PhosphorIconsFill.user, 'Profile'),
  ];

  /// Space screens should keep clear above the bottom edge for the bar.
  static double spaceOf(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Theme.of(context).platform == TargetPlatform.iOS
        ? _iosBarHeight + bottom
        : _androidBarHeight + bottom;
  }

  @override
  State<PlatformNavigation> createState() => _PlatformNavigationState();
}

class _PlatformNavigationState extends State<PlatformNavigation> {
  MethodChannel? _channel;

  @override
  void didUpdateWidget(PlatformNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) _syncNative();
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  void _syncNative() =>
      _channel?.invokeMethod<void>('select', widget.selectedIndex);

  void _attach(int id) {
    _channel = MethodChannel('playerszwz/navigation/$id')
      ..setMethodCallHandler((call) async {
        final index = call.arguments;
        if (call.method != 'selected' || index is! int) return;
        if (index < 0 || index >= PlatformNavigation._destinations.length) {
          _syncNative();
          return;
        }
        if (index == widget.selectedIndex) {
          _syncNative();
        } else {
          widget.onSelected(index);
        }
      });
  }

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return SizedBox(
        height: PlatformNavigation.spaceOf(context),
        child: UiKitView(
          viewType: 'playerszwz/native-tab-bar',
          creationParams: {
            'selectedIndex': widget.selectedIndex,
            'items': [
              for (final (icon, selectedIcon, label)
                  in PlatformNavigation._destinations)
                {
                  'title': label,
                  ...glyphArgs(icon),
                  ...glyphArgs(selectedIcon, 'selected'),
                },
            ],
          },
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _attach,
        ),
      );
    }
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        height: PlatformNavigation._androidBarHeight,
        backgroundColor: const Color(0xFF0E0E10),
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppTheme.lime,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              size: 22,
              color: states.contains(WidgetState.selected)
                  ? Colors.black
                  : AppTheme.muted,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppTheme.primaryText : AppTheme.muted,
          );
        }),
      ),
      child: NavigationBar(
        selectedIndex: widget.selectedIndex,
        onDestinationSelected: (index) {
          if (index != widget.selectedIndex) {
            HapticFeedback.selectionClick();
            widget.onSelected(index);
          }
        },
        destinations: [
          for (final (icon, selectedIcon, label)
              in PlatformNavigation._destinations)
            NavigationDestination(
              icon: Icon(icon),
              selectedIcon: Icon(selectedIcon),
              label: label,
            ),
        ],
      ),
    );
  }
}

