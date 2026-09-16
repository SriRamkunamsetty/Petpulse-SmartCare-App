import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tokens.dart';

/// Heading font (Caprasimo) and body font (Figtree), matching styles.css
/// `--font-heading` / `--font-body`.
TextStyle ppHeading(
    {double size = 20, Color? color, double letterSpacing = -0.3}) {
  return GoogleFonts.caprasimo(
    fontSize: size,
    color: color ?? PpColors.text,
    height: 1.12,
    letterSpacing: letterSpacing,
  );
}

TextStyle ppBody({
  double size = 15,
  FontWeight weight = FontWeight.w400,
  Color? color,
}) {
  return GoogleFonts.figtree(
    fontSize: size,
    fontWeight: weight,
    color: color ?? PpColors.text,
    height: 1.4,
  );
}

ThemeData buildPpTheme() {
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: PpColors.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: PpColors.accent,
      primary: PpColors.accent,
      secondary: PpColors.accent2,
      surface: PpColors.surface,
      brightness: Brightness.light,
    ),
    fontFamily: GoogleFonts.figtree().fontFamily,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: PpColors.text,
      displayColor: PpColors.text,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}
