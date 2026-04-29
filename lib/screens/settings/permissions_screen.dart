import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class PermissionsScreen extends StatelessWidget {
  const PermissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        iconTheme: const IconThemeData(color: AppColors.primary),
        title: const Text(
          'Разрешения',
          style: TextStyle(color: AppColors.textPrimary),
        ),
      ),
      body: const Center(
        child: Text(
          'Здесь будут разрешения SMS и PUSH',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}