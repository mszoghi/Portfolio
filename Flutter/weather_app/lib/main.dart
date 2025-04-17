import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pages/settings_page.dart';
import 'pages/home_page.dart';
import 'pages/splash_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'services/weather_service.dart';
import 'dart:convert';
import 'providers/favorites_provider.dart';
import 'providers/temp_unit_provider.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

/*
Entry point of the application.

Initializes SQLite FFI for non-web platforms before launching the app.
FFI (Foreign Function Interface) is required for desktop platforms
to interact with the SQLite database.
The code initializes the SQLite database for non-web platforms
using FFI and launches the main application.
The  kIsWeb constant is used to check if the app is running on web,
where FFI initialization is not needed.
*/
void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure plugins are registered
  if (!kIsWeb) {
    // Initialize FFI
    sqfliteFfiInit();
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => FavoritesProvider()),
        ChangeNotifierProvider(create: (context) => TempUnitProvider()),
      ],
      child: MyApp(),
    ),
  );
}

/*
The root widget of the application.

This widget configures the overall app settings including:
  - Disabling the debug banner
  - Setting the app title
  - Setting up the main screen
  - Defining route mappings for navigation
  - Setting up route observers
*/
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  Map<String, dynamic>? _assetManifest;

  /// Initializes the app by loading the asset manifest.
  Future<void> _initialize(BuildContext context) async {
    try {
      final manifestContent = await DefaultAssetBundle.of(context)
          .loadString('AssetManifest.json');

      _assetManifest = json.decode(manifestContent) as Map<String, dynamic>;
      WeatherService.setAssetManifest(
        Map<String, List<String>>.from(
          _assetManifest!.map((key, value) =>
            MapEntry(key, (value as List).cast<String>())
          )
        )
      );
    } catch (e) {
      rethrow;
    }
  }



  Widget _buildMainApp() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 375, maxWidth: 600),
        child: Scaffold(
          appBar: AppBar(
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                _navigatorKey.currentState?.pushNamed('/settings');
              },
            ),
            title: const Text('Weather App'),
          ),
          body: const HomePage(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
      routes: {
        '/': (context) => SplashScreen(
              onInitializationComplete: _buildMainApp,
              initializeApp: _initialize,
            ),
        '/settings': (context) => Theme(
          data: ThemeData.light(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 375, maxWidth: 600),
              child: const SettingsPage(),
            ),
          ),
        ),
      },
      initialRoute: '/',
    );
  }
}


