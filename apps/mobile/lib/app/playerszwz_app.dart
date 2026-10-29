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

const appBackground = Color(0xFF000000);
const appSurface = Color(0xFF1D1D1D);
const appAccent = Color(0xFFD7FF00);
const appSuccess = Color(0xFF32D583);
const appError = Color(0xFFFF6268);

class PlayersZWZApp extends StatelessWidget {
  const PlayersZWZApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlayersZWZ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: appBackground,
        colorScheme: const ColorScheme.dark(
          primary: appAccent,
          surface: appSurface,
          onPrimary: Colors.black,
        ),
        useMaterial3: true,
      ),
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

class _ProfileFlowState extends State<_ProfileFlow> {
  late bool _complete = widget.account.profileComplete;
  late Area? _area = widget.account.area;
  bool _editingArea = false;
  bool _reverseTransition = false;
  late final _location = LocationService(apiKey: ApiConfig.geoapifyApiKey);
  late final _api = ApiClient(
      baseUrl: ApiConfig.baseUrl,
      accessTokenProvider: () => widget.user.getIdToken());
  late final _photo = ProfilePhotoController(ProfilePhotoService(_api));
  @override
  void initState() {
    super.initState();
    _photo.load();
    _photo.recover();
  }

  @override
  void dispose() {
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
    if (_area == null || _editingArea) {
      return LocationSetup(
          key: const ValueKey('location-setup'),
          api: _api,
          location: _location,
          signOut: widget.signOut,
          onCancel: _area == null
              ? null
              : () => setState(() {
                    _reverseTransition = true;
                    _editingArea = false;
                  }),
          onComplete: (area) => setState(() {
                _reverseTransition = _editingArea;
                _area = area;
                _editingArea = false;
              }));
    }
    return ExploreScreen(
        key: ValueKey(_area),
        area: _area!,
        photo: _photo,
        name: widget.account.name,
        apiKey: ApiConfig.geoapifyApiKey,
        changeArea: () => setState(() {
              _reverseTransition = false;
              _editingArea = true;
            }),
        signOut: widget.signOut);
  }
}
