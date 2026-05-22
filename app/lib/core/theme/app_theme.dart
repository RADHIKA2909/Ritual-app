import 'package:flutter/material.dart';

class AppTheme {
  // ── Ritual Premium Palette ─────────────────────────────────────────
  // Deep Indigo / Amethyst / Warm Gold
  // Light: Porcelain white with warm tones
  // Dark: Near-black with rich purple depth

  // --- Primary brand color: deep indigo/violet
  static const Color primaryLight = Color(0xFF5B4FCF);   // Rich indigo
  static const Color primaryDark  = Color(0xFF7B6FE8);   // Soft lavender-indigo (glows on dark)

  // --- Accent: warm gold (for streaks, highlights)
  static const Color accent        = Color(0xFFE8A838);

  // --- Light surfaces
  static const Color bgLight       = Color(0xFFF7F6FC);  // Near-white with violet tint
  static const Color surfaceLight  = Color(0xFFFFFFFF);
  static const Color cardLight     = Color(0xFFF0EEF9);  // Lavender tinted card

  // --- Dark surfaces
  static const Color bgDark        = Color(0xFF0F0E17);  // Very deep indigo-black
  static const Color surfaceDark   = Color(0xFF1A1830);  // Dark indigo
  static const Color cardDark      = Color(0xFF231F3B);  // Slightly lighter card

  // --- Text
  static const Color textDark      = Color(0xFF1A1830);
  static const Color textLight     = Color(0xFFF0EEFF);
  static const Color textMuted     = Color(0xFF9992C8);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primaryLight,
        secondary: accent,
        background: bgLight,
        surface: surfaceLight,
        onPrimary: Colors.white,
        onBackground: textDark,
        onSurface: textDark,
        surfaceVariant: cardLight,
        outline: const Color(0xFFD4CEEF),
      ),
      scaffoldBackgroundColor: bgLight,
      appBarTheme: AppBarTheme(
        backgroundColor: bgLight,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textDark),
        titleTextStyle: const TextStyle(
          color: textDark,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      fontFamily: 'Inter',
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryLight,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryLight,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        color: cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD4CEEF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD4CEEF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryLight, width: 2),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primaryDark,
        secondary: accent,
        background: bgDark,
        surface: surfaceDark,
        onPrimary: Colors.white,
        onBackground: textLight,
        onSurface: textLight,
        surfaceVariant: cardDark,
        outline: const Color(0xFF3A3460),
      ),
      scaffoldBackgroundColor: bgDark,
      appBarTheme: AppBarTheme(
        backgroundColor: bgDark,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textLight),
        titleTextStyle: const TextStyle(
          color: textLight,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      fontFamily: 'Inter',
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryDark,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryDark,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF3A3460)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF3A3460)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryDark, width: 2),
        ),
      ),
    );
  }
}
