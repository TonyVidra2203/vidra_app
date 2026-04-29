import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../widgets/common/app_card.dart';
import 'widgets/sender_bottom_nav_bar.dart';
import 'sender_settings_screen.dart';
import 'sender_permissions_screen.dart';

class SenderStatusScreen extends StatelessWidget {
  const SenderStatusScreen({super.key});

  void _onNavTap(BuildContext context, int index) {
    if (index == 0) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) {
          if (index == 1) {
            return const SenderSettingsScreen();
          } else {
            return const SenderPermissionsScreen();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const _Header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  _ConnectionCard(),
                  SizedBox(height: 16),
                  _DeviceInfoCard(),
                  SizedBox(height: 16),
                  _ServiceCard(),
                  SizedBox(height: 16),
                  _QuickStatsCard(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SenderBottomNavBar(
        currentIndex: 0,
        onTap: (index) => _onNavTap(context, index),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(18, 14, 18, 8),
      child: Center(
        child: Text(
          'Статус устройства',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: const [
          CircleAvatar(
            backgroundColor: Color(0xFF173B24),
            child: Icon(Icons.phone_android, color: AppColors.success),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Подключено',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Устройство отправляет данные на главный телефон',
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

class _DeviceInfoCard extends StatelessWidget {
  const _DeviceInfoCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: const [
          _InfoRow(title: 'Имя устройства', value: 'Redmi Note 11'),
          SizedBox(height: 12),
          _InfoRow(title: 'Аккаунт', value: 'user@example.com'),
          SizedBox(height: 12),
          _InfoRow(title: 'Последнее соединение', value: '25.05.2025 10:45'),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Сервис',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(
                child: Text(
                  'Работает\nСервис запущен и работает в фоне',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
              Icon(Icons.check_circle, color: AppColors.success),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              onPressed: null,
              child: Text('Остановить'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStatsCard extends StatelessWidget {
  const _QuickStatsCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Быстрая статистика',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 14),
          Row(
            children: [
              _StatBox(title: 'SMS сегодня', value: '248'),
              SizedBox(width: 10),
              _StatBox(title: 'PUSH сегодня', value: '156'),
              SizedBox(width: 10),
              _StatBox(title: 'Ошибки', value: '2', isError: true),
            ],
          ),
        ],
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
          title,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String title;
  final String value;
  final bool isError;

  const _StatBox({
    required this.title,
    required this.value,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 74,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                color: isError ? AppColors.danger : AppColors.primary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}