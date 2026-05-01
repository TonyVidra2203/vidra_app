import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants/app_colors.dart';
import '../../services/sender_permission_service.dart';
import '../../widgets/common/app_card.dart';
import 'sender_settings_screen.dart';
import 'sender_status_screen.dart';
import 'widgets/sender_bottom_nav_bar.dart';

class SenderPermissionsScreen extends StatefulWidget {
  const SenderPermissionsScreen({super.key});

  @override
  State<SenderPermissionsScreen> createState() =>
      _SenderPermissionsScreenState();
}

class _SenderPermissionsScreenState extends State<SenderPermissionsScreen>
    with WidgetsBindingObserver {
  final SenderPermissionService permissionService =
  const SenderPermissionService();

  bool smsPermission = false;
  bool notificationPermission = false;
  bool backgroundPermission = false;

  bool isLoading = true;
  bool isActionRunning = false;
  String? loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadPermissions();
    }
  }

  Future<void> _loadPermissions() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });

    try {
      final sms = await permissionService.isSmsGranted();
      final notification =
      await permissionService.isNotificationListenerEnabled();
      final background =
      await permissionService.isBatteryOptimizationDisabled();

      if (!mounted) return;

      setState(() {
        smsPermission = sms;
        notificationPermission = notification;
        backgroundPermission = background;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        loadError = e.toString();
      });
    }
  }

  void _onNavTap(BuildContext context, int index) {
    if (index == 2) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) {
          if (index == 0) {
            return const SenderStatusScreen();
          }

          return const SenderSettingsScreen();
        },
      ),
    );
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (isActionRunning) return;

    setState(() => isActionRunning = true);

    try {
      await action();
    } finally {
      if (!mounted) return;

      setState(() => isActionRunning = false);
      await _loadPermissions();
    }
  }

  Future<void> _openSmsPermission() async {
    await _runAction(() async {
      if (smsPermission) {
        await openAppSettings();
        return;
      }

      final granted = await permissionService.requestSms();

      if (!granted) {
        await openAppSettings();
      }
    });
  }

  Future<void> _openNotificationSettings() async {
    await _runAction(() async {
      await permissionService.openNotificationListenerSettings();

      if (!mounted) return;

      _showInfo(
        'Включи VidRA в списке доступа к уведомлениям, затем вернись назад.',
      );
    });
  }

  Future<void> _openBatterySettings() async {
    await _runAction(() async {
      await permissionService.openBatteryOptimizationSettings();

      if (!mounted) return;

      _showInfo(
        'Если системное окно не открылось, открой настройки приложения VidRA и отключи ограничение батареи вручную.',
      );
    });
  }

  void _showInfo(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
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
                  : RefreshIndicator(
                onRefresh: _loadPermissions,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (loadError != null) ...[
                      AppCard(
                        child: Text(
                          loadError!,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    _PermissionCard(
                      title: 'SMS',
                      subtitle: smsPermission
                          ? 'Доступ к входящим SMS выдан'
                          : 'Нужно разрешить доступ к SMS',
                      granted: smsPermission,
                      buttonText: smsPermission ? 'Настройки' : 'Выдать',
                      disabled: isActionRunning,
                      onTap: _openSmsPermission,
                    ),
                    const SizedBox(height: 14),
                    _PermissionCard(
                      title: 'Уведомления',
                      subtitle: notificationPermission
                          ? 'VidRA может читать PUSH-уведомления'
                          : 'Нужно включить доступ к уведомлениям',
                      granted: notificationPermission,
                      buttonText: notificationPermission
                          ? 'Настройки'
                          : 'Открыть',
                      disabled: isActionRunning,
                      onTap: _openNotificationSettings,
                    ),
                    const SizedBox(height: 14),
                    _PermissionCard(
                      title: 'Фоновая работа',
                      subtitle: backgroundPermission
                          ? 'Android не ограничивает работу VidRA'
                          : 'Нужно отключить оптимизацию батареи',
                      granted: backgroundPermission,
                      buttonText: backgroundPermission
                          ? 'Настройки'
                          : 'Открыть',
                      disabled: isActionRunning,
                      onTap: _openBatterySettings,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 46,
                      child: OutlinedButton(
                        onPressed:
                        isActionRunning ? null : _loadPermissions,
                        child: const Text('Обновить разрешения'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Важно: на эмуляторе Android фоновая работа может отображаться некорректно. На реальном телефоне нужно отключить оптимизацию батареи для VidRA.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SenderBottomNavBar(
        currentIndex: 2,
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
          'Разрешения',
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

class _PermissionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool granted;
  final String buttonText;
  final bool disabled;
  final VoidCallback onTap;

  const _PermissionCard({
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.buttonText,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = granted ? AppColors.success : AppColors.warning;

    return AppCard(
      child: Row(
        children: [
          Icon(
            granted ? Icons.check_circle : Icons.error_outline,
            color: color,
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
          const SizedBox(width: 10),
          TextButton(
            onPressed: disabled ? null : onTap,
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }
}