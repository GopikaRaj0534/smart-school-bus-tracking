import 'package:flutter/material.dart';
import 'package:routesafe/screens/splash/splash_screen.dart';
import 'package:routesafe/utils/app_theme.dart';

void main() {
  runApp(const RouteSafeApp());
}

class RouteSafeApp extends StatelessWidget {
  const RouteSafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "RouteSafe",
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}