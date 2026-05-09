import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../navigation/app_routes.dart';
import '../../widgets/common/app_bottom_nav_bar.dart';
import '../../widgets/common/app_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const _SettingsHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                children: const [
                  _SettingsIntroCard(),
                  SizedBox(height: 16),
                  _SettingsMenuItem(
                    icon: Icons.verified_user_outlined,
                    title: 'Разрешения',
                    subtitle: 'SMS, уведомления и доступы Android',
                  ),
                  _SettingsMenuItem(
                    icon: Icons.sms_outlined,
                    title: 'SMS',
                    subtitle: 'Приём входящих SMS',
                  ),
                  _SettingsMenuItem(
                    icon: Icons.notifications_none_outlined,
                    title: 'PUSH',
                    subtitle: 'Приём уведомлений приложений',
                  ),
                  _SettingsMenuItem(
                    icon: Icons.battery_saver_outlined,
                    title: 'Фоновая работа',
                    subtitle: 'Автозапуск и работа без остановки',
                  ),
                  _SettingsMenuItem(
                    icon: Icons.lock_outline,
                    title: 'Безопасность',
                    subtitle: 'Защита приложения',
                  ),
                  _SettingsMenuItem(
                    icon: Icons.storage_outlined,
                    title: 'Память',
                    subtitle: 'История, кеш и очистка',
                  ),
                  _SettingsMenuItem(
                    icon: Icons.health_and_safety_outlined,
                    title: 'Диагностика',
                    subtitle: 'Проверка работы приёма',
                  ),
                  _SettingsMenuItem(
                    icon: Icons.info_outline,
                    title: 'О приложении',
                    subtitle: 'Версия и информация',
                  ),
                ],
              ),
            ),
            const AppBottomNavBar(currentRoute: AppRoutes.settings),
          ],
        ),
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Row(
        children: [
          Icon(
            Icons.settings_outlined,
            color: AppColors.primary,
            size: 26,
          ),
          SizedBox(width: 10),
          Text(
            'Настройки',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsIntroCard extends StatelessWidget {
  const _SettingsIntroCard();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Text(
        'Основные настройки телефона, который принимает SMS и PUSH-уведомления.',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          height: 1.4,
        ),
      ),
    );
  }
}

class _SettingsMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SettingsMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Row(
          children: [
            Icon(
              icon,
              color: AppColors.primary,
              size: 24,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}