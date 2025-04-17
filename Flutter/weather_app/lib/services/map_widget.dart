// filepath: /Users/saeed/Projects/Portfolio/weather_app/lib/widgets/nominatim_map.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
// import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

class NominatimMap extends StatelessWidget {
  final double latitude;
  final double longitude;

  const NominatimMap({
    Key? key,
    required this.latitude,
    required this.longitude,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: LatLng(latitude, longitude),
        initialZoom: 13.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          // userAgentPackageName: 'com.example.app', // Change this as needed
        ),
        MarkerLayer(
          markers: [
            Marker(
              width: 80.0,
              height: 80.0,
              point: LatLng(latitude, longitude),
              child: const Icon(
                Icons.location_on,
                color: Colors.red,
                size: 50,
              ), 
            ),
          ],
        ),
      ],
    );
  }
}