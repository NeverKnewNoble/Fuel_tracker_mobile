import 'package:flutter/material.dart';
import 'package:fuel_tracker/pages/home.dart';
import 'package:fuel_tracker/pages/login.dart';
import 'package:fuel_tracker/pages/settings.dart';
import 'package:fuel_tracker/pages/splash.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ex-Maintenance',
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginPage(),
        '/home': (context) => HomePage(),
        '/settings': (context) => const SettingsPage(),
      },
    );
  }
}