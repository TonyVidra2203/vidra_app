import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/device_model.dart';
import '../../models/event_model.dart';
import '../../navigation/app_routes.dart';
import '../../services/native_main_phone_service.dart';
import '../../widgets/common/app_bottom_nav_bar.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final NativeMainPhoneService nativeService = const NativeMainPhoneService();

  StreamSubscription? messageUpdatesSubscription;
  Timer? refreshTimer;

  List<DeviceModel> devices = [];
  List<EventModel> events = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDashboardData();
    _listenMessageUpdates();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    messageUpdatesSubscription?.cancel();
    refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadDashboardData();
      _listenMessageUpdates();
      _startAutoRefresh();
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      messageUpdatesSubscription?.cancel();
      messageUpdatesSubscription = null;
      refreshTimer?.cancel();
      refreshTimer = null;
    }
  }

  void _listenMessageUpdates() {
    messageUpdatesSubscription?.cancel();
    messageUpdatesSubscription = nativeService.messageUpdates.listen((_) {
      _loadDashboardData();
    });
  }

  void _startAutoRefresh() {
    refreshTimer?.cancel();
    refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _loadDashboardData();
    });
  }

  Future<void> _loadDashboardData() async {
    final messages = await nativeService.getMessages();

    if (!mounted) {
      return;
    }

    setState(() {
      devices = _buildDeviceList(messages);
      events = messages.take(5).map(_mapMessageToEvent).toList();
    });
  }

  List<DeviceModel> _buildDeviceList(List<NativeForwardedMessage> messages) {
    final latestByDevice = <String, NativeForwardedMessage>{};

    for (final message in messages) {
      final key = _deviceKey(message);

      if (key.isEmpty) {
        continue;
      }

      final current = latestByDevice[key];

      if (current == null || message.receivedAt > current.receivedAt) {
        latestByDevice[key] = message;
      }
    }

    return latestByDevice.values.map((message) {
      return DeviceModel(
        name: _remoteDeviceName(message),
        system: _remoteDeviceSystem(message),
        isOnline: _isRecentlyActive(message.receivedAt),
        lastSeen: _formatLastSeen(message.receivedAt),
        battery: '-',
      );
    }).toList();
  }

  String _deviceKey(NativeForwardedMessage message) {
    if (message.deviceId.trim().isNotEmpty) {
      return message.deviceId.trim();
    }

    if (message.deviceName.trim().isNotEmpty) {
      return message.deviceName.trim();
    }

    if (_remoteDeviceSystem(message).trim().isNotEmpty) {
      return _remoteDeviceSystem(message).trim();
    }

    return '';
  }

  String _remoteDeviceName(NativeForwardedMessage message) {
    if (message.deviceName.trim().isNotEmpty) {
      return message.deviceName.trim();
    }

    return 'Рабочий телефон';
  }

  String _remoteDeviceSystem(NativeForwardedMessage message) {
    final brand = _cleanPhoneText(message.deviceBrand);
    final model = _cleanPhoneText(message.deviceModel);

    if (brand.isNotEmpty && model.isNotEmpty) {
      if (model.toLowerCase().contains(brand.toLowerCase())) {
        return model;
      }

      return '$brand $model';
    }

    if (model.isNotEmpty) {
      return model;
    }

    if (brand.isNotEmpty) {
      return brand;
    }

    if (message.deviceId.trim().isNotEmpty) {
      return 'ID: ${message.deviceId.trim()}';
    }

    return 'Подключённый телефон';
  }

  String _cleanPhoneText(String value) {
    final text = value.trim();

    if (text.isEmpty) {
      return '';
    }

    return text.split(' ').where((part) => part.trim().isNotEmpty).join(' ');
  }

  bool _isRecentlyActive(int receivedAt) {
    final date = DateTime.fromMillisecondsSinceEpoch(receivedAt);
    return DateTime.now().difference(date).inMinutes < 5;
  }

  EventModel _mapMessageToEvent(NativeForwardedMessage message) {
    final date = DateTime.fromMillisecondsSinceEpoch(message.receivedAt);

    return EventModel(
      title: message.isSms
          ? 'SMS от ${message.displayTitle}'
          : 'PUSH от ${message.displayTitle}',
      time: _formatTime(date),
      type: message.isSms ? EventType.sms : EventType.push,
    );
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}:'
        '${date.second.toString().padLeft(2, '0')}';
  }

  String _formatLastSeen(int receivedAt) {
    final date = DateTime.fromMillisecondsSinceEpoch(receivedAt);
    final diff = DateTime.now().difference(date);

    if (diff.inSeconds < 10) {
      return 'Сейчас';
    }

    if (diff.inMinutes < 1) {
      return '${diff.inSeconds} сек. назад';
    }

    if (diff.inHours < 1) {
      return '${diff.inMinutes} мин. назад';
    }

    if (diff.inDays < 1) {
      return '${diff.inHours} ч. назад';
    }

    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  int get _onlineCount {
    return devices.where((device) => device.isOnline).length;
  }

  int get _offlineCount {
    return devices.length - _onlineCount;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            const _BackgroundGlow(),
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 104),
              children: [
                const _DashboardHeader(),
                const SizedBox(height: 18),
                _DevicesCard(
                  devices: devices,
                  totalCount: devices.length,
                  onlineCount: _onlineCount,
                  offlineCount: _offlineCount,
                ),
                const SizedBox(height: 18),
                _EventsCard(events: events),
              ],
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AppBottomNavBar(
                currentRoute: AppRoutes.dashboard,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.35, -0.95),
            radius: 0.9,
            colors: [
              AppColors.primary.withValues(alpha: 0.12),
              AppColors.background.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.menu_rounded,
          color: AppColors.primary,
          size: 32,
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Дашборд',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Главный телефон (прием данных)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.primary,
              size: 32,
            ),
            Positioned(
              right: 1,
              top: 1,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DevicesCard extends StatelessWidget {
  final List<DeviceModel> devices;
  final int totalCount;
  final int onlineCount;
  final int offlineCount;

  const _DevicesCard({
    required this.devices,
    required this.totalCount,
    required this.onlineCount,
    required this.offlineCount,
  });

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      child: Column(
        children: [
          const _CardTitleRow(
            title: 'Устройства',
            action: 'Все устройства',
          ),
          const SizedBox(height: 18),
          _DeviceSummary(
            totalCount: totalCount,
            onlineCount: onlineCount,
            offlineCount: offlineCount,
          ),
          const SizedBox(height: 16),
          const _DividerLine(),
          if (devices.isEmpty)
            const _EmptyState(
              icon: Icons.phone_android_rounded,
              title: 'Нет устройств',
              subtitle: 'Устройства появятся после первого SMS или PUSH',
            )
          else
            ...devices.take(5).map((device) {
              return _DeviceRow(device: device);
            }),
        ],
      ),
    );
  }
}

