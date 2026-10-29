import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/playerszwz_app.dart';
import '../../core/api_client.dart';
import 'account_session.dart';
import 'auth_service.dart';
import '../../core/widgets/launch_screen.dart';
import '../../core/widgets/motion.dart';

/// One setup attempt per signed-in identity, with explicit retries on failure.
class AccountSessionGate extends StatefulWidget {
  const AccountSessionGate({
    super.key,
    required this.loadSession,
    required this.signOut,
    required this.builder,
    this.identity,
  });

  final String? identity;
  final Future<AccountSession> Function() loadSession;
  final Future<void> Function() signOut;
  final Widget Function(AccountSession) builder;

  @override
  State<AccountSessionGate> createState() => _AccountSessionGateState();
}

class _AccountSessionGateState extends State<AccountSessionGate> {
  late Future<AccountSession> _session;
  bool _signingOut = false;
  String? _signOutError;

  @override
  void initState() {
    super.initState();
    _session = Future.sync(widget.loadSession);
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() {
      _signingOut = true;
      _signOutError = null;
    });
    try {
      await widget.signOut();
    } catch (_) {
      if (mounted) {
        setState(() => _signOutError = 'Could not sign out. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  String _message(Object? error) {
    if (error is FirebaseAuthException) return readableAuthError(error);
    if (error is ApiException) {
      return switch (error.code) {
        'CONFIGURATION_ERROR' =>
          'The app’s server connection has not been configured yet.',
        'ACCOUNT_SUSPENDED' =>
          'This account is suspended. Please contact support.',
        'INVALID_TOKEN' ||
        'UNAUTHORIZED' =>
          'Your sign-in could not be verified. Sign out and log in again.',
        'NETWORK_ERROR' ||
        'REQUEST_TIMEOUT' =>
          'Could not reach PlayersZWZ. Check your connection and try again.',
        _ => 'Could not load your account right now. Please try again.',
      };
    }
    return 'Could not load your account right now. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AccountSession>(
      future: _session,
      builder: (context, snapshot) => MotionSwap(
          fill: true,
          child: KeyedSubtree(
              key: ValueKey('${snapshot.connectionState}-${snapshot.hasError}'),
              child: _content(snapshot))),
    );
  }

  Widget _content(AsyncSnapshot<AccountSession> snapshot) {
    final loading = snapshot.connectionState != ConnectionState.done;
    if (!loading && snapshot.hasData) return widget.builder(snapshot.data!);
    if (loading) return LaunchScreen(identity: widget.identity, loading: true);
    final error = snapshot.error;
    final canRetry = error is! ApiException ||
        !{
          'ACCOUNT_SUSPENDED',
          'CONFIGURATION_ERROR',
          'INVALID_TOKEN',
          'UNAUTHORIZED'
        }.contains(error.code);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandMark(size: 76),
                const SizedBox(height: 24),
                if (loading) ...[
                  const CircularProgressIndicator(color: appAccent),
                  const SizedBox(height: 16),
                  const Text('Loading your account…'),
                ] else ...[
                  const Text('Account unavailable',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Text(_message(error), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  if (canRetry)
                    FilledButton(
                      onPressed: _signingOut
                          ? null
                          : () => setState(() {
                                _session = Future.sync(widget.loadSession);
                              }),
                      child: const Text('Try again'),
                    ),
                ],
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _signingOut ? null : _signOut,
                  child: Text(_signingOut ? 'Signing out…' : 'Sign out'),
                ),
                if (_signOutError != null)
                  Text(_signOutError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFFF6666))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
