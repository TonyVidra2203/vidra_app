import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'navigation/app_routes.dart';

import 'screens/dashboard/dashboard_screen.dart';
import 'screens/messages/messages_screen.dart';
import 'screens/settings/settings_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VidRA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,

      initialRoute: AppRoutes.dashboard,

      routes: {
        AppRoutes.dashboard: (context) => const DashboardScreen(),
        AppRoutes.messages: (context) => const MessagesScreen(),
        AppRoutes.settings: (context) => const SettingsScreen(),
      },
    );
  }
}