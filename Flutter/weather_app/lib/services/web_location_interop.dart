import 'dart:async';
import 'package:flutter/foundation.dart';
// import 'package:js/js.dart';
import 'web_stub.dart' if (dart.library.html) 'dart:html';

@pragma('dart2js:tryInline')
@pragma('dart2js:fastCall')
class WebLocationService {
  static Future<Map<String, dynamic>> getCurrentLocation() async {
    if (!kIsWeb) return _defaultLocation();

    try {
      final completer = Completer<Map<String, dynamic>>();
    
      // Call getCurrentPosition with named parameters
      final position = await window.navigator.geolocation.getCurrentPosition(
        enableHighAccuracy: true,
        timeout: const Duration(milliseconds: 5000),
        maximumAge: const Duration(milliseconds: 0)
      );

      completer.complete({
        'latitude': position.coords?.latitude.toString(),
        'longitude': position.coords?.longitude.toString(),
        // 'timezone': position.timestamp.timeZoneName,
        // 'offset': position.timestamp.timeZoneOffset,
        'country': "unknown",
        'ipAddress': "0"
      });

      return completer.future;
    } catch (e) {
      return _defaultLocation();
    }
  }

  static Map<String, dynamic> _defaultLocation() {
    return {
      'latitude': "0",
      'longitude': "0",
      'accuracy': "0",
      'locality': "unknown",
      'postalCode': "unknown",
      'administrativeArea': "unknown",
      'country': "unknown",
      'ipAddress': "0"
    };
  }
}
