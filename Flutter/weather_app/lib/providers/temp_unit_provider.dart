import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TemperatureUnit {
  celsius,
  fahrenheit,
}

class TempUnitProvider extends ChangeNotifier {
  TemperatureUnit _unit = TemperatureUnit.celsius;
  
  TemperatureUnit get unit => _unit;
  
  // Constructor loads saved preference
  TempUnitProvider() {
    _loadPreference();
  }
  
  // Load saved preference from SharedPreferences
  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final isFahrenheit = prefs.getBool('isFahrenheit') ?? false;
    _unit = isFahrenheit ? TemperatureUnit.fahrenheit : TemperatureUnit.celsius;
    notifyListeners();
  }
  
  // Set temperature unit and save preference
  Future<void> setUnit(TemperatureUnit unit) async {
    if (_unit == unit) return;
    
    _unit = unit;
    
    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFahrenheit', unit == TemperatureUnit.fahrenheit);
    
    notifyListeners();
  }
  
  // Helper method to convert temperature based on current unit
  double convertTemperature(double celsius) {
    if (_unit == TemperatureUnit.celsius) {
      return celsius;
    } else {
      return (celsius * 9 / 5) + 32;
    }
  }
  
  // Format temperature with the appropriate unit symbol
  String formatTemperature(double celsius) {
    final temp = convertTemperature(celsius);
    final symbol = _unit == TemperatureUnit.celsius ? '°C' : '°F';
    return '${temp.round()}$symbol';
  }
}
