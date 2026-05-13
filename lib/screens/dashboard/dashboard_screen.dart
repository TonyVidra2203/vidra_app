import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../models/app_mode.dart';
import '../../models/device_model.dart';
import '../../models/event_model.dart';
import '../../navigation/app_routes.dart';
import '../../services/app_mode_service.dart';
import '../../services/device_pairing_service.dart';
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
  static const String _pushNotificationsKey =
      'dashboard_push_notifications_enabled';
  static const String _deletedDevicesKey = 'dashboard_deleted_devices';

  final NativeMainPhoneService nativeService = const NativeMainPhoneService();
  final DevicePairingService pairingService = DevicePairingService();

  StreamSubscription<void>? messageUpdatesSubscription;
  Timer? fallbackRefreshTimer;

  List<NativeForwardedMessage> latestMessages = [];
  List<DeviceModel> devices = [];
  List<EventModel> events = [];
  Set<String> deletedDeviceIds = {};

  DevicePairingState pairingState = const DevicePairingState.empty();
  EventModel? pairingConnectedEvent;

  bool hasLoadedOnce = false;
  bool hasConfirmedPairing = false;
  bool isLoading = false;
  bool isPairing = false;
  bool pushNotificationsEnabled = true;

  bool get _isMainPhoneLocked {
    return pairingState.isMainPhone &&
        (pairingState.isPaired ||
            hasConfirmedPairing ||
            latestMessages.isNotEmpty);
  }

  @override
  void initState() {
    super.initState();
    AppModeService.setMode(AppMode.receiver);
    WidgetsBinding.instance.addObserver(this);
    _loadSavedSettings();
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

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) {
      return;
    }

    setState(() {
      pushNotificationsEnabled = prefs.getBool(_pushNotificationsKey) ?? true;
      deletedDeviceIds = prefs.getStringList(_deletedDevicesKey)?.toSet() ?? {};
      _rebuildDashboardState();
    });
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
      const Duration(seconds: 5),
          (_) => _loadDashboardData(),
    );
  }

  Future<void> _loadDashboardData() async {
    if (isLoading) {
      return;
    }

    isLoading = true;

    try {
      final loadedPairingState = await pairingService.refreshMainPhonePairing();
      final messages = await nativeService.getMessages();

      if (!mounted) {
        return;
      }

      if (loadedPairingState.isMainPhone &&
          (loadedPairingState.isPaired ||
              hasConfirmedPairing ||
              messages.isNotEmpty)) {
        await AppModeService.activateMode(AppMode.receiver);
      }

      if (!loadedPairingState.isMainPhone && pairingState.isMainPhone) {
        await AppModeService.resetActivation();
      }

      setState(() {
        hasLoadedOnce = true;
        pairingState = loadedPairingState;

        if (messages.isNotEmpty || !loadedPairingState.isPaired) {
          latestMessages = messages;
        }

        _rememberConfirmedPairing(loadedPairingState, latestMessages);
        _rebuildDashboardState();
      });
    } finally {
      isLoading = false;
    }
  }

  void _rememberConfirmedPairing(
      DevicePairingState newState,
      List<NativeForwardedMessage> messages,
      ) {
    final isConfirmed = newState.isMainPhone &&
        (newState.isPaired || messages.isNotEmpty || hasConfirmedPairing);

    if (!isConfirmed) {
      return;
    }

    if (!hasConfirmedPairing) {
      pairingConnectedEvent = EventModel(
        title: _connectedEventTitle(newState, messages),
        time: _formatTime(DateTime.now()),
        type: EventType.device,
      );
    }

    hasConfirmedPairing = true;
  }

  String _connectedEventTitle(
      DevicePairingState state,
      List<NativeForwardedMessage> messages,
      ) {
    final realDeviceName =
    messages.isEmpty ? '' : _remoteDeviceName(messages.first);
    final stateDeviceName = state.pairedDeviceName.trim();
    final deviceName = realDeviceName.trim().isNotEmpty
        ? realDeviceName.trim()
        : stateDeviceName;

    if (deviceName.isEmpty) {
      return 'Рабочий телефон успешно подключён';
    }

    return 'Рабочий телефон "$deviceName" успешно подключён';
  }

  void _rebuildDashboardState() {
    devices = _buildDeviceList(latestMessages);

    final latestEvents = latestMessages.take(5).map(_mapMessageToEvent).toList();

    if (pairingConnectedEvent != null) {
      events = [
        pairingConnectedEvent!,
        ...latestEvents,
      ].take(5).toList();
      return;
    }

    events = latestEvents;
  }

  List<DeviceModel> _buildDeviceList(List<NativeForwardedMessage> messages) {
    final Map<String, NativeForwardedMessage> latestByDevice = {};

    for (final message in messages) {
      final key = _deviceKey(message);

      if (key.isEmpty || deletedDeviceIds.contains(key)) {
        continue;
      }

      final current = latestByDevice[key];

      if (current == null || message.receivedAt > current.receivedAt) {
        latestByDevice[key] = message;
      }
    }

    final result = latestByDevice.values.map((message) {
      final key = _deviceKey(message);

      return DeviceModel(
        id: key,
        name: _remoteDeviceName(message),
        system: _remoteDeviceSystem(message),
        isOnline: _isRecentlyActive(message.receivedAt),
        lastSeen: _formatLastSeen(message.receivedAt),
        battery: '-',
        phoneNumber: _phoneNumber(message),
      );
    }).toList();

    if (result.isNotEmpty) {
      return result;
    }

    final pairedDevice = _buildPairedDevicePlaceholder();

    if (pairedDevice != null && !deletedDeviceIds.contains(pairedDevice.id)) {
      result.insert(0, pairedDevice);
    }

    return result;
  }

  DeviceModel? _buildPairedDevicePlaceholder() {
    if (!pairingState.isMainPhone || !pairingState.hasPairCode) {
      return null;
    }

    final pairedName = pairingState.pairedDeviceName.trim().isEmpty
        ? 'Рабочий телефон'
        : pairingState.pairedDeviceName.trim();

    final pairCode = pairingState.pairCode.trim();
    final id = pairCode.isEmpty ? pairedName : 'paired_$pairCode';
    final isConnected = pairingState.isPaired || hasConfirmedPairing;

    return DeviceModel(
      id: id,
      name: pairedName,
      system: isConnected
          ? 'Связан с главным телефоном'
          : 'Ожидает подключения по коду $pairCode',
      isOnline: isConnected,
      lastSeen: isConnected ? 'Только что привязан' : 'Ожидание',
      battery: '-',
      phoneNumber: 'Не указан',
    );
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

  String _phoneNumber(NativeForwardedMessage message) {
    if (message.isSms && message.sender.trim().isNotEmpty) {
      return message.sender.trim();
    }

    return 'Не указан';
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

  Future<void> _openDevicePairing() async {
    final action = await showModalBottomSheet<_PairingAction>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Добавить рабочий телефон',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Отсканируйте QR-код с рабочего телефона.\n'
                      'Если камеры нет — сгенерируйте код вручную.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 18),
                _PairingOptionTile(
                  icon: Icons.qr_code_scanner,
                  title: 'Сканировать QR-код',
                  subtitle: 'Открыть камеру и считать QR с рабочего телефона',
                  onTap: () {
                    Navigator.of(context).pop(_PairingAction.scanQr);
                  },
                ),
                const SizedBox(height: 10),
                _PairingOptionTile(
                  icon: Icons.pin,
                  title: 'Сгенерировать код связки',
                  subtitle: 'Запасной вариант без камеры',
                  onTap: () {
                    Navigator.of(context).pop(_PairingAction.generateCode);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    if (action == _PairingAction.scanQr) {
      await _scanWorkerQr();
      return;
    }

    await _createMainPhoneCode();
  }

  Future<void> _scanWorkerQr() async {
    final payload = await Navigator.of(context).pushNamed(
      AppRoutes.qrPairingScanner,
    );

    if (!mounted || payload == null) {
      return;
    }

    if (payload is WorkerPairingQrPayload) {
      await _createMainPhoneCode(
        pairedDeviceName: payload.deviceName,
      );
      return;
    }

    _showSnackBar('Это не QR-код рабочего телефона VidRA.');
  }

  Future<void> _createMainPhoneCode({
    String pairedDeviceName = '',
  }) async {
    if (isPairing) {
      return;
    }

    setState(() {
      isPairing = true;
    });

    try {
      final newState = await pairingService.createMainPhonePairCode(
        deviceName: 'Главный телефон',
        pairedDeviceName: pairedDeviceName,
      );

      await AppModeService.activateMode(AppMode.receiver);

      if (!mounted) {
        return;
      }

      setState(() {
        pairingState = newState;
        _rebuildDashboardState();
      });

      await _showPairCodeSheet(newState);
      await _loadDashboardData();
    } on DevicePairingException catch (error) {
      _showSnackBar(error.message);
    } catch (_) {
      _showSnackBar('Не удалось создать код связки.');
    } finally {
      if (mounted) {
        setState(() {
          isPairing = false;
        });
      }
    }
  }

  Future<void> _showPairCodeSheet(DevicePairingState state) async {
    Timer? pairingCheckTimer;
    BuildContext? sheetContext;
    bool isSheetClosed = false;

    pairingCheckTimer = Timer.periodic(
      const Duration(seconds: 2),
          (_) async {
        if (isSheetClosed || !mounted) {
          return;
        }

        try {
          final newState = await pairingService.refreshMainPhonePairing();

          if (isSheetClosed || !mounted) {
            return;
          }

          setState(() {
            pairingState = newState;
            _rememberConfirmedPairing(newState, latestMessages);
            _rebuildDashboardState();
          });

          if (newState.isMainPhone && newState.isPaired) {
            await AppModeService.activateMode(AppMode.receiver);

            isSheetClosed = true;
            pairingCheckTimer?.cancel();

            if (sheetContext != null) {
              Navigator.of(sheetContext!).pop();
            }

            _showSnackBar('Рабочий телефон привязан.');
          }
        } catch (_) {}
      },
    );

    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(22),
          ),
        ),
        builder: (context) {
          sheetContext = context;

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 18,
                bottom: MediaQuery.of(context).viewInsets.bottom + 18,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.pin,
                      color: AppColors.primary,
                      size: 42,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Код связки создан',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Введите этот код на рабочем телефоне во вкладке '
                          '“Передача”. Окно закроется автоматически после '
                          'подключения.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Код для ручного ввода',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      state.pairCode,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 7,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Ожидаем подключение рабочего телефона...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Закрыть'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } finally {
      isSheetClosed = true;
      pairingCheckTimer.cancel();
    }
  }

  void _onModeChanged(AppMode mode) {
    if (mode == AppMode.receiver || _isMainPhoneLocked) {
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

  Future<void> _onPushNotificationsChanged(bool value) async {
    if (value) {
      final allowed = await nativeService.requestPostNotificationPermission();

      if (!allowed && mounted) {
        _showSnackBar('Разрешение на PUSH уведомления не выдано');
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pushNotificationsKey, value);

    if (!mounted) {
      return;
    }

    setState(() {
      pushNotificationsEnabled = value;
    });

    _showSnackBar(
      value
          ? 'Уведомления о новых сообщениях включены'
          : 'Уведомления о новых сообщениях выключены',
    );
  }

  Future<void> _deleteDevice(DeviceModel device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text(
            'Отвязать устройство?',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Text(
            'Телефон "${device.name}" будет отвязан от главного телефона.\n'
                'Связь будет сброшена, а новые SMS и PUSH с этого подключения '
                'больше не будут приниматься.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Отвязать',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    deletedDeviceIds.add(device.id);

    if (pairingState.isMainPhone || pairingState.isPaired) {
      final pairCode = pairingState.pairCode.trim();
      final targetDeviceId = device.id.startsWith('paired_') ? '' : device.id;

      if (pairCode.isNotEmpty) {
        deletedDeviceIds.add('paired_$pairCode');
      }

      await pairingService.sendUnpairEvent(
        pairingState,
        targetDeviceId: targetDeviceId,
      );
      await pairingService.resetPairing(notifyRemote: false);
      await AppModeService.resetActivation();

      pairingState = const DevicePairingState.empty();
      pairingConnectedEvent = null;
      hasConfirmedPairing = false;
    }

    await prefs.setStringList(_deletedDevicesKey, deletedDeviceIds.toList());

    if (!mounted) {
      return;
    }

    setState(() {
      latestMessages = [];
      devices = [];
      events = [];
      hasLoadedOnce = false;
      _rebuildDashboardState();
    });

    _showSnackBar('Устройство отвязано');
  }

  void _showSnackBar(String text) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMainPhoneLocked = _isMainPhoneLocked;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ModeSwitchHeader(
              currentMode: AppMode.receiver,
              pushNotificationsEnabled: pushNotificationsEnabled,
              onModeChanged: _onModeChanged,
              onPushNotificationsChanged: _onPushNotificationsChanged,
              visibleModes:
              isMainPhoneLocked ? const [AppMode.receiver] : AppMode.values,
              onResetPairing: null,
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
                            action: isPairing ? 'Создаю...' : 'Добавить',
                            onActionPressed:
                            isPairing ? null : _openDevicePairing,
                          ),
                          const SizedBox(height: 12),
                          devices.isEmpty
                              ? const _EmptyDevices()
                              : DeviceList(
                            devices: devices,
                            onDeleteDevice: _deleteDevice,
                          ),
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

enum _PairingAction {
  scanQr,
  generateCode,
}

class _PairingOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PairingOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                icon,
                color: AppColors.primary,
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
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
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
              const Icon(
                Icons.chevron_right,
                color: AppColors.primary,
              ),
            ],
          ),
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
              'Телефон появится здесь сразу после создания связки',
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