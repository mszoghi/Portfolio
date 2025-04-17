import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/favorites_provider.dart';

class SplashScreen extends StatefulWidget {
  final Widget Function() onInitializationComplete;
  final Future<void> Function(BuildContext) initializeApp;

  const SplashScreen({
    super.key,
    required this.onInitializationComplete,
    required this.initializeApp,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Initialize app and load favorites in parallel
      await Future.wait([
        widget.initializeApp(context),
        Provider.of<FavoritesProvider>(context, listen: false).initialize(),
        Future.delayed(const Duration(seconds: 2)),
      ]);

      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
    } catch (e) {
      print('Error initializing app: $e');
      if (mounted) {
        setState(() {
          _initialized = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initialized) {
      return widget.onInitializationComplete();
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/splash_screen.gif',
              width: 300,
              height: 480,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            // const SizedBox(height: 24),
            // Text(
            //   'Weather App',
            //   style: Theme.of(context).textTheme.headlineMedium,
            // ),
          ],
        ),
      ),
    );
  }
}
