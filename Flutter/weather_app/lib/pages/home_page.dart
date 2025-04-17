import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/weather_service.dart';
import 'package:card_swiper/card_swiper.dart';
import '../db/favorites_db.dart' as db;
import '../db/weather_cache_db.dart' as cache_db;
import 'package:flutter_svg/flutter_svg.dart';
import '../main.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/temp_unit_provider.dart';

// DateTime utcTime = DateTime.now().toUtc(); // UTC time
// print('UTC time: $utcTime');

/// A StatefulWidget that represents the home page of the weather application.
///
/// This widget displays a swipeable list of weather cards for favorite cities.
/// It manages the loading, caching, and display of weather data for each location,
/// including current conditions and forecasts.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

/// The state class for HomePage that manages weather data and user interactions.
///
/// Key features:
/// * Manages favorite locations using a local database
/// * Implements card swiping for multiple locations
/// * Handles data prefetching for smooth transitions
/// * Provides weather data caching
class HomePageState extends State<HomePage> with RouteAware {
  // Current weather data for the selected location
  Map<String, dynamic>? currentWeather;
  // Controller for the city search input field
  final TextEditingController _cityController = TextEditingController();
  // Stores forecast data for the current location
  List<Map<String, dynamic>>? forecastData;
  final double latitude = 0;
  final double longitude = 0;
  String currentLocation = 'London';
  // Cache for prefetched weather data, keyed by location index
  final Map<int, Future<Map<String, dynamic>>> _prefetchedData = {};
  // Currently displayed card index in the swiper
  int _currentIndex = 0;
  // Add a key to force rebuild of Swiper
  Key _swiperKey = UniqueKey();
  // Add this cache map at the class level
  final Map<int, Widget> _cardCache = {};

  @override
  void initState() {
    super.initState();
    // No need to load favorites here as it's handled by the provider
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route observer
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
    // Clear cache when dependencies change
    _cardCache.clear();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _cityController.dispose();
    _cardCache.clear(); // Clear cache on dispose
    super.dispose();
  }

  @override
  void didPopNext() {
    super.didPopNext();
    // Refresh data when returning to this page
    setState(() {
      // Clear prefetched data to ensure fresh data is loaded
      _prefetchedData.clear();
      // Generate new key to force Swiper rebuild
      _swiperKey = UniqueKey();
      // Clear widget cache
      _cardCache.clear();
    });
  }

  /// Prefetches weather data for nearby cards to ensure smooth transitions.
  ///
  /// [index] The current card index being viewed.
  /// This method fetches data for previous and next cards if they exist.
  void _prefetchData(int index) {
    final favorites = Provider.of<FavoritesProvider>(context, listen: false).favorites;
    // Prefetch next and previous cards
    for (var i = index - 1; i <= index + 1; i++) {
      if (i >= 0 && i < favorites.length && !_prefetchedData.containsKey(i)) {
        _prefetchedData[i] = _getWeatherData(favorites[i]['id'], favorites[i]['name']);
      }
    }

    // Clean up old prefetched data
    _prefetchedData.removeWhere((key, value) =>
      (key < index - 1 || key > index + 1));
  }

  /// Retrieves weather data either from cache or from the weather service.
  ///
  /// [locationId] The unique identifier for the location
  /// [name] The name of the location
  /// Returns a Future with the weather data as a Map
  Future<Map<String, dynamic>> _getWeatherData(int locationId, String name) async {
    final cachedWeather = await cache_db.WeatherCacheDB.instance.getCachedWeather(locationId);
    if (cachedWeather != null) {
      return json.decode(cachedWeather['forecast_data']);
    }
    return WeatherService.fetchForecast(name);
  }

  @override
  Widget build(BuildContext context) {
    // Get favorites from provider
    final favoritesProvider = Provider.of<FavoritesProvider>(context);
    final favorites = favoritesProvider.favorites;

    return Scaffold(
      backgroundColor: Colors.blueAccent.shade700,
      body: favorites.isEmpty
          ? Center(child: Text('No favorite cities'))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Swiper(
                key: _swiperKey,
                itemCount: favorites.length,
                itemWidth: 375,
                indicatorLayout: PageIndicatorLayout.COLOR,
                pagination: const SwiperPagination(),
                control: kIsWeb ? const SwiperControl() : null,  // Show controls only in web mode
                onIndexChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                  _prefetchData(index);
                },
                itemBuilder: (context, index) {
                  // Use cached widget if available
                  if (_cardCache.containsKey(index)) {
                    return _cardCache[index]!;
                  }

                  // Build and cache new widget
                  final widget = FavoriteCityCard(
                    key: ValueKey('${favorites[index]['id']}_$_swiperKey'),
                    favorite: favorites[index]
                  );
                  _cardCache[index] = widget;
                  return widget;
                },
              ),
            ),
    );
  }
}

