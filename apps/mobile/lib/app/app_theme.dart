import 'package:flutter/material.dart';

/// Shared visual tokens for the PlayersZWZ mobile app.
abstract final class AppTheme {
  static const Color black = Color(0xFF000000);
  /// Sheets and grouped backgrounds.
  static const Color surface = Color(0xFF0E0E10);

  /// Cards, rows and unselected controls.
  static const Color surfaceRaised = Color(0xFF141416);

  /// Controls nested inside cards, tracks and badges.
  static const Color surfaceHighest = Color(0xFF232326);

  /// Hairlines and card edges.
  static const Color line = Color(0xFF222225);
  static const Color lime = Color(0xFFC6F432);
  static const Color destructive = Color(0xFFFF6259);
  static const Color muted = Color(0xFF8C8C91);
  static const Color primaryText = Color(0xFFF5F5F5);

  static const double radiusCard = 26;
  static const double radiusMap = 38;
  static const double radiusSheet = 38;
  static const double radiusPill = 99;
  static const double space1 = 8;
  static const double space2 = 16;
  static const double space3 = 24;
  static const double space4 = 32;

  // Type scale. Archivo for display titles, Inter for everything else.
  // Inter's tall x-height reads like SF Pro one size up, so body is 16.
  static const String display = 'Archivo';

  static const TextStyle largeTitle = TextStyle(
      fontFamily: display, fontSize: 34, height: 1.08, letterSpacing: -.7,
      fontWeight: FontWeight.w800, color: primaryText);
  static const TextStyle title1 = TextStyle(
      fontFamily: display, fontSize: 28, height: 1.12, letterSpacing: -.6,
      fontWeight: FontWeight.w800, color: primaryText);
  static const TextStyle title2 = TextStyle(
      fontFamily: display, fontSize: 22, height: 1.18, letterSpacing: -.4,
      fontWeight: FontWeight.w700, color: primaryText);
  static const TextStyle title3 = TextStyle(
      fontSize: 18, height: 1.25, letterSpacing: -.35,
      fontWeight: FontWeight.w600, color: primaryText);
  static const TextStyle headline = TextStyle(
      fontSize: 16, height: 1.3, letterSpacing: -.25,
      fontWeight: FontWeight.w600, color: primaryText);
  static const TextStyle bodyText = TextStyle(
      fontSize: 15, height: 1.4, letterSpacing: -.15, color: primaryText);
  static const TextStyle subhead = TextStyle(
      fontSize: 14, height: 1.35, letterSpacing: -.1,
      fontWeight: FontWeight.w500, color: primaryText);
  static const TextStyle footnote = TextStyle(
      fontSize: 13, height: 1.35, letterSpacing: -.05, color: muted);
  static const TextStyle caption = TextStyle(
      fontSize: 12, height: 1.3, fontWeight: FontWeight.w500, color: muted);

  /// Short screens (iPhone SE, 667 pt tall) get a slightly smaller title.
  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).height < 700;

  static TextStyle screenTitle(BuildContext context) => isCompact(context)
      ? largeTitle.copyWith(fontSize: 30, letterSpacing: -.6)
      : largeTitle;

  // Older names kept for existing call sites.
  static const TextStyle heading = largeTitle;
  static const TextStyle title = title1;
  static const TextStyle body = bodyText;

  static ThemeData get theme {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: black,
      colorScheme: const ColorScheme.dark(
        primary: lime,
        surface: surface,
        onPrimary: black,
        onSurface: primaryText,
        error: destructive,
      ),
      textTheme: Typography.material2021()
          .white
          .apply(
              fontFamily: 'Inter',
              bodyColor: primaryText,
              displayColor: primaryText)
          .copyWith(
            displayLarge: largeTitle,
            displayMedium: largeTitle,
            headlineLarge: title1,
            headlineMedium: title2,
            titleLarge: title2,
            titleMedium: headline,
            titleSmall: subhead,
            bodyLarge: bodyText.copyWith(fontSize: 16),
            // Default for every Text: inherited tracking keeps Inter tight.
            bodyMedium: const TextStyle(
                fontFamily: 'Inter', fontSize: 15, letterSpacing: -.15,
                color: primaryText),
            bodySmall: footnote,
            labelLarge: const TextStyle(
                fontFamily: 'Inter', fontSize: 15, letterSpacing: -.15,
                fontWeight: FontWeight.w600),
          ),
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: black,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceRaised,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: muted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          borderSide: const BorderSide(color: lime, width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: lime,
          foregroundColor: black,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
              fontSize: 16, letterSpacing: -.2, fontWeight: FontWeight.w700),
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceRaised,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceRaised,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: surfaceRaised,
        selectedColor: lime,
        side: BorderSide.none,
        shape: StadiumBorder(),
        labelStyle: TextStyle(color: primaryText),
        secondaryLabelStyle: TextStyle(color: black),
      ),
      dividerTheme: const DividerThemeData(
        color: line,
        thickness: .5,
        space: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
      ),
    );
  }
}
