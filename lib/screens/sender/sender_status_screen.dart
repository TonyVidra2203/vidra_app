import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../models/app_mode.dart';
import '../../services/app_mode_service.dart';
import '../../services/device_pairing_service.dart';
import '../../services/sender_settings_service.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/mode_switch_header.dart';
import '../dashboard/dashboard_screen.dart';
import 'sender_permissions_screen.dart';
import 'sender_settings_screen.dart';
import 'widgets/sender_bottom_nav_bar.dart';

class SenderStatusScreen extends StatefulWidget {
  const SenderStatusScreen({super.key});

  @override
  State<SenderStatusScreen> createState() => _SenderStatusScreenState();
}

class _SenderStatusScreenState extends State<SenderStatusScreen> {
  final SenderSettingsService _settingsService = const SenderSettingsService();
  final DevicePairingService _pairingService = DevicePairingService();
  final TextEditingController _pairCodeController = TextEditingController();

  Timer? remoteUnpairTimer;

  SenderSettingsState? settings;
  DevicePairingState pairingState = const DevicePairingState.empty();
  WorkerPairingQrPayload? workerQrPayload;

  bool pushNotificationsEnabled = true;
  bool isLoading = true;
  bool isSaving = false;
  bool showManualCodeInput = false;
  String message = '';

  bool get isWorkerPhonePaired {
    return pairingState.isPaired && pairingState.isWorkerPhone;
  }

  @override
  void initState() {
    super.initState();
    AppModeService.setMode(AppMode.sender);
    _loadData();
    _startRemoteUnpairWatcher();
  }

  @override
  void dispose() {
    remoteUnpairTimer?.cancel();
    _pairCodeController.dispose();
    super.dispose();
  }

  void _startRemoteUnpairWatcher() {
    remoteUnpairTimer?.cancel();

    remoteUnpairTimer = Timer.periodic(
      const Duration(seconds: 5),
          (_) => _syncRemoteUnpair(),
    );
  }

  Future<void> _syncRemoteUnpair() async {
    if (isLoading || isSaving || !isWorkerPhonePaired) {
      return;
    }

    final syncedState = await _pairingService.syncRemoteUnpair();

    if (!mounted || syncedState.isPaired || !pairingState.isWorkerPhone) {
      return;
    }

    await AppModeService.resetActivation();

    final loadedSettings = await _settingsService.load();

    final payload = await _pairingService.createWorkerQrPayload(
      deviceName: loadedSettings.deviceName.trim().isEmpty
          ? 'Телефон передачи'
          : loadedSettings.deviceName.trim(),
      phoneNumber: '',
    );

    if (!mounted) {
      return;
    }

    setState(() {
      settings = loadedSettings;
      pairingState = const DevicePairingState.empty();
      workerQrPayload = payload;
      _pairCodeController.clear();
      showManualCodeInput = false;
      message = 'Главный телефон разъединил связку.\nПодключите телефон заново.';
    });
  }

  Future<void> _loadData() async {
    final loadedSettings = await _settingsService.load();
    final loadedPairingState = await _pairingService.loadState();

    final shouldShowPairingQr =
        !loadedPairingState.isPaired || !loadedPairingState.isWorkerPhone;

    WorkerPairingQrPayload? qrPayload;

    if (shouldShowPairingQr) {
      qrPayload = await _pairingService.createWorkerQrPayload(
        deviceName: loadedSettings.deviceName.trim().isEmpty
            ? 'Телефон передачи'
            : loadedSettings.deviceName.trim(),
        phoneNumber: '',
      );
    }

    if (loadedPairingState.isPaired && loadedPairingState.isWorkerPhone) {
      await AppModeService.activateMode(AppMode.sender);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      settings = loadedSettings;
      pairingState = loadedPairingState;
      workerQrPayload = qrPayload;
      pushNotificationsEnabled = loadedSettings.pushForwarding;
      isLoading = false;
    });
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

  Future<void> _onPushNotificationsChanged(bool value) async {
    final currentSettings = settings;

    if (currentSettings == null || !isWorkerPhonePaired) {
      return;
    }

    final updatedSettings = currentSettings.copyWith(pushForwarding: value);

    setState(() {
      settings = updatedSettings;
      pushNotificationsEnabled = value;
    });

    await _settingsService.save(updatedSettings);
  }

