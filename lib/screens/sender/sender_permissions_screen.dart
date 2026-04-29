import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../widgets/common/app_card.dart';
import 'sender_settings_screen.dart';
import 'sender_status_screen.dart';
import 'widgets/sender_bottom_nav_bar.dart';

class SenderPermissionsScreen extends StatefulWidget {
  const SenderPermissionsScreen({super.key});

  @override
  State<SenderPermissionsScreen> createState() =>
      _SenderPermissionsScreenState();
}

class _SenderPermissionsScreenState extends State<SenderPermissionsScreen> {
  bool smsPermission = true;
  bool notificationPermission = false;
  bool backgroundPermission = true;

  void _onNavTap(BuildContext context, int index) {
    if (index == 2) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) {
          if (index == 0) {
            return const SenderStatusScreen();
          }
          return const SenderSettingsScreen();
        },
      ),
    );
  }

  void _requestPermission(String type) {
    setState(() {
      if (type == 'sms') smsPermission = true;
      if (type == 'notification') notificationPermission = true;
      if (type == 'background') backgroundPermission = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Разрешение "$type" выдано (заглушка)'),
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
                children: [
                  _PermissionCard(
                    title: 'SMS',
                    subtitle: 'Доступ к входящим SMS',
                    granted: smsPermission,
                    onTap: () => _requestPermission('sms'),
                  ),
                  const SizedBox(height: 14),
                  _PermissionCard(
                    title: 'Уведомления',
                    subtitle: 'Доступ к PUSH-уведомлениям',
                    granted: notificationPermission,
                    onTap: () => _requestPermission('notification'),
                  ),
                  const SizedBox(height: 14),
                  _PermissionCard(
                    title: 'Фоновая работа',
                    subtitle: 'Работа приложения в фоне',
                    granted: backgroundPermission,
                    onTap: () => _requestPermission('background'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SenderBottomNavBar(
        currentIndex: 2,
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
          'Разрешения',
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

class _PermissionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool granted;
  final VoidCallback onTap;

  const _PermissionCard({
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Icon(
            granted ? Icons.check_circle : Icons.error_outline,
            color: granted ? AppColors.success : AppColors.warning,
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
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          granted
              ? const Text(
            'Разрешено',
            style: TextStyle(
              color: AppColors.success,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          )
              : TextButton(
            onPressed: onTap,
            child: const Text('Выдать'),
          ),
        ],
      ),
    );
  }
}