class _DeviceSummary extends StatelessWidget {
  final int totalCount;
  final int onlineCount;
  final int offlineCount;

  const _DeviceSummary({
    required this.totalCount,
    required this.onlineCount,
    required this.offlineCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _SummaryIcon(),
        const SizedBox(width: 14),
        Expanded(
          child: _SummaryItem(
            label: 'Всего',
            value: totalCount.toString(),
          ),
        ),
        Expanded(
          child: _SummaryItem(
            label: 'Онлайн',
            value: onlineCount.toString(),
            dotColor: AppColors.success,
          ),
        ),
        Expanded(
          child: _SummaryItem(
            label: 'Оффлайн',
            value: offlineCount.toString(),
            dotColor: AppColors.danger,
          ),
        ),
      ],
    );
  }
}

class _SummaryIcon extends StatelessWidget {
  const _SummaryIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 34,
      child: Icon(
        Icons.phone_android_rounded,
        color: AppColors.primary,
        size: 31,
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? dotColor;

  const _SummaryItem({
    required this.label,
    required this.value,
    this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (dotColor != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 30,
            fontWeight: FontWeight.w300,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _DeviceRow extends StatelessWidget {
  final DeviceModel device;

  const _DeviceRow({
    required this.device,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = device.isOnline ? AppColors.success : AppColors.danger;
    final statusText = device.isOnline ? 'Онлайн' : 'Оффлайн';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              const Icon(
                Icons.phone_android_rounded,
                color: AppColors.textPrimary,
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      device.system,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 5,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statusText,
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
                            device.lastSeen,
                            maxLines: 1,
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
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primary,
                size: 25,
              ),
            ],
          ),
        ),
        const _DividerLine(),
      ],
    );
  }
}

class _EventsCard extends StatelessWidget {
  final List<EventModel> events;

  const _EventsCard({
    required this.events,
  });

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      child: Column(
        children: [
          const _CardTitleRow(
            title: 'Последние события',
            action: 'Все события',
          ),
          const SizedBox(height: 14),
          if (events.isEmpty)
            const _EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'Нет событий',
              subtitle: 'Новые SMS и PUSH появятся здесь автоматически',
            )
          else
            ...events.take(5).map((event) {
              return _EventRow(event: event);
            }),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final EventModel event;

  const _EventRow({
    required this.event,
  });

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(event.type);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 19),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Padding(
          padding: const EdgeInsets.only(top: 13),
          child: Icon(
            _eventIcon(event.type),
            color: event.type == EventType.error
                ? AppColors.danger
                : AppColors.textPrimary,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      event.time,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const _DividerLine(),
            ],
          ),
        ),
      ],
    );
  }

  Color _statusColor(EventType type) {
    switch (type) {
      case EventType.error:
        return AppColors.danger;
      case EventType.warning:
        return AppColors.warning;
      case EventType.device:
      case EventType.sms:
      case EventType.push:
        return AppColors.success;
    }
  }

  IconData _eventIcon(EventType type) {
    switch (type) {
      case EventType.device:
        return Icons.phone_android_rounded;
      case EventType.sms:
        return Icons.chat_bubble_outline_rounded;
      case EventType.push:
        return Icons.notifications_none_rounded;
      case EventType.error:
        return Icons.warning_rounded;
      case EventType.warning:
        return Icons.info_outline_rounded;
    }
  }
}

class _CardTitleRow extends StatelessWidget {
  final String title;
  final String action;

  const _CardTitleRow({
    required this.title,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  action,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final Widget child;

  const _DashboardCard({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.cardBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DividerLine extends StatelessWidget {
  const _DividerLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: AppColors.cardBorder.withValues(alpha: 0.7),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(
            icon,
            color: AppColors.primary,
            size: 38,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}