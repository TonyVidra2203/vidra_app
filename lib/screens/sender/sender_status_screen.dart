import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/app_mode.dart';
import '../../services/app_mode_service.dart';
import '../../services/sender_settings_service.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/mode_switch_header.dart';
import '../dashboard/dashboard_screen.dart';
import 'sender_permissions_screen.dart';
import 'sender_settings_screen.dart';
import 'widgets/sender_bottom_nav_bar.dart';

class SenderStatusScreen extends StatefulWidget {
  const SenderStatusScreen({super.key});

  @override
  State<SenderStatusScreen> createState() => _SenderStatusScreenState();
}

class _SenderStatusScreenState extends State<SenderStatusScreen> {
  final SenderSettingsService _settingsService = const SenderSettingsService();

  SenderSettingsState? settings;
  bool pushNotificationsEnabled = true;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    AppModeService.setMode(AppMode.sender);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final loadedSettings = await _settingsService.load();

    if (!mounted) {
      return;
    }

    setState(() {
      settings = loadedSettings;
      pushNotificationsEnabled = loadedSettings.pushForwarding;
      isLoading = false;
    });
  }

  void _onModeChanged(AppMode mode) {
    if (mode == AppMode.sender) {
      return;
    }

    AppModeService.setMode(AppMode.receiver);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const DashboardScreen(),
      ),
    );
  }

  Future<void> _onPushNotificationsChanged(bool value) async {
    final currentSettings = settings;

    if (currentSettings == null) {
      return;
    }

    final updatedSettings = currentSettings.copyWith(pushForwarding: value);

    setState(() {
      settings = updatedSettings;
      pushNotificationsEnabled = value;
    });

    await _settingsService.save(updatedSettings);
  }

  void _onNavTap(int index) {
    if (index == 0) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) {
          if (index == 1) {
            return const SenderSettingsScreen();
          }

          return const SenderPermissionsScreen();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentSettings = settings;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ModeSwitchHeader(
              currentMode: AppMode.sender,
              onModeChanged: _onModeChanged,
              pushNotificationsEnabled: pushNotificationsEnabled,
              onPushNotificationsChanged: _onPushNotificationsChanged,
            ),
            Expanded(
              child: isLoading || currentSettings == null
                  ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              )
                  : RefreshIndicator(
                onRefresh: _loadSettings,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _StatusCard(settings: currentSettings),
                    const SizedBox(height: 14),
                    _InfoCard(settings: currentSettings),
                    const SizedBox(height: 14),
                    _MenuButton(
                      icon: Icons.settings_outlined,
                      title: 'Настройки передачи',
                      subtitle: 'SMS, PUSH, фон и интернет',
                      onTap: () => _onNavTap(1),
                    ),
                    const SizedBox(height: 12),
                    _MenuButton(
                      icon: Icons.verified_user_outlined,
                      title: 'Разрешения Android',
                      subtitle: 'SMS, уведомления и работа в фоне',
                      onTap: () => _onNavTap(2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SenderBottomNavBar(
        currentIndex: 0,
        onTap: _onNavTap,
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final SenderSettingsState settings;

  const _StatusCard({
    required this.settings,
  });

  bool get isReady {
    return settings.smsForwarding || settings.pushForwarding;
  }

  @override
  Widget build(BuildContext context) {
    final color = isReady ? AppColors.success : AppColors.warning;

    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.16),
            child: Icon(
              isReady ? Icons.send_to_mobile : Icons.pause_circle_outline,
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isReady ? 'Передача активна' : 'Передача выключена',
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Этот телефон отправляет SMS и PUSH на главный телефон.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
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

class _InfoCard extends StatelessWidget {
  final SenderSettingsState settings;

  const _InfoCard({
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          _StatusRow(
            title: 'SMS',
            value: settings.smsForwarding ? 'Включено' : 'Выключено',
            isActive: settings.smsForwarding,
          ),
          const SizedBox(height: 12),
          _StatusRow(
            title: 'PUSH',
            value: settings.pushForwarding ? 'Включено' : 'Выключено',
            isActive: settings.pushForwarding,
          ),
          const SizedBox(height: 12),
          _StatusRow(
            title: 'Фоновый режим',
            value: settings.backgroundMode ? 'Включён' : 'Выключен',
            isActive: settings.backgroundMode,
          ),
          const SizedBox(height: 12),
          _StatusRow(
            title: 'Интернет',
            value: settings.onlyWithInternet ? 'Только онлайн' : 'Без ограничения',
            isActive: !settings.onlyWithInternet,
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String title;
  final String value;
  final bool isActive;

  const _StatusRow({
    required this.title,
    required this.value,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.success : AppColors.textSecondary;

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Row(
          children: [
            Icon(
              icon,
              color: AppColors.primary,
              size: 30,
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
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
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
            const Icon(
              Icons.chevron_right,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}