import 'package:flutter/material.dart';

class AppTheme {
  // WhatsApp brand colors
  static const Color primaryDark = Color(0xFF075E54);
  static const Color primary = Color(0xFF128C7E);
  static const Color primaryLight = Color(0xFF25D366);
  static const Color accentBlue = Color(0xFF34B7F1);

  static const Color chatBackground = Color(0xFFE5DDD5);
  static const Color sentBubble = Color(0xFFDCF8C6);
  static const Color receivedBubble = Color(0xFFFFFFFF);
  static const Color systemMessage = Color(0xFFE1F2FB);

  static const Color textPrimary = Color(0xFF303030);
  static const Color textSecondary = Color(0xFF667781);
  static const Color textTimestamp = Color(0xFF8696A0);
  static const Color divider = Color(0xFFE9EDEF);
  static const Color unreadBadge = Color(0xFF25D366);

  static const Color appBarIconColor = Colors.white;
  static const Color searchBarBg = Color(0xFFF0F2F5);

  static ThemeData whatsAppTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primaryDark,
        secondary: primaryLight,
        surface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
      ),
      scaffoldBackgroundColor: Colors.white,
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryLight,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      dividerTheme: const DividerThemeData(color: divider, thickness: 0.5),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: searchBarBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        hintStyle: const TextStyle(color: textSecondary, fontSize: 15),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: textPrimary, fontSize: 14),
        bodySmall: TextStyle(color: textSecondary, fontSize: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryLight,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
    );
  }
}
