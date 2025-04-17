import 'package:flutter/foundation.dart';
import '../db/favorites_db.dart' as db;

/// A provider class that manages the global favorites state for the app.
/// 
/// This class:
/// * Provides access to favorites data across all pages
/// * Handles loading favorites from the database
/// * Notifies listeners when favorites change
/// * Provides methods to add, update, and delete favorites
class FavoritesProvider extends ChangeNotifier {
  /// Singleton instance of the FavoritesProvider
  static final FavoritesProvider _instance = FavoritesProvider._internal();
  
  /// Factory constructor to return the singleton instance
  factory FavoritesProvider() => _instance;
  
  /// Private constructor for singleton pattern
  FavoritesProvider._internal();

  /// List of user's favorite locations
  List<Map<String, dynamic>> _favorites = [];
  
  /// Getter for the favorites list
  List<Map<String, dynamic>> get favorites => _favorites;
  
  /// Flag to track if favorites have been initialized
  bool _initialized = false;
  
  /// Getter to check if favorites have been initialized
  bool get isInitialized => _initialized;

  /// Initializes the favorites list by loading from the database
  Future<void> initialize() async {
    if (!_initialized) {
      await loadFavorites();
      _initialized = true;
    }
  }

  /// Loads favorite locations from the database
  Future<void> loadFavorites() async {
    final favs = await db.FavoritesDB.instance.getFavorites();
    _favorites = favs;
    notifyListeners();
  }

  /// Adds a new favorite to the database and updates the list
  Future<void> addFavorite(Map<String, dynamic> favorite) async {
    await db.FavoritesDB.instance.insertFavorite(favorite);
    await loadFavorites();
  }

  /// Deletes a favorite from the database and updates the list
  Future<void> deleteFavorite(int id) async {
    await db.FavoritesDB.instance.deleteFavorite(id);
    await loadFavorites();
  }
}
