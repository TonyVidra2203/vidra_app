import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../services/device_pairing_service.dart';

class DevicePairingScreenArguments {
  final bool openScannerOnStart;

  const DevicePairingScreenArguments({
    this.openScannerOnStart = false,
  });
}

class DevicePairingScreen extends StatefulWidget {
  const DevicePairingScreen({super.key});

  @override
  State<DevicePairingScreen> createState() => _DevicePairingScreenState();
}

class _DevicePairingScreenState extends State<DevicePairingScreen> {
  final DevicePairingService service = DevicePairingService();
  final TextEditingController deviceNameController = TextEditingController();
  final TextEditingController phoneNumberController = TextEditingController();
  final TextEditingController pairCodeController = TextEditingController();

  DevicePairingState state = const DevicePairingState.empty();
  WorkerPairingQrPayload? workerQrPayload;

  Timer? remoteUnpairTimer;

  bool isLoading = true;
  bool isSaving = false;
  bool isManualCodeVisible = false;

  String message = '';

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    remoteUnpairTimer?.cancel();
    deviceNameController.dispose();
    phoneNumberController.dispose();
    pairCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final loadedState = await service.loadState();

    if (!mounted) {
      return;
    }

    deviceNameController.text = loadedState.deviceName.trim().isEmpty
        ? 'Рабочий телефон'
        : loadedState.deviceName;
    phoneNumberController.text = loadedState.phoneNumber;

    setState(() {
      state = loadedState;
      isLoading = false;
    });

    _updateRemoteUnpairWatcher(loadedState);

    if (!loadedState.isPaired) {
      await _refreshWorkerQrPayload();
    }
  }

  Future<void> _refreshWorkerQrPayload() async {
    final payload = await service.createWorkerQrPayload(
      deviceName: deviceNameController.text,
      phoneNumber: phoneNumberController.text,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      workerQrPayload = payload;
    });
  }

  Future<void> _connectWorkerPhone() async {
    setState(() {
      isSaving = true;
      message = '';
    });

    try {
      final newState = await service.connectWorkerPhone(
        deviceName: deviceNameController.text,
        phoneNumber: phoneNumberController.text,
        pairCode: pairCodeController.text,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        state = newState;
        isSaving = false;
        message = 'Телефон подключён.\n'
            'SMS и PUSH будут передаваться на главный телефон.';
      });

      _updateRemoteUnpairWatcher(newState);
    } on DevicePairingException catch (error) {
      _setError(error.message);
    } catch (_) {
      _setError('Не удалось подключить телефон.');
    }
  }

  Future<void> _resetPairing() async {
    setState(() {
      isSaving = true;
      message = '';
    });

    await service.resetPairing();

    if (!mounted) {
      return;
    }

    setState(() {
      state = const DevicePairingState.empty();
      pairCodeController.clear();
      isManualCodeVisible = false;
      isSaving = false;
      message = 'Связка сброшена.';
    });

    _updateRemoteUnpairWatcher(state);
    await _refreshWorkerQrPayload();
  }

  void _updateRemoteUnpairWatcher(DevicePairingState currentState) {
    remoteUnpairTimer?.cancel();
    remoteUnpairTimer = null;

    if (!currentState.isPaired) {
      return;
    }

    remoteUnpairTimer = Timer.periodic(
      const Duration(seconds: 2),
          (_) => _syncRemoteUnpair(),
    );
  }

  Future<void> _syncRemoteUnpair() async {
    if (isSaving || !state.isPaired) {
      return;
    }

    final syncedState = await service.syncRemoteUnpair();

    if (!mounted) {
      return;
    }

    if (syncedState.isPaired) {
      setState(() {
        state = syncedState;
      });
      return;
    }

    setState(() {
      state = const DevicePairingState.empty();
      pairCodeController.clear();
      isManualCodeVisible = false;
      message = 'Главный телефон сбросил связку. '
          'Этот телефон возвращён в режим подключения.';
    });

    _updateRemoteUnpairWatcher(state);
    await _refreshWorkerQrPayload();
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
    if (isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Передача'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        actions: [
          if (state.isPaired)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                onPressed: isSaving ? null : _resetPairing,
                tooltip: 'Разъединить устройства',
                icon: const Icon(Icons.link_off_rounded),
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (state.isPaired) _buildConnectedCard() else _buildPairingCard(),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildMessage(),
          ],
        ],
      ),
    );
  }

  Widget _buildPairingCard() {
    return Card(
      color: AppColors.card,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.qr_code_2,
              size: 48,
              color: AppColors.primary,
            ),
            const SizedBox(height: 12),
            const Text(
              'Подключение телефона передачи',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Покажите этот QR-код главному телефону.\n'
                  'После сканирования главный телефон создаст код связки.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 18),
            _buildDeviceFields(),
            const SizedBox(height: 18),
            _buildQrCode(),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: isSaving
                  ? null
                  : () {
                setState(() {
                  isManualCodeVisible = !isManualCodeVisible;
                });
              },
              icon: const Icon(Icons.keyboard),
              label: Text(
                isManualCodeVisible ? 'Скрыть ввод кода' : 'Ввести код',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
              ),
            ),
            if (isManualCodeVisible) ...[
              const SizedBox(height: 16),
              _buildManualCodeForm(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceFields() {
    return Column(
      children: [
        TextField(
          controller: deviceNameController,
          textInputAction: TextInputAction.next,
          style: const TextStyle(color: AppColors.textPrimary),
          onChanged: (_) => _refreshWorkerQrPayload(),
          decoration: const InputDecoration(
            labelText: 'Название телефона',
            hintText: 'Например: Redmi Note 11',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: phoneNumberController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          style: const TextStyle(color: AppColors.textPrimary),
          onChanged: (_) => _refreshWorkerQrPayload(),
          decoration: const InputDecoration(
            labelText: 'Номер телефона',
            hintText: '+7 999 123-45-67',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildQrCode() {
    final payload = workerQrPayload;

    if (payload == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: QrImageView(
          data: payload.toQrValue(),
          version: QrVersions.auto,
          size: 230,
        ),
      ),
    );
  }

  Widget _buildManualCodeForm() {
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
          onPressed: isSaving ? null : _connectWorkerPhone,
          icon: const Icon(Icons.link),
          label: Text(isSaving ? 'Подключаю...' : 'Подключить телефон'),
        ),
      ],
    );
  }

  Widget _buildConnectedCard() {
    return Card(
      color: AppColors.card,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(
              Icons.check_circle,
              size: 56,
              color: AppColors.success,
            ),
            const SizedBox(height: 12),
            const Text(
              'Телефон передачи подключён',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _InfoRow(
              title: 'Название',
              value: state.deviceName.trim().isEmpty
                  ? 'Рабочий телефон'
                  : state.deviceName,
            ),
            const SizedBox(height: 8),
            _InfoRow(
              title: 'Номер',
              value: state.phoneNumber.trim().isEmpty
                  ? 'Не указан'
                  : state.phoneNumber,
            ),
            const SizedBox(height: 8),
            _InfoRow(
              title: 'Код связки',
              value: state.pairCode,
            ),
            const SizedBox(height: 16),
            const Text(
              'Теперь SMS и PUSH с этого телефона будут отправляться '
                  'на главный телефон через сервер VidRA.',
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

  Widget _buildMessage() {
    return Card(
      color: AppColors.card,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String title;
  final String value;

  const _InfoRow({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$title: ',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}