import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/app_mode.dart';

class ModeSwitchHeader extends StatelessWidget {
  final AppMode currentMode;
  final ValueChanged<AppMode> onModeChanged;
  final bool pushNotificationsEnabled;
  final ValueChanged<bool>? onPushNotificationsChanged;

  final List<AppMode> visibleModes;

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

  bool get _isSingleSenderMode {
    return visibleModes.length == 1 && visibleModes.contains(AppMode.sender);
  }

  bool get _isSingleReceiverMode {
    return visibleModes.length == 1 && visibleModes.contains(AppMode.receiver);
  }

  @override
  Widget build(BuildContext context) {
    final canShowReceiver = visibleModes.contains(AppMode.receiver);
    final canShowSender = visibleModes.contains(AppMode.sender);
    final isSingleMode = visibleModes.length == 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderCard(
            currentMode: currentMode,
            isSingleSenderMode: _isSingleSenderMode,
            isSingleReceiverMode: _isSingleReceiverMode,
          ),
          const SizedBox(height: 12),
          if (!isSingleMode)
            _ModeSegmentSwitch(
              currentMode: currentMode,
              canShowReceiver: canShowReceiver,
              canShowSender: canShowSender,
              onModeChanged: onModeChanged,
            ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final AppMode currentMode;
  final bool isSingleSenderMode;
  final bool isSingleReceiverMode;

  const _HeaderCard({
    required this.currentMode,
    required this.isSingleSenderMode,
    required this.isSingleReceiverMode,
  });

  @override
  Widget build(BuildContext context) {
    final isSender = currentMode == AppMode.sender;

    final title = isSingleSenderMode
        ? 'Рабочий телефон'
        : isSingleReceiverMode
        ? 'Главный телефон'
        : 'VidRA';

    final subtitle = isSingleSenderMode
        ? 'Передача SMS и PUSH'
        : isSingleReceiverMode
        ? 'Приём сообщений'
        : 'SMS & PUSH Forwarder';

    final icon = isSender
        ? Icons.send_to_mobile_rounded
        : Icons.phone_android_rounded;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          _MenuButton(
            icon: Icons.menu_rounded,
            onTap: () {},
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
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.35),
              ),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background.withOpacity(0.45),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 22,
          ),
        ),
      ),
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
        color: AppColors.card.withOpacity(0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
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
                  color: AppColors.primary.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.45),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              if (canShowReceiver)
                _ModeSwitchItem(
                  title: 'Приём',
                  icon: Icons.call_received_rounded,
                  isActive: isReceiver,
                  onTap: () => onModeChanged(AppMode.receiver),
                ),
              if (canShowSender)
                _ModeSwitchItem(
                  title: 'Передача',
                  icon: Icons.call_made_rounded,
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
    final color = isActive ? AppColors.primary : AppColors.textSecondary;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
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