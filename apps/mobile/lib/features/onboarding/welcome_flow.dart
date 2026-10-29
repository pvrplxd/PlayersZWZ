import 'package:flutter/material.dart';

import '../auth/auth_screen.dart';
import '../auth/auth_service.dart';
import 'onboarding_screen.dart';
import '../../core/widgets/motion.dart';

/// Keep forms inside the auth gate: a successful sign-in replaces the entire
/// signed-out flow, so no login route remains above the signed-in screen.
class WelcomeFlow extends StatefulWidget {
  const WelcomeFlow({super.key, this.authService});

  final AuthService? authService;

  @override
  State<WelcomeFlow> createState() => _WelcomeFlowState();
}

class _WelcomeFlowState extends State<WelcomeFlow> {
  late final _auth = widget.authService ?? AuthService();
  bool? _createAccount;

  @override
  Widget build(BuildContext context) => MotionSwap(
      fill: true,
      reverse: _createAccount == null,
      child: KeyedSubtree(key: ValueKey(_createAccount), child: _page()));

  Widget _page() {
    if (_createAccount == null) {
      return OnboardingScreen(
        onGoogleSignIn: _auth.signInWithGoogle,
        onEmailSignUp: () => setState(() => _createAccount = true),
        onLogin: () => setState(() => _createAccount = false),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) setState(() => _createAccount = null);
      },
      child: Stack(
        children: [
          AuthScreen(createAccount: _createAccount!, authService: _auth),
          SafeArea(
            child: IconButton(
              tooltip: 'Back to welcome',
              onPressed: () => setState(() => _createAccount = null),
              icon: const Icon(Icons.arrow_back),
            ),
          ),
        ],
      ),
    );
  }
}