  void _onNavTap(int index) {
    if (!isWorkerPhonePaired) {
      return;
    }

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

  Future<void> _connectByManualCode() async {
    setState(() {
      isSaving = true;
      message = '';
    });

    try {
      final loadedSettings = settings ?? await _settingsService.load();

      final newState = await _pairingService.connectWorkerPhone(
        deviceName: loadedSettings.deviceName.trim().isEmpty
            ? 'Телефон передачи'
            : loadedSettings.deviceName.trim(),
        phoneNumber: '',
        pairCode: _pairCodeController.text,
      );

      await AppModeService.activateMode(AppMode.sender);

      final updatedSettings = await _settingsService.load();

      if (!mounted) {
        return;
      }

      setState(() {
        pairingState = newState;
        settings = updatedSettings;
        pushNotificationsEnabled = updatedSettings.pushForwarding;
        isSaving = false;
        message = 'Телефон передачи привязан.\nТеперь доступно меню передачи.';
      });
    } on DevicePairingException catch (error) {
      _setError(error.message);
    } catch (_) {
      _setError('Не удалось привязать телефон передачи.');
    }
  }

  Future<void> _resetPairing() async {
    setState(() {
      isSaving = true;
      message = '';
    });

    await _pairingService.resetPairing();
    await AppModeService.resetActivation();

    final loadedSettings = await _settingsService.load();

    final payload = await _pairingService.createWorkerQrPayload(
      deviceName: loadedSettings.deviceName.trim().isEmpty
          ? 'Телефон передачи'
          : loadedSettings.deviceName.trim(),
      phoneNumber: '',
    );

    if (!mounted) {
      return;
    }

    setState(() {
      settings = loadedSettings;
      pairingState = const DevicePairingState.empty();
      workerQrPayload = payload;
      _pairCodeController.clear();
      showManualCodeInput = false;
      isSaving = false;
      message = 'Связка сброшена.\nТеперь снова доступны вкладки Приём и Передача.';
    });
  }

  void _setError(String text) {
    if (!mounted) {
      return;
    }

    setState(() {
      isSaving = false;
      message = text;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentSettings = settings;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ModeSwitchHeader(
              currentMode: AppMode.sender,
              onModeChanged: _onModeChanged,
              pushNotificationsEnabled:
              isWorkerPhonePaired && pushNotificationsEnabled,
              onPushNotificationsChanged: _onPushNotificationsChanged,
              visibleModes:
              isWorkerPhonePaired ? const [AppMode.sender] : AppMode.values,
              onResetPairing: isWorkerPhonePaired ? _resetPairing : null,
            ),
            Expanded(
              child: isLoading || currentSettings == null
                  ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              )
                  : RefreshIndicator(
                onRefresh: _loadData,
                child: isWorkerPhonePaired
                    ? _buildPairedContent(currentSettings)
                    : _buildPairingContent(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: isWorkerPhonePaired
          ? SenderBottomNavBar(
        currentIndex: 0,
        onTap: _onNavTap,
      )
          : null,
    );
  }

  Widget _buildPairingContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _WorkerPairingCard(
          payload: workerQrPayload,
          isManualCodeVisible: showManualCodeInput,
          pairCodeController: _pairCodeController,
          isSaving: isSaving,
          onToggleManualCode: () {
            setState(() {
              showManualCodeInput = !showManualCodeInput;
            });
          },
          onConnect: _connectByManualCode,
        ),
        if (message.isNotEmpty) ...[
          const SizedBox(height: 14),
          _MessageCard(message: message),
        ],
      ],
    );
  }

  Widget _buildPairedContent(SenderSettingsState currentSettings) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _WorkerHeroCard(settings: currentSettings),
        const SizedBox(height: 14),
        _QuickStatusGrid(settings: currentSettings),
        const SizedBox(height: 14),
        _TransmissionCard(settings: currentSettings),
        const SizedBox(height: 14),
        _QuickActionsCard(
          isSaving: isSaving,
          onSettingsTap: () => _onNavTap(1),
          onPermissionsTap: () => _onNavTap(2),
          onRefreshTap: _loadData,
          onResetPairing: _resetPairing,
        ),
        if (message.isNotEmpty) ...[
          const SizedBox(height: 14),
          _MessageCard(message: message),
        ],
      ],
    );
  }
}

