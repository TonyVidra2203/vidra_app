import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class SenderBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const SenderBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
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
          _SenderNavItem(
            index: 0,
            currentIndex: currentIndex,
            icon: Icons.phone_android_outlined,
            label: 'Статус',
            onTap: onTap,
          ),
          _SenderNavItem(
            index: 1,
            currentIndex: currentIndex,
            icon: Icons.settings_outlined,
            label: 'Настройки',
            onTap: onTap,
          ),
          _SenderNavItem(
            index: 2,
            currentIndex: currentIndex,
            icon: Icons.verified_user_outlined,
            label: 'Разрешения',
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

class _SenderNavItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final IconData icon;
  final String label;
  final ValueChanged<int> onTap;

  const _SenderNavItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == currentIndex;
    final color = isActive ? AppColors.primary : AppColors.textSecondary;

    return GestureDetector(
      onTap: () => onTap(index),
      child: SizedBox(
        width: 90,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}