import 'dart:convert';
import 'package:sqflite/sqflite.dart';

import '../database/local_database.dart';

class SudokuRepository {
  SudokuRepository(this.database);
  final LocalDatabase database;

  Future<int> save(Map<String, Object?> game,
      {int? id, bool completed = false}) async {
    final db = await database.database;
    final now = DateTime.now().toIso8601String();
    final dailyDate = game['dailyDate'] as String?;
    final row = {
      'saved_at': now,
      'payload': jsonEncode(game),
      'completed': completed ? 1 : 0,
      'daily_date': dailyDate,
    };
    if (id != null) {
      await db.update('games', row, where: 'id = ?', whereArgs: [id]);
      return id;
    }
    return db.transaction((txn) async {
      final newId = await txn.insert('games', row);
      await txn.rawUpdate(
          'UPDATE stats SET games_started = games_started + 1 WHERE id = 1');
      if (dailyDate != null) {
        await txn.insert(
          'daily_challenges',
          {
            'challenge_date': dailyDate,
            'mode': game['mode'],
            'difficulty': game['difficulty'],
            'seed': game['seed'] ?? 0,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      return newId;
    });
  }

  Future<List<Map<String, Object?>>> savedGames() async =>
      (await (await database.database).query(
        'games',
        where: 'completed = 0',
        orderBy: 'saved_at DESC',
      ))
          .cast<Map<String, Object?>>();

  Future<Map<String, Object?>?> latest() async {
    final rows = await savedGames();
    if (rows.isEmpty) return null;
    final payload =
        jsonDecode(rows.first['payload']! as String) as Map<String, Object?>;
    return {...payload, '_gameId': rows.first['id']};
  }

  Future<void> recordCompletion({
    required int gameId,
    required int seconds,
    required int mode,
    required int difficulty,
    required int hints,
    required int mistakes,
    String? dailyDate,
    required Map<String, Object?> payload,
  }) async {
    final db = await database.database;
    await db.transaction((txn) async {
      await txn.update(
        'games',
        {
          'saved_at': DateTime.now().toIso8601String(),
          'payload': jsonEncode(payload),
          'completed': 1,
          'daily_date': dailyDate,
        },
        where: 'id = ?',
        whereArgs: [gameId],
      );
      final inserted = await txn.insert(
        'completion_records',
        {
          'game_id': gameId,
          'completed_at': DateTime.now().toIso8601String(),
          'seconds': seconds,
          'mode': mode,
          'difficulty': difficulty,
          'hints': hints,
          'mistakes': mistakes,
          'daily_date': dailyDate,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      final alreadyRecorded = await txn.query('completion_records',
          where: 'game_id = ?', whereArgs: [gameId], columns: ['id']);
      if (alreadyRecorded.isEmpty || inserted == 0) return;
      await txn.update('games', {'completed': 1},
          where: 'id = ?', whereArgs: [gameId]);

      final rows = await txn.query('stats', where: 'id = 1', limit: 1);
      final stats = rows.single;
      final now = DateTime.now();
      final today = _dateKey(now);
      final yesterday = _dateKey(now.subtract(const Duration(days: 1)));
      final lastDate = stats['last_completion_date'] as String?;
      final current = stats['current_streak']! as int;
      final newStreak = lastDate == today
          ? current
          : lastDate == yesterday
              ? current + 1
              : 1;
      final previousBest = stats['best_seconds'] as int?;
      await txn.update(
          'stats',
          {
            'games_played': (stats['games_played']! as int) + 1,
            'games_won': (stats['games_won']! as int) + 1,
            'best_seconds': previousBest == null || seconds < previousBest
                ? seconds
                : previousBest,
            'total_seconds': (stats['total_seconds']! as int) + seconds,
            'hints_used': (stats['hints_used']! as int) + hints,
            'mistakes_made': (stats['mistakes_made']! as int) + mistakes,
            'current_streak': newStreak,
            'longest_streak': newStreak > (stats['longest_streak']! as int)
                ? newStreak
                : stats['longest_streak'],
            'last_completion_date': today,
          },
          where: 'id = 1');
      if (dailyDate != null) {
        await txn.update(
            'daily_challenges', {'completed': 1, 'completed_game_id': gameId},
            where: 'challenge_date = ?', whereArgs: [dailyDate]);
      }
    });
  }

  Future<Map<String, Object?>> statistics() async {
    final db = await database.database;
    final rows = await db.query('stats', where: 'id = 1', limit: 1);
    return rows.single;
  }

  Future<List<Map<String, Object?>>> completionBreakdown(
      {String? groupBy}) async {
    final db = await database.database;
    final column = switch (groupBy) {
      'mode' => 'mode',
      'difficulty' => 'difficulty',
      'month' => "strftime('%Y-%m', completed_at)",
      _ => null,
    };
    if (column == null) {
      return db.query('completion_records', orderBy: 'completed_at DESC');
    }
    return db.rawQuery(
        'SELECT $column AS category, COUNT(*) AS games, AVG(seconds) AS average_seconds FROM completion_records GROUP BY category ORDER BY category');
  }

  Future<bool> dailyCompleted(String dateKey) async {
    final rows = await (await database.database).query('daily_challenges',
        columns: ['completed'],
        where: 'challenge_date = ?',
        whereArgs: [dateKey],
        limit: 1);
    return rows.isNotEmpty && rows.single['completed'] == 1;
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
