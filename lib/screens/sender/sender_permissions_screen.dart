import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/native_main_phone_service.dart';
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
  final NativeMainPhoneService nativeService = const NativeMainPhoneService();

  MainPhoneNativeStatus status = const MainPhoneNativeStatus();
  bool isLoading = true;

  bool get allReady =>
      status.smsPermission &&
          status.notificationListener &&
          status.batteryOptimizationDisabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadStatus();
    }
  }

  Future<void> _loadStatus() async {
    final loadedStatus = await nativeService.getStatus();

    if (!mounted) {
      return;
    }

    setState(() {
      status = loadedStatus;
      isLoading = false;
    });
  }

  Future<void> _requestSmsPermissions() async {
    await nativeService.requestSmsPermissions();
    await _loadStatus();
  }

  Future<void> _requestPostNotificationPermission() async {
    await nativeService.requestPostNotificationPermission();
    await _loadStatus();
  }

  Future<void> _openNotificationListenerSettings() async {
    await nativeService.openNotificationListenerSettings();
  }

  Future<void> _openBatteryOptimizationSettings() async {
    await nativeService.openBatteryOptimizationSettings();
  }

  Future<void> _openAppSettings() async {
    await nativeService.openAppSettings();
  }

  void _onNavTap(BuildContext context, int index) {
    if (index == 2) {
      return;
    }

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
                onRefresh: _loadStatus,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _SummaryCard(allReady: allReady),
                    const SizedBox(height: 16),
                    _PermissionCard(
                      icon: Icons.sms_outlined,
                      title: 'SMS',
                      description:
                      'Нужно для чтения входящих SMS на главном телефоне.',
                      isReady: status.smsPermission,
                      readyText: 'Разрешение SMS включено',
                      actionText: 'Разрешить SMS',
                      onPressed: _requestSmsPermissions,
                    ),
                    const SizedBox(height: 12),
                    _PermissionCard(
                      icon: Icons.notifications_none,
                      title: 'PUSH-уведомления',
                      description:
                      'Нужно для получения уведомлений от банков, Telegram и других приложений.',
                      isReady: status.notificationListener,
                      readyText: 'Доступ к уведомлениям включён',
                      actionText: 'Открыть доступ к уведомлениям',
                      onPressed: _openNotificationListenerSettings,
                    ),
                    const SizedBox(height: 12),
                    _PermissionCard(
                      icon: Icons.battery_saver_outlined,
                      title: 'Фоновая работа',
                      description:
                      'Нужно, чтобы Android не останавливал VidRA в фоне.',
                      isReady: status.batteryOptimizationDisabled,
                      readyText: 'Ограничение батареи отключено',
                      actionText: 'Отключить ограничение батареи',
                      onPressed: _openBatteryOptimizationSettings,
                    ),
                    const SizedBox(height: 12),
                    _PermissionCard(
                      icon: Icons.app_settings_alt_outlined,
                      title: 'Уведомления Android 13+',
                      description:
                      'Нужно для системного разрешения уведомлений на новых версиях Android.',
                      isReady: status.postNotificationPermission,
                      readyText: 'Системные уведомления разрешены',
                      actionText: 'Разрешить уведомления',
                      onPressed: _requestPostNotificationPermission,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 46,
                      child: OutlinedButton(
                        onPressed: _openAppSettings,
                        child: const Text('Открыть настройки приложения'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _loadStatus,
                        child: const Text('Проверить снова'),
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

class _SummaryCard extends StatelessWidget {
  final bool allReady;

  const _SummaryCard({
    required this.allReady,
  });

  @override
  Widget build(BuildContext context) {
    final color = allReady ? AppColors.success : AppColors.warning;

    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.16),
            child: Icon(
              allReady ? Icons.check_circle : Icons.warning_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allReady
                      ? 'Все разрешения включены'
                      : 'Нужно включить разрешения',
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'После включения разрешений VidRA сможет принимать SMS и PUSH в фоне.',
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

class _PermissionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isReady;
  final String readyText;
  final String actionText;
  final VoidCallback onPressed;

  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.isReady,
    required this.readyText,
    required this.actionText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = isReady ? AppColors.success : AppColors.danger;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.12),
                child: Icon(
                  icon,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Icon(
                isReady ? Icons.check_circle : Icons.error_outline,
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isReady ? readyText : 'Не включено',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!isReady) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: onPressed,
                child: Text(actionText),
              ),
            ),
          ],
        ],
      ),
    );
  }
}