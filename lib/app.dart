import 'package:flutter/material.dart';

import 'core/constants/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'navigation/app_routes.dart';
import 'screens/auth/mode_selection_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/filters/filters_screen.dart';
import 'screens/messages/messages_screen.dart';
import 'screens/pairing/device_pairing_screen.dart';
import 'screens/pairing/qr_pairing_scanner_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/splash/splash_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VidRA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: AppRoutes.splash,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      routes: {
        AppRoutes.splash: (context) => const SplashScreen(),
        AppRoutes.modeSelection: (context) => const ModeSelectionScreen(),
        AppRoutes.dashboard: (context) => const DashboardScreen(),
        AppRoutes.messages: (context) => const MessagesScreen(),
        AppRoutes.filters: (context) => const FiltersScreen(),
        AppRoutes.settings: (context) => const SettingsScreen(),
        AppRoutes.devicePairing: (context) => const DevicePairingScreen(),
        AppRoutes.qrPairingScanner: (context) => const QrPairingScannerScreen(),
      },
    );
  }
}