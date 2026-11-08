import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';

ThemeMode initialThemeMode = ThemeMode.system;
final themeModeProvider = StateProvider<ThemeMode>((ref) => initialThemeMode);

class SudokuMasterApp extends ConsumerWidget {
  const SudokuMasterApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        title: 'Sudoku Master',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ref.watch(themeModeProvider),
        routerConfig: appRouter,
      );
}
