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
  final TextEditingController serverUrlController = TextEditingController();

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
    serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final loadedState = await service.loadState();

    if (!mounted) return;

    setState(() {
      state = loadedState;
      deviceNameController.text = loadedState.deviceName;
      serverUrlController.text = _extractServerUrl(loadedState.relayUrl);
      isLoading = false;
    });
  }

  Future<void> _createMainPhoneCode() async {
    setState(() {
      isSaving = true;
      message = '';
    });

    try {
      final newState = await service.createMainPhonePairCode(
        deviceName: deviceNameController.text,
        serverUrl: serverUrlController.text,
      );

      if (!mounted) return;

      setState(() {
        state = newState;
        serverUrlController.text = _extractServerUrl(newState.relayUrl);
        isSaving = false;
        message = 'Код создан.\nВведите этот же сервер и код на рабочем телефоне.';
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
        message = 'Не удалось создать код связки.';
      });
    }
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
        serverUrl: serverUrlController.text,
      );

      if (!mounted) return;

      setState(() {
        state = newState;
        serverUrlController.text = _extractServerUrl(newState.relayUrl);
        isSaving = false;
        message = 'Рабочий телефон привязан.\nSMS и PUSH будут отправляться на сервер.';
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
        message = 'Связка подтверждена.\nГлавный телефон будет получать события с сервера.';
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
            _buildServerUrlField(),
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
          'Свяжите два телефона через ваш VidRA сервер.\n\n'
              '1. На главном телефоне введите адрес сервера и создайте код.\n'
              '2. На рабочем телефоне введите тот же адрес сервера и этот код.\n'
              '3. Рабочий телефон будет отправлять SMS/PUSH на сервер.\n'
              '4. Главный телефон будет забирать события с сервера.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }

  Widget _buildDeviceNameField() {
    return TextField(
      controller: deviceNameController,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: 'Название этого телефона',
        hintText: 'Например: Магазин 1',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildServerUrlField() {
    return TextField(
      controller: serverUrlController,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(
        labelText: 'Адрес сервера',
        hintText: 'https://your-domain.com',
        helperText: 'Одинаковый адрес на главном и рабочем телефоне',
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
            SelectableText(
              _extractServerUrl(state.relayUrl),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'На рабочем телефоне введите этот же адрес сервера и этот код.',
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
            if (state.relayUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              SelectableText(
                'Сервер: ${_extractServerUrl(state.relayUrl)}',
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 14),
            Text(
              state.isMainPhone
                  ? 'Главный телефон будет получать события с сервера в разделе “Сообщения”.'
                  : 'Рабочий телефон будет отправлять SMS и PUSH на сервер.',
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

  String _extractServerUrl(String relayUrl) {
    final cleaned = relayUrl.trim();

    if (cleaned.isEmpty) {
      return '';
    }

    const marker = '/events/';

    if (!cleaned.contains(marker)) {
      return cleaned;
    }

    return cleaned.split(marker).first;
  }
}