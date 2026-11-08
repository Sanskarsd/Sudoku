import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'features/settings/game_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final savedMode = preferences.getString('theme_mode');
  initialThemeMode = ThemeMode.values.firstWhere(
    (mode) => mode.name == savedMode,
    orElse: () => ThemeMode.system,
  );
  initialGameSettings = GameSettings(
    highlightMistakes: preferences.getBool('highlight_mistakes') ?? true,
    automaticNotes: preferences.getBool('automatic_notes') ?? true,
    timerEnabled: preferences.getBool('timer_enabled') ?? true,
    mistakeLimit: preferences.getInt('mistake_limit'),
  );
  runApp(const ProviderScope(child: SudokuMasterApp()));
}
