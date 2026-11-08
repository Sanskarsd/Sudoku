import 'package:sqflite/sqflite.dart';

class DatabaseMigrations {
  static Future<void> createLatest(Database db) async {
    await db.execute('''CREATE TABLE games(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      saved_at TEXT NOT NULL,
      payload TEXT NOT NULL,
      completed INTEGER NOT NULL DEFAULT 0,
      daily_date TEXT
    )''');
    await db.execute('''CREATE TABLE stats(
      id INTEGER PRIMARY KEY CHECK(id = 1),
      games_started INTEGER NOT NULL DEFAULT 0,
      games_played INTEGER NOT NULL DEFAULT 0,
      games_won INTEGER NOT NULL DEFAULT 0,
      best_seconds INTEGER,
      total_seconds INTEGER NOT NULL DEFAULT 0,
      hints_used INTEGER NOT NULL DEFAULT 0,
      mistakes_made INTEGER NOT NULL DEFAULT 0,
      current_streak INTEGER NOT NULL DEFAULT 0,
      longest_streak INTEGER NOT NULL DEFAULT 0,
      last_completion_date TEXT
    )''');
    await db.insert('stats', {'id': 1});
    await db.execute('''CREATE TABLE completion_records(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      game_id INTEGER NOT NULL UNIQUE,
      completed_at TEXT NOT NULL,
      seconds INTEGER NOT NULL,
      mode INTEGER NOT NULL,
      difficulty INTEGER NOT NULL,
      hints INTEGER NOT NULL,
      mistakes INTEGER NOT NULL,
      daily_date TEXT,
      FOREIGN KEY(game_id) REFERENCES games(id)
    )''');
    await db.execute('''CREATE TABLE daily_challenges(
      challenge_date TEXT PRIMARY KEY,
      mode INTEGER NOT NULL,
      difficulty INTEGER NOT NULL,
      seed INTEGER NOT NULL,
      completed INTEGER NOT NULL DEFAULT 0,
      completed_game_id INTEGER
    )''');
  }

  static Future<void> migrate(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 1) {
      await createLatest(db);
      return;
    }
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE games ADD COLUMN daily_date TEXT');
      await db.execute(
          'ALTER TABLE stats ADD COLUMN games_started INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE stats ADD COLUMN total_seconds INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE stats ADD COLUMN hints_used INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE stats ADD COLUMN mistakes_made INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE stats ADD COLUMN current_streak INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE stats ADD COLUMN longest_streak INTEGER NOT NULL DEFAULT 0');
      await db
          .execute('ALTER TABLE stats ADD COLUMN last_completion_date TEXT');
      await db.execute(
          'UPDATE stats SET games_started = games_played WHERE id = 1');
      await db.execute('''CREATE TABLE completion_records(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        game_id INTEGER NOT NULL UNIQUE,
        completed_at TEXT NOT NULL,
        seconds INTEGER NOT NULL,
        mode INTEGER NOT NULL,
        difficulty INTEGER NOT NULL,
        hints INTEGER NOT NULL,
        mistakes INTEGER NOT NULL,
        daily_date TEXT,
        FOREIGN KEY(game_id) REFERENCES games(id)
      )''');
      await db.execute('''CREATE TABLE daily_challenges(
        challenge_date TEXT PRIMARY KEY,
        mode INTEGER NOT NULL,
        difficulty INTEGER NOT NULL,
        seed INTEGER NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        completed_game_id INTEGER
      )''');
    }
  }
}
