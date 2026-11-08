import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// SAKINA design system: calm emerald, restrained gold, and warm neutrals.
const Color gold = Color(0xFFC9A24B);
const Color goldDeep = Color(0xFF9C7A2B);
const Color cream = Color(0xFFF7F3EA);
const Color creamCard = Color(0xFFFFFDF9);
const Color ink = Color(0xFF17231F);
const Color inkMuted = Color(0xFF65716C);
const double radiusSmall = 14;
const double radiusCard = 22;
const double radiusLarge = 30;

/// ألوان أيقونات الاختصارات (تدرج هادئ متناسق مع المراجع).
const tintGreen = Color(0xFF2E8B6A);
const tintOrange = Color(0xFFE8892B);
const tintBlue = Color(0xFF4F7CC4);
const tintPurple = Color(0xFF8A5CC2);
const tintGold = Color(0xFFD4A017);
const tintRose = Color(0xFFC4505F);

class AccentOption {
  final String name;
  final Color color;
  const AccentOption(this.name, this.color);
}

const accents = <AccentOption>[
  AccentOption('أخضر سكينة', Color(0xFF087A5B)),
  AccentOption('زمردي', Color(0xFF14695A)),
  AccentOption('أزرق ليلي', Color(0xFF2A5D8F)),
  AccentOption('بنفسجي', Color(0xFF6B4C9A)),
  AccentOption('ذهبي', Color(0xFFA37F1E)),
  AccentOption('عنابي', Color(0xFF8E3B46)),
  AccentOption('برتقالي', Color(0xFFD9772B)),
  AccentOption('ترابي', Color(0xFF8B5E3C)),
];

const fontChoices = <String>['Cairo', 'Tajawal', 'Almarai', 'Amiri'];

TextTheme _textFor(String font, TextTheme base) {
  switch (font) {
    case 'Tajawal':
      return GoogleFonts.tajawalTextTheme(base);
    case 'Almarai':
      return GoogleFonts.almaraiTextTheme(base);
    case 'Amiri':
      return GoogleFonts.amiriTextTheme(base);
    default:
      return GoogleFonts.cairoTextTheme(base);
  }
}

TextStyle quranStyle(double size, Color color) {
  try {
    return GoogleFonts.amiriQuran(fontSize: size, height: 2.1, color: color);
  } catch (_) {
    return TextStyle(fontSize: size, height: 2.1, color: color);
  }
}

ThemeData buildTheme(Brightness brightness, int accentIndex, String font) {
  final dark = brightness == Brightness.dark;
  final seed = accents[accentIndex.clamp(0, accents.length - 1)].color;
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    surface: dark ? const Color(0xFF17231F) : creamCard,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final text = _textFor(font, base.textTheme);
  final outline = dark ? Colors.white.withAlpha(22) : const Color(0xFFE6E8E2);
  return base.copyWith(
    scaffoldBackgroundColor: dark ? const Color(0xFF0E1714) : cream,
    textTheme: text,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: dark ? const Color(0xFF0E1714) : cream,
      surfaceTintColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      titleTextStyle: text.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w800,
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusCard),
        side: BorderSide(color: outline),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF1B2924) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: scheme.onSurface.withAlpha(125)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSmall),
        borderSide: BorderSide(color: outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSmall),
        borderSide: BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSmall),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(color: scheme.primary.withAlpha(90)),
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      side: BorderSide(color: outline),
      labelStyle: text.labelMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 70,
      elevation: 0,
      backgroundColor: dark ? const Color(0xFF17231F) : creamCard,
      indicatorColor: scheme.primary.withAlpha(dark ? 58 : 28),
      labelTextStyle: WidgetStateProperty.resolveWith((states) =>
          text.labelSmall?.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
          )),
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    iconTheme: IconThemeData(color: scheme.onSurface),
  );
}
