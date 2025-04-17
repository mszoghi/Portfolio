import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'dart:convert';
import 'dart:io' show Platform;

// Create separate files for web and non-web implementations
import 'storage_web.dart' if (dart.library.io) 'storage_io.dart' as storage;

/// Handles web storage operations for favorites data.
/// 
/// This class provides a platform-independent way to store and retrieve
/// data using localStorage on web platforms.
class WebStorage {
  static String? getItem(String key) {
    if (kIsWeb) {
      return storage.getLocalStorageItem(key);
    }
    return null;
  }

  static void setItem(String key, String value) {
    if (kIsWeb) {
      storage.setLocalStorageItem(key, value);
    }
  }
}

/// Database manager for favorite locations in the weather application.
/// 
/// This class provides:
/// * CRUD operations for favorite locations
/// * Cross-platform database support (Web, Desktop, Mobile)
/// * Data persistence using SQLite and IndexedDB
/// * Web storage fallback mechanisms
class FavoritesDB {
  /// The singleton instance of the FavoritesDB
  static final FavoritesDB instance = FavoritesDB._init();
  static Database? _database;
  static const String _webStorageKey = 'weather_app.favorites_data';
  static bool _initialized = false;
  late final DatabaseFactory _factory;

  FavoritesDB._init() {
    _factory = kIsWeb ? databaseFactoryFfiWeb : databaseFactoryFfi;
    if (kIsWeb) {
      _factory.setDatabasesPath('indexeddb');
    }
  }

