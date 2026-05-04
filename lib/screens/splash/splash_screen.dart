import 'dart:async';

import 'package:flutter/material.dart';

import '../../navigation/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _duration = Duration(seconds: 4);

  @override
  void initState() {
    super.initState();

    Timer(_duration, () {
      if (!mounted) return;

      Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF080808),
      body: SizedBox.expand(
        child: Image(
          image: AssetImage('assets/images/vidra_splash.png'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}