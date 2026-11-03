// Темы, как на ПК: 0 - M3E, 1 - Тёплая, 2 - Моно, 3 - Классика, 4 - Лёгкая.

import 'package:flutter/material.dart';

enum ZStyle { m3e, warm, mono, classic, lite }

const styleNames = ['M3E', 'Тёплая', 'Моно', 'Классика', 'Лёгкая'];
const accents = [
  Color(0xFF8E6CEF),
  Color(0xFFC96442),
  Color(0xFF4F8CF7),
  Color(0xFF2FB38C),
  Color(0xFFE8833A),
  Color(0xFFE05584),
  Color(0xFF9AA0A6),
];

/// Смесь как `a.mix(b, f)` в Slint: f - доля цвета [a].
Color mix(Color a, Color b, double f) => Color.lerp(b, a, f)!;

Color brighter(Color c, double f) {
  final h = HSVColor.fromColor(c);
  return h.withValue((h.value * (1 + f)).clamp(0, 1)).withSaturation((h.saturation * (1 - f * 0.35)).clamp(0, 1)).toColor();
}

Color darker(Color c, double f) {
  final h = HSVColor.fromColor(c);
  return h.withValue((h.value / (1 + f)).clamp(0, 1)).toColor();
}

class ZTheme {
  final ZStyle style;
  final bool darkPref;
  final bool animations;
  final Color accent;

  const ZTheme({this.style = ZStyle.classic, this.darkPref = true, this.animations = true, this.accent = const Color(0xFF8E6CEF)});

  ZTheme copyWith({ZStyle? style, bool? dark, bool? animations, Color? accent}) => ZTheme(
        style: style ?? this.style,
        darkPref: dark ?? darkPref,
        animations: animations ?? this.animations,
        accent: accent ?? this.accent,
      );

  bool get m3e => style == ZStyle.m3e;
  bool get warm => style == ZStyle.warm;
  bool get mono => style == ZStyle.mono;
  bool get classic => style == ZStyle.classic;
  bool get lite => style == ZStyle.lite;
  bool get motion => animations && !lite;
  bool get dark => darkPref || classic;

  Duration get fast => Duration(milliseconds: motion ? 150 : 0);
  Duration get normal => Duration(milliseconds: motion ? 320 : 0);
  Duration get slow => Duration(milliseconds: motion ? 600 : 0);

  // ---------- цвета ----------
  Color get background => warm
      ? (dark ? mix(accent, const Color(0xFF262421), .06) : mix(accent, const Color(0xFFF3EFE6), .07))
      : mono
          ? (dark ? Colors.black : Colors.white)
          : classic
              ? const Color(0xFF05010A)
              : m3e
                  ? (dark ? mix(accent, const Color(0xFF07050B), .12) : mix(accent, const Color(0xFFFDFBFF), .04))
                  : dark
                      ? mix(accent, const Color(0xFF100F14), .07)
                      : mix(accent, const Color(0xFFFDFBFF), .05);

  Color get surface => warm
      ? (dark ? mix(accent, const Color(0xFF2E2B27), .07) : mix(accent, const Color(0xFFFAF8F3), .04))
      : mono
          ? (dark ? const Color(0xFF121212) : const Color(0xFFF3F3F3))
          : classic
              ? Colors.white.withValues(alpha: .06)
              : m3e
                  ? (dark ? mix(accent, const Color(0xFF151020), .18) : mix(accent, const Color(0xFFF4EEFC), .10))
                  : dark
                      ? mix(accent, const Color(0xFF1B1921), .10)
                      : mix(accent, const Color(0xFFF3EFF9), .10);

  Color get surfaceHigh => warm
      ? (dark ? mix(accent, const Color(0xFF3A3631), .10) : mix(accent, const Color(0xFFE9E3D6), .12))
      : mono
          ? (dark ? const Color(0xFF1F1F1F) : const Color(0xFFE7E7E7))
          : classic
              ? Colors.white.withValues(alpha: .12)
              : m3e
                  ? (dark ? mix(accent, const Color(0xFF231B33), .26) : mix(accent, const Color(0xFFEBE3F7), .18))
                  : dark
                      ? mix(accent, const Color(0xFF2A2632), .16)
                      : mix(accent, const Color(0xFFE8E1F1), .16);