/// A widget that displays weather information for a favorite city.
///
/// This card shows:
/// * Current weather conditions with animated icons
/// * Temperature information
/// * 7-day forecast with daily highs and lows
/// * Weather condition icons for each forecast day
class FavoriteCityCard extends StatefulWidget {
  final Map<String, dynamic> favorite;
  const FavoriteCityCard({super.key, required this.favorite});

  @override
  State<FavoriteCityCard> createState() => _FavoriteCityCardState();
}

/// The state class for FavoriteCityCard that handles weather data display.
///
/// Features:
/// * Manages weather icon mappings
/// * Handles data loading and error states
/// * Provides animated and static weather icons
/// * Formats and displays forecast data
class _FavoriteCityCardState extends State<FavoriteCityCard> {

  /// Abbreviated day names for the week
  final List<String> dayOfWeek = const ['Mon', 'Tus', 'Wed', 'Thr', 'Fri', 'Sat', 'Sun'];

  late Future<Map<String, dynamic>> _forecastFuture;

  @override
  void initState() {
    super.initState();
    _forecastFuture = _getWeatherData();
  }

  @override
  void didUpdateWidget(FavoriteCityCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset forecast data if favorite changed
    if (oldWidget.favorite['id'] != widget.favorite['id']) {
      setState(() {
        _forecastFuture = _getWeatherData();
      });
    }
  }

  Future<Map<String, dynamic>> _getWeatherData() async {
    // Try to get cached data first
    final cachedWeather = await cache_db.WeatherCacheDB.instance.getCachedWeather(widget.favorite['id']);

    if (cachedWeather != null) {
      return json.decode(cachedWeather['forecast_data']);
    }

    // If no cache or expired, fetch new data
    return WeatherService.fetchForecast(widget.favorite['name']);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _forecastFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if(snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Error loading forecast'),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _forecastFuture = _getWeatherData();
                    });
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        final data = snapshot.data!;
        final current = data['current'];
        bool isDay = data['current']['is_day'] == 1;

        // Use the weathercode directly instead of converting to description
        final weatherCode = current['weather_code'] as int;
        final iconPath = WeatherService.weatherIconFile(weatherCode, isDay);

