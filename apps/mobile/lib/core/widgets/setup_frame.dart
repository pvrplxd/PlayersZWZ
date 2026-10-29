import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../app/playerszwz_app.dart';
import 'motion.dart';

/// Shared rhythm for the three setup steps. The action stays above the keyboard
/// while the form can scroll independently on small screens or at large type.
class SetupFrame extends StatelessWidget {
  const SetupFrame(
      {super.key,
      required this.step,
      required this.title,
      required this.subtitle,
      required this.child,
      required this.action,
      required this.onContinue,
      this.onBack,
      this.busy = false,
      this.reverse = false});
  final int step;
  final String title, subtitle, action;
  final Widget child;
  final VoidCallback? onContinue, onBack;
  final bool busy;
  final bool reverse;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: appBackground,
        body: SafeArea(
            child: Column(children: [
          SizedBox(
              height: 44,
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: onBack == null
                      ? null
                      : Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: IconButton(
                              onPressed: busy ? null : onBack,
                              tooltip: 'Back',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 48, minHeight: 44),
                              icon: const Icon(CupertinoIcons.chevron_back,
                                  size: 21))))),
          Expanded(
              child: MotionSwap(
                  fill: true,
                  reverse: reverse,
                  child: SingleChildScrollView(
                    key: ValueKey(step),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 32,
                                  height: 1.1,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -1.1)),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(subtitle,
                                style: const TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFFAAAAAA),
                                    height: 1.45)),
                          ],
                          const SizedBox(height: 32),
                          child,
                        ]),
                  ))),
          Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SetupProgress(step: step),
                const SizedBox(height: 20),
                PressFeedback(
                    enabled: !busy && onContinue != null,
                    child: FilledButton(
                      onPressed: busy ? null : onContinue,
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: const Color(0xFF252525),
                          disabledForegroundColor: Colors.white38,
                          minimumSize: const Size.fromHeight(56),
                          padding: const EdgeInsets.fromLTRB(24, 7, 7, 7),
                          shape: const StadiumBorder()),
                      child: Row(children: [
                        const SizedBox(width: 26),
                        Expanded(
                            child: Text(action,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600))),
                        const SizedBox(width: 8),
                        Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: onContinue == null || busy
                                    ? Colors.white12
                                    : appAccent),
                            child: busy
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white70))
                                : const Icon(CupertinoIcons.arrow_right,
                                    size: 23)),
                      ]),
                    )),
              ])),
        ])),
      );
}

InputDecoration setupInput(String hint, {Widget? prefix, Widget? suffix}) =>
    InputDecoration(
      hintText: hint,
      counterText: '',
      filled: true,
      fillColor: appSurface,
      prefixIcon: prefix,
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      hintStyle:
          const TextStyle(color: Colors.white38, fontWeight: FontWeight.w400),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Colors.transparent)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Colors.transparent)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: appAccent)),
    );
