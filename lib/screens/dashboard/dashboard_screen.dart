import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/app_mode.dart';
import '../../models/device_model.dart';
import '../../models/event_model.dart';
import '../../navigation/app_routes.dart';
import '../../services/app_mode_service.dart';
import '../../services/native_main_phone_service.dart';
import '../../widgets/common/app_bottom_nav_bar.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/mode_switch_header.dart';
import '../../widgets/dashboard/device_list.dart';
import '../../widgets/dashboard/event_list.dart';
import '../sender/sender_status_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final NativeMainPhoneService nativeService = const NativeMainPhoneService();

  StreamSubscription<dynamic>? messageUpdatesSubscription;
  Timer? fallbackRefreshTimer;

  List<DeviceModel> devices = [];
  List<EventModel> events = [];

  bool hasLoadedOnce = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();

    AppModeService.setMode(AppMode.receiver);
    WidgetsBinding.instance.addObserver(this);
    _loadDashboardData();
    _listenMessageUpdates();
    _startFallbackRefresh();
  }

  @override
  void dispose() {
    messageUpdatesSubscription?.cancel();
    fallbackRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadDashboardData();
      _listenMessageUpdates();
      _startFallbackRefresh();
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      messageUpdatesSubscription?.cancel();
      messageUpdatesSubscription = null;
      fallbackRefreshTimer?.cancel();
      fallbackRefreshTimer = null;
    }
  }

  void _listenMessageUpdates() {
    messageUpdatesSubscription?.cancel();
    messageUpdatesSubscription = nativeService.messageUpdates.listen((_) {
      _loadDashboardData();
    });
  }

  void _startFallbackRefresh() {
    fallbackRefreshTimer?.cancel();
    fallbackRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
          (_) => _loadDashboardData(),
    );
  }

  Future<void> _loadDashboardData() async {
    if (isLoading) {
      return;
    }

    isLoading = true;

    try {
      final messages = await nativeService.getMessages();

      if (!mounted) {
        return;
      }

      if (messages.isEmpty && hasLoadedOnce) {
        return;
      }

      setState(() {
        hasLoadedOnce = true;
        devices = _buildDeviceList(messages);
        events = messages.take(5).map(_mapMessageToEvent).toList();
      });
    } finally {
      isLoading = false;
    }
  }

  List<DeviceModel> _buildDeviceList(
      List<NativeForwardedMessage> messages,
      ) {
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

    return 'Телефон передачи';
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

    return text
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .join(' ');
  }

  bool _isRecentlyActive(int receivedAt) {
    final date = DateTime.fromMillisecondsSinceEpoch(receivedAt);
    final difference = DateTime.now().difference(date);

    return difference.inMinutes < 5;
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
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');

    return '$hour:$minute:$second';
  }

  String _formatLastSeen(int receivedAt) {
    final date = DateTime.fromMillisecondsSinceEpoch(receivedAt);
    final difference = DateTime.now().difference(date);

    if (difference.inSeconds < 10) {
      return 'Сейчас';
    }

    if (difference.inMinutes < 1) {
      return '${difference.inSeconds} сек. назад';
    }

    if (difference.inHours < 1) {
      return '${difference.inMinutes} мин. назад';
    }

    if (difference.inDays < 1) {
      return '${difference.inHours} ч. назад';
    }

    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  void _openDevicePairing() {
    Navigator.of(context).pushNamed(AppRoutes.devicePairing);
  }

  void _onModeChanged(AppMode mode) {
    if (mode == AppMode.receiver) {
      return;
    }

    AppModeService.setMode(AppMode.sender);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const SenderStatusScreen(),
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
            ModeSwitchHeader(
              currentMode: AppMode.receiver,
              onModeChanged: _onModeChanged,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CardTitle(
                            title: 'Устройства',
                            action: 'Добавить',
                            onActionPressed: _openDevicePairing,
                          ),
                          const SizedBox(height: 12),
                          devices.isEmpty
                              ? const _EmptyDevices()
                              : DeviceList(devices: devices),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _CardTitle(
                            title: 'Последние события',
                            action: 'Фактические',
                          ),
                          const SizedBox(height: 12),
                          events.isEmpty
                              ? const _EmptyEvents()
                              : EventList(events: events),
                        ],
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

class _CardTitle extends StatelessWidget {
  final String title;
  final String action;
  final VoidCallback? onActionPressed;

  const _CardTitle({
    required this.title,
    required this.action,
    this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    final actionText = Text(
      action,
      style: const TextStyle(
        color: AppColors.primary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );

    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        onActionPressed == null
            ? actionText
            : TextButton.icon(
          onPressed: onActionPressed,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const Icon(
            Icons.add,
            size: 18,
          ),
          label: actionText,
        ),
      ],
    );
  }
}

class _EmptyDevices extends StatelessWidget {
  const _EmptyDevices();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.phone_android_outlined,
              color: AppColors.textSecondary,
              size: 42,
            ),
            SizedBox(height: 12),
            Text(
              'Подключённых устройств нет',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Телефоны передачи появятся здесь после первого SMS или PUSH',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyEvents extends StatelessWidget {
  const _EmptyEvents();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.notifications_off_outlined,
              color: AppColors.textSecondary,
              size: 42,
            ),
            SizedBox(height: 12),
            Text(
              'Событий нет',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Новые SMS и PUSH появятся здесь автоматически',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}