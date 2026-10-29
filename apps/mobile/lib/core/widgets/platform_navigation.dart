import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/playerszwz_app.dart';

/// UIKit owns iOS materials, SF Symbols, selection and accessibility. Android
/// uses Material 3 destinations. Neither platform paints an imitation glass bar.
class PlatformNavigation extends StatefulWidget {
  const PlatformNavigation(
      {super.key, required this.selectedIndex, required this.onSelected});
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  State<PlatformNavigation> createState() => _PlatformNavigationState();
}

class _PlatformNavigationState extends State<PlatformNavigation> {
  MethodChannel? _channel;

  @override
  void didUpdateWidget(covariant PlatformNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) _syncSelection();
  }

  Future<void> _syncSelection() async {
    try {
      await _channel?.invokeMethod<void>('select', widget.selectedIndex);
    } on PlatformException {
      /* A disposed native view may have a pending update. */
    }
  }

  void _created(int id) {
    _channel = MethodChannel('playerszwz/navigation/$id');
    _channel!.setMethodCallHandler((call) async {
      if (call.method == 'selected' && call.arguments is int && mounted) {
        final index = call.arguments as int;
        if (index >= 0 && index < 4) widget.onSelected(index);
      }
    });
    _syncSelection();
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && Theme.of(context).platform == TargetPlatform.iOS) {
      // The native bar owns the bottom safe area. Reserve room for its floating
      // presentation on current iOS and the standard bar on earlier versions.
      return SizedBox(
          height: 64 + MediaQuery.paddingOf(context).bottom,
          child: UiKitView(
              viewType: 'playerszwz/native-tab-bar',
              creationParams: {'selectedIndex': widget.selectedIndex},
              creationParamsCodec: const StandardMessageCodec(),
              onPlatformViewCreated: _created));
    }
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: const Color(0xFF171914),
        surfaceTintColor: Colors.transparent,
        indicatorColor: appAccent,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? Colors.black
                : Colors.white60)),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? Colors.white
                : Colors.white60)),
      ),
      child: NavigationBar(
          selectedIndex: widget.selectedIndex,
          onDestinationSelected: widget.onSelected,
          animationDuration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore),
                label: 'Explore'),
            NavigationDestination(
                icon: Icon(Icons.bolt_outlined),
                selectedIcon: Icon(Icons.bolt),
                label: 'Activity'),
            NavigationDestination(
                icon: Icon(Icons.stadium_outlined),
                selectedIcon: Icon(Icons.stadium),
                label: 'Arenas'),
            NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile'),
          ]),
    );
  }
}
