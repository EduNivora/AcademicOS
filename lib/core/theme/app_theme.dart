import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFF5B6CFF);
  static const Color primaryStrong = Color(0xFF3B82F6);
  static const Color primaryAction = Color(0xFF4E5FD8);
  // WCAG AA text tones paired with the app's light and dark surfaces.
  static const Color primaryTextLight = Color(0xFF4E5FD8);
  static const Color primaryTextDark = Color(0xFFA5B4FC);
  static const Color mutedTextLight = Color(0xFF475569);
  static const Color accessibleOutline = Color(0xFF64748B);
  static const Color primarySoft = Color(0xFFE0E7FF);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color surface = Color(0xFF1E293B);
  static const Color surfaceSoft = Color(0xFF0F172A);
  static const Color accentGlow = Color(0xFF93C5FD);
  static const Color textPrimary = Color(0xFFE2E8F0);
  static const Color textSecondary = Color(0xFFCBD5E1);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color border = Color(0xFF334155);

  static const double radiusSm = 12.0;
  static const double radiusMd = 16.0;
  static const double radiusLg = 22.0;

  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;

  static ThemeData lightTheme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF5F7FF),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
      ).copyWith(primary: primaryAction, onPrimary: Colors.white),
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: const Color(0xFFE2E8F0), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryAction,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(color: Color(0xFF64748B)),
        prefixIconColor: primary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: accessibleOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: accessibleOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryAction,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          side: const BorderSide(color: accessibleOutline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryTextLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide.none,
        selectedColor: primarySoft,
        backgroundColor: const Color(0xFFF8FAFC),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.94),
        indicatorColor: primarySoft,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? primaryTextLight
                : mutedTextLight,
            fontWeight: FontWeight.w600,
          );
        }),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: Color(0xFF0F172A),
          fontWeight: FontWeight.w800,
        ),
        titleLarge: TextStyle(
          color: Color(0xFF0F172A),
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(color: Color(0xFF0F172A)),
        bodyMedium: TextStyle(color: Color(0xFF334155)),
      ),
    );
  }

  static ThemeData darkTheme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF020817),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
      ).copyWith(primary: primaryAction, onPrimary: Colors.white),
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0B1220),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF111827).withValues(alpha: 0.9),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryAction,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0F172A).withValues(alpha: 0.9),
        hintStyle: const TextStyle(color: textMuted),
        prefixIconColor: Colors.white70,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: accessibleOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: accessibleOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryAction,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          side: const BorderSide(color: accessibleOutline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryTextDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide.none,
        selectedColor: const Color(0xFF312E81).withValues(alpha: 0.8),
        backgroundColor: const Color(0xFF111827),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF0B1220).withValues(alpha: 0.94),
        indicatorColor: const Color(0xFF312E81).withValues(alpha: 0.5),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? primaryTextDark
                : textMuted,
            fontWeight: FontWeight.w600,
          );
        }),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w800,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textSecondary),
      ),
    );
  }
}
