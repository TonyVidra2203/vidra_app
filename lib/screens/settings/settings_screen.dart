import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../navigation/app_routes.dart';
import '../../widgets/common/app_bottom_nav_bar.dart';
import '../../services/app_mode_service.dart';
import '../../models/app_mode.dart';
import 'permissions_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = AppModeService.getMode();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(mode: mode),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 👇 ТОЛЬКО ДЛЯ РАБОЧЕГО ТЕЛЕФОНА
                  if (mode == AppMode.sender)
                    _SettingsItem(
                      icon: Icons.security,
                      title: 'Разрешения',
                      subtitle: 'SMS и уведомления',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PermissionsScreen(),
                          ),
                        );
                      },
                    ),

                  // 👇 ОБЩИЕ НАСТРОЙКИ (пока заглушка)
                  _SettingsItem(
                    icon: Icons.info_outline,
                    title: 'О приложении',
                    subtitle: 'Информация о VidRA',
                    onTap: () {},
                  ),

                  _SettingsItem(
                    icon: Icons.help_outline,
                    title: 'Помощь',
                    subtitle: 'FAQ и поддержка',
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(
        currentRoute: AppRoutes.settings,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final AppMode mode;

  const _Header({
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      child: Row(
        children: [
          const Icon(Icons.menu, color: AppColors.primary, size: 32),

          const SizedBox(width: 18),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Настройки',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  mode == AppMode.receiver
                      ? 'Главный телефон'
                      : 'Рабочий телефон',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsItem({
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
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
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