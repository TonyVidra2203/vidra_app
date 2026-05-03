import 'package:flutter/material.dart';

import '../../navigation/app_routes.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle(context, 'Устройства'),
          const SizedBox(height: 8),
          _buildPairingTile(context),
          const SizedBox(height: 24),
          _buildSectionTitle(context, 'Прочее'),
          const SizedBox(height: 8),
          _buildAboutTile(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium,
    );
  }

  Widget _buildPairingTile(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.devices),
        title: const Text('Связка телефонов'),
        subtitle: const Text('Главный и рабочий телефон'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.pushNamed(context, AppRoutes.devicePairing);
        },
      ),
    );
  }

  Widget _buildAboutTile() {
    return const Card(
      child: ListTile(
        leading: Icon(Icons.info_outline),
        title: Text('О приложении'),
        subtitle: Text('VidRA SMS & PUSH Forwarder'),
      ),
    );
  }
}