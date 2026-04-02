import 'package:flutter/material.dart';

import 'ifa_tokens.dart';

class IfaTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: IfaTokens.paper,
      colorScheme: const ColorScheme.light(
        primary: IfaTokens.greenPrimary,
        secondary: IfaTokens.goldMuted,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: IfaTokens.greenPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: IfaTokens.ink,
        ),
        bodyLarge: TextStyle(fontSize: 15, height: 1.55, color: IfaTokens.ink),
      ),
      cardTheme: CardTheme(
        color: IfaTokens.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: IfaTokens.border),
        ),
      ).data,
    );
  }
}
