import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/sender_settings_service.dart';
import '../../widgets/common/app_card.dart';
import 'sender_permissions_screen.dart';
import 'sender_status_screen.dart';
import 'widgets/sender_bottom_nav_bar.dart';

class SenderSettingsScreen extends StatefulWidget {
  const SenderSettingsScreen({super.key});

  @override
  State<SenderSettingsScreen> createState() => _SenderSettingsScreenState();
}

class _SenderSettingsScreenState extends State<SenderSettingsScreen> {
  final SenderSettingsService settingsService = const SenderSettingsService();

  SenderSettingsState settings = const SenderSettingsState(
    smsForwarding: true,
    pushForwarding: true,
    backgroundMode: true,
    onlyWithInternet: false,
  );

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final loadedSettings = await settingsService.load();

    if (!mounted) return;

    setState(() {
      settings = loadedSettings;
      isLoading = false;
    });
  }

  Future<void> _updateSettings(SenderSettingsState newSettings) async {
    setState(() => settings = newSettings);
    await settingsService.save(newSettings);
  }

  void _onNavTap(BuildContext context, int index) {
    if (index == 1) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) {
          if (index == 0) {
            return const SenderStatusScreen();
          }

          return const SenderPermissionsScreen();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const _Header(),
            Expanded(
              child: isLoading
                  ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              )
                  : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SwitchCard(
                    title: 'Пересылка SMS',
                    subtitle: 'Отправлять входящие SMS на главный телефон',
                    value: settings.smsForwarding,
                    onChanged: (value) {
                      _updateSettings(
                        settings.copyWith(smsForwarding: value),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _SwitchCard(
                    title: 'Пересылка PUSH',
                    subtitle: 'Отправлять уведомления приложений',
                    value: settings.pushForwarding,
                    onChanged: (value) {
                      _updateSettings(
                        settings.copyWith(pushForwarding: value),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _SwitchCard(
                    title: 'Фоновый режим',
                    subtitle: 'Продолжать работу после закрытия приложения',
                    value: settings.backgroundMode,
                    onChanged: (value) {
                      _updateSettings(
                        settings.copyWith(backgroundMode: value),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _SwitchCard(
                    title: 'Только через интернет',
                    subtitle: 'Не отправлять данные без подключения к сети',
                    value: settings.onlyWithInternet,
                    onChanged: (value) {
                      _updateSettings(
                        settings.copyWith(onlyWithInternet: value),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SenderBottomNavBar(
        currentIndex: 1,
        onTap: (index) => _onNavTap(context, index),
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
      child: Center(
        child: Text(
          'Настройки',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _SwitchCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}