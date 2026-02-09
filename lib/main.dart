import 'package:flutter/material.dart';
import 'package:fuel_tracker/pages/home.dart';
import 'package:fuel_tracker/pages/login.dart';
import 'package:fuel_tracker/pages/settings.dart';
import 'package:fuel_tracker/pages/splash.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check if the app is restarting after being killed during camera use
  final prefs = await SharedPreferences.getInstance();
  final cameraWasOpen = prefs.getBool('_formState_cameraOpen') ?? false;
  final hasApiKey = prefs.getString('cachedApiKey') != null;
  final skipToHome = cameraWasOpen && hasApiKey;

  runApp(MyApp(skipToHome: skipToHome));
}

class MyApp extends StatelessWidget {
  final bool skipToHome;

  const MyApp({super.key, this.skipToHome = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ex-Maintenance',
      // When recovering from camera kill, use home: to go directly to HomePage
      // without creating SplashScreen (whose timer would redirect to login).
      home: skipToHome
          ? HomePage(openFuelForm: true)
          : const SplashScreen(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => HomePage(),
        '/settings': (context) => const SettingsPage(),
      },
    );
  }
}