class _WorkerHeroCard extends StatelessWidget {
  final SenderSettingsState settings;

  const _WorkerHeroCard({
    required this.settings,
  });

  bool get isTransmissionEnabled {
    return settings.smsForwarding || settings.pushForwarding;
  }

  String get deviceName {
    final value = settings.deviceName.trim();

    if (value.isEmpty) {
      return 'Рабочий телефон';
    }

    return value;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = isTransmissionEnabled ? AppColors.success : AppColors.warning;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.9),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.08),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: statusColor.withOpacity(0.38),
                  ),
                ),
                child: Icon(
                  isTransmissionEnabled
                      ? Icons.send_to_mobile_rounded
                      : Icons.pause_circle_outline_rounded,
                  color: statusColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isTransmissionEnabled
                          ? 'Передача работает'
                          : 'Передача выключена',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      deviceName,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              _OnlineBadge(isActive: isTransmissionEnabled),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Этот телефон принимает SMS и PUSH-уведомления, а затем передаёт их на главный телефон VidRA.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _HeroMiniInfo(
                  icon: Icons.sms_outlined,
                  title: 'SMS',
                  value: settings.smsForwarding ? 'Активно' : 'Выкл.',
                  isActive: settings.smsForwarding,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroMiniInfo(
                  icon: Icons.notifications_none_rounded,
                  title: 'PUSH',
                  value: settings.pushForwarding ? 'Активно' : 'Выкл.',
                  isActive: settings.pushForwarding,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OnlineBadge extends StatelessWidget {
  final bool isActive;

  const _OnlineBadge({
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.success : AppColors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'ON' : 'OFF',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMiniInfo extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool isActive;

  const _HeroMiniInfo({
    required this.icon,
    required this.title,
    required this.value,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primary : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
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

class _QuickStatusGrid extends StatelessWidget {
  final SenderSettingsState settings;

  const _QuickStatusGrid({
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatusTile(
            icon: Icons.link_rounded,
            title: 'Связка',
            value: 'Подключена',
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatusTile(
            icon: Icons.wifi_tethering_rounded,
            title: 'Передача',
            value: settings.onlyWithInternet ? 'Онлайн' : 'Всегда',
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

class _StatusTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatusTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransmissionCard extends StatelessWidget {
  final SenderSettingsState settings;

  const _TransmissionCard({
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Что сейчас включено',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Основные параметры рабочего телефона',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          _TransmissionRow(
            icon: Icons.sms_outlined,
            title: 'SMS-сообщения',
            subtitle: 'Передача входящих SMS',
            isActive: settings.smsForwarding,
          ),
          const SizedBox(height: 12),
          _TransmissionRow(
            icon: Icons.notifications_none_rounded,
            title: 'PUSH-уведомления',
            subtitle: 'Передача уведомлений приложений',
            isActive: settings.pushForwarding,
          ),
          const SizedBox(height: 12),
          _TransmissionRow(
            icon: Icons.battery_charging_full_rounded,
            title: 'Фоновая работа',
            subtitle: 'Работа без открытого приложения',
            isActive: settings.backgroundMode,
          ),
          const SizedBox(height: 12),
          _TransmissionRow(
            icon: Icons.public_rounded,
            title: 'Интернет',
            subtitle: settings.onlyWithInternet
                ? 'Передача только при подключении'
                : 'Передача без строгого ограничения',
            isActive: !settings.onlyWithInternet,
          ),
        ],
      ),
    );
  }
}

class _TransmissionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isActive;

  const _TransmissionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.success : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.38),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: color,
              size: 21,
            ),
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
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          _SmallStatePill(isActive: isActive),
        ],
      ),
    );
  }
}

class _SmallStatePill extends StatelessWidget {
  final bool isActive;

  const _SmallStatePill({
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.success : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isActive ? 'Вкл' : 'Выкл',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onSettingsTap;
  final VoidCallback onPermissionsTap;
  final VoidCallback onRefreshTap;
  final VoidCallback onResetPairing;

  const _QuickActionsCard({
    required this.isSaving,
    required this.onSettingsTap,
    required this.onPermissionsTap,
    required this.onRefreshTap,
    required this.onResetPairing,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Быстрые действия',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          _ActionButton(
            icon: Icons.settings_outlined,
            title: 'Настройки передачи',
            subtitle: 'SMS, PUSH, фон и интернет',
            onTap: onSettingsTap,
          ),
          const SizedBox(height: 10),
          _ActionButton(
            icon: Icons.verified_user_outlined,
            title: 'Разрешения Android',
            subtitle: 'Проверить доступы телефона',
            onTap: onPermissionsTap,
          ),
          const SizedBox(height: 10),
          _ActionButton(
            icon: Icons.refresh_rounded,
            title: 'Обновить статус',
            subtitle: 'Перепроверить текущие параметры',
            onTap: onRefreshTap,
          ),
          const SizedBox(height: 10),
          _ActionButton(
            icon: Icons.link_off_rounded,
            title: 'Сбросить связку',
            subtitle: 'Отвязать этот рабочий телефон',
            isDanger: true,
            onTap: isSaving ? null : onResetPairing,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDanger;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDanger ? AppColors.danger : AppColors.primary;

    return Material(
      color: AppColors.background.withOpacity(0.38),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 21,
                ),
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
                        fontWeight: FontWeight.w800,
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
              Icon(
                Icons.chevron_right_rounded,
                color: color,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkerPairingCard extends StatelessWidget {
  final WorkerPairingQrPayload? payload;
  final bool isManualCodeVisible;
  final TextEditingController pairCodeController;
  final bool isSaving;
  final VoidCallback onToggleManualCode;
  final VoidCallback onConnect;

  const _WorkerPairingCard({
    required this.payload,
    required this.isManualCodeVisible,
    required this.pairCodeController,
    required this.isSaving,
    required this.onToggleManualCode,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final currentPayload = payload;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          const Icon(
            Icons.qr_code_2_rounded,
            color: AppColors.primary,
            size: 48,
          ),
          const SizedBox(height: 12),
          const Text(
            'Передача',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Покажите этот QR-код главному телефону для быстрой привязки.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.20),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: currentPayload == null
                  ? const SizedBox(
                width: 230,
                height: 230,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
                  : QrImageView(
                data: currentPayload.toQrValue(),
                version: QrVersions.auto,
                size: 230,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _ManualCodeButton(
            isExpanded: isManualCodeVisible,
            onTap: isSaving ? null : onToggleManualCode,
          ),
          if (isManualCodeVisible) ...[
            const SizedBox(height: 16),
            _ManualCodeForm(
              pairCodeController: pairCodeController,
              isSaving: isSaving,
              onConnect: onConnect,
            ),
          ],
        ],
      ),
    );
  }
}

class _ManualCodeButton extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback? onTap;

  const _ManualCodeButton({
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withOpacity(0.12),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.keyboard_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isExpanded ? 'Скрыть ручной ввод' : 'Ввести код вручную',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManualCodeForm extends StatelessWidget {
  final TextEditingController pairCodeController;
  final bool isSaving;
  final VoidCallback onConnect;

  const _ManualCodeForm({
    required this.pairCodeController,
    required this.isSaving,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Введите код, который показан на главном телефоне.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: pairCodeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 6,
          ),
          decoration: const InputDecoration(
            labelText: 'Код связки',
            hintText: '000000',
            border: OutlineInputBorder(),
            counterText: '',
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: isSaving ? null : onConnect,
          icon: const Icon(Icons.link_rounded),
          label: Text(
            isSaving ? 'Подключаю...' : 'Подключить телефон',
          ),
        ),
      ],
    );
  }
}

class _MessageCard extends StatelessWidget {
  final String message;

  const _MessageCard({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
        ),
      ),
    );
  }
}