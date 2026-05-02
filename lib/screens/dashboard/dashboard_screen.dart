import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/device_model.dart';
import '../../models/event_model.dart';
import '../../navigation/app_routes.dart';
import '../../services/native_main_phone_service.dart';
import '../../widgets/common/app_bottom_nav_bar.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/dashboard/device_list.dart';
import '../../widgets/dashboard/event_list.dart';

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

    messageUpdatesSubscription?.cancel();
    messageUpdatesSubscription = null;
    refreshTimer?.cancel();
    refreshTimer = null;
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

    if (!mounted) return;

    setState(() {
      devices = _buildDeviceList(messages);
      events = messages.take(5).map(_mapMessageToEvent).toList();
    });
  }

  List<DeviceModel> _buildDeviceList(List<NativeForwardedMessage> messages) {
    final latestByDevice = <String, NativeForwardedMessage>{};

    for (final message in messages) {
      final key = _deviceKey(message);
      if (key.isEmpty) continue;

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
    if (message.deviceId.trim().isNotEmpty) return message.deviceId.trim();
    if (message.deviceName.trim().isNotEmpty) return message.deviceName.trim();
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

    if (model.isNotEmpty) return model;
    if (brand.isNotEmpty) return brand;
    if (message.deviceId.trim().isNotEmpty) {
      return 'ID: ${message.deviceId.trim()}';
    }

    return 'Подключённый телефон';
  }

  String _cleanPhoneText(String value) {
    final text = value.trim();
    if (text.isEmpty) return '';
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

    if (diff.inSeconds < 10) return 'Сейчас';
    if (diff.inMinutes < 1) return '${diff.inSeconds} сек. назад';
    if (diff.inHours < 1) return '${diff.inMinutes} мин. назад';
    if (diff.inDays < 1) return '${diff.inHours} ч. назад';

    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  void _goToModeSelection() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.modeSelection,
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _DashboardHeader(onChangeModePressed: _goToModeSelection),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(child: _StatCard('Устройства', devices.length)),
                      const SizedBox(width: 10),
                      Expanded(child: _StatCard('События', events.length)),
                    ],
                  ),

                  const SizedBox(height: 16),

                  AppCard(
                    child: devices.isEmpty
                        ? const Center(child: Text('Нет устройств'))
                        : DeviceList(devices: devices),
                  ),

                  const SizedBox(height: 16),

                  AppCard(
                    child: events.isEmpty
                        ? const Center(child: Text('Нет событий'))
                        : EventList(events: events),
                  ),
                ],
              ),
            ),
            const AppBottomNavBar(currentRoute: AppRoutes.dashboard),
          ],
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final VoidCallback onChangeModePressed;

  const _DashboardHeader({required this.onChangeModePressed});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'VidRA',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'SMS & PUSH Forwarder',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onChangeModePressed,
            child: const Text('Сменить устройство'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final int value;

  const _StatCard(this.title, this.value);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}