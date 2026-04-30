import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../services/sender_permission_service.dart';
import '../../services/sender_settings_service.dart';
import '../../widgets/common/app_card.dart';
import 'sender_permissions_screen.dart';
import 'sender_settings_screen.dart';
import 'widgets/sender_bottom_nav_bar.dart';

class SenderStatusScreen extends StatefulWidget {
  const SenderStatusScreen({super.key});

  @override
  State<SenderStatusScreen> createState() => _SenderStatusScreenState();
}

class _SenderStatusScreenState extends State<SenderStatusScreen>
    with WidgetsBindingObserver {
  final SenderSettingsService settingsService = const SenderSettingsService();
  final SenderPermissionService permissionService =
  const SenderPermissionService();

  SenderSettingsState settings = const SenderSettingsState(
    smsForwarding: true,
    pushForwarding: true,
    backgroundMode: true,
    onlyWithInternet: false,
  );

  bool smsPermission = false;
  bool pushPermission = false;
  bool backgroundPermission = false;
  bool isLoading = true;

  bool get isSmsReady => !settings.smsForwarding || smsPermission;

  bool get isPushReady => !settings.pushForwarding || pushPermission;

  bool get isBackgroundReady =>
      !settings.backgroundMode || backgroundPermission;

  bool get hasActiveForwarding =>
      settings.smsForwarding || settings.pushForwarding;

  bool get isReady =>
      hasActiveForwarding && isSmsReady && isPushReady && isBackgroundReady;

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
    final loadedSettings = await settingsService.load();
    final smsGranted = await permissionService.isSmsGranted();
    final pushGranted =
    await permissionService.isNotificationListenerEnabled();
    final backgroundGranted =
    await permissionService.isBatteryOptimizationDisabled();

    if (!mounted) return;

    setState(() {
      settings = loadedSettings;
      smsPermission = smsGranted;
      pushPermission = pushGranted;
      backgroundPermission = backgroundGranted;
      isLoading = false;
    });
  }

  void _onNavTap(BuildContext context, int index) {
    if (index == 0) return;

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

  String _mainStatusTitle() {
    if (!hasActiveForwarding) {
      return 'Передача отключена';
    }

    if (isReady) {
      return 'Готово к работе';
    }

    return 'Требуется настройка';
  }

  String _mainStatusSubtitle() {
    if (!hasActiveForwarding) {
      return 'В настройках отключены SMS и PUSH';
    }

    if (isReady) {
      return 'Телефон готов передавать SMS и PUSH-уведомления';
    }

    return 'Проверь разрешения или настройки передачи';
  }

  Color _mainStatusColor() {
    if (isReady) return AppColors.success;
    if (!hasActiveForwarding) return AppColors.warning;
    return AppColors.danger;
  }

  IconData _mainStatusIcon() {
    if (isReady) return Icons.check_circle;
    if (!hasActiveForwarding) return Icons.pause_circle;
    return Icons.error;
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
                    _MainStatusCard(
                      title: _mainStatusTitle(),
                      subtitle: _mainStatusSubtitle(),
                      color: _mainStatusColor(),
                      icon: _mainStatusIcon(),
                    ),
                    const SizedBox(height: 16),
                    _StatusGroupCard(
                      title: 'Передача данных',
                      children: [
                        _StatusRow(
                          title: 'SMS',
                          subtitle: settings.smsForwarding
                              ? 'Передача SMS включена'
                              : 'Передача SMS отключена',
                          isReady: settings.smsForwarding,
                        ),
                        _StatusRow(
                          title: 'PUSH',
                          subtitle: settings.pushForwarding
                              ? 'Передача PUSH включена'
                              : 'Передача PUSH отключена',
                          isReady: settings.pushForwarding,
                        ),
                        _StatusRow(
                          title: 'Только через интернет',
                          subtitle: settings.onlyWithInternet
                              ? 'Без интернета данные не отправляются'
                              : 'Ограничение отключено',
                          isReady: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _StatusGroupCard(
                      title: 'Разрешения',
                      children: [
                        _StatusRow(
                          title: 'SMS-разрешение',
                          subtitle: smsPermission
                              ? 'Доступ к SMS выдан'
                              : 'Нет доступа к SMS',
                          isReady: smsPermission,
                        ),
                        _StatusRow(
                          title: 'Доступ к PUSH',
                          subtitle: pushPermission
                              ? 'Доступ к уведомлениям выдан'
                              : 'Нет доступа к уведомлениям',
                          isReady: pushPermission,
                        ),
                        _StatusRow(
                          title: 'Фоновая работа',
                          subtitle: backgroundPermission
                              ? 'Оптимизация батареи отключена'
                              : 'Фоновая работа может ограничиваться',
                          isReady: backgroundPermission,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _StatusGroupCard(
                      title: 'Сервис',
                      children: [
                        _StatusRow(
                          title: 'Режим работы',
                          subtitle: settings.backgroundMode
                              ? 'Фоновый режим включен'
                              : 'Фоновый режим отключен',
                          isReady: settings.backgroundMode,
                        ),
                        _StatusRow(
                          title: 'Готовность',
                          subtitle: isReady
                              ? 'Можно принимать и передавать данные'
                              : 'Есть проблемы в настройках',
                          isReady: isReady,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 46,
                      child: OutlinedButton(
                        onPressed: _loadStatus,
                        child: const Text('Обновить статус'),
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
        currentIndex: 0,
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
          'Статус устройства',
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

class _MainStatusCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _MainStatusCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.16),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
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
        ],
      ),
    );
  }
}

class _StatusGroupCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _StatusGroupCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isReady;

  const _StatusRow({
    required this.title,
    required this.subtitle,
    required this.isReady,
  });

  @override
  Widget build(BuildContext context) {
    final color = isReady ? AppColors.success : AppColors.danger;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            isReady ? Icons.check_circle : Icons.error_outline,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
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
        ],
      ),
    );
  }
}