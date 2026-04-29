import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../navigation/app_routes.dart';
import '../../widgets/common/app_bottom_nav_bar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Text(
          'Настройки',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentRoute: AppRoutes.settings,
      ),
    );
  }
}