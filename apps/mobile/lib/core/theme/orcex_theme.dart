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

/// Dark surfaces and restrained controls, keeping the familiar ORCEX layout.
ThemeData orcexDarkTheme() {
  const background = Color(0xff1c1c1e);
  const surface = Color(0xff2c2c2e);
  const accent = Color(0xffff8a34);
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Inter',
    colorScheme: const ColorScheme.dark(
      primary: accent,
      secondary: accent,
      surface: surface,
      onPrimary: Color(0xff171717),
      onSurface: Color(0xfff2f2f7),
      outline: Color(0xff48484a),
    ),
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: Color(0xff48484a)),
  );
  return base.copyWith(
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: Color(0xfff2f2f7),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Color(0xfff2f2f7),
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0x14ffffff)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      labelStyle: const TextStyle(color: Color(0xffb8b8c0)),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: accent, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: const Color(0xff171717),
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xfff2f2f7),
        minimumSize: const Size(0, 46),
        side: const BorderSide(color: Color(0xff48484a)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      height: 76,
      indicatorColor: const Color(0x26ff8a34),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? accent
              : const Color(0xffa3a3ad),
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? accent
              : const Color(0xffa3a3ad),
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xff38383a),
      thickness: .5,
      space: 28,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xff3a2b22),
      labelStyle: const TextStyle(
        color: accent,
        fontFamily: 'Inter',
        fontWeight: FontWeight.w500,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    ),
  );
}
