import 'package:flutter/cupertino.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
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
  Widget build(BuildContext context) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final disabled = busy || onContinue == null;
    final continueControl = isIOS
        ? CupertinoButton(
            onPressed: disabled ? null : onContinue,
            color: disabled ? const Color(0xFF252525) : appAccent,
            borderRadius: BorderRadius.circular(16),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(children: [
              Expanded(
                child: Text(action,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: disabled ? Colors.white38 : Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 10),
              busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : Icon(
                      PhosphorIconsRegular.arrowRight,
                      size: 19,
                      color: disabled ? Colors.white38 : Colors.black,
                    ),
            ]),
          )
        : FilledButton(
            onPressed: disabled ? null : onContinue,
            style: FilledButton.styleFrom(
              backgroundColor: appAccent,
              foregroundColor: Colors.black,
              disabledBackgroundColor: const Color(0xFF252525),
              disabledForegroundColor: Colors.white38,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(action,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(width: 10),
              busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Icon(PhosphorIconsRegular.arrowRight, size: 19),
            ]),
          );

    return Scaffold(
      backgroundColor: appBackground,
      body: SafeArea(
        child: Column(children: [
          SizedBox(
            height: 44,
            child: Align(
              alignment: Alignment.centerLeft,
              child: onBack == null
                  ? null
                  : isIOS
                      ? CupertinoButton(
                          onPressed: busy ? null : onBack,
                          padding: const EdgeInsets.only(left: 12),
                          minSize: 44,
                          child: const Icon(PhosphorIconsRegular.caretLeft,
                              size: 21, color: Colors.white),
                        )
                      : IconButton(
                          onPressed: busy ? null : onBack,
                          tooltip: 'Back',
                          constraints: const BoxConstraints(
                              minWidth: 48, minHeight: 44),
                          icon: const Icon(PhosphorIconsRegular.arrowLeft, size: 21),
                        ),
            ),
          ),
          Expanded(
            child: MotionSwap(
              fill: true,
              reverse: reverse,
              child: SingleChildScrollView(
                key: ValueKey(step),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontFamily: 'Archivo', fontSize: 34,
                              height: 1.08,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -.6)),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(subtitle,
                            style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFFAAAAAA),
                                height: 1.45)),
                      ],
                      const SizedBox(height: 28),
                      child,
                    ]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 14),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SetupProgress(step: step),
              const SizedBox(height: 14),
              PressFeedback(
                enabled: !disabled,
                child: SizedBox(
                    width: double.infinity, child: continueControl),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
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
                          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Colors.transparent)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Colors.transparent)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: appAccent)),
    );
