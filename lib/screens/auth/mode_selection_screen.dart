import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/app_mode.dart';
import '../../services/app_mode_service.dart';
import '../dashboard/dashboard_screen.dart';
import '../sender/sender_status_screen.dart';

class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({super.key});

  void _selectMode(BuildContext context, AppMode mode) {
    AppModeService.setMode(mode);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) {
          if (mode == AppMode.sender) {
            return const SenderStatusScreen();
          }

          return const DashboardScreen();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              const Text(
                'Выберите режим',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Укажите, как будет работать это устройство',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 32),
              _ModeCard(
                icon: Icons.phone_android,
                title: AppMode.receiver.title,
                subtitle: AppMode.receiver.subtitle,
                onTap: () => _selectMode(context, AppMode.receiver),
              ),
              const SizedBox(height: 14),
              _ModeCard(
                icon: Icons.send_to_mobile,
                title: AppMode.sender.title,
                subtitle: AppMode.sender.subtitle,
                onTap: () => _selectMode(context, AppMode.sender),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 34),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}