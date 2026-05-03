import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/sender_settings_service.dart';
import '../../widgets/common/app_card.dart';
import '../pairing/device_pairing_screen.dart';
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

  final TextEditingController deviceNameController = TextEditingController();
  final TextEditingController relayUrlController = TextEditingController();
  final TextEditingController relayApiKeyController = TextEditingController();

  SenderSettingsState settings = const SenderSettingsState(
    smsForwarding: true,
    pushForwarding: true,
    backgroundMode: true,
    onlyWithInternet: false,
  );

  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    deviceNameController.dispose();
    relayUrlController.dispose();
    relayApiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final loadedSettings = await settingsService.load();

      if (!mounted) return;

      setState(() {
        settings = loadedSettings;
        deviceNameController.text = loadedSettings.deviceName;
        relayUrlController.text = loadedSettings.relayUrl;
        relayApiKeyController.text = loadedSettings.relayApiKey;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> _updateSettings(SenderSettingsState newSettings) async {
    setState(() {
      settings = newSettings;
      isSaving = true;
    });

    await settingsService.save(newSettings);

    if (!mounted) return;
    setState(() => isSaving = false);
  }

  Future<void> _saveDeviceSettings() async {
    final deviceName = deviceNameController.text.trim();
    final relayUrl = relayUrlController.text.trim();
    final relayApiKey = relayApiKeyController.text.trim();

    await _updateSettings(
      settings.copyWith(
        deviceName: deviceName.isEmpty ? 'Рабочий телефон' : deviceName,
        relayUrl: relayUrl,
        relayApiKey: relayApiKey,
      ),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Настройки сохранены')),
    );
  }

  void _openPairingScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const DevicePairingScreen(),
      ),
    );
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
                  _PairingCard(onTap: _openPairingScreen),
                  const SizedBox(height: 14),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Рабочее устройство',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Название будет отображаться в личном кабинете и на главном телефоне.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: deviceNameController,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Рабочий телефон',
                            labelText: 'Название устройства',
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: relayUrlController,
                          keyboardType: TextInputType.url,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                          ),
                          decoration: const InputDecoration(
                            hintText:
                            'http://45.80.68.83:8000/events',
                            labelText: 'URL сервера',
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: relayApiKeyController,
                          obscureText: true,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Ключ будет выдан сервером',
                            labelText: 'API-ключ',
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : _saveDeviceSettings,
                            child: Text(
                              isSaving ? 'Сохраняю...' : 'Сохранить',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SwitchCard(
                    title: 'Пересылка SMS',
                    subtitle: 'Передавать входящие SMS в аккаунт VidRA',
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
                    subtitle:
                    'Передавать уведомления приложений в аккаунт VidRA',
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
                    subtitle:
                    'Продолжать работу после закрытия приложения',
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

class _PairingCard extends StatelessWidget {
  final VoidCallback onTap;

  const _PairingCard({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(
          backgroundColor: Color(0x1A8B5CF6),
          child: Icon(
            Icons.link,
            color: AppColors.primary,
          ),
        ),
        title: const Text(
          'Связка телефонов',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: const Text(
          'Введите код с главного телефона или проверьте привязку',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppColors.primary,
        ),
        onTap: onTap,
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
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withOpacity(0.4),
          ),
        ],
      ),
    );
  }
}