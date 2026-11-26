import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';
import 'database_migrations.dart';

/// Singleton SQLite database manager for TeaField Capture.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.databaseName);

    return openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onConfigure: (Database db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (Database db, int version) async {
        await DatabaseMigrations.createTables(db);
      },
      onUpgrade: DatabaseMigrations.upgrade,
    );
  }

  /// Allows injecting an in-memory database during unit tests.
  void setTestDatabase(Database db) {
    _database = db;
  }

  /// Closes the open database connection.
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
