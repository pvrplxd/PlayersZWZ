import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../app/playerszwz_app.dart';
import '../auth/auth_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onGoogleSignIn,
    required this.onEmailSignUp,
    required this.onLogin,
  });

  final Future<void> Function() onGoogleSignIn;
  final VoidCallback onEmailSignUp;
  final VoidCallback onLogin;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pages = [
    ('Welcome\nto PlayersZWZ', 'welcome'),
    ('Find nearby\nplayers', 'nearby'),
    ('Book arenas\ninstantly', 'arenas'),
    ('AI-powered\nmatchmaking', 'matchmaking'),
  ];
  final _controller = PageController();
  int _page = 0;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onGoogleSignIn();
    } on GoogleSignInException catch (error) {
      if (mounted && error.code != GoogleSignInExceptionCode.canceled) {
        setState(() =>
            _error = 'Google sign-in could not finish. Please try again.');
      }
    } catch (error) {
      if (mounted) setState(() => _error = readableAuthError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _next() {
    final next = (_page + 1) % _pages.length;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(next);
    } else {
      _controller.animateToPage(next,
          duration: const Duration(milliseconds: 250),
          curve: const Cubic(.23, 1, .32, 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            final largeText = MediaQuery.textScalerOf(context).scale(16) > 24;
            final height =
                math.max(constraints.maxHeight, largeText ? 1200.0 : 0.0);
            final content = SizedBox(
                height: height,
                child: Column(children: [
                  SizedBox(height: height < 700 ? 16 : 42),
                  BrandMark(size: height < 700 ? 56 : 78),
                  const SizedBox(height: 12),
                  Expanded(
                      child: PageView.builder(
                          controller: _controller,
                          physics: _busy
                              ? const NeverScrollableScrollPhysics()
                              : null,
                          itemCount: 4,
                          onPageChanged: (value) =>
                              setState(() => _page = value),
                          itemBuilder: (context, index) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(children: [
                                Text(_pages[index].$1,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: height < 700 ? 30 : 36,
                                        height: 1.12,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -1)),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Image.asset(
                                      'assets/onboarding/${_pages[index].$2}.png',
                                      fit: BoxFit.contain,
                                      excludeFromSemantics: true,
                                    ),
                                  ),
                                ),
                              ])))),
                  Semantics(
                      label: 'Page ${_page + 1} of 4. Next introduction',
                      button: true,
                      child: SizedBox(
                          height: 48,
                          width: 100,
                          child: TextButton(
                              onPressed: _busy ? null : _next,
                              child: AnimatedBuilder(
                                animation: _controller,
                                builder: (context, child) {
                                  final position =
                                      MediaQuery.disableAnimationsOf(context)
                                          ? _page.toDouble()
                                          : (_controller.hasClients
                                                  ? _controller.page ?? 0
                                                  : 0)
                                              .toDouble();
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(4, (i) {
                                      final active = (1 - (position - i).abs())
                                          .clamp(0.0, 1.0);
                                      return Container(
                                        key: ValueKey('onboarding-dot-$i'),
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 2),
                                        height: 7,
                                        width: 7 + 24 * active,
                                        decoration: BoxDecoration(
                                            color: Color.lerp(Colors.white24,
                                                Colors.white, active),
                                            borderRadius:
                                                BorderRadius.circular(4)),
                                      );
                                    }),
                                  );
                                },
                              )))),
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(children: [
                        if (_error != null)
                          Semantics(
                              liveRegion: true,
                              child: Text(_error!,
                                  style: const TextStyle(
                                      color: Color(0xFFFF7777)))),
                        _action(
                            'Continue with Google',
                            _busy
                                ? const SizedBox.square(
                                    dimension: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : SvgPicture.asset(
                                    'assets/branding/google-icon.svg',
                                    width: 24,
                                    height: 24),
                            _signIn),
                        const SizedBox(height: 12),
                        _action(
                            'Sign up with email',
                            const Icon(Icons.mail_outline, size: 24),
                            widget.onEmailSignUp),
                        const SizedBox(height: 10),
                        const Text('Already have an account?',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 16)),
                        SizedBox(
                            height: 48,
                            child: TextButton(
                                onPressed: _busy ? null : widget.onLogin,
                                child: const Text('Log In',
                                    style: TextStyle(
                                        color: Colors.white,
                                        decoration: TextDecoration.underline,
                                        fontSize: 16)))),
                      ])),
                  const SizedBox(height: 8),
                ]));
            return Center(
                child: SizedBox(
                    width: math.min(constraints.maxWidth, 402),
                    child: largeText
                        ? SingleChildScrollView(child: content)
                        : content));
          }),
        ));
  }

  Widget _action(String label, Widget icon, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: _busy ? null : onPressed,
        style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white54,
            backgroundColor: appSurface,
            minimumSize: const Size(48, 50),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          icon,
          const SizedBox(width: 14),
          Flexible(
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w400))),
        ]),
      ),
    );
  }
}
