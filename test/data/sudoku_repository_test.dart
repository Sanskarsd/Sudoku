import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sudoku_master/data/database/local_database.dart';
import 'package:sudoku_master/data/migrations/database_migrations.dart';
import 'package:sudoku_master/data/repositories/sudoku_repository.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('v1 database migrates while preserving existing game totals', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute(
        'CREATE TABLE games(id INTEGER PRIMARY KEY, saved_at TEXT NOT NULL, payload TEXT NOT NULL, completed INTEGER NOT NULL DEFAULT 0)');
    await db.execute(
        'CREATE TABLE stats(id INTEGER PRIMARY KEY, games_played INTEGER NOT NULL DEFAULT 0, games_won INTEGER NOT NULL DEFAULT 0, best_seconds INTEGER)');
    await db.insert('stats',
        {'id': 1, 'games_played': 4, 'games_won': 3, 'best_seconds': 89});

    await DatabaseMigrations.migrate(db, 1, 2);
    final stats = (await db.query('stats')).single;
    final columns = (await db.rawQuery('PRAGMA table_info(games)'))
        .map((row) => row['name'])
        .toSet();
    expect(stats['games_started'], 4);
    expect(stats['games_won'], 3);
    expect(stats['best_seconds'], 89);
    expect(columns.contains('daily_date'), isTrue);
    expect(
        await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='completion_records'"),
        hasLength(1));
    await db.close();
  });

  test('save restores game payload and completion is recorded once', () async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (database, version) =>
            DatabaseMigrations.createLatest(database),
      ),
    );
    final repository = SudokuRepository(LocalDatabase.test(db));
    final payload = <String, Object?>{
      'mode': 2,
      'difficulty': 0,
      'initial': [
        [1, 0],
        [0, 1]
      ],
      'board': [
        [1, 2],
        [2, 1]
      ],
      'solution': [
        [1, 2],
        [2, 1]
      ],
      'notes': [[], []],
      'elapsed': 32,
      'mistakes': 1,
      'hints': 0,
      'finished': true,
    };
    final id = await repository.save(payload);
    final restored = await repository.latest();
    expect(restored?['board'], payload['board']);
    expect(restored?['_gameId'], id);

    for (var i = 0; i < 2; i++) {
      await repository.recordCompletion(
        gameId: id,
        seconds: 32,
        mode: 2,
        difficulty: 0,
        hints: 0,
        mistakes: 1,
        payload: payload,
      );
    }
    final stats = await repository.statistics();
    expect(stats['games_started'], 1);
    expect(stats['games_won'], 1);
    expect(stats['total_seconds'], 32);
    expect(stats['mistakes_made'], 1);
    expect(await repository.savedGames(), isEmpty);
    await db.close();
  });
}
