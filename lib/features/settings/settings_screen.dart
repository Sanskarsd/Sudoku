import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app.dart';
import 'game_settings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _save(String key, Object value) async {
    final preferences = await SharedPreferences.getInstance();
    if (value is bool) await preferences.setBool(key, value);
    if (value is int) await preferences.setInt(key, value);
    if (value is String) await preferences.setString(key, value);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(gameSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        DropdownButtonFormField<ThemeMode>(
          initialValue: ref.watch(themeModeProvider),
          decoration: const InputDecoration(labelText: 'Appearance'),
          items: const [
            DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
            DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
            DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
          ],
          onChanged: (mode) async {
            if (mode == null) return;
            ref.read(themeModeProvider.notifier).state = mode;
            await _save('theme_mode', mode.name);
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: settings.highlightMistakes,
          title: const Text('Highlight conflicts'),
          onChanged: (value) {
            ref.read(gameSettingsProvider.notifier).state =
                settings.copyWith(highlightMistakes: value);
            _save('highlight_mistakes', value);
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: settings.timerEnabled,
          title: const Text('Show timer'),
          onChanged: (value) {
            ref.read(gameSettingsProvider.notifier).state =
                settings.copyWith(timerEnabled: value);
            _save('timer_enabled', value);
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: settings.automaticNotes,
          title: const Text('Remove notes after entering a number'),
          onChanged: (value) {
            ref.read(gameSettingsProvider.notifier).state =
                settings.copyWith(automaticNotes: value);
            _save('automatic_notes', value);
          },
        ),
        DropdownButtonFormField<int?>(
          initialValue: settings.mistakeLimit,
          decoration: const InputDecoration(labelText: 'Mistake limit'),
          items: const [
            DropdownMenuItem<int?>(value: null, child: Text('No limit')),
            DropdownMenuItem<int?>(value: 3, child: Text('3 mistakes')),
            DropdownMenuItem<int?>(value: 5, child: Text('5 mistakes')),
            DropdownMenuItem<int?>(value: 10, child: Text('10 mistakes')),
          ],
          onChanged: (value) {
            final next = settings.copyWith(
              mistakeLimit: value,
              clearMistakeLimit: value == null,
            );
            ref.read(gameSettingsProvider.notifier).state = next;
            if (value == null) {
              SharedPreferences.getInstance()
                  .then((p) => p.remove('mistake_limit'));
            } else {
              _save('mistake_limit', value);
            }
          },
        ),
      ]),
    );
  }
}
