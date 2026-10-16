import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.dark ? Palette.night : Palette.day;
  final base = ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Brand.coral,
      brightness: b,
      primary: Brand.coral,
      surface: p.card,
    ),
    scaffoldBackgroundColor: p.sand,
  );
  final text = GoogleFonts.readexProTextTheme(base.textTheme).apply(
    bodyColor: p.ink,
    displayColor: p.ink,
  );
  return base.copyWith(
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium?.copyWith(fontSize: 26, fontWeight: FontWeight.w700),
      titleLarge: text.titleLarge?.copyWith(fontSize: 19, fontWeight: FontWeight.w700),
      titleMedium: text.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 14.5),
      bodySmall: text.bodySmall?.copyWith(fontSize: 12.5, color: p.muted),
    ),
    extensions: [p],
    appBarTheme: AppBarTheme(
      backgroundColor: p.sand,
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: p.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        side: BorderSide(color: p.edge),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.card,
      indicatorColor: Brand.coral.withValues(alpha: .14),
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(
        GoogleFonts.readexPro(fontSize: 11.5, fontWeight: FontWeight.w600, color: p.ink),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? Brand.coral : p.muted),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Brand.coral,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.btn)),
        textStyle: GoogleFonts.readexPro(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    dividerTheme: DividerThemeData(color: p.edge, space: 1, thickness: 1),
  );
}