  /// Initializes and returns the database instance.
  /// 
  /// Creates the database if it doesn't exist and handles web storage restoration.
  Future<Database> get database async {
    if (_database != null) return _database!;
    
    _database = await _initDB('favorites.db');
    
    if (kIsWeb && !_initialized) {
      await _restoreWebData();
      _initialized = true;
    }
    
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (kIsWeb) {
      return await _factory.openDatabase(
        filePath,
        options: OpenDatabaseOptions(
          version: 3,  // Increment version to 3
          onCreate: _createDB,
          onUpgrade: _onUpgrade,
          singleInstance: true,
        ),
      );
    } else if (!kIsWeb && !Platform.isAndroid && !Platform.isIOS) {
      // For desktop platforms
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, filePath);
      return await _factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 3,  // Increment version to 3
          onCreate: _createDB,
          onUpgrade: _onUpgrade,
          singleInstance: true,
        ),
      );
    } else {
      // For Android and iOS
      final dbPath = await sqflite.getDatabasesPath();
      final path = join(dbPath, filePath);
      return await sqflite.openDatabase(
        path,
        version: 3,  // Increment version to 3
        onCreate: _createDB,
        onUpgrade: _onUpgrade,
      );
    }
  }

  /// Saves the current database state to web storage.
  /// 
  /// This method is only active on web platforms and ensures data persistence
  /// across browser sessions.
  Future<void> _saveWebData() async {
    if (!kIsWeb) return;
    
    final db = await database;
    final data = await db.query('favorites');
    
    if (data.isNotEmpty) {
      final jsonData = json.encode(data);
      await saveToWebStorage(jsonData);
    }
  }

  Future<void> _restoreWebData() async {
    if (!kIsWeb) return;
    
    final savedData = getFromWebStorage();
    
    if (savedData != null && savedData.isNotEmpty) {
      final List<dynamic> data = json.decode(savedData);
      final db = await database;
      
      await db.delete('favorites');
      
      for (var item in data) {
        await db.insert(
          'favorites', 
          Map<String, dynamic>.from(item),
          conflictAlgorithm: ConflictAlgorithm.replace
        );
      }
    }
  }

  Future<void> saveToWebStorage(String data) async {
    if (kIsWeb) {
      WebStorage.setItem(_webStorageKey, data);
    }
  }

  String? getFromWebStorage() {
    if (kIsWeb) {
      return WebStorage.getItem(_webStorageKey);
    }
    return null;
  }

  /// Retrieves a favorite location by its name.
  /// 
  /// [name] The name of the location to retrieve
  /// Returns null if the location is not found
  Future<Map<String, dynamic>?> getFavoriteByName(String name) async {
    final db = await database;
    final result = await db.query(
      'favorites',
      where: 'name = ?',
      whereArgs: [name],
    );
    return result.isNotEmpty ? result.first : null;
  }

  /// Adds a new favorite location to the database.
  /// 
  /// [favorite] Map containing the location data
  /// Returns the ID of the inserted record
  Future<int> insertFavorite(Map<String, dynamic> favorite) async {
    final db = await instance.database;
    try {
      // Validate required fields
      final requiredFields = ['name', 'notes', 'latitude', 'longitude', 'timezone', 'offset'];
      for (var field in requiredFields) {
        if (!favorite.containsKey(field) || favorite[field] == null) {
          throw Exception('Missing required field: $field');
        }
      }

      try {
        final result = await db.insert(
          'favorites', 
          favorite,
          conflictAlgorithm: ConflictAlgorithm.replace
        );
        return result;
      } on DatabaseException catch (e) {
        if (e.isUniqueConstraintError()) {
          throw Exception('A favorite with this name already exists');
        } else if (e.isNoSuchTableError()) {
          throw Exception('Database schema error: favorites table not found');
        } else {
          // Try to handle database schema issues by upgrading
          if (e.toString().contains('no column named timezone')) {
            try {
              // Force a database upgrade
              final currentDb = await database;
              await _onUpgrade(currentDb, 2, 3); // Upgrade from version 1 to 3
              
              // Retry the insert after upgrade
              final result = await db.insert(
                'favorites', 
                favorite,
                conflictAlgorithm: ConflictAlgorithm.replace
              );
              return result;
            } catch (upgradeError) {
              throw Exception('Failed to upgrade database schema: ${upgradeError.toString()}');
            }
          }
          throw Exception('Database error while inserting favorite: ${e.toString()}');
        }
      } catch (e) {
        throw Exception('Unexpected error while inserting favorite: ${e.toString()}');
      }
    } catch (e) {
      throw Exception('Failed to insert favorite: ${e.toString()}. Make sure all required fields (name, notes, latitude, longitude, timezone, offset) are provided.');
    }
  }

  Future<List<Map<String, dynamic>>> getFavorites() async {
    final db = await instance.database;
    final results = await db.query('favorites');
    if (kIsWeb && results.isEmpty) {
      await _restoreWebData();
      return await db.query('favorites');
    }
    return results;
  }

  Future<void> deleteFavorite(int id) async {
    final db = await instance.database;
    await db.delete(
      'favorites',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (kIsWeb) {
      await _saveWebData();
    }
  }

  Future<void> deleteDatabase() async {
    if (kIsWeb) {
      var factory = databaseFactoryFfiWeb;
      await factory.deleteDatabase('favorites.db');
    } else {
      var factory = databaseFactoryFfi;
      final path = join(await getDatabasesPath(), 'favorites.db');
      await factory.deleteDatabase(path);
    }
    _database = null;
    _initialized = false;
  }

  /// Creates the initial database schema.
  /// 
  /// [db] The database instance
  /// [version] The database version number
  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        notes TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        timezone TEXT NOT NULL,
        offset REAL NOT NULL DEFAULT 0.0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    try {
      if (oldVersion < 2) {
        // Check if timezone column exists before adding it
        var tableInfo = await db.rawQuery('PRAGMA table_info(favorites)');
        bool hasTimezone = tableInfo.any((column) => column['name'] == 'timezone');
        
        if (!hasTimezone) {
          // Simple addition of a column can use ALTER TABLE
          await db.execute('ALTER TABLE favorites ADD COLUMN timezone TEXT NOT NULL DEFAULT "UTC"');
        }
      }

      if (oldVersion < 3) {
        // rename description to notes
        // use _complexMigration 
        await _complexMigration(db, (table) => '''
          CREATE TABLE $table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            notes TEXT,      
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            timezone TEXT NOT NULL DEFAULT "UTC",
            offset REAL NOT NULL DEFAULT 0.0
          )
        ''');
      }
    } catch (e) {
      if (e.toString().contains('no column named timezone')) {
        // Handle the specific timezone column error
        print('Warning: timezone column already exists or table structure is invalid');
        // Optionally, you could try to recover here or log the error
      } else {
        throw Exception('Database upgrade failed: ${e.toString()}');
      }
    }
  }

  Future<void> _complexMigration(Database db, String Function(String) createTableSql) async {
    final tempTableName = 'favorites_new';
    final targetTableName = 'favorites';

    await db.transaction((txn) async {
      // 1. Create new table with desired schema
      await txn.execute(createTableSql(tempTableName));

      // 2. Copy data with column mapping
      await txn.execute('''
        INSERT INTO $tempTableName (
          id, name, notes, latitude, longitude, timezone, offset
        )
        SELECT 
          id, name, description, latitude, longitude, 
          COALESCE(timezone, "UTC"), 
          0.0  -- Use literal value instead of COALESCE(offset, 0.0)
        FROM $targetTableName
      ''');

      // 3. Drop old table
      await txn.execute('DROP TABLE $targetTableName');

      // 4. Rename new table
      await txn.execute('ALTER TABLE $tempTableName RENAME TO $targetTableName');
    });
  }
}
