// Stub class to match the web implementation
class Window {
  Navigator get navigator => Navigator();
}

class Navigator {
  Geolocation get geolocation => Geolocation();
}

class Geolocation {
  Future<Position> getCurrentPosition({
    bool? enableHighAccuracy,
    Duration? timeout,
    Duration? maximumAge,
  }) async {
    throw UnsupportedError('Geolocation is only supported on web platforms.');
  }
}

class Position {
  Coordinates? get coords => null;
}

class Coordinates {
  double get latitude => 0;
  double get longitude => 0;
  double get accuracy => 0;
}

Window window = Window();
