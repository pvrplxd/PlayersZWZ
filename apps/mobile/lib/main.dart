import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'app/playerszwz_app.dart';
import 'firebase_options.dart';
import 'core/widgets/launch_screen.dart';
import 'core/config/api_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(StartupApp(
    initializeServices: _initializeServices,
    child: const PlayersZWZApp(),
  ));
}

Future<void> _initializeServices() async {
  await _timedStartup('Firebase', () async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  });
  await _timedStartup('Google Sign-In', () async {
    await GoogleSignIn.instance.initialize();
  });
  await _timedStartup('Runtime configuration', ApiConfig.loadRuntimeConfig);
}

Future<void> _timedStartup(
    String stage, Future<void> Function() initialize) async {
  final watch = Stopwatch()..start();
  try {
    await initialize();
  } catch (error, stackTrace) {
    Error.throwWithStackTrace(
      StateError('$stage initialization failed: $error'),
      stackTrace,
    );
  } finally {
    if (!kReleaseMode) {
      debugPrint(
          '[Startup] $stage finished after ${watch.elapsedMilliseconds}ms');
    }
  }
}

/// Paint the startup state before invoking native service initialization.
class StartupApp extends StatefulWidget {
  const StartupApp({
    super.key,
    required this.initializeServices,
    required this.child,
  });

  final Future<void> Function() initializeServices;
  final Widget child;

  @override
  State<StartupApp> createState() => _StartupAppState();
}

class _StartupAppState extends State<StartupApp> {
  late final Future<void> _startup;

  @override
  void initState() {
    super.initState();
    _startup = _startAfterFirstFrame();
  }

  Future<void> _startAfterFirstFrame() async {
    final watch = Stopwatch()..start();
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    if (!kReleaseMode) {
      debugPrint(
          '[Startup] First Flutter frame after ${watch.elapsedMilliseconds}ms '
          'from startup widget creation');
    }
    await Future.wait([
      widget.initializeServices(),
      Future<void>.delayed(const Duration(milliseconds: 900))
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _startup,
      builder: (context, snapshot) {
        final ready = snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError;
        return AnimatedSwitcher(
            duration: Duration(
                milliseconds: WidgetsBinding.instance.platformDispatcher
                        .accessibilityFeatures.disableAnimations
                    ? 120
                    : 280),
            child: KeyedSubtree(
                key: ValueKey(ready),
                child: ready
                    ? widget.child
                    : MaterialApp(
                        debugShowCheckedModeBanner: false,
                        theme: ThemeData.dark(),
                        home: !snapshot.hasError
                            ? const LaunchScreen()
                            : Scaffold(
                                backgroundColor: const Color(0xFF000000),
                                body: SafeArea(
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: snapshot.hasError
                                          ? Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Text(
                                                  'PlayersZWZ could not start',
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                                const SizedBox(height: 12),
                                                SelectableText(
                                                  '${snapshot.error}',
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            )
                                          : const Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                CircularProgressIndicator(
                                                  color: Color(0xFFD7FF00),
                                                ),
                                                SizedBox(height: 16),
                                                Text('Starting PlayersZWZ…'),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                      )));
      },
    );
  }
}
