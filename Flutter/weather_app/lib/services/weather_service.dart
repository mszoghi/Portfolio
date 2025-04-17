/// This module provides weather-related services for the Weather App.
///
/// It includes functions to interpret weather codes, fetch current weather and forecast
/// information from the Open-Meteo API, and present a location selector for the user.
///
/// WMO Weather interpretation codes are used to convert numeric weather codes to human-readable
/// descriptions. For details, see the comments below.
library weather_service;
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:osm_nominatim/osm_nominatim.dart';
import '../db/favorites_db.dart';
import '../db/weather_cache_db.dart';
import '../utils/logger.dart';
import 'location_service.dart';
import '../providers/temp_unit_provider.dart';
import 'package:flutter/material.dart';

// WMO Weather interpretation codes (WW)
// Code	Description
// 0	Clear sky
// 1, 2, 3	Mainly clear, partly cloudy, and overcast
// 45, 48	Fog and depositing rime fog
// 51, 53, 55	Drizzle: Light, moderate, and dense intensity
// 56, 57	Freezing Drizzle: Light and dense intensity
// 61, 63, 65	Rain: Slight, moderate and heavy intensity
// 66, 67	Freezing Rain: Light and heavy intensity
// 71, 73, 75	Snow fall: Slight, moderate, and heavy intensity
// 77	Snow grains
// 80, 81, 82	Rain showers: Slight, moderate, and violent
// 85, 86	Snow showers slight and heavy
// 95 *	Thunderstorm: Slight or moderate
// 96, 99 *	Thunderstorm with slight and heavy hail
// (*) Thunderstorm forecast with hail is only available in Central Europe

/// Returns a human-readable weather description based on a weather code.
///
/// [code] is the numeric weather code from the API.
///
/// Returns a string description corresponding to the weather code.
String getWeatherDescription(int code) {
  const Map<int, String> weatherDescriptions = {
    0: "Clear Sky",
    1: "Mainly Clear",
    2: "Partly Cloudy",
    3: "Overcast",
    45: "Fog",
    48: "Rime Fog",
    51: "Light Drizzle",
    53: "Moderate Drizzle",
    55: "Heavy Drizzle",
    56: "Light Freezing Drizzle",
    57: "Heavy Freezing Drizzle",
    61: "Slight Rain",
    63: "Moderate Rain",
    65: "Heavy Rain",
    66: "Light Freezing Rain",
    67: "Heavy Freezing Rain",
    71: "Slight Snow Fall",
    73: "Moderate Snow Fall",
    75: "Heavy Snow Fall",
    77: "Snow Grains",
    80: "Slight Rain Showers",
    81: "Moderate Rain Showers",
    82: "Violent Rain Showers",
    85: "Slight Snow Showers",
    86: "Heavy Snow Showers",
    95: "Thunderstorm",
    96: "Thunderstorm with Slight Hail",
    99: "Thunderstorm with Heavy Hail",
  };

  return weatherDescriptions[code] ?? "Unknown weather";
}

/// Maps weather codes to their corresponding icon names.
/// Used for both animated and static weather icons.
const Map<int, String> weatherIcons = {
  0:  'clear',   // Clear sky
  1:  'clear',   // Mainly clear
  2:  'cloudy',      // Partly cloudy
  3:  'overcast',    // Overcast
  45: 'fog',         // Fog
  48: 'fog',         // Rime fog
  51: 'drizzle',     // Light drizzle
  53: 'drizzle',     // Moderate drizzle
  55: 'extreme-drizzle',     // Heavy drizzle
  56: 'sleet',       // Light freezing drizzle
  57: 'extreme-sleet',       // Heavy freezing drizzle
  61: 'rain',        // Slight rain
  63: 'rain',        // Moderate rain
  65: 'extreme-rain',        // Heavy rain
  66: 'sleet',       // Light freezing rain
  67: 'extreme-sleet',       // Heavy freezing rain
  71: 'snow',        // Slight snow fall
  73: 'snow',        // Moderate snow fall
  75: 'extreme-snow',        // Heavy snow fall
  77: 'hail',        // Snow grains
  80: 'rain',        // Slight rain showers
  81: 'rain',        // Moderate rain showers
  82: 'rain',        // Violent rain showers
  85: 'snow',        // Slight snow showers
  86: 'extreme-snow',        // Heavy snow showers
  95: 'thunderstorms', // Thunderstorm
  96: 'thunderstorms-rain', // Thunderstorm with slight hail
  99: 'thunderstorms-extreme-rain', // Thunderstorm with heavy hail
};

