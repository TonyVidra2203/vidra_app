import 'package:flutter/material.dart';

import '../../services/device_pairing_service.dart';

class DevicePairingScreen extends StatefulWidget {
  const DevicePairingScreen({super.key});

  @override
  State<DevicePairingScreen> createState() => _DevicePairingScreenState();
}

class _DevicePairingScreenState extends State<DevicePairingScreen> {
  final DevicePairingService service = DevicePairingService();

  final TextEditingController deviceNameController = TextEditingController();
  final TextEditingController pairCodeController = TextEditingController();

  DevicePairingState state = const DevicePairingState.empty();

  bool isLoading = true;
  bool isSaving = false;
  String message = '';

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    deviceNameController.dispose();
    pairCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final loadedState = await service.loadState();

    if (!mounted) return;

    setState(() {
      state = loadedState;
      deviceNameController.text = loadedState.deviceName;
      isLoading = false;
    });
  }

  Future<void> _createMainPhoneCode() async {
    setState(() {
      isSaving = true;
      message = '';
    });

    final newState = await service.createMainPhonePairCode(
      deviceName: deviceNameController.text,
    );

    if (!mounted) return;

    setState(() {
      state = newState;
      isSaving = false;
      message = 'Код создан. Введите его на рабочем телефоне.';
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
        pairCode: pairCodeController.text,
      );

      if (!mounted) return;

      setState(() {
        state = newState;
        isSaving = false;
        message = 'Рабочий телефон привязан. SMS и PUSH будут отправляться автоматически.';
      });
    } on DevicePairingException catch (error) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
        message = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
        message = 'Не удалось привязать рабочий телефон.';
      });
    }
  }

  Future<void> _confirmWorkerPhone() async {
    setState(() {
      isSaving = true;
      message = '';
    });

    try {
      final newState = await service.confirmWorkerPhone(
        workerDeviceName: 'Рабочий телефон',
      );

      if (!mounted) return;

      setState(() {
        state = newState;
        isSaving = false;
        message = 'Связка подтверждена. Главный телефон готов получать события.';
      });
    } on DevicePairingException catch (error) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
        message = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
        message = 'Не удалось подтвердить связку.';
      });
    }
  }

  Future<void> _resetPairing() async {
    setState(() {
      isSaving = true;
      message = '';
    });

    await service.resetPairing();

    if (!mounted) return;

    setState(() {
      state = const DevicePairingState.empty();
      pairCodeController.clear();
      isSaving = false;
      message = 'Связка сброшена.';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Связка телефонов'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildIntroCard(),
          const SizedBox(height: 16),
          if (!state.isPaired) ...[
            _buildDeviceNameField(),
            const SizedBox(height: 16),
          ],
          if (state.status == DevicePairingStatus.notPaired) _buildRoleButtons(),
          if (state.status == DevicePairingStatus.waitingForWorker)
            _buildMainPhoneCodeCard(),
          if (state.status == DevicePairingStatus.paired) _buildPairedCard(),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildMessage(),
          ],
        ],
      ),
    );
  }

  Widget _buildIntroCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Свяжите два телефона один раз.\n\n'
              'Главный телефон показывает код.\n'
              'Рабочий телефон вводит этот код.\n\n'
              'После связки SMS и PUSH будут передаваться автоматически, без ручного ввода URL.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }

  Widget _buildDeviceNameField() {
    return TextField(
      controller: deviceNameController,
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(
        labelText: 'Название этого телефона',
        hintText: 'Например: Магазин 1',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildRoleButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: isSaving ? null : _createMainPhoneCode,
          icon: const Icon(Icons.phone_android),
          label: Text(isSaving ? 'Создаю код...' : 'Это главный телефон'),
        ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 20),
        TextField(
          controller: pairCodeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'Код с главного телефона',
            hintText: 'Введите 6 цифр',
            border: OutlineInputBorder(),
            counterText: '',
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: isSaving ? null : _connectWorkerPhone,
          icon: const Icon(Icons.send_to_mobile),
          label: Text(isSaving ? 'Привязываю...' : 'Это рабочий телефон'),
        ),
      ],
    );
  }

  Widget _buildMainPhoneCodeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(
              Icons.qr_code_2,
              size: 44,
            ),
            const SizedBox(height: 12),
            const Text(
              'Код для рабочего телефона',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            SelectableText(
              state.pairCode,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Откройте VidRA на рабочем телефоне, выберите “Это рабочий телефон” и введите этот код.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSaving ? null : _confirmWorkerPhone,
                child: Text(
                  isSaving ? 'Подтверждаю...' : 'Я ввёл код на рабочем телефоне',
                ),
              ),
            ),
            TextButton(
              onPressed: isSaving ? null : _resetPairing,
              child: const Text('Сбросить связку'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPairedCard() {
    final roleText = state.isMainPhone ? 'Главный телефон' : 'Рабочий телефон';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(
              Icons.check_circle,
              size: 52,
              color: Colors.green,
            ),
            const SizedBox(height: 12),
            Text(
              'Телефон привязан',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('Роль: $roleText'),
            if (state.pairCode.isNotEmpty) Text('Код связки: ${state.pairCode}'),
            if (state.pairedDeviceName.isNotEmpty)
              Text('Связан с: ${state.pairedDeviceName}'),
            const SizedBox(height: 14),
            const Text(
              'Теперь приложение использует скрытый канал передачи. Пользователю не нужно вводить Relay URL вручную.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            TextButton(
              onPressed: isSaving ? null : _resetPairing,
              child: const Text('Сбросить связку'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}