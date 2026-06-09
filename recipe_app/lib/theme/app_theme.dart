import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFFE8632A);    // warm orange
  static const Color surface = Color(0xFFFFF8F0);    // cream
  static const Color onSurface = Color(0xFF2C1810);  // dark brown

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: surface,
        appBarTheme: const AppBarTheme(
          backgroundColor: surface,
          foregroundColor: onSurface,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFEEE0D4), width: 1),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFEEE0D4)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFEEE0D4)),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFFCEEE4),
          selectedColor: primary,
          labelStyle: const TextStyle(fontSize: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      );
}
