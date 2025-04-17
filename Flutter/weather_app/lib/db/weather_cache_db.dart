import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

class WeatherCacheDB {
  static final WeatherCacheDB instance = WeatherCacheDB._init();
  static Database? _database;

  WeatherCacheDB._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('weather_cache.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (kIsWeb) {
      // Web-specific initialization
      var factory = databaseFactoryFfiWeb;
      return await factory.openDatabase(
        filePath,
        options: OpenDatabaseOptions(
          version: 2,  // Increment version number
          onCreate: _createDB,
          onUpgrade: _onUpgrade,
        ),
      );
    } else {
      // Desktop/Mobile initialization
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, filePath);
      return await openDatabase(
        path, 
        version: 2,  // Increment version number
        onCreate: _createDB,
        onUpgrade: _onUpgrade,
      );
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE weather_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        location_id INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        temperature REAL,
        condition TEXT,
        weathercode INTEGER,  
        forecast_data TEXT,
        FOREIGN KEY (location_id) REFERENCES favorites (id)
        ON DELETE CASCADE
      )
    ''');

    // Index for faster lookups
    await db.execute(
      'CREATE INDEX idx_location_timestamp ON weather_cache(location_id, timestamp)'
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add weathercode column if upgrading from version 1
      await db.execute('ALTER TABLE weather_cache ADD COLUMN weathercode INTEGER');
    }
  }

  Future<void> cacheWeatherData({
    required int locationId,
    required double temperature,
    required String condition,
    required String forecastData, 
    required int weathercode, 
    required int zoneOffset,
  }) async {
    final db = await database;
    
    // Delete old cache for this location
    await db.delete(
      'weather_cache',
      where: 'location_id = ?',
      whereArgs: [locationId],
    );

    // Insert new cache
    await db.insert('weather_cache', {
      'location_id': locationId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'temperature': temperature,
      'condition': condition,
      'forecast_data': forecastData,
      'weathercode': weathercode,
    });
  }

  Future<Map<String, dynamic>?> getCachedWeather(int locationId) async {
    final db = await database;
    final cacheTimeout = Duration(minutes: 30).inMilliseconds;
    final cutoffTime = DateTime.now().millisecondsSinceEpoch - cacheTimeout;

    final results = await db.query(
      'weather_cache',
      where: 'location_id = ? AND timestamp > ?',
      whereArgs: [locationId, cutoffTime],
      orderBy: 'timestamp DESC',
      limit: 1,
    );

    if (results.isEmpty) {
      return null;
    }
    return results.first;
  }
}
