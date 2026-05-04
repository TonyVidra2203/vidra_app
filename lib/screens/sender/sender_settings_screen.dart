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
  final SenderSettingsService _settingsService = const SenderSettingsService();

  bool smsForwarding = true;
  bool pushForwarding = true;
  bool backgroundMode = true;
  bool onlyWithInternet = false;
  bool isLoading = true;

  SenderSettingsState? _settings;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsService.load();

    if (!mounted) return;

    setState(() {
      _settings = settings;
      smsForwarding = settings.smsForwarding;
      pushForwarding = settings.pushForwarding;
      backgroundMode = settings.backgroundMode;
      onlyWithInternet = settings.onlyWithInternet;
      isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final current = _settings;

    if (current == null) return;

    final updated = current.copyWith(
      smsForwarding: smsForwarding,
      pushForwarding: pushForwarding,
      backgroundMode: backgroundMode,
      onlyWithInternet: onlyWithInternet,
    );

    _settings = updated;
    await _settingsService.save(updated);
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

  Future<void> _onSwitchChanged({
    required String type,
    required bool value,
  }) async {
    setState(() {
      if (type == 'sms') {
        smsForwarding = value;
      } else if (type == 'push') {
        pushForwarding = value;
      } else if (type == 'background') {
        backgroundMode = value;
      } else if (type == 'internet') {
        onlyWithInternet = value;
      }
    });

    await _saveSettings();
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
                  const _InfoCard(),
                  const SizedBox(height: 14),
                  _SwitchCard(
                    title: 'Пересылка SMS',
                    subtitle: 'Отправлять входящие SMS на главный телефон',
                    value: smsForwarding,
                    onChanged: (value) {
                      _onSwitchChanged(type: 'sms', value: value);
                    },
                  ),
                  const SizedBox(height: 14),
                  _SwitchCard(
                    title: 'Пересылка PUSH',
                    subtitle: 'Отправлять уведомления приложений',
                    value: pushForwarding,
                    onChanged: (value) {
                      _onSwitchChanged(type: 'push', value: value);
                    },
                  ),
                  const SizedBox(height: 14),
                  _SwitchCard(
                    title: 'Фоновый режим',
                    subtitle: 'Продолжать работу после закрытия приложения',
                    value: backgroundMode,
                    onChanged: (value) {
                      _onSwitchChanged(type: 'background', value: value);
                    },
                  ),
                  const SizedBox(height: 14),
                  _SwitchCard(
                    title: 'Только через интернет',
                    subtitle: 'Не отправлять данные без подключения к сети',
                    value: onlyWithInternet,
                    onChanged: (value) {
                      _onSwitchChanged(type: 'internet', value: value);
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

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Text(
        'Настройки теперь сохраняются сразу. Если SMS не доходят, проверьте, что пересылка SMS включена и разрешение SMS выдано.',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          height: 1.4,
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