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
  }

  @override
  void dispose() {
    _pairCodeController.dispose();
    super.dispose();
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
      message =
      'Связка сброшена. Теперь снова доступны вкладки Приём и Передача.';
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
              visibleModes: isWorkerPhonePaired
                  ? const [AppMode.sender]
                  : AppMode.values,
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
        _StatusCard(settings: currentSettings),
        const SizedBox(height: 14),
        _InfoCard(settings: currentSettings),
        const SizedBox(height: 14),
        _MenuButton(
          icon: Icons.settings_outlined,
          title: 'Настройки передачи',
          subtitle: 'SMS, PUSH, фон и интернет',
          onTap: () => _onNavTap(1),
        ),
        const SizedBox(height: 12),
        _MenuButton(
          icon: Icons.verified_user_outlined,
          title: 'Разрешения Android',
          subtitle: 'SMS, уведомления и работа в фоне',
          onTap: () => _onNavTap(2),
        ),
        const SizedBox(height: 12),
        _MenuButton(
          icon: Icons.link_off,
          title: 'Сбросить связку',
          subtitle: 'Вернуть телефон передачи к экрану привязки',
          onTap: isSaving ? () {} : _resetPairing,
        ),
        if (message.isNotEmpty) ...[
          const SizedBox(height: 14),
          _MessageCard(message: message),
        ],
      ],
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

class _StatusCard extends StatelessWidget {
  final SenderSettingsState settings;

  const _StatusCard({
    required this.settings,
  });

  bool get isReady {
    return settings.smsForwarding || settings.pushForwarding;
  }

  @override
  Widget build(BuildContext context) {
    final color = isReady ? AppColors.success : AppColors.warning;

    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.16),
            child: Icon(
              isReady ? Icons.send_to_mobile : Icons.pause_circle_outline,
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isReady ? 'Передача активна' : 'Передача выключена',
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Этот телефон отправляет SMS и PUSH на главный телефон.',
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

class _InfoCard extends StatelessWidget {
  final SenderSettingsState settings;

  const _InfoCard({
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          _StatusRow(
            title: 'SMS',
            value: settings.smsForwarding ? 'Включено' : 'Выключено',
            isActive: settings.smsForwarding,
          ),
          const SizedBox(height: 12),
          _StatusRow(
            title: 'PUSH',
            value: settings.pushForwarding ? 'Включено' : 'Выключено',
            isActive: settings.pushForwarding,
          ),
          const SizedBox(height: 12),
          _StatusRow(
            title: 'Фоновый режим',
            value: settings.backgroundMode ? 'Включён' : 'Выключен',
            isActive: settings.backgroundMode,
          ),
          const SizedBox(height: 12),
          _StatusRow(
            title: 'Интернет',
            value: settings.onlyWithInternet
                ? 'Только онлайн'
                : 'Без ограничения',
            isActive: !settings.onlyWithInternet,
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String title;
  final String value;
  final bool isActive;

  const _StatusRow({
    required this.title,
    required this.value,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.success : AppColors.textSecondary;

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
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
            const Icon(
              Icons.chevron_right,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
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