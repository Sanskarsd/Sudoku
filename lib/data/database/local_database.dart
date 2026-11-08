import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../migrations/database_migrations.dart';

class LocalDatabase {
  LocalDatabase._();
  LocalDatabase.test(Database database) : _db = database;
  static final instance = LocalDatabase._();
  Database? _db;
  Future<Database> get database async => _db ??= await openDatabase(
        p.join(await getDatabasesPath(), 'sudoku_master.db'),
        version: 2,
        onCreate: (db, version) => DatabaseMigrations.createLatest(db),
        onUpgrade: DatabaseMigrations.migrate,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      );
}