/// Provides weather services by fetching and caching weather data from an API.
class WeatherService {
  /// Global temperature unit setting
  static TemperatureUnit tempUnit = TemperatureUnit.celsius;

  /// Base URL of the Open-Meteo API.
  static const String baseUrl = 'https://api.open-meteo.com/v1/forecast';
  static const String dailyOptions = '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,wind_speed_10m_max';
  static const String hourlyOptions = '&hourly=temperature_2m,weather_code,wind_speed_10m,precipitation';
  static const String currentOptions = '&current=is_day,relative_humidity_2m,precipitation,weather_code,temperature_2m,wind_speed_10m,showers,rain';

  /// Get the temperature unit string for API requests
  static String get temperatureUnitString => tempUnit == TemperatureUnit.celsius ? 'celsius' : 'fahrenheit';

  /// Get the general options string with the current temperature unit
  static String get generalOptions => '&models=best_match&timezone=auto&past_days=1&temperature_unit=${temperatureUnitString}&forecast_hours=24&past_hours=1';

  /// Converts temperature based on the current unit setting
  static double convertTemperature(double celsius) {
    if (tempUnit == TemperatureUnit.celsius) {
      return celsius;
    } else {
      return (celsius * 9 / 5) + 32;
    }
  }

  /// Formats temperature with the appropriate unit symbol
  static String formatTemperature(double temp) {
    final symbol = tempUnit == TemperatureUnit.celsius ? '°C' : '°F';
    return '${temp.round()}$symbol';
  }

  /// Map of weather codes to their corresponding Material icons for faster lookup
  static final Map<int, IconData> weatherIconsData = {
    0: Icons.wb_sunny, // Clear sky
    1: Icons.cloud_queue, // Mainly clear
    2: Icons.cloud_queue, // Partly cloudy
    3: Icons.cloud, // Overcast
    45: Icons.foggy, // Fog
    48: Icons.foggy, // Depositing rime fog
    51: Icons.grain, // Light drizzle
    53: Icons.grain, // Moderate drizzle
    55: Icons.grain, // Dense drizzle
    56: Icons.ac_unit, // Light freezing drizzle
    57: Icons.ac_unit, // Dense freezing drizzle
    61: Icons.water_drop, // Slight rain
    63: Icons.water_drop, // Moderate rain
    65: Icons.water_drop, // Heavy rain
    66: Icons.snowing, // Light freezing rain
    67: Icons.snowing, // Heavy freezing rain
    71: Icons.snowing, // Slight snow fall
    73: Icons.snowing, // Moderate snow fall
    75: Icons.snowing, // Heavy snow fall
    77: Icons.grain, // Snow grains
    80: Icons.shower, // Slight rain showers
    81: Icons.shower, // Moderate rain showers
    82: Icons.shower, // Violent rain showers
    85: Icons.cloudy_snowing, // Slight snow showers
    86: Icons.cloudy_snowing, // Heavy snow showers
    95: Icons.thunderstorm, // Thunderstorm
    96: Icons.thunderstorm, // Thunderstorm with slight hail
    99: Icons.thunderstorm, // Thunderstorm with heavy hail
  };

  /// Returns an appropriate Material icon for the given weather code
  static IconData getWeatherIconData(int code) {
    return weatherIconsData[code] ?? Icons.question_mark;
  }

  /// Cached asset manifest
  static Map<String, List<String>>? _assetManifest;

  /// Sets the asset manifest for the service
  static void setAssetManifest(Map<String, List<String>> manifest) {
    _assetManifest = manifest;
  }

  /// Returns the appropriate weather icon file path based on the weather code and time of day.
  ///
  /// [code] The weather code from the API
  /// [isDay] Whether it's currently daytime
  /// Returns the path to the icon file, or a default icon if the specific one isn't found
  static String weatherIconFile(int code, bool isDay) {
    if (_assetManifest == null) {
      throw StateError('WeatherService not initialized. Call initialize() first.');
    }

    final String iconName = weatherIcons[code] ?? 'not-available';
    final String baseIconPath = 'assets/icons/static.svg';
    final String timePrefix = isDay ? '-day' : '-night';

    // Try time-specific variant first
    final String timeSpecificPath = '$baseIconPath/$iconName$timePrefix.svg';
    if (_assetExists(timeSpecificPath)) {
      return timeSpecificPath;
    }

    // Fall back to base icon
    final String basePath = '$baseIconPath/$iconName.svg';
    if (_assetExists(basePath)) {
      return basePath;
    }

    // If neither exists, return not-available icon
    return '$baseIconPath/not-available.svg';
  }

