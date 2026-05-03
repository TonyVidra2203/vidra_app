import 'package:flutter/material.dart';

import '../../services/device_pairing_service.dart';

class DeviceStatusCard extends StatefulWidget {
  const DeviceStatusCard({super.key});

  @override
  State<DeviceStatusCard> createState() => _DeviceStatusCardState();
}

class _DeviceStatusCardState extends State<DeviceStatusCard> {
  final DevicePairingService _service = DevicePairingService();

  DevicePairingState _state = const DevicePairingState.empty();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = await _service.loadState();

    if (!mounted) return;

    setState(() {
      _state = state;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _buildIcon(),
            const SizedBox(width: 12),
            Expanded(
              child: _buildText(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    if (_state.status == DevicePairingStatus.notPaired) {
      return const Icon(Icons.device_unknown, size: 40);
    }

    if (_state.isMainPhone) {
      return const Icon(Icons.phone_android, size: 40);
    }

    return const Icon(Icons.sim_card, size: 40);
  }

  Widget _buildText(BuildContext context) {
    if (_state.status == DevicePairingStatus.notPaired) {
      return const Text('Телефон не привязан');
    }

    if (_state.isMainPhone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Главный телефон'),
          if (_state.pairedDeviceName.isNotEmpty)
            Text('Рабочий: ${_state.pairedDeviceName}'),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Рабочий телефон'),
        if (_state.pairedDeviceName.isNotEmpty)
          Text('Главный: ${_state.pairedDeviceName}'),
      ],
    );
  }
}