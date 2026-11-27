import 'package:flutter/material.dart';

ThemeData buildAppTheme({Brightness brightness = Brightness.light}) {
  const purple = Color(0xFF6345ED);
  const ink = Color(0xFF19172D);
  const muted = Color(0xFF6D687E);
  const line = Color(0xFFE2DEEB);
  final dark = brightness == Brightness.dark;
  final seeded = ColorScheme.fromSeed(
    seedColor: purple,
    brightness: brightness,
  );
  final scheme = dark
      ? seeded
      : seeded.copyWith(
          primary: purple,
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: ink,
          onSurfaceVariant: muted,
          outline: line,
        );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: scheme.outline),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        height: 1.15,
        fontWeight: FontWeight.w700,
        letterSpacing: -1,
        color: scheme.onSurface,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: scheme.onSurface),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.55,
        color: scheme.onSurfaceVariant,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.5,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      labelMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark
          ? scheme.surfaceContainerHighest
          : const Color(0xFFFAF9FD),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      hintStyle: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: border.copyWith(borderSide: BorderSide(color: scheme.error)),
      focusedErrorBorder: border.copyWith(
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
      errorMaxLines: 3,
      helperMaxLines: 2,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
