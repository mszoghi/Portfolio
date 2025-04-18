import 'dart:async';
import 'package:flutter/material.dart';
import 'package:osm_nominatim/osm_nominatim.dart';
import '../services/location_service.dart';
import 'package:provider/provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/temp_unit_provider.dart';
import '../services/weather_service.dart';

class SettingsPage extends StatefulWidget {

  const SettingsPage({super.key});

  @override
  SettingsPageState createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  // Controllers for favorite city inputs
  final TextEditingController _nameController = TextEditingController();

  dynamic location = {};
  late DataTable _favoritesTable;

  // State variables for location search
  List<Place> _searchResults = [];
  bool _isSearching = false;
  int _selectedLocationIndex = 0;

  // Debounce timer for search
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadLocationData();

    // Add listener to text field to trigger search
    _nameController.addListener(_onSearchTextChanged);
  }

  Future<void> _loadLocationData() async {
    final dynamic local = await LocationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        location = local;
        _updateFavoritesTable();
      });
    }
  }

  void _updateFavoritesTable() {
    final favorites = Provider.of<FavoritesProvider>(context, listen: false).favorites;
    _favoritesTable = _createDataTable(favorites);
  }

  // The showLocationSelector method has been replaced with inline location selection UI

  /// Adds a favorite from a selected Place object
  Future<void> _addFavoriteFromPlace(BuildContext context, Place selectedLocation) async {
    try {
      // Store the context for later use
      final String cityName = selectedLocation.address?['city'] ??
                             selectedLocation.address?['town'] ??
                             selectedLocation.address?['village'] ??
                             selectedLocation.displayName.split(',')[0];

      final timezoneData = await LocationService.getTimezoneFromCoordinates(
        selectedLocation.lat,
        selectedLocation.lon
      );

      final Map<String, dynamic> favorite = {
        'name': cityName,
        'notes': '${selectedLocation.address?['country'] ?? ''} ${selectedLocation.address?['state'] ?? ''} ${selectedLocation.address?['city'] ?? ''}'.trim(),
        'latitude': selectedLocation.lat,
        'longitude': selectedLocation.lon,
        'timezone': timezoneData['timezone'],
        'offset': timezoneData['utc_offset_seconds'],
      };

      // Clear search results
      setState(() {
        _searchResults = [];
        _nameController.clear();
      });

      // Use the provider to add the favorite
      if (mounted) {
        final favoritesProvider = Provider.of<FavoritesProvider>(context, listen: false);
        await favoritesProvider.addFavorite(favorite);

        // Update the table with the new data
        setState(() {
          _updateFavoritesTable();
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added $cityName to favorites')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding favorite: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _addFavorite(BuildContext context, String city) async {
    try {
      setState(() {
        _isSearching = true;
      });

      List<Place> locations = await Nominatim.searchByName(
        query: city,
        limit: 5,
        addressDetails: true,
        extraTags: true,
        nameDetails: true,
      );

      setState(() {
        _isSearching = false;
      });

      if (locations.isNotEmpty) {
        if (locations.length == 1) {
          // If only one location found, add it directly
          await _addFavoriteFromPlace(context, locations[0]);
        } else {
          // If multiple locations found, show them in the UI
          setState(() {
            _searchResults = locations;
            _selectedLocationIndex = 0;
          });

          // Show a message to select a location
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please select a location from the list')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No locations found for "$city"')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isSearching = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching for location: ${e.toString()}')),
        );
      }
    }
  }

  DataTable _createDataTable(List<Map<String, dynamic>> favorites) {
    return DataTable(
      columnSpacing: 24,
      horizontalMargin: 0,  // Remove default margins
      columns: const [
        DataColumn(label: Text('City', style: TextStyle(color: Colors.yellow))),
        DataColumn(label: Text('Location', style: TextStyle(color: Colors.yellow))),
        DataColumn(label: Text('Action', style: TextStyle(color: Colors.yellow))),
      ],
      rows: favorites.map((favs) => DataRow(
        cells: [
          DataCell(Text(
            favs['name'],
            style: const TextStyle(color: Colors.white),
          )),
          DataCell(Text(
            favs['notes'],
            style: const TextStyle(color: Colors.white),
          )),
          DataCell(IconButton(
            icon: const Icon(Icons.delete, color: Colors.yellow),
            onPressed: () => _showDeleteConfirmation(context, favs),
          )),
        ],
      )).toList(),
    );
  }

  Future<void> _showDeleteConfirmation(BuildContext context, Map<String, dynamic> favorite) async {
    // Store the favorite ID for later use
    final int favoriteId = favorite['id'];
    final String favoriteName = favorite['name'];

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete $favoriteName?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    // Only proceed if the user confirmed and the widget is still mounted
    if (confirm == true && mounted) {
      try {
        // Get a fresh context reference
        final favoritesProvider = Provider.of<FavoritesProvider>(context, listen: false);
        // Delete the favorite
        await favoritesProvider.deleteFavorite(favoriteId);

        // Update the table with the new data
        if (mounted) {
          setState(() {
            _updateFavoritesTable();
          });

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted $favoriteName from favorites')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting favorite: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to the favorites provider to rebuild when favorites change
    final favoritesProvider = Provider.of<FavoritesProvider>(context);
    // Update the table when the widget rebuilds
    _favoritesTable = _createDataTable(favoritesProvider.favorites);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      backgroundColor: Colors.blueAccent.shade700,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          color: const Color.fromARGB(255, 8, 64, 128),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Theme selector
                  // Unit selection (Celsius/Fahrenheit)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Units',
                        style: TextStyle(color: Colors.white),
                      ),
                      Consumer<TempUnitProvider>(
                        builder: (context, tempUnitProvider, child) {
                          // Update the WeatherService's static tempUnit
                          WeatherService.tempUnit = tempUnitProvider.unit;

                          return DropdownButton<TemperatureUnit>(
                            value: tempUnitProvider.unit,
                            dropdownColor: Colors.blue,
                            style: const TextStyle(color: Colors.white),
                            items: [
                              DropdownMenuItem(
                                value: TemperatureUnit.celsius,
                                child: const Text(
                                  'Celsius',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                              DropdownMenuItem(
                                value: TemperatureUnit.fahrenheit,
                                child: const Text(
                                  'Fahrenheit',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                tempUnitProvider.setUnit(value);
                              }
                            },
                          );
                        },
                      )
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Favorite Cities Section
                  Text(
                    'Favorite Cities',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, color: Colors.white70),
                      labelText: 'City Name',
                      labelStyle: const TextStyle(color: Colors.white70),
                      border: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white70),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      suffixIcon: _isSearching
                        ? const CircularProgressIndicator(color: Colors.white)
                        : null,
                    ),
                  ),
                  // Location selector dropdown
                  if (_searchResults.isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade800,
                        border: Border.all(color: Colors.white70),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'Select a location:',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final place = _searchResults[index];
                              return RadioListTile<int>(
                                title: Text(
                                  place.displayName,
                                  style: const TextStyle(color: Colors.white),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                value: index,
                                groupValue: _selectedLocationIndex,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedLocationIndex = value!;
                                  });
                                },
                                activeColor: Colors.yellow,
                                fillColor: WidgetStateProperty.resolveWith<Color>(
                                  (Set<WidgetState> states) {
                                    if (states.contains(WidgetState.selected)) {
                                      return Colors.yellow;
                                    }
                                    return Colors.white;
                                  },
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blue,
                        ),
                        onPressed: () {
                          setState(() {
                            _nameController.clear();
                            _searchResults = [];
                          });
                        },
                        child: const Text('Clear'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blue,
                        ),
                        onPressed: _searchResults.isNotEmpty
                          ? () async {
                              try {
                                final selectedPlace = _searchResults[_selectedLocationIndex];
                                await _addFavoriteFromPlace(context, selectedPlace);
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error adding favorite: ${e.toString()}')),
                                  );
                                }
                              }
                            }
                          : _nameController.text.isNotEmpty
                            ? () async {
                                try {
                                  await _addFavorite(context, _nameController.text);
                                } catch (e) {
                                  // Handle errors
                                }
                              }
                            : null,
                        child: const Text('Add Favorite City'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Display favorite cities
                  SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: _favoritesTable,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Handles text changes in the search field with debouncing
  Future<void> _onSearchTextChanged() async {
    // Cancel any previous timer
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }

    // Start a new timer
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final query = _nameController.text.trim();

      if (query.length < 3) {
        // Clear results if query is too short
        if (_searchResults.isNotEmpty) {
          setState(() {
            _searchResults = [];
            _isSearching = false;
          });
        }
        return;
      }

      setState(() {
        _isSearching = true;
      });

      try {
        // Search for locations matching the query
        final locations = await Nominatim.searchByName(
          query: query,
          limit: 5,
          addressDetails: true,
          extraTags: true,
          nameDetails: true,
        );

        if (mounted) {
          setState(() {
            _searchResults = locations;
            _isSearching = false;
            _selectedLocationIndex = 0;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isSearching = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }
}
