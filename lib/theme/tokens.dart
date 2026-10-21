import 'package:flutter/material.dart';

/// Brand colours carried over from the prototype.
class Brand {
  static const coral = Color(0xFFF25C2C);
  static const navy = Color(0xFF14213D);
  static const leaf = Color(0xFF2FB36C);
  static const sea = Color(0xFF12A4B8);
  static const seaDeep = Color(0xFF0B6E8A);
  static const sun = Color(0xFFFFB81C);
  static const grape = Color(0xFF5B3FD9);
}

/// Surface + text tokens that change between day and night.
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.sand,
    required this.sand2,
    required this.card,
    required this.ink,
    required this.muted,
    required this.edge,
    required this.good,
    required this.goodSoft,
    required this.bad,
    required this.badSoft,
    required this.sunSoft,
    required this.goldInk,
    required this.grapeSoft,
    required this.grapeInk,
  });

  final Color sand, sand2, card, ink, muted, edge;
  final Color good, goodSoft, bad, badSoft, sunSoft, goldInk, grapeSoft, grapeInk;

  static const day = Palette(
    sand: Color(0xFFF4F2ED),
    sand2: Color(0xFFECE7DD),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF14213D),
    muted: Color(0xFF5E6679),
    edge: Color(0xFFE3DCCF),
    good: Color(0xFF1F7A4A),
    goodSoft: Color(0xFFE3F5EA),
    bad: Color(0xFFC2410C),
    badSoft: Color(0xFFFFE7DD),
    sunSoft: Color(0xFFFFF3D6),
    goldInk: Color(0xFF6B4A00),
    grapeSoft: Color(0xFFEEEAFF),
    grapeInk: Color(0xFF4B2FC9),
  );

  static const night = Palette(
    sand: Color(0xFF0E1525),
    sand2: Color(0xFF22335A),
    card: Color(0xFF17223D),
    ink: Color(0xFFEEF2FA),
    muted: Color(0xFFA3AEC6),
    edge: Color(0xFF26314E),
    good: Color(0xFF4ADE8B),
    goodSoft: Color(0xFF123425),
    bad: Color(0xFFFF9A6B),
    badSoft: Color(0xFF3A1E16),
    sunSoft: Color(0xFF33280F),
    goldInk: Color(0xFFFFD27A),
    grapeSoft: Color(0xFF2A2350),
    grapeInk: Color(0xFFC3B5FF),
  );

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) {
    if (other is! Palette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return Palette(
      sand: l(sand, other.sand),
      sand2: l(sand2, other.sand2),
      card: l(card, other.card),
      ink: l(ink, other.ink),
      muted: l(muted, other.muted),
      edge: l(edge, other.edge),
      good: l(good, other.good),
      goodSoft: l(goodSoft, other.goodSoft),
      bad: l(bad, other.bad),
      badSoft: l(badSoft, other.badSoft),
      sunSoft: l(sunSoft, other.sunSoft),
      goldInk: l(goldInk, other.goldInk),
      grapeSoft: l(grapeSoft, other.grapeSoft),
      grapeInk: l(grapeInk, other.grapeInk),
    );
  }
}

/// Spacing + radii on a 4pt grid.
class Gap {
  static const xs = 4.0, s = 8.0, m = 12.0, l = 16.0, xl = 22.0, xxl = 32.0;
}

class Radii {
  static const card = 18.0, btn = 14.0, chip = 999.0, sheet = 24.0;
}

extension PaletteX on BuildContext {
  Palette get pal => Theme.of(this).extension<Palette>()!;
}

/// Brand gradients (from the share templates).
class Grad {
  static const sunset = LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFFF25C2C), Color(0xFFFFB81C)]);
  static const night = LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF22335A), Color(0xFF0E1525)]);
  static const sea = LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF0B6E8A), Color(0xFF12A4B8)]);
  static const purple = LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF4B2FC9), Color(0xFFB04BD9)]);
}
