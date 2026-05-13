import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/app_mode.dart';

class ModeSwitchHeader extends StatelessWidget {
  final AppMode currentMode;
  final ValueChanged<AppMode> onModeChanged;
  final bool pushNotificationsEnabled;
  final ValueChanged<bool>? onPushNotificationsChanged;

  /// Какие режимы показывать сверху.
  ///
  /// До привязки -> [receiver, sender]
  /// После привязки главного -> [receiver]
  /// После привязки рабочего -> [sender]
  final List<AppMode> visibleModes;

  /// Кнопка разъединения связки телефонов.
  final VoidCallback? onResetPairing;

  const ModeSwitchHeader({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
    this.pushNotificationsEnabled = true,
    this.onPushNotificationsChanged,
    this.visibleModes = AppMode.values,
    this.onResetPairing,
  });

  @override
  Widget build(BuildContext context) {
    final canShowReceiver = visibleModes.contains(AppMode.receiver);
    final canShowSender = visibleModes.contains(AppMode.sender);
    final isSingleMode = visibleModes.length == 1;

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
          if (!isSingleMode) ...[
            const SizedBox(height: 16),
            _ModeSegmentSwitch(
              currentMode: currentMode,
              canShowReceiver: canShowReceiver,
              canShowSender: canShowSender,
              onModeChanged: onModeChanged,
            ),
          ] else if (onResetPairing != null) ...[
            const SizedBox(height: 16),
            _DisconnectPairingButton(onResetPairing: onResetPairing),
          ],
        ],
      ),
    );
  }
}

class _DisconnectPairingButton extends StatelessWidget {
  final VoidCallback? onResetPairing;

  const _DisconnectPairingButton({
    required this.onResetPairing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onResetPairing,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 48,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.35),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.link_off_rounded,
                  color: AppColors.danger,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Разъединить телефоны',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primary,
                size: 24,
              ),
            ],
          ),
        ),
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
  final bool canShowReceiver;
  final bool canShowSender;
  final ValueChanged<AppMode> onModeChanged;

  const _ModeSegmentSwitch({
    required this.currentMode,
    required this.canShowReceiver,
    required this.canShowSender,
    required this.onModeChanged,
  });

  bool get isReceiver => currentMode == AppMode.receiver;

  @override
  Widget build(BuildContext context) {
    final visibleItems = [
      if (canShowReceiver) AppMode.receiver,
      if (canShowSender) AppMode.sender,
    ];

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
              widthFactor: 1 / visibleItems.length,
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
              if (canShowReceiver)
                _ModeSwitchItem(
                  title: 'Приём',
                  icon: Icons.call_received,
                  isActive: isReceiver,
                  onTap: () => onModeChanged(AppMode.receiver),
                ),
              if (canShowSender)
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