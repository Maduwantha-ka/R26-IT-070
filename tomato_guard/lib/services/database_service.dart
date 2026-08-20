import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/disease_result.dart';
import '../models/scan_record.dart';

class DatabaseService {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'tomato_guard_history.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE scans (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            disease_name TEXT NOT NULL,
            scientific_name TEXT NOT NULL,
            confidence REAL NOT NULL,
            is_enhanced INTEGER NOT NULL,
            severity_level TEXT NOT NULL,
            affected_percentage REAL NOT NULL,
            overview TEXT NOT NULL,
            image_path TEXT,
            timestamp TEXT NOT NULL
          )
        ''');
      },
    );
  }

  /// Insert a new disease classification result into history
  static Future<int> saveScan(DiseaseResult result) async {
    final db = await database;
    final record = ScanRecord.fromDiseaseResult(result);
    return await db.insert(
      'scans',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Fetch all scan records sorted newest first
  static Future<List<ScanRecord>> getAllScans() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'scans',
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => ScanRecord.fromMap(map)).toList();
  }

  /// Search scans by disease name or severity
  static Future<List<ScanRecord>> searchScans(String query) async {
    if (query.trim().isEmpty) return getAllScans();
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'scans',
      where: 'disease_name LIKE ? OR scientific_name LIKE ? OR severity_level LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => ScanRecord.fromMap(map)).toList();
  }

  /// Delete a scan record by ID
  static Future<int> deleteScan(int id) async {
    final db = await database;
    return await db.delete(
      'scans',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Clear entire scan history
  static Future<int> clearAllScans() async {
    final db = await database;
    return await db.delete('scans');
  }
}
