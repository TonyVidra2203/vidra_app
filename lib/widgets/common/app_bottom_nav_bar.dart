import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../navigation/app_routes.dart';

class AppBottomNavBar extends StatelessWidget {
  final String currentRoute;

  const AppBottomNavBar({
    super.key,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.cardBorder),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.home_outlined,
            label: 'Дашборд',
            route: AppRoutes.dashboard,
            currentRoute: currentRoute,
          ),
          _NavItem(
            icon: Icons.chat_bubble_outline,
            label: 'Сообщения',
            route: AppRoutes.messages,
            currentRoute: currentRoute,
          ),
          _NavItem(
            icon: Icons.sync_alt,
            label: 'Логи',
            route: AppRoutes.logs,
            currentRoute: currentRoute,
          ),
          _NavItem(
            icon: Icons.filter_alt_outlined,
            label: 'Фильтры',
            route: AppRoutes.filters,
            currentRoute: currentRoute,
          ),
          _NavItem(
            icon: Icons.settings_outlined,
            label: 'Настройки',
            route: AppRoutes.settings,
            currentRoute: currentRoute,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final String currentRoute;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = route == currentRoute;
    final color = isActive ? AppColors.primary : AppColors.textSecondary;

    return GestureDetector(
      onTap: () {
        if (!isActive) {
          Navigator.pushReplacementNamed(context, route);
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }
}