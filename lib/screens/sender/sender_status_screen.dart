import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/app_mode.dart';
import '../../services/app_mode_service.dart';
import '../../services/native_main_phone_service.dart';
import '../../services/sender_settings_service.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/mode_switch_header.dart';
import '../dashboard/dashboard_screen.dart';
import '../pairing/device_pairing_screen.dart';
import 'sender_permissions_screen.dart';
import 'sender_settings_screen.dart';
import 'widgets/sender_bottom_nav_bar.dart';

class SenderStatusScreen extends StatefulWidget {
  const SenderStatusScreen({super.key});

  @override
  State createState() => _SenderStatusScreenState();
}

class _SenderStatusScreenState extends State with WidgetsBindingObserver {
  final SenderSettingsService settingsService = const SenderSettingsService();
  final NativeMainPhoneService nativeService = const NativeMainPhoneService();

  SenderSettingsState settings = const SenderSettingsState(
    smsForwarding: true,
    pushForwarding: true,
    backgroundMode: true,
    onlyWithInternet: false,
  );

  MainPhoneNativeStatus nativeStatus = const MainPhoneNativeStatus();

  List messages = [];
  bool isLoading = true;

  bool get hasActiveForwarding {
    return settings.smsForwarding || settings.pushForwarding;
  }

  bool get isSmsReady {
    return !settings.smsForwarding || nativeStatus.smsPermission;
  }

  bool get isPushReady {
    return !settings.pushForwarding || nativeStatus.notificationListener;
  }

  bool get isBackgroundReady {
    return !settings.backgroundMode ||
        nativeStatus.batteryOptimizationDisabled;
  }

  bool get isRelayReady {
    return nativeStatus.relayConfigured;
  }

  bool get isReady {
    return hasActiveForwarding &&
        isSmsReady &&
        isPushReady &&
        isBackgroundReady &&
        isRelayReady;
  }

  @override
  void initState() {
    super.initState();

    AppModeService.setMode(AppMode.sender);
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

  Future _loadStatus() async {
    final loadedSettings = await settingsService.load();
    final loadedStatus = await nativeService.getStatus();
    final loadedMessages = await nativeService.getMessages();

    if (!mounted) {
      return;
    }

    setState(() {
      settings = loadedSettings;
      nativeStatus = loadedStatus;
      messages = loadedMessages;
      isLoading = false;
    });
  }

  Future _clearMessages() async {
    await nativeService.clearMessages();
    await _loadStatus();
  }

  Future _openPairingScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const DevicePairingScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadStatus();
  }