  Color get onSurface => warm
      ? (dark ? mix(accent, const Color(0xFFECE6DC), .05) : mix(accent, const Color(0xFF2A2520), .08))
      : mono
          ? (dark ? Colors.white : Colors.black)
          : dark
              ? const Color(0xFFEBE6F0)
              : const Color(0xFF1C1A21);

  Color get onSurfaceVariant => warm
      ? (dark ? mix(accent, const Color(0xFFAEA596), .10) : mix(accent, const Color(0xFF6E655B), .10))
      : mono
          ? (dark ? const Color(0xFF8C8C8C) : const Color(0xFF6B6B6B))
          : dark
              ? const Color(0xFFB8B1C4)
              : const Color(0xFF57525F);

  Color get outline => warm
      ? onSurface.withValues(alpha: .14)
      : dark
          ? Colors.white.withValues(alpha: .13)
          : Colors.black.withValues(alpha: .13);

  Color get primary => mono
      ? onSurface
      : m3e
          ? (dark ? mix(accent, Colors.white, .72) : darker(accent, .18))
          : dark
              ? brighter(accent, .28)
              : darker(accent, .12);

  Color get onPrimary => mono
      ? background
      : warm || !dark
          ? Colors.white
          : darker(accent, .70);

  Color get primaryContainer => mono
      ? surfaceHigh
      : warm
          ? mix(accent, background, .20)
          : m3e
              ? (dark ? mix(accent, const Color(0xFF1C1233), .58) : mix(accent, Colors.white, .40))
          : dark
              ? mix(accent, const Color(0xFF2A2433), .38)
              : mix(accent, Colors.white, .24);

  Color get onPrimaryContainer => mono ? onSurface : dark ? mix(accent, Colors.white, .22) : darker(accent, .55);

  Color get success => mono ? accent : dark ? const Color(0xFF86DBA0) : const Color(0xFF1E7A3C);
  Color get error => dark ? const Color(0xFFFFB4AB) : const Color(0xFFBA1A1A);

  // ---------- формы ----------
  double get radiusS => lite ? 4 : warm ? 8 : mono ? 10 : classic ? 8 : 14;
  double get radiusM => lite ? 6 : warm ? 12 : mono ? 14 : classic ? 12 : 22;
  double get radiusL => lite ? 8 : warm ? 16 : mono ? 18 : classic ? 18 : 32;
  bool get pillButtons => m3e || classic;
  bool get cardBorder => warm || classic;

  // ---------- шрифты ----------
  String get font => mono ? 'IBMPlexMono' : classic || lite ? 'Onest' : 'GoogleSans';
  String get headingFont => warm ? 'Lora' : font;
  FontWeight get headingWeight => warm ? FontWeight.w500 : (mono || m3e) ? FontWeight.w600 : FontWeight.w700;
  FontWeight get strongWeight => m3e ? FontWeight.w500 : FontWeight.w600;
  double get displaySize => m3e ? 40 : warm ? 34 : mono ? 26 : 30;
  bool get leftAligned => warm || mono;

  /// Текст в "Моно" - строчными, как в версии для ПК.
  String t(String s) => mono ? s.toLowerCase() : s;

  ThemeData get material => ThemeData(
        useMaterial3: true,
        brightness: dark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: background,
        fontFamily: font,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: dark ? Brightness.dark : Brightness.light,
          primary: primary,
          onPrimary: onPrimary,
          surface: background,
          onSurface: onSurface,
        ),
        splashFactory: lite ? NoSplash.splashFactory : InkSparkle.splashFactory,
      );
}

/// Доступ к текущей теме из любого виджета: `ZThemeScope.of(context)`.
class ZThemeScope extends InheritedWidget {
  final ZTheme theme;
  const ZThemeScope({super.key, required this.theme, required super.child});

  static ZTheme of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ZThemeScope>()?.theme ?? const ZTheme();

  @override
  bool updateShouldNotify(ZThemeScope old) => old.theme != theme;
}
