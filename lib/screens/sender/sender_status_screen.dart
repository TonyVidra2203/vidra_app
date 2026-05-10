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

  final TextEditingController _deviceNameController = TextEditingController(
    text: 'Рабочий телефон',
  );
  final TextEditingController _pairCodeController = TextEditingController();

  SenderSettingsState? settings;
  DevicePairingState pairingState = const DevicePairingState.empty();
  WorkerPairingQrPayload? workerQrPayload;

  bool pushNotificationsEnabled = true;
  bool isLoading = true;
  bool isSaving = false;
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
    _deviceNameController.dispose();
    _pairCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final loadedSettings = await _settingsService.load();
    final loadedPairingState = await _pairingService.loadState();

    WorkerPairingQrPayload? qrPayload;
    if (!loadedPairingState.isPaired) {
      qrPayload = await _pairingService.createWorkerQrPayload(
        deviceName: loadedSettings.deviceName,
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      settings = loadedSettings;
      pairingState = loadedPairingState;
      workerQrPayload = qrPayload;
      pushNotificationsEnabled = loadedSettings.pushForwarding;
      _deviceNameController.text = loadedSettings.deviceName.trim().isEmpty
          ? 'Рабочий телефон'
          : loadedSettings.deviceName.trim();
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

  Future<void> _refreshWorkerQr() async {
    final payload = await _pairingService.createWorkerQrPayload(
      deviceName: _deviceNameController.text,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      workerQrPayload = payload;
      message = 'QR-код обновлён.';
    });
  }

  Future<void> _connectByManualCode() async {
    setState(() {
      isSaving = true;
      message = '';
    });

    try {
      final newState = await _pairingService.connectWorkerPhone(
        deviceName: _deviceNameController.text,
        pairCode: _pairCodeController.text,
      );

      final loadedSettings = await _settingsService.load();

      if (!mounted) {
        return;
      }

      setState(() {
        pairingState = newState;
        settings = loadedSettings;
        pushNotificationsEnabled = loadedSettings.pushForwarding;
        isSaving = false;
        message = 'Рабочий телефон привязан. Теперь доступно меню передачи.';
      });
    } on DevicePairingException catch (error) {
      _setError(error.message);
    } catch (_) {
      _setError('Не удалось привязать рабочий телефон.');
    }
  }

  Future<void> _resetPairing() async {
    setState(() {
      isSaving = true;
      message = '';
    });

    await _pairingService.resetPairing();

    final loadedSettings = await _settingsService.load();
    final payload = await _pairingService.createWorkerQrPayload(
      deviceName: loadedSettings.deviceName,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      settings = loadedSettings;
      pairingState = const DevicePairingState.empty();
      workerQrPayload = payload;
      _pairCodeController.clear();
      isSaving = false;
      message = 'Связка сброшена.';
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
        _WorkerPairingIntroCard(
          deviceNameController: _deviceNameController,
        ),
        const SizedBox(height: 14),
        _WorkerQrCard(
          payload: workerQrPayload,
          onRefresh: isSaving ? null : _refreshWorkerQr,
        ),
        const SizedBox(height: 14),
        _ManualPairingCard(
          pairCodeController: _pairCodeController,
          isSaving: isSaving,
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
          subtitle: 'Вернуть рабочий телефон к экрану привязки',
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

class _WorkerPairingIntroCard extends StatelessWidget {
  final TextEditingController deviceNameController;

  const _WorkerPairingIntroCard({
    required this.deviceNameController,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.send_to_mobile,
                color: AppColors.primary,
                size: 30,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Связка рабочего телефона',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Покажите QR-код главному телефону. На главном телефоне нажмите “+ добавить” и отсканируйте этот код.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: deviceNameController,
            textInputAction: TextInputAction.done,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Название этого рабочего телефона',
              hintText: 'Например: Рабочий телефон 1',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkerQrCard extends StatelessWidget {
  final WorkerPairingQrPayload? payload;
  final VoidCallback? onRefresh;

  const _WorkerQrCard({
    required this.payload,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final currentPayload = payload;

    return AppCard(
      child: Column(
        children: [
          const Text(
            'QR-код для главного телефона',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: currentPayload == null
                ? const SizedBox(
              width: 210,
              height: 210,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
                : QrImageView(
              data: currentPayload.toQrValue(),
              version: QrVersions.auto,
              size: 210,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'После сканирования главный телефон создаст код связки. Если камера недоступна — используйте ручной ввод ниже.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Обновить QR-код'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualPairingCard extends StatelessWidget {
  final TextEditingController pairCodeController;
  final bool isSaving;
  final VoidCallback onConnect;

  const _ManualPairingCard({
    required this.pairCodeController,
    required this.isSaving,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Запасной вариант',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Введите код, который сгенерировал главный телефон. Адрес сервера подставляется автоматически.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: pairCodeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Код с главного телефона',
              hintText: 'Введите 6 цифр',
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: isSaving ? null : onConnect,
            icon: const Icon(Icons.link),
            label: Text(
              isSaving ? 'Привязываю...' : 'Привязать рабочий телефон',
            ),
          ),
        ],
      ),
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
            value: settings.onlyWithInternet ? 'Только онлайн' : 'Без ограничения',
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