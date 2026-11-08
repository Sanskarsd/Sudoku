import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff5b5bd6)),
        useMaterial3: true,
      );
  static ThemeData dark() => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xffaaa8ff),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      );
}
