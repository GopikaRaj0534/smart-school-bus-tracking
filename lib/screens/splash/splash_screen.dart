import 'dart:async';
import 'package:flutter/material.dart';
import 'package:routesafe/screens/auth/login_screen.dart';
import 'package:routesafe/widgets/routesafe_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Timer(const Duration(seconds: 5), () {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1E40AF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_bus_filled_rounded,
              color: Color(0xFFF59E0B),
              size: 75,
            ),
            SizedBox(height: 20),
            RouteSafeLogo(
              fontSize: 38,
              isDarkBackground: true,
              showIcon: false,
            ),
            SizedBox(height: 12),
            Text(
              'SAFE.  SMART.  CONNECTED.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}