  /// Checks if an asset exists in the manifest
  static bool _assetExists(String path) {
    return _assetManifest?.containsKey(path) ?? false;
  }

  /// Fetches current weather data for [city].
  ///
  /// First checks the cache using the favorite location record. If cached data exists,
  /// it returns the temperature and condition from the cache. Otherwise, data is fetched
  /// from the API. Upon a successful fetch, the new data is cached.
  ///
  /// Throws an [Exception] if the API call fails.
  static Future<Map<String, dynamic>> fetchCurrentWeather(String city) async {
    try {
      // Try to get cached data first
      final favorite = await FavoritesDB.instance.getFavoriteByName(city);
      if (favorite != null) {
        final cachedData = await WeatherCacheDB.instance.getCachedWeather(favorite['id']);
        if (cachedData != null) {
          Logger.log('Retrieved cached weather data for $city', name: 'WeatherService');
          return {
            'temperature': cachedData['temperature'],
            'condition': cachedData['condition'],
          };
        }
      }

      // If no cache or cache expired, fetch from API
      final url = '$baseUrl?latitude=51.5074&longitude=-0.1278&current_weather=true';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        // Logger.log('Fetched new weather data for $city', name: 'WeatherService');
        var data = json.decode(response.body);
        final weatherData = {
          'temperature': data['current_weather']['temperature'],
          'condition': getWeatherDescription(data['current']['weather_code']),
        };

        // Cache the new data
        if (favorite != null) {
          await WeatherCacheDB.instance.cacheWeatherData(
            locationId: favorite['id'],
            temperature: weatherData['temperature'],
            condition: weatherData['condition'],
            forecastData: json.encode(data),
            zoneOffset: data['utc_offset_seconds'],
            weathercode: data['current']['weather_code'],
          );
          Logger.log('Cached new weather data for $city', name: 'WeatherService');
        }

        return weatherData;
      } else {
        throw Exception('Failed to fetch weather data: ${response.statusCode}');
      }
    } catch (e) {
      Logger.log('Error in fetchCurrentWeather: $e', name: 'WeatherService');
      rethrow;
    }
  }

  /// Fetches forecast data for [city] and caches the result.
  ///
  /// Looks up the favorite location, constructs a request URL using the location’s
  /// latitude and longitude, and then fetches and caches the forecast data.
  ///
  ///
  /// Throws an [Exception] if the location is not found or the API call fails.
  static Future<Map<String, dynamic>> fetchForecast(String city) async {
    try {
      // Try to get favorite location first
      final favorite = await FavoritesDB.instance.getFavoriteByName(city);
      if (favorite!.isEmpty) {
        throw Exception('Location not found!!!');
      }

      final selectedLocation = Place(
        lat: favorite['latitude'],
        lon: favorite['longitude'],
        displayName: favorite['notes'] ?? favorite['description'],
        address: {},
        importance: 0,
        placeId: 0,
        osmType: '',
        osmId: 0,
        type: '',
        nameDetails: {},
        extraTags: {},
        boundingBox: [],
        placeRank: 0,
        category: '',
      );

      final latlon = '?latitude=${selectedLocation.lat}&longitude=${selectedLocation.lon}';
      final url = '$baseUrl$latlon$generalOptions$dailyOptions$currentOptions$hourlyOptions';
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Failed to connect to weather service');
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;

        // Cache the new data if we have a favorite
        await WeatherCacheDB.instance.cacheWeatherData(
          locationId: favorite['id'],
          temperature: data['current']['temperature_2m'],
          condition: getWeatherDescription(data['current']['weather_code']),
          weathercode: data['current']['weather_code'],
          zoneOffset: data['utc_offset_seconds'],
          forecastData: json.encode(data),
        );

        return data;
      } else {
        throw Exception('Weather service error: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      Logger.log('Network error: $e', name: 'WeatherService');
      throw Exception('Please check your internet connection');
    } catch (e) {
      Logger.log('Error in fetchForecast: $e', name: 'WeatherService');
      throw Exception('Failed to fetch weather data: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> getCurrentLocationWeather() async {
    final location = await LocationService.getCurrentLocation();
    final latlon = '$baseUrl?latitude=${location['latitude']}&longitude=${location['longitude']}';
    final url = '$baseUrl$latlon$generalOptions$dailyOptions$currentOptions$hourlyOptions';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to fetch weather data');
    }
  }

}


