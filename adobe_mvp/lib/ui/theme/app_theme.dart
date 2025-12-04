// app_theme.dart
// Creates ThemeData from minimal figma_tokens.json. Provides AppTheme static helpers.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class AppTheme {
  static ThemeData lightTheme = _buildLight();
  static ThemeData darkTheme = _buildDark();

  static ThemeData _buildLight() {
    // Load tokens synchronously is awkward; for scaffold we use hardcoded fallback.
    final primary = const Color(0xFF0D47A1);
    final accent = const Color(0xFFFF6F00);

    return ThemeData(
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(seedColor: primary, primary: primary, secondary: accent),
      scaffoldBackgroundColor: const Color(0xFFF7F8FA),
      useMaterial3: true,
    );
  }

  static ThemeData _buildDark() {
    // Preserve the exact visual tokens you asked for.
    final onColor = Colors.white;
    final cardColor = const Color(0xFF1E1E1E); // panel/background color you specified
    final accent = const Color(0xFFE2AE01);
    final actionBlue = const Color(0xFF3B62FB); // active accent used in UI
    final actionRed = const Color(0xFFDB4437);

    // Start from a seed color scheme and then override the specific tokens we need
    final colorScheme = ColorScheme.fromSeed(
      seedColor: actionBlue,
      primary: onColor,
      secondary: accent,
      brightness: Brightness.dark,
      
    ).copyWith(
      onPrimary: onColor,
      onSecondary: actionBlue,
      onSurface: onColor,
      onBackground: onColor,
      onError: onColor, 
      surface: cardColor,
      surfaceContainerHighest: const Color(0xFF4D4B4B),
      tertiary: const Color(0xFF077B18),
      inversePrimary: actionRed,
      background: const Color(0xFF111111),
    );

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      canvasColor: Colors.white, // set canvasColor to white
      textTheme: Typography.whiteMountainView.apply(bodyColor: onColor, displayColor: onColor, fontFamily: 'Adobe Clean'),
      primaryTextTheme: Typography.whiteMountainView.apply(bodyColor: onColor, displayColor: onColor, fontFamily: 'Adobe Clean'),
      cardColor: cardColor,
      secondaryHeaderColor: const Color(0xFF3B62FB),
      // primaryColorLight: Colors.white,
      scaffoldBackgroundColor: const Color(0xFF111111),
      useMaterial3: true,
      iconTheme: IconThemeData(color: onColor),
    );
  }
  // Optional: load tokens at runtime (not used by default but useful later)
  static Future<Map<String, dynamic>> loadTokens() async {
    final s = await rootBundle.loadString('lib/ui/theme/figma_tokens.json');
    return jsonDecode(s) as Map<String, dynamic>;
  }
}
