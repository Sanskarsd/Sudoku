import 'package:flutter_riverpod/flutter_riverpod.dart';

class GameSettings {
  const GameSettings(
      {this.highlightMistakes = true,
      this.automaticNotes = true,
      this.timerEnabled = true,
      this.mistakeLimit});
  final bool highlightMistakes;
  final bool automaticNotes;
  final bool timerEnabled;
  final int? mistakeLimit;
  GameSettings copyWith(
          {bool? highlightMistakes,
          bool? automaticNotes,
          bool? timerEnabled,
          int? mistakeLimit,
          bool clearMistakeLimit = false}) =>
      GameSettings(
        highlightMistakes: highlightMistakes ?? this.highlightMistakes,
        automaticNotes: automaticNotes ?? this.automaticNotes,
        timerEnabled: timerEnabled ?? this.timerEnabled,
        mistakeLimit:
            clearMistakeLimit ? null : mistakeLimit ?? this.mistakeLimit,
      );
}

GameSettings initialGameSettings = const GameSettings();
final gameSettingsProvider =
    StateProvider<GameSettings>((ref) => initialGameSettings);
