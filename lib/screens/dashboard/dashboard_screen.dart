import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../navigation/app_routes.dart';
import '../../services/native_main_phone_service.dart';
import '../../widgets/common/app_bottom_nav_bar.dart';
import '../../widgets/common/app_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final NativeMainPhoneService nativeService = const NativeMainPhoneService();

  MainPhoneNativeStatus status = const MainPhoneNativeStatus();
  List<NativeForwardedMessage> messages = <NativeForwardedMessage>[];

  bool isLoading = true;

  bool get smsReady => status.smsPermission && status.smsForwarding;

  bool get pushReady => status.notificationListener && status.pushForwarding;

  bool get backgroundReady => status.batteryOptimizationDisabled;

  bool get relayReady => status.relayConfigured;

  bool get isReady => smsReady && pushReady && backgroundReady && relayReady;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final loadedStatus = await nativeService.getStatus();
    final loadedMessages = await nativeService.getMessages();

    if (!mounted) {
      return;
    }

    setState(() {
      status = loadedStatus;
      messages = loadedMessages;
      isLoading = false;
    });
  }

  String _statusTitle() {
    if (isReady) {
      return 'Главный телефон работает';
    }

    if (!relayReady) {
      return 'Не настроен сервер';
    }

    return 'Нужна настройка Android';
  }

  String _statusSubtitle() {
    if (isReady) {
      return 'SMS и PUSH принимаются, сохраняются и готовы к отправке.';
    }

    if (!relayReady) {
      return 'Укажи адрес сервера в настройках, чтобы отправлять события.';
    }

    return 'Проверь SMS, доступ к уведомлениям и работу в фоне.';
  }

  Color _statusColor() {
    if (isReady) {
      return AppColors.success;
    }

    if (!relayReady) {
      return AppColors.warning;
    }

    return AppColors.danger;
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
                onRefresh: _loadData,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _MainStatusCard(
                      title: _statusTitle(),
                      subtitle: _statusSubtitle(),
                      color: _statusColor(),
                      isReady: isReady,
                    ),
                    const SizedBox(height: 16),
                    _CountersCard(
                      smsCount: status.smsCount,
                      pushCount: status.pushCount,
                      totalCount: status.totalCount,
                    ),
                    const SizedBox(height: 16),
                    _SystemStatusCard(
                      smsReady: smsReady,
                      pushReady: pushReady,
                      backgroundReady: backgroundReady,
                      relayReady: relayReady,
                    ),
                    const SizedBox(height: 16),
                    _LastEventsCard(messages: messages),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 46,
                      child: OutlinedButton(
                        onPressed: _loadData,
                        child: const Text('Обновить'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const AppBottomNavBar(
              currentRoute: AppRoutes.dashboard,
            ),
          ],
        ),
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
      child: Row(
        children: [
          Icon(
            Icons.phone_android,
            color: AppColors.primary,
            size: 32,
          ),
          SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Дашборд',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Главный телефон',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.sync,
            color: AppColors.primary,
            size: 30,
          ),
        ],
      ),
    );
  }
}

class _MainStatusCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final bool isReady;

  const _MainStatusCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isReady,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: color.withOpacity(0.16),
            child: Icon(
              isReady ? Icons.check_circle : Icons.warning_rounded,
              color: color,
              size: 30,
            ),
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
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

class _CountersCard extends StatelessWidget {
  final int smsCount;
  final int pushCount;
  final int totalCount;

  const _CountersCard({
    required this.smsCount,
    required this.pushCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          _CounterItem(
            icon: Icons.sms_outlined,
            title: 'SMS',
            value: smsCount.toString(),
          ),
          _CounterItem(
            icon: Icons.notifications_none,
            title: 'PUSH',
            value: pushCount.toString(),
          ),
          _CounterItem(
            icon: Icons.all_inbox_outlined,
            title: 'Всего',
            value: totalCount.toString(),
          ),
        ],
      ),
    );
  }
}

class _CounterItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _CounterItem({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            color: AppColors.primary,
            size: 26,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
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
      ),
    );
  }
}

class _SystemStatusCard extends StatelessWidget {
  final bool smsReady;
  final bool pushReady;
  final bool backgroundReady;
  final bool relayReady;

  const _SystemStatusCard({
    required this.smsReady,
    required this.pushReady,
    required this.backgroundReady,
    required this.relayReady,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Состояние системы',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          _StatusRow(
            title: 'SMS-приёмник',
            subtitle: smsReady ? 'Работает' : 'Нет разрешения или выключен',
            isReady: smsReady,
          ),
          _StatusRow(
            title: 'PUSH-приёмник',
            subtitle: pushReady ? 'Работает' : 'Нет доступа к уведомлениям',
            isReady: pushReady,
          ),
          _StatusRow(
            title: 'Фоновая работа',
            subtitle: backgroundReady
                ? 'Android не должен останавливать приложение'
                : 'Может быть остановлено системой',
            isReady: backgroundReady,
          ),
          _StatusRow(
            title: 'Сервер отправки',
            subtitle: relayReady ? 'Настроен' : 'Не указан',
            isReady: relayReady,
          ),
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

class _LastEventsCard extends StatelessWidget {
  final List<NativeForwardedMessage> messages;

  const _LastEventsCard({
    required this.messages,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Последние события',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (messages.isEmpty)
            const Text(
              'Пока нет входящих SMS или PUSH. Когда Android поймает событие, оно появится здесь.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            )
          else
            ...messages.take(5).map(
                  (message) => _EventRow(message: message),
            ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final NativeForwardedMessage message;

  const _EventRow({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isSms = message.isSms;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: AppColors.primary.withOpacity(0.13),
            child: Icon(
              isSms ? Icons.sms_outlined : Icons.notifications_none,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${isSms ? 'SMS' : 'PUSH'} • ${message.displayTitle}',
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