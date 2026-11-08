import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/database/local_database.dart';
import '../../data/repositories/sudoku_repository.dart';
import '../sudoku/domain/models/sudoku_config.dart';
import '../sudoku/presentation/screens/game_screen.dart';

class DailyChallengeScreen extends StatefulWidget {
  const DailyChallengeScreen({super.key});
  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen> {
  late final DateTime today = DateTime.now();
  late final String dateKey = _dateKey(today);
  late final int seed = today.year * 10000 + today.month * 100 + today.day;
  late Future<bool> completed;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    completed =
        SudokuRepository(LocalDatabase.instance).dailyCompleted(dateKey);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Daily challenge')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: FutureBuilder<bool>(
              future: completed,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                        'Daily challenge status is unavailable: ${snapshot.error}'),
                  );
                }
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final isComplete = snapshot.data!;
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                        isComplete
                            ? Icons.check_circle_outline
                            : Icons.today_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(_prettyDate(today),
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    const Text(
                        'Today’s Classic Sudoku is generated from a stable local date seed. It works offline and is the same on this device for today.'),
                    const SizedBox(height: 8),
                    Text(isComplete ? 'Completed today' : 'Classic · Easy',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: isComplete || busy ? null : _start,
                      icon: busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.play_arrow),
                      label: Text(busy
                          ? 'Creating challenge…'
                          : isComplete
                              ? 'Completed'
                              : 'Start today’s challenge'),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52)),
                    ),
                  ]),
                );
              },
            ),
          ),
        ),
      );

  Future<void> _start() async {
    setState(() => busy = true);
    try {
      final puzzle = await GameScreen.createPuzzle(
        SudokuConfig.classic,
        SudokuDifficulty.easy,
        seed: seed,
      );
      if (!mounted) return;
      context.push('/game', extra: GameLaunch(puzzle, dateKey));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  static String _prettyDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
