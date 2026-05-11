import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/app_mode.dart';
import '../../services/app_mode_service.dart';
import '../dashboard/dashboard_screen.dart';
import '../sender/sender_status_screen.dart';

class ModeSelectionScreen extends StatefulWidget {
  const ModeSelectionScreen({super.key});

  @override
  State<ModeSelectionScreen> createState() => _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends State<ModeSelectionScreen> {
  bool isLoading = true;
  AppMode? activatedMode;

  @override
  void initState() {
    super.initState();
    _loadActivatedMode();
  }

  Future<void> _loadActivatedMode() async {
    await AppModeService.ensureInitialized();

    if (!mounted) {
      return;
    }

    setState(() {
      activatedMode = AppModeService.activatedMode;
      isLoading = false;
    });
  }

  Future<void> _selectMode(AppMode mode) async {
    final canActivate = await AppModeService.activateMode(mode);

    if (!mounted) {
      return;
    }

    if (!canActivate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Этот телефон уже активирован как "${activatedMode?.title}".',
          ),
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) {
          if (mode == AppMode.sender) {
            return const SenderStatusScreen();
          }

          return const DashboardScreen();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final receiverEnabled = activatedMode == null ||
        activatedMode == AppMode.receiver;
    final senderEnabled = activatedMode == null || activatedMode == AppMode.sender;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: isLoading
              ? const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          )
              : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              const Text(
                'Выберите режим',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                activatedMode == null
                    ? 'Укажите, как будет работать это устройство'
                    : 'Этот телефон уже активирован как "${activatedMode!.title}"',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 32),
              _ModeCard(
                icon: Icons.phone_android,
                title: AppMode.receiver.title,
                subtitle: receiverEnabled
                    ? AppMode.receiver.subtitle
                    : 'Недоступно: телефон уже работает в режиме передачи',
                enabled: receiverEnabled,
                onTap: () => _selectMode(AppMode.receiver),
              ),
              const SizedBox(height: 14),
              _ModeCard(
                icon: Icons.send_to_mobile,
                title: AppMode.sender.title,
                subtitle: senderEnabled
                    ? AppMode.sender.subtitle
                    : 'Недоступно: телефон уже работает в режиме приёма',
                enabled: senderEnabled,
                onTap: () => _selectMode(AppMode.sender),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final contentColor =
    enabled ? AppColors.textPrimary : AppColors.textSecondary;
    final iconColor = enabled ? AppColors.primary : AppColors.textSecondary;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 34),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: contentColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                enabled ? Icons.chevron_right : Icons.lock_outline,
                color: iconColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}