import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../navigation/app_routes.dart';
import '../../services/dashboard_mock_data.dart';
import '../../widgets/common/app_bottom_nav_bar.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/dashboard/device_list.dart';
import '../../widgets/dashboard/event_list.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final devices = DashboardMockData.devices;
    final events = DashboardMockData.events;
    final onlineCount = devices.where((d) => d.isOnline).length;
    final offlineCount = devices.where((d) => !d.isOnline).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const _Header(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _CardTitle(
                            title: 'Устройства',
                            action: 'Все устройства',
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              _StatItem(
                                icon: Icons.phone_android,
                                label: 'Всего',
                                value: devices.length.toString(),
                                color: AppColors.primary,
                              ),
                              _StatItem(
                                icon: Icons.circle,
                                label: 'Онлайн',
                                value: onlineCount.toString(),
                                color: AppColors.success,
                              ),
                              _StatItem(
                                icon: Icons.circle,
                                label: 'Оффлайн',
                                value: offlineCount.toString(),
                                color: AppColors.danger,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DeviceList(devices: devices),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _CardTitle(
                            title: 'Последние события',
                            action: 'Все события',
                          ),
                          const SizedBox(height: 12),
                          EventList(events: events),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const AppBottomNavBar(
              currentRoute: AppRoutes.dashboard,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(18, 14, 18, 8),
      child: Row(
        children: [
          Icon(
            Icons.menu,
            color: AppColors.primary,
            size: 32,
          ),
          SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Дашборд',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Главный телефон (прием данных)',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.notifications_none,
            color: AppColors.primary,
            size: 32,
          ),
        ],
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  final String title;
  final String action;

  const _CardTitle({
    required this.title,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Text(
          action,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 14,
          ),
        ),
        const Icon(
          Icons.chevron_right,
          color: AppColors.primary,
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}