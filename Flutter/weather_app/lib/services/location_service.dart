import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'web_location_interop.dart';
import '../utils/logger.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LocationService {
  static Future<Map<String, dynamic>> getCurrentLocation() async {
    try {
      // if (kIsWeb) {
      //   return WebLocationService.getCurrentLocation();
      // } else {
        return _getNativeLocation();
      // }
    } catch (e) {
      Logger.log('Error getting location: $e');
      return WebLocationService.getCurrentLocation();
    }
  }

  static Future<Map<String, dynamic>> _getNativeLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }

    final position = await Geolocator.getCurrentPosition();
    
    return {
      'latitude': position.latitude.toString(),
      'longitude': position.longitude.toString(),
      'timezone': position.timestamp.timeZoneName,
      'offset': position.timestamp.timeZoneOffset.inSeconds,
      'country': "unknown",
      'ipAddress': "0"
    };
  }

  static Future<bool> requestPermission() async {
    if (kIsWeb) {
      return true; // Web handles permissions through the browser
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    return permission == LocationPermission.whileInUse || 
           permission == LocationPermission.always;
  }

/*
// https://api.open-meteo.com/v1/forecast?latitude=31.3378465&longitude=-95.390805&timezone=auto
Response:
{
  "latitude": 31.345598,
  "longitude": -95.40536,
  "generationtime_ms": 0.000715255737304687,
  "utc_offset_seconds": -18000,
  "timezone": "America/Chicago",
  "timezone_abbreviation": "GMT-5",
  "elevation": 122
}
*/
  static Future<Map<String, dynamic>> getTimezoneFromCoordinates(double latitude, double longitude) async {
    try {
      // final url = 'http://api.timezonedb.com/v2.1/get-time-zone?key=YOUR_API_KEY&format=json&by=position&lat=$latitude&lng=$longitude';
      final url = 'https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&timezone=auto';
      // final url = 'https://www.timeapi.io/api/timezone/coordinate?latitude=$latitude&longitude=$longitude';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'timeZone': 'UTC',
          'currentUtcOffset': {'seconds': 0}
        };
      }
    } catch (e) {
      Logger.log('Error getting timezone: $e');
      return {
        'timeZone': 'UTC',
        'currentUtcOffset': {'seconds': 0}
      };
    }
  }
}
