import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/database/local_database.dart';
import '../../data/repositories/sudoku_repository.dart';
import '../sudoku/domain/models/sudoku_config.dart';

class SavedGamesScreen extends StatefulWidget {
  const SavedGamesScreen({super.key});
  @override
  State<SavedGamesScreen> createState() => _SavedGamesScreenState();
}

class _SavedGamesScreenState extends State<SavedGamesScreen> {
  late Future<List<Map<String, Object?>>> games;
  @override
  void initState() {
    super.initState();
    games = SudokuRepository(LocalDatabase.instance).savedGames();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Saved games')),
        body: FutureBuilder<List<Map<String, Object?>>>(
          future: games,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                  child: Text(
                      'Saved games could not be loaded: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.data!.isEmpty) {
              return const Center(
                  child: Text('No saved games. Start a game to see it here.'));
            }
            return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final row = snapshot.data![index];
                  final payload = jsonDecode(row['payload']! as String)
                      as Map<String, Object?>;
                  final mode = SudokuMode.values[payload['mode']! as int];
                  final difficulty =
                      SudokuDifficulty.values[payload['difficulty']! as int];
                  return ListTile(
                    leading: const Icon(Icons.grid_4x4),
                    title: Text(
                        '${SudokuConfig.fromMode(mode).label} · ${difficulty.name}'),
                    subtitle: Text(
                        'Saved ${DateTime.parse(row['saved_at']! as String).toLocal()}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/game',
                        extra: {...payload, '_gameId': row['id']}),
                  );
                });
          },
        ),
      );
}
