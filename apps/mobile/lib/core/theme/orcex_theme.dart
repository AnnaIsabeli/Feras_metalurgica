import 'package:flutter/material.dart';

ThemeData orcexTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  fontFamily: 'Inter',
  colorScheme: const ColorScheme.dark(
    primary: Color(0xffff6d00),
    secondary: Color(0xffffa261),
    surface: Color(0xff373533),
    onPrimary: Colors.white,
    onSurface: Colors.white,
  ),
  scaffoldBackgroundColor: const Color(0xff373533),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: Color(0xff373533),
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      fontFamily: 'Inter',
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: Color(0xff373533),
    ),
  ),
  cardTheme: CardThemeData(
    color: const Color(0xff42413f),
    elevation: 0,
    margin: const EdgeInsets.symmetric(vertical: 6),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: Color(0x26ffffff), width: 2),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xff292724),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    labelStyle: const TextStyle(color: Color(0xffc5c0b8)),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xff77716b)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xff77716b)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xffff6d00), width: 2),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xffff6d00),
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 44),
      side: const BorderSide(color: Color(0xff8b8279)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: const Color(0xff3d2a1a),
    labelStyle: const TextStyle(
      fontFamily: 'Inter',
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Color(0xffff8b37),
    ),
    side: BorderSide.none,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    height: 80,
    indicatorColor: const Color(0x1aff6d00),
    labelTextStyle: WidgetStateProperty.resolveWith(
      (states) => TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        color: states.contains(WidgetState.selected)
            ? const Color(0xffb94e00)
            : const Color(0xff373533),
      ),
    ),
    iconTheme: WidgetStateProperty.resolveWith(
      (states) => IconThemeData(
        color: states.contains(WidgetState.selected)
            ? const Color(0xffff6d00)
            : const Color(0xff373533),
      ),
    ),
  ),
);