        final daily = data['daily'] as Map<String, dynamic>;
        final hourly = data['hourly']as Map<String, dynamic>;
        final List<dynamic> times = daily['time'];
        final List<dynamic> tempMax = daily['temperature_2m_max'];
        final List<dynamic> tempMin = daily['temperature_2m_min'];
        final List<dynamic> weatherCodes = daily['weather_code'];
        final List<dynamic> precip = daily['precipitation_probability_max'];
        DateTime utcTime = DateTime.now().toUtc(); // UTC time
        DateTime locationTime = utcTime.add(Duration(seconds: data['utc_offset_seconds']));

/*
hourly
{
'time' : [25],
'temperature_2m' : [25],
'weather_code' : [25],
'wind_speed_10m' : [25],
'precipitation' : [25],
}
*/
        return Card(
          // clipBehavior: Clip.antiAlias,
          color: Color.fromARGB(255, 8, 64, 128),
          // shadowColor: Colors.blueGrey,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.favorite['name']}',
                      style: const TextStyle(fontSize: 30, color: Colors.white),
                    ),
                    Text(
                      DateFormat('hh:mm a d-MMM-yyyy').format(locationTime),
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    Material(
                      elevation: 5,
                      color: Colors.blue.shade600,
                      borderRadius: BorderRadius.circular(10.0),
                      child: Row(
                        children: [
                          SvgPicture.asset(iconPath, height: 120, width: 120),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // const SizedBox(height: 8),
                              Consumer<TempUnitProvider>(
                                builder: (context, tempUnitProvider, child) {
                                  // Update the WeatherService's static tempUnit
                                  WeatherService.tempUnit = tempUnitProvider.unit;

                                  return Text(
                                    WeatherService.formatTemperature(current['temperature_2m']),
                                    style: const TextStyle(fontSize: 40, color: Colors.white),
                                  );
                                },
                              ),
                              Text(
                                getWeatherDescription(weatherCode),
                                style: const TextStyle(color: Colors.white),
                              ),
                              Text(
                                'Wind: ${current['wind_speed_10m']} km/h',
                                style: const TextStyle(color: Colors.white),
                              ),
                              Text(
                                'Humidity: ${current['relative_humidity_2m']} %',
                                style: const TextStyle(color: Colors.white),
                              ),
                              Text(
                                'Precipitation: ${current['precipitation']} mm',
                                style: const TextStyle(color: Colors.white),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Hourly forecast section with scrollbar for web mode
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
                          child: Text(
                            'Hourly Forecast',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        // Container for hourly forecast with bottom padding for scrollbar
                        Container(
                          height: kIsWeb ? 120 : 100, // Extra height for scrollbar in web mode
                          padding: EdgeInsets.only(bottom: kIsWeb ? 15 : 0), // Bottom padding for scrollbar
                          child: Builder(builder: (context) {
                            // Create a ScrollController that will be disposed with this widget
                            final ScrollController controller = ScrollController();

                            return RawScrollbar(
                              controller: controller,
                              thumbVisibility: kIsWeb, // Always show scrollbar in web mode
                              trackVisibility: kIsWeb, // Show track in web mode
                              thickness: 8, // Scrollbar thickness
                              thumbColor: Colors.white.withAlpha(153), // 0.6 opacity
                              trackColor: Colors.white.withAlpha(25), // 0.1 opacity
                              radius: const Radius.circular(4),
                              // Position the scrollbar at the bottom
                              scrollbarOrientation: ScrollbarOrientation.bottom,
                              child: SingleChildScrollView(
                                controller: controller,
                                scrollDirection: Axis.horizontal,                                
                                child: Row(
                                  children: List.generate(25, (index) {
                                    // Parse time string to DateTime
                                    final timeStr = hourly['time'][index];
                                    final time = DateTime.tryParse(timeStr) ?? DateTime.now();
                                    final temp = hourly['temperature_2m'][index];
                                    final weatherCode = hourly['weather_code'][index];
                                    final precipitation = hourly['precipitation'][index];
                                
                                    // Format time to display only hour
                                    final hour = DateFormat('HH:mm').format(time);
                                
                                    return Consumer<TempUnitProvider>(
                                      builder: (context, tempUnitProvider, _) {
                                        // Update the WeatherService's static tempUnit
                                        WeatherService.tempUnit = tempUnitProvider.unit;
                                
                                        return Container(
                                          width: 45, // Narrow width
                                          margin: EdgeInsets.symmetric(horizontal: 2), // Minimal margin
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade800,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.blue.shade700),
                                          ),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                            children: [
                                              Icon(
                                                WeatherService.getWeatherIconData(weatherCode),
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                              SizedBox(height: 3),
                                              Text(
                                                WeatherService.formatTemperature(temp),
                                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                              ),
                                              SizedBox(height: 1),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.water_drop, color: Colors.blue.shade300, size: 10),
                                                  SizedBox(width: 1),
                                                  Text(
                                                    '${precipitation.toStringAsFixed(1)}',
                                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 3),
                                              Text(
                                                hour,
                                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                              ),
                                              SizedBox(height: 3),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  }),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(  // Add this to allow the table to fill remaining space
                      child: SingleChildScrollView(
                        child: Table(
                          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                          children: List.generate(times.length > 7 ? 7 : times.length, (i) {
                            DateTime date = DateTime.tryParse(times[i]) ?? DateTime.now();
                            return TableRow(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 5.0),
                                  child: Material(
                                    elevation: 3,
                                    color: i == 1 ? Colors.blue.shade600 : Colors.blue.shade800,
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 3.0),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                        children: [
                                          SizedBox(
                                            width: 50,
                                            child: Text(
                                              i == 1 ? 'Today' : dayOfWeek[date.weekday - 1],
                                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                              textAlign: TextAlign.left,
                                            ),
                                          ),
                                          SvgPicture.asset(
                                            WeatherService.weatherIconFile(weatherCodes[i], isDay),
                                            width: 40,
                                            height: 40
                                          ),
                                          // Text(
                                          //   "${date.month}/${date.day}",
                                          //   style: const TextStyle(fontSize: 14, color: Colors.white),
                                          //   textAlign: TextAlign.center,
                                          // ),
                                          Consumer<TempUnitProvider>(
                                            builder: (context, tempUnitProvider, _) {
                                              // Update the WeatherService's static tempUnit
                                              WeatherService.tempUnit = tempUnitProvider.unit;

                                              final minTemp = tempMin[i];
                                              final maxTemp = tempMax[i];

                                              return Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    '${minTemp.round()}°',
                                                    style: const TextStyle(color: Colors.white),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '${maxTemp.round()}°',
                                                    style: const TextStyle(color: Colors.white),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
