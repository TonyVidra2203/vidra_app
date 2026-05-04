import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/app_mode.dart';

class ModeSwitchHeader extends StatelessWidget {
  final AppMode currentMode;
  final ValueChanged<AppMode> onModeChanged;
  final bool pushNotificationsEnabled;
  final ValueChanged<bool>? onPushNotificationsChanged;

  const ModeSwitchHeader({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
    this.pushNotificationsEnabled = true,
    this.onPushNotificationsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.menu,
                color: AppColors.primary,
                size: 32,
              ),
              const SizedBox(width: 18),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VidRA',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'SMS & Push Forwarder',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (onPushNotificationsChanged != null)
                _PushNotificationSwitch(
                  value: pushNotificationsEnabled,
                  onChanged: onPushNotificationsChanged!,
                ),
            ],
          ),
          const SizedBox(height: 16),
          _ModeSegmentSwitch(
            currentMode: currentMode,
            onModeChanged: onModeChanged,
          ),
        ],
      ),
    );
  }
}

class _PushNotificationSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PushNotificationSwitch({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          value ? Icons.notifications_active : Icons.notifications_off,
          color: value ? AppColors.primary : AppColors.textSecondary,
          size: 22,
        ),
        const SizedBox(width: 6),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
          activeTrackColor: AppColors.primary.withOpacity(0.35),
          inactiveThumbColor: AppColors.textSecondary,
          inactiveTrackColor: AppColors.cardBorder,
        ),
      ],
    );
  }
}

class _ModeSegmentSwitch extends StatelessWidget {
  final AppMode currentMode;
  final ValueChanged<AppMode> onModeChanged;

  const _ModeSegmentSwitch({
    required this.currentMode,
    required this.onModeChanged,
  });

  bool get isReceiver => currentMode == AppMode.receiver;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.35),
        ),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 230),
            curve: Curves.easeOutCubic,
            alignment: isReceiver ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                height: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Row(
            children: [
              _ModeSwitchItem(
                title: 'Приём',
                icon: Icons.call_received,
                isActive: isReceiver,
                onTap: () => onModeChanged(AppMode.receiver),
              ),
              _ModeSwitchItem(
                title: 'Передача',
                icon: Icons.call_made,
                isActive: !isReceiver,
                onTap: () => onModeChanged(AppMode.sender),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeSwitchItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _ModeSwitchItem({
    required this.title,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.background : AppColors.textSecondary;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}