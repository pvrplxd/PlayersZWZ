import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../core/widgets/platform_navigation.dart';
import '../profile/profile_photo.dart';
import '../profile/profile_photo_editor.dart';
import 'map_motion.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/playerszwz_app.dart';
import '../location/location_service.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen(
      {super.key,
      required this.area,
      required this.apiKey,
      required this.changeArea,
      required this.signOut,
      this.tileProvider,
      this.photo,
      this.name = 'Player'});
  final ProfilePhotoController? photo;
  final String name;
  final Area area;
  final String apiKey;
  final VoidCallback changeArea;
  final Future<void> Function() signOut;
  final TileProvider? tileProvider;
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with SingleTickerProviderStateMixin {
  final _map = MapController();
  late final MapRecenterMotion _cameraMotion;
  Timer? _timeout;
  bool _loading = true, _failed = false, _signingOut = false;
  int _attempt = 0;
  LatLng get _center => LatLng(widget.area.latitude, widget.area.longitude);

  @override
  void initState() {
    super.initState();
    _cameraMotion = MapRecenterMotion(map: _map, vsync: this);
    _startTimeout();
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

  Future<void> _link(String url) async {
    try {
      if (await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not open the attribution link.')));
    }
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
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

  void _credits() => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        backgroundColor: appSurface,
        builder: (context) => SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(
              title: Text('Map credits',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600))),
          ListTile(
              title: const Text('Powered by Geoapify'),
              trailing: const Icon(CupertinoIcons.arrow_up_right, size: 18),
              onTap: () => _link('https://www.geoapify.com/')),
          ListTile(
              title: const Text('© OpenMapTiles'),
              trailing: const Icon(CupertinoIcons.arrow_up_right, size: 18),
              onTap: () => _link('https://openmaptiles.org/')),
          ListTile(
              title: const Text('© OpenStreetMap contributors'),
              trailing: const Icon(CupertinoIcons.arrow_up_right, size: 18),
              onTap: () => _link('https://www.openstreetmap.org/copyright')),
        ])),
      );

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
              setState(() => _tab = index);
            }),
        body: IndexedStack(index: _tab, children: [
          _explore(),
          _destination(
              'Activity',
              CupertinoIcons.bolt,
              'Make room for your next game.',
              'Joining and hosting games will be available in a future update.'),
          _destination(
              'Arenas',
              CupertinoIcons.sportscourt,
              'A place for every game.',
              'Arena discovery and booking will be available in a future update.'),
          _profile(),
        ]),
      ),
    );
  }

  double get _navigationSpace =>
      (Theme.of(context).platform == TargetPlatform.iOS ? 64 : 80) +
      MediaQuery.viewPaddingOf(context).bottom;

  Widget _explore() {
    final attempt = _attempt;
    final bottom = _navigationSpace;
    return Stack(fit: StackFit.expand, children: [
      Positioned.fill(
          child: widget.apiKey.isEmpty
              ? const Center(
                  child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                          'The map is unavailable right now. Your saved area is safe.',
                          textAlign: TextAlign.center)))
              : FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                      onPositionChanged: (_, gesture) {
                        if (gesture) _cameraMotion.stop();
                      },
                      initialCenter: _center,
                      initialZoom: 16,
                      minZoom: 3,
                      maxZoom: 19,
                      backgroundColor: appSurface,
                      interactionOptions: const InteractionOptions(
                          flags:
                              InteractiveFlag.all & ~InteractiveFlag.rotate)),
                  children: [
                    TileLayer(
                      key: ValueKey(attempt),
                      urlTemplate:
                          'https://maps.geoapify.com/v1/tile/dark-matter/{z}/{x}/{y}.png?apiKey=${Uri.encodeQueryComponent(widget.apiKey)}',
                      userAgentPackageName: 'com.playerszwz.app',
                      tileProvider: widget.tileProvider,
                      maxNativeZoom: 20,
                      errorTileCallback: (_, error, stack) =>
                          _tileStatus(true, attempt),
                      tileBuilder: (context, child, tile) => AnimatedBuilder(
                          animation: tile,
                          builder: (context, _) {
                            if (tile.loadFinishedAt != null) {
                              _tileStatus(tile.loadError, attempt);
                            }
                            return child;
                          }),
                    ),
                    MarkerLayer(markers: [
                      Marker(
                          point: _center,
                          width: 64,
                          height: 64,
                          child: Semantics(
                            label: 'Saved area: ${widget.area.label}',
                            child: const AreaMarker(),
                          ))
                    ]),
                  ],
                )),
      Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: IgnorePointer(
              child: Container(
            height: MediaQuery.viewPaddingOf(context).top + 160,
            decoration: const BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                  Color(0xF5000000),
                  Color(0xA6000000),
                  Color(0x00000000)
                ])),
          ))),
      SafeArea(
          bottom: false,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 20, 0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      const Expanded(
                          child: Text('Explore',
                              style: TextStyle(
                                  fontSize: 34,
                                  height: 1.15,
                                  letterSpacing: -1.1,
                                  fontWeight: FontWeight.w700))),
                      ClipOval(
                          child: BackdropFilter(
                              filter: ui.ImageFilter.blur(
                                  sigmaX: Theme.of(context).platform == TargetPlatform.iOS
                                      ? 18
                                      : 0,
                                  sigmaY: Theme.of(context).platform ==
                                          TargetPlatform.iOS
                                      ? 18
                                      : 0),
                              child: Container(
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color:
                                          Colors.white.withValues(alpha: .10),
                                      border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: .22))),
                                  child: IconButton(
                                      onPressed: widget.changeArea,
                                      tooltip: 'Change area',
                                      icon: const Icon(CupertinoIcons.search, size: 22),
                                      style: IconButton.styleFrom(minimumSize: const Size(48, 48)))))),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      const Icon(CupertinoIcons.location_fill,
                          size: 13, color: appAccent),
                      const SizedBox(width: 7),
                      Flexible(
                          child: Text(widget.area.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 15, color: Colors.white70))),
                    ]),
                    if (widget.apiKey.isNotEmpty && _loading)
                      const Padding(
                          padding: EdgeInsets.only(top: 18),
                          child: LinearProgressIndicator(
                              color: appAccent,
                              backgroundColor: appSurface,
                              minHeight: 2,
                              semanticsLabel: 'Loading map')),
                    if (widget.apiKey.isNotEmpty && _failed)
                      Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Material(
                              color: appSurface,
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Map could not load',
                                            style: TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 6),
                                        const Text(
                                            'Check your connection and try again.',
                                            style: TextStyle(
                                                color: Colors.white60)),
                                        TextButton(
                                            onPressed: _retry,
                                            child: const Text('Retry map')),
                                      ])))),
                  ]))),
      if (widget.apiKey.isNotEmpty)
        Positioned(
            right: 20,
            bottom: bottom + 72,
            child: Material(
                color: Colors.white,
                elevation: 6,
                shape: const CircleBorder(),
                child: IconButton(
                    onPressed: () => _cameraMotion.recenter(_center,
                        reducedMotion: MediaQuery.disableAnimationsOf(context)),
                    tooltip: 'Recenter on saved area',
                    style:
                        IconButton.styleFrom(minimumSize: const Size(44, 44)),
                    icon: const Icon(Icons.my_location,
                        size: 21, color: Color(0xFF444444))))),
      Positioned(
          left: 16,
          right: 16,
          bottom: bottom + 8,
          child: Row(children: [
            Expanded(
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                          color: const Color(0xB3000000),
                          borderRadius: BorderRadius.circular(4)),
                      child: const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                          child: Text(
                              'Powered by Geoapify · © OpenStreetMap · © OpenMapTiles',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.white70))),
                    ))),
            IconButton(
                onPressed: _credits,
                tooltip: 'Map credits',
                icon: const Icon(CupertinoIcons.info_circle,
                    size: 18, color: Colors.white70)),
          ])),
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
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 34,
                          letterSpacing: -1,
                          fontWeight: FontWeight.w700)))),
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
                                fontSize: 26,
                                letterSpacing: -.6,
                                fontWeight: FontWeight.w600,
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
                            child: const Text('Explore your area')),
                      ]))),
        ]),
      );

  Widget _profile() => SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(24, 20, 24, _navigationSpace + 24),
        children: [
          const Text('Profile',
              style: TextStyle(
                  fontSize: 34,
                  letterSpacing: -1,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 36),
          if (widget.photo != null)
            ProfilePhotoEditor(
                controller: widget.photo!,
                name: widget.name,
                enabled: !_signingOut)
          else
            Center(child: ProfileAvatar(name: widget.name)),
          const SizedBox(height: 12),
          Text(widget.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.4)),
          const SizedBox(height: 36),
          const Text('YOUR PLAYING AREA',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w600,
                  color: Colors.white54)),
          const SizedBox(height: 12),
          Material(
              color: appSurface,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  leading: const Icon(CupertinoIcons.map_pin_ellipse,
                      color: appAccent),
                  title: Text(widget.area.label),
                  subtitle: const Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: Text('Change area',
                          style: TextStyle(color: Colors.white54))),
                  trailing: const Icon(CupertinoIcons.chevron_right, size: 18),
                  onTap: widget.changeArea)),
          const SizedBox(height: 24),
          ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: const Icon(CupertinoIcons.square_arrow_right,
                  color: Colors.white60),
              title: Text(_signingOut ? 'Signing out…' : 'Sign out'),
              onTap: _signingOut ? null : _signOut),
        ],
      ));
}
