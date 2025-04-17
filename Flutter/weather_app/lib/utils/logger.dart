import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

class Logger {
  static void log(String message, {String? name = 'WeatherApp'}) {
    if (kDebugMode) {
      if (kIsWeb) {
        // For web platform (PWA)
        final timestamp = DateTime.now().toIso8601String();
        print('[$name][$timestamp] $message'); // Enhanced logging for PWA
      } else {
        // For mobile/desktop platforms
        developer.log(
          message,
          name: name ?? 'WeatherApp',
          time: DateTime.now(),
        );
      }
    }
  }
}