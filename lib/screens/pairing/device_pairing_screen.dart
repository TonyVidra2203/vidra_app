import 'package:flutter/material.dart';

import '../../services/device_pairing_service.dart';

class DevicePairingScreen extends StatefulWidget {
  const DevicePairingScreen({super.key});

  @override
  State<DevicePairingScreen> createState() => _DevicePairingScreenState();
}

class _DevicePairingScreenState extends State<DevicePairingScreen> {
  final DevicePairingService _service = DevicePairingService();
  final TextEditingController _deviceNameController = TextEditingController();
  final TextEditingController _pairCodeController = TextEditingController();

  DevicePairingState _state = const DevicePairingState.empty();
  bool _isLoading = true;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _deviceNameController.dispose();
    _pairCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final state = await _service.loadState();

    if (!mounted) return;

    setState(() {
      _state = state;
      _isLoading = false;
    });
  }

  Future<void> _createMainPhoneCode() async {
    final state = await _service.createMainPhonePairCode(
      deviceName: _deviceNameController.text,
    );

    if (!mounted) return;

    setState(() {
      _state = state;
      _message = 'Код создан. Введите его на рабочем телефоне.';
    });
  }

  Future<void> _connectWorkerPhone() async {
    try {
      final state = await _service.connectWorkerPhone(
        deviceName: _deviceNameController.text,
        pairCode: _pairCodeController.text,
      );

      if (!mounted) return;

      setState(() {
        _state = state;
        _message = 'Рабочий телефон привязан.';
      });
    } on DevicePairingException catch (error) {
      setState(() {
        _message = error.message;
      });
    }
  }

  Future<void> _confirmWorkerPhone() async {
    final state = await _service.confirmWorkerPhone(
      workerDeviceName: 'Рабочий телефон',
    );

    if (!mounted) return;

    setState(() {
      _state = state;
      _message = 'Рабочий телефон подтверждён.';
    });
  }

  Future<void> _resetPairing() async {
    await _service.resetPairing();

    if (!mounted) return;

    setState(() {
      _state = const DevicePairingState.empty();
      _message = 'Связка сброшена.';
      _pairCodeController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
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
          _buildDeviceNameField(),
          const SizedBox(height: 16),
          if (_state.status == DevicePairingStatus.notPaired) ...[
            _buildRoleButtons(),
          ],
          if (_state.status == DevicePairingStatus.waitingForWorker) ...[
            _buildMainPhoneCodeCard(),
          ],
          if (_state.status == DevicePairingStatus.paired) ...[
            _buildPairedCard(),
          ],
          const SizedBox(height: 16),
          if (_message.isNotEmpty) _buildMessage(),
        ],
      ),
    );
  }

  Widget _buildIntroCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Выберите роль телефона.\n\n'
              'Главный телефон — получает сообщения и управляет настройками.\n'
              'Рабочий телефон — стоит там, где нужна пересылка SMS и PUSH.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }

  Widget _buildDeviceNameField() {
    return TextField(
      controller: _deviceNameController,
      decoration: const InputDecoration(
        labelText: 'Название этого телефона',
        hintText: 'Например: Магазин 1',
      ),
    );
  }

  Widget _buildRoleButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _createMainPhoneCode,
            child: const Text('Это главный телефон'),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pairCodeController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Код с главного телефона',
            hintText: 'Введите 6 цифр',
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _connectWorkerPhone,
            child: const Text('Это рабочий телефон'),
          ),
        ),
      ],
    );
  }

  Widget _buildMainPhoneCodeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Код для рабочего телефона'),
            const SizedBox(height: 12),
            SelectableText(
              _state.pairCode,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'Откройте VidRA на рабочем телефоне и введите этот код.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _confirmWorkerPhone,
                child: const Text('Я ввёл код на рабочем телефоне'),
              ),
            ),
            TextButton(
              onPressed: _resetPairing,
              child: const Text('Сбросить связку'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPairedCard() {
    final roleText = _state.isMainPhone ? 'Главный телефон' : 'Рабочий телефон';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.check_circle, size: 48),
            const SizedBox(height: 12),
            Text(
              'Телефон привязан',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('Роль: $roleText'),
            if (_state.pairedDeviceName.isNotEmpty)
              Text('Связан с: ${_state.pairedDeviceName}'),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _resetPairing,
              child: const Text('Сбросить связку'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage() {
    return Text(
      _message,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}