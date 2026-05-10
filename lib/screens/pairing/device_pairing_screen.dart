import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../navigation/app_routes.dart';
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
  final TextEditingController pairCodeController = TextEditingController();

  DevicePairingState state = const DevicePairingState.empty();

  bool isLoading = true;
  bool isSaving = false;
  bool didHandleArguments = false;
  String message = '';

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (didHandleArguments) {
      return;
    }

    didHandleArguments = true;

    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is DevicePairingScreenArguments && arguments.openScannerOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _openPairingOptions();
        }
      });
    }
  }

  @override
  void dispose() {
    deviceNameController.dispose();
    pairCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final loadedState = await service.loadState();

    if (!mounted) {
      return;
    }

    setState(() {
      state = loadedState;
      deviceNameController.text = loadedState.deviceName.trim().isEmpty
          ? 'Главный телефон'
          : loadedState.deviceName;
      isLoading = false;
    });
  }

  Future<void> _openPairingOptions() async {
    final action = await showModalBottomSheet<_PairingAction>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
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
                  'Отсканируйте QR-код с рабочего телефона. Если камеры нет — сгенерируйте код вручную.',
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
      await _scanQrCode();
      return;
    }

    await _createMainPhoneCode();
  }

  Future<void> _scanQrCode() async {
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

    setState(() {
      message = 'Это не QR-код рабочего телефона VidRA.';
    });
  }

  Future<void> _createMainPhoneCode({
    String pairedDeviceName = '',
  }) async {
    setState(() {
      isSaving = true;
      message = '';
    });

    try {
      final newState = await service.createMainPhonePairCode(
        deviceName: deviceNameController.text,
        pairedDeviceName: pairedDeviceName,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        state = newState;
        isSaving = false;
        message = pairedDeviceName.trim().isEmpty
            ? 'Код создан. Введите его на рабочем телефоне.'
            : 'QR-код рабочего телефона считан. Код связки создан.';
      });
    } on DevicePairingException catch (error) {
      _setError(error.message);
    } catch (_) {
      _setError('Не удалось создать код связки.');
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
      );

      if (!mounted) {
        return;
      }

      setState(() {
        state = newState;
        isSaving = false;
        message = 'Рабочий телефон привязан. SMS и PUSH будут отправляться на сервер.';
      });
    } on DevicePairingException catch (error) {
      _setError(error.message);
    } catch (_) {
      _setError('Не удалось привязать рабочий телефон.');
    }
  }

  Future<void> _confirmWorkerPhone() async {
    setState(() {
      isSaving = true;
      message = '';
    });

    try {
      final newState = await service.confirmWorkerPhone();

      if (!mounted) {
        return;
      }

      setState(() {
        state = newState;
        isSaving = false;
        message = 'Связка подтверждена. Главный телефон будет получать события с сервера.';
      });
    } on DevicePairingException catch (error) {
      _setError(error.message);
    } catch (_) {
      _setError('Не удалось подтвердить связку.');
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
        title: const Text('Связка телефонов'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            onPressed: isSaving ? null : _openPairingOptions,
            icon: const Icon(Icons.add_link),
            tooltip: 'Добавить устройство',
          ),
        ],
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
      color: AppColors.card,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Свяжите главный и рабочий телефон через VidRA.\n\n'
              'Главный телефон нажимает “+ добавить” и сканирует QR-код с рабочего телефона.\n\n'
              'Если камеры нет — главный телефон генерирует код, а рабочий телефон вводит его вручную.\n\n'
              'Сервер используется автоматически: ${DevicePairingService.defaultServerUrl}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceNameField() {
    return TextField(
      controller: deviceNameController,
      textInputAction: TextInputAction.done,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: const InputDecoration(
        labelText: 'Название этого телефона',
        hintText: 'Например: Главный телефон',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildRoleButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: isSaving ? null : _openPairingOptions,
          icon: const Icon(Icons.add),
          label: Text(isSaving ? 'Создаю...' : '+ Добавить рабочий телефон'),
        ),
        const SizedBox(height: 20),
        const Divider(color: AppColors.cardBorder),
        const SizedBox(height: 20),
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
    final qrPayload = service.createQrPayload(state);

    return Card(
      color: AppColors.card,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(
              Icons.qr_code_2,
              size: 44,
              color: AppColors.primary,
            ),
            const SizedBox(height: 12),
            const Text(
              'Код связки для рабочего телефона',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: QrImageView(
                data: qrPayload.toQrValue(),
                version: QrVersions.auto,
                size: 210,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Введите этот код на рабочем телефоне во вкладке “Передача”.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Код для ручного ввода',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            SelectableText(
              state.pairCode,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: 12),
            const SelectableText(
              DevicePairingService.defaultServerUrl,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSaving ? null : _confirmWorkerPhone,
                child: Text(
                  isSaving ? 'Проверяю...' : 'Рабочий телефон подключён',
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
      color: AppColors.card,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(
              Icons.check_circle,
              size: 52,
              color: AppColors.success,
            ),
            const SizedBox(height: 12),
            Text(
              'Телефон привязан',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Роль: $roleText',
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            if (state.pairCode.isNotEmpty)
              Text(
                'Код связки: ${state.pairCode}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            if (state.pairedDeviceName.isNotEmpty)
              Text(
                'Связан с: ${state.pairedDeviceName}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            const SizedBox(height: 8),
            const SelectableText(
              'Сервер: ${DevicePairingService.defaultServerUrl}',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 14),
            Text(
              state.isMainPhone
                  ? 'Главный телефон будет получать события с сервера в разделе “Сообщения”.'
                  : 'Рабочий телефон будет отправлять SMS и PUSH на сервер.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
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