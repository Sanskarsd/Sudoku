import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../sudoku/domain/models/sudoku_config.dart';
import '../sudoku/presentation/screens/game_screen.dart';

class NewGameScreen extends StatefulWidget {
  const NewGameScreen({super.key});
  @override
  State<NewGameScreen> createState() => _NewGameScreenState();
}

class _NewGameScreenState extends State<NewGameScreen> {
  SudokuMode mode = SudokuMode.classic;
  SudokuDifficulty difficulty = SudokuDifficulty.easy;
  bool busy = false;
  Object? error;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('New game')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
                padding: const EdgeInsets.all(24),
                shrinkWrap: true,
                children: [
                  Text('Choose your board',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text(
                      'Every puzzle is generated on your device and checked for a unique solution.'),
                  const SizedBox(height: 20),
                  Wrap(
                      spacing: 8,
                      children: SudokuMode.values
                          .map((value) => ChoiceChip(
                                label: Text(SudokuConfig.fromMode(value)
                                    .label
                                    .replaceAll(' Sudoku', '')),
                                selected: mode == value,
                                onSelected: busy
                                    ? null
                                    : (_) => setState(() {
                                          mode = value;
                                          if (mode == SudokuMode.mini) {
                                            difficulty = SudokuDifficulty.easy;
                                          }
                                        }),
                              ))
                          .toList()),
                  if (mode == SudokuMode.mini) ...[
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                          'Mini is a 3×3 Latin-square game with row and column rules only. Its difficulty range is intentionally limited to Easy.'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  DropdownButtonFormField<SudokuDifficulty>(
                    initialValue: difficulty,
                    decoration: const InputDecoration(labelText: 'Difficulty'),
                    items: (mode == SudokuMode.mini
                            ? [SudokuDifficulty.easy]
                            : SudokuDifficulty.values)
                        .map((value) => DropdownMenuItem(
                            value: value, child: Text(_title(value.name))))
                        .toList(),
                    onChanged: busy
                        ? null
                        : (value) => setState(() => difficulty = value!),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text('Could not create this difficulty. ${error!}',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: busy ? null : _start,
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.play_arrow),
                    label: Text(
                        busy ? 'Generating and evaluating…' : 'Start game'),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                  ),
                ]),
          ),
        ),
      );

  Future<void> _start() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final puzzle = await GameScreen.createPuzzle(
          SudokuConfig.fromMode(mode), difficulty);
      if (mounted) context.go('/game', extra: puzzle);
    } catch (exception) {
      if (mounted) setState(() => error = exception);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  static String _title(String value) =>
      '${value[0].toUpperCase()}${value.substring(1)}';
}
