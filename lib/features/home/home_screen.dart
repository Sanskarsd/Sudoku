import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/database/local_database.dart';
import '../../data/repositories/sudoku_repository.dart';
import '../sudoku/presentation/screens/game_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Sudoku Master'),
          actions: [
            IconButton(
              tooltip: 'Settings',
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.all(24),
                shrinkWrap: true,
                children: [
                  const SizedBox(height: 18),
                  Icon(
                    Icons.grid_on_rounded,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'A little logic, every day.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Play offline. Your progress stays on this device.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: () => context.push('/new-game'),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('New game'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.all(18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/daily'),
                    icon: const Icon(Icons.today_outlined),
                    label: const Text('Daily challenge'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _resume(context),
                    icon: const Icon(Icons.restore),
                    label: const Text('Resume saved game'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/saved-games'),
                    icon: const Icon(Icons.bookmarks_outlined),
                    label: const Text('Saved games'),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16)),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/statistics'),
                    icon: const Icon(Icons.insights_outlined),
                    label: const Text('Statistics'),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16)),
                  ),
                  const SizedBox(height: 16),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Mini Sudoku is a simplified 3×3 Latin-square game: each row and column contains 1, 2, 3 exactly once. It has no boxes and limited difficulty variation.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const _StatsCard(),
                ],
              ),
            ),
          ),
        ),
      );
  Future<void> _resume(BuildContext context) async {
    final game = await GameScreen.loadLatest();
    if (!context.mounted) return;
    if (game == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No saved game yet.')));
      return;
    }
    context.push('/game', extra: game);
  }
}

class _StatsCard extends StatefulWidget {
  const _StatsCard();
  @override
  State<_StatsCard> createState() => _StatsCardState();
}

class _StatsCardState extends State<_StatsCard> {
  late final future = SudokuRepository(LocalDatabase.instance).statistics();
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, Object?>>(
        future: future,
        builder: (context, snapshot) {
          final stats = snapshot.data;
          final played = stats?['games_played'] as int? ?? 0;
          final wins = stats?['games_won'] as int? ?? 0;
          final best = stats?['best_seconds'] as int?;
          return Card(
            child: ListTile(
              leading: const Icon(Icons.insights),
              title: const Text('Statistics'),
              subtitle: Text(snapshot.hasError
                  ? 'Statistics are unavailable on this device.'
                  : '$wins wins · $played games${best == null ? '' : ' · best ${best ~/ 60}:${(best % 60).toString().padLeft(2, '0')}'}'),
            ),
          );
        },
      );
}