  void _onNavTap(BuildContext context, int index) {
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

  String _mainStatusTitle() {
    if (!hasActiveForwarding) {
      return 'Передача отключена';
    }

    if (!isRelayReady) {
      return 'Телефон не привязан';
    }

    if (isReady) {
      return 'Передача активна';
    }

    return 'Требуется настройка';
  }

  String _mainStatusSubtitle() {
    if (!hasActiveForwarding) {
      return 'В настройках отключены SMS и PUSH';
    }

    if (!isRelayReady) {
      return 'Подключи этот телефон через код связки';
    }

    if (isReady) {
      return 'Android принимает SMS/PUSH и отправляет их дальше';
    }

    return 'Проверь разрешения Android и фоновую работу';
  }

  Color _mainStatusColor() {
    if (isReady) {
      return AppColors.success;
    }

    if (!hasActiveForwarding || !isRelayReady) {
      return AppColors.warning;
    }

    return AppColors.danger;
  }

  IconData _mainStatusIcon() {
    if (isReady) {
      return Icons.check_circle;
    }

    if (!hasActiveForwarding || !isRelayReady) {
      return Icons.link_off;
    }

    return Icons.error;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ModeSwitchHeader(
              currentMode: AppMode.sender,
              onModeChanged: _onModeChanged,
            ),
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
                    _PairingCard(
                      isConnected: isRelayReady,
                      relayUrl: settings.relayUrl,
                      onTap: _openPairingScreen,
                    ),
                    const SizedBox(height: 16),
                    _StatusGroupCard(
                      title: 'Android-интеграция',
                      children: [
                        _StatusRow(
                          title: 'SMS-приёмник',
                          subtitle: nativeStatus.smsPermission
                              ? 'Android разрешил чтение входящих SMS'
                              : 'Нет разрешения на SMS',
                          isReady: nativeStatus.smsPermission,
                        ),
                        _StatusRow(
                          title: 'PUSH-приёмник',
                          subtitle: nativeStatus.notificationListener
                              ? 'Доступ к уведомлениям включён'
                              : 'Доступ к уведомлениям не включён',
                          isReady: nativeStatus.notificationListener,
                        ),
                        _StatusRow(
                          title: 'Фоновая работа',
                          subtitle:
                          nativeStatus.batteryOptimizationDisabled
                              ? 'Ограничение батареи отключено'
                              : 'Android может остановить приложение',
                          isReady:
                          nativeStatus.batteryOptimizationDisabled,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _StatusGroupCard(
                      title: 'Передача данных',
                      children: [
                        _StatusRow(
                          title: 'SMS',
                          subtitle: settings.smsForwarding
                              ? 'Реальная пересылка SMS включена'
                              : 'Пересылка SMS отключена',
                          isReady: settings.smsForwarding,
                        ),
                        _StatusRow(
                          title: 'PUSH',
                          subtitle: settings.pushForwarding
                              ? 'Реальная пересылка PUSH включена'
                              : 'Пересылка PUSH отключена',
                          isReady: settings.pushForwarding,
                        ),
                        _StatusRow(
                          title: 'Связка',
                          subtitle: nativeStatus.relayConfigured
                              ? 'Адрес приёма сохранён'
                              : 'Телефон ещё не подключён',
                          isReady: nativeStatus.relayConfigured,
                        ),
                        _StatusRow(
                          title: 'Только через интернет',
                          subtitle: settings.onlyWithInternet
                              ? 'Без интернета события не отправляются'
                              : 'События сохраняются локально',
                          isReady: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _CounterCard(
                      smsCount: nativeStatus.smsCount,
                      pushCount: nativeStatus.pushCount,
                      totalCount: nativeStatus.totalCount,
                    ),
                    const SizedBox(height: 16),
                    _MessagesCard(
                      messages: messages,
                      onClear: messages.isEmpty ? null : _clearMessages,
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

class _PairingCard extends StatelessWidget {
  final bool isConnected;
  final String relayUrl;
  final VoidCallback onTap;

  const _PairingCard({
    required this.isConnected,
    required this.relayUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.14),
                child: Icon(
                  isConnected ? Icons.link : Icons.phonelink_setup,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isConnected
                          ? 'Связка активна'
                          : 'Подключить передачу',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isConnected
                          ? 'SMS и PUSH будут уходить на выбранный адрес'
                          : 'Введи код связки и адрес сервера приёма',
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
          if (isConnected && relayUrl.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              relayUrl.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: onTap,
              icon: Icon(isConnected ? Icons.settings : Icons.link),
              label: Text(
                isConnected ? 'Управлять связкой' : 'Подключить телефон',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusGroupCard extends StatelessWidget {
  final String title;
  final List children;

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

class _CounterCard extends StatelessWidget {
  final int smsCount;
  final int pushCount;
  final int totalCount;

  const _CounterCard({
    required this.smsCount,
    required this.pushCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: _CounterItem(
              title: 'SMS',
              value: smsCount.toString(),
              icon: Icons.sms_outlined,
            ),
          ),
          Expanded(
            child: _CounterItem(
              title: 'PUSH',
              value: pushCount.toString(),
              icon: Icons.notifications_none,
            ),
          ),
          Expanded(
            child: _CounterItem(
              title: 'Всего',
              value: totalCount.toString(),
              icon: Icons.all_inbox_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

class _CounterItem extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _CounterItem({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _MessagesCard extends StatelessWidget {
  final List messages;
  final VoidCallback? onClear;

  const _MessagesCard({
    required this.messages,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Последние события Android',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: onClear,
                child: const Text('Очистить'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (messages.isEmpty)
            const Text(
              'Пока нет SMS или PUSH.\nПосле входящего события оно появится здесь.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            )
          else
            ...messages.take(8).map(
                  (message) => _MessageRow(message: message),
            ),
        ],
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  final NativeForwardedMessage message;

  const _MessageRow({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final icon = message.isSms
        ? Icons.sms_outlined
        : Icons.notifications_none;
    final label = message.isSms ? 'SMS' : 'PUSH';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withOpacity(0.12),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label • ${message.displayTitle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message.displaySubtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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