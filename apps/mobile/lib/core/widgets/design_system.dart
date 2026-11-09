import 'package:flutter/material.dart';

import '../../app/app_theme.dart';

class HeavyHeading extends StatelessWidget {
  const HeavyHeading(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppTheme.heading.merge(style),
      );
}

class SheetGrabber extends StatelessWidget {
  const SheetGrabber({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF3A3A3A),
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            ),
          ),
        ),
      );
}

class LimeChip extends StatelessWidget {
  const LimeChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? AppTheme.lime : AppTheme.surfaceRaised,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: () => onSelected(!selected),
          customBorder: const StadiumBorder(),
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? AppTheme.black : AppTheme.primaryText,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.backgroundColor = AppTheme.surfaceRaised,
    this.foregroundColor = AppTheme.primaryText,
    this.borderColor,
    this.size = 48,
  });

  final Widget icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final double size;

  @override
  Widget build(BuildContext context) => Material(
        color: backgroundColor,
        shape: CircleBorder(
          side: borderColor == null
              ? BorderSide.none
              : BorderSide(color: borderColor!, width: .8),
        ),
        child: IconButton(
          onPressed: onPressed,
          tooltip: tooltip,
          constraints: BoxConstraints.tightFor(width: size, height: size),
          icon: IconTheme(
            data: IconThemeData(color: foregroundColor),
            child: icon,
          ),
        ),
      );
}
