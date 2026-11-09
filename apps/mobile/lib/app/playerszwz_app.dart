import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../features/onboarding/welcome_flow.dart';
import '../features/auth/auth_service.dart';
import '../features/auth/account_session.dart';
import '../features/auth/account_session_gate.dart';
import '../core/api_client.dart';
import '../core/config/api_config.dart';
import '../features/profile/profile_setup.dart';
import '../features/profile/profile_photo.dart';
import '../core/widgets/motion.dart';
import '../core/widgets/launch_screen.dart';
import '../features/location/location_service.dart';
import '../features/location/location_setup.dart';
import '../features/discovery/explore_screen.dart';
import 'app_theme.dart';

const appBackground = AppTheme.black;
const appSurface = AppTheme.surfaceRaised;
const appAccent = AppTheme.lime;
const appSuccess = AppTheme.lime;
const appError = AppTheme.destructive;

class PlayersZWZApp extends StatelessWidget {
  const PlayersZWZApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlayersZWZ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late final _auth = AuthService();
  // Reuse the subscription when the surrounding UI rebuilds.
  late final Stream<User?> _userChanges = _auth.userChanges;

  Future<AccountSession> _loadSession(User user) async {
    final api = ApiClient(
      baseUrl: ApiConfig.baseUrl,
      accessTokenProvider: () => user.getIdToken(),
    );
    try {
      return await AccountSessionService(api).establish(user);
    } finally {
      api.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _userChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: LaunchScreen(),
          );
        }
        final user = snapshot.data;
        if (user == null) return WelcomeFlow(authService: _auth);
        return AccountSessionGate(
          key: ValueKey(user.uid),
          identity: user.displayName?.trim().isNotEmpty == true
              ? user.displayName
              : user.email,
          loadSession: () => _loadSession(user),
          signOut: _auth.signOut,
          builder: (account) => _ProfileFlow(
              key: ValueKey(user.uid),
              user: user,
              account: account,
              signOut: _auth.signOut),
        );
      },
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF050505),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: SvgPicture.asset(
        'assets/branding/playerszwz-logo.svg',
        width: size * .76,
        height: size * .52,
        semanticsLabel: 'PlayersZWZ',
      ),
    );
  }
}

class _ProfileFlow extends StatefulWidget {
  const _ProfileFlow(
      {super.key,
      required this.user,
      required this.account,
      required this.signOut});
  final User user;
  final AccountSession account;
  final Future<void> Function() signOut;
  @override
  State<_ProfileFlow> createState() => _ProfileFlowState();
}

class _ProfileFlowState extends State<_ProfileFlow>
    with WidgetsBindingObserver {
  late bool _complete = widget.account.profileComplete;
  late Area? _area = widget.account.area;
  bool _reverseTransition = false;
  bool _refreshingLocation = false;
  late final _location = LocationService(apiKey: ApiConfig.geoapifyApiKey);
  late final _api = ApiClient(
      baseUrl: ApiConfig.baseUrl,
      accessTokenProvider: () => widget.user.getIdToken());
  late final _photo = ProfilePhotoController(ProfilePhotoService(_api));
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _photo.load();
    _photo.recover();
    if (_complete && _area != null) _refreshLiveLocation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _complete && _area != null) {
      _refreshLiveLocation();
    }
  }

  Future<Area?> _refreshLiveLocation() async {
    if (_refreshingLocation) return null;
    _refreshingLocation = true;
    try {
      final area = await _location.current(requestPermission: false);
      if (mounted) setState(() => _area = area);
      return area;
    } catch (_) {
      // Keep the last known map center if location is temporarily unavailable.
      return null;
    } finally {
      _refreshingLocation = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _photo.dispose();
    _location.close();
    _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MotionSwap(
      fill: true, reverse: _reverseTransition, child: _page(context));

  Widget _page(BuildContext context) {
    if (!_complete) {
      return ProfileSetup(
          key: const ValueKey('profile-setup'),
          photo: _photo,
          api: _api,
          name: widget.account.name,
          signOut: widget.signOut,
          onComplete: () => setState(() => _complete = true));
    }
    if (_area == null) {
      return LocationSetup(
          key: const ValueKey('location-setup'),
          api: _api,
          location: _location,
          signOut: widget.signOut,
          onComplete: (area) => setState(() {
                _area = area;
              }));
    }
    return ExploreScreen(
        area: _area!,
        photo: _photo,
        name: widget.account.name,
        api: _api,
        apiKey: ApiConfig.geoapifyApiKey,
        refreshLocation: _refreshLiveLocation,
        userId: widget.user.uid,
        signOut: widget.signOut);
  }
}
