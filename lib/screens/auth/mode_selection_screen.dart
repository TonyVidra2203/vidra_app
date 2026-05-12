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
  bool isSelecting = false;

  Future<void> _selectMode(AppMode mode) async {
    if (isSelecting) {
      return;
    }

    setState(() {
      isSelecting = true;
    });

    final activated = await AppModeService.activateMode(mode);

    if (!mounted) {
      return;
    }

    if (!activated) {
      setState(() {
        isSelecting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Этот телефон уже активирован как '
                '"${AppModeService.activatedMode?.title ?? 'другой режим'}".',
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
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
              const Text(
                'Укажите, как будет работать это устройство',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 32),
              _ModeCard(
                icon: Icons.phone_android,
                title: AppMode.receiver.title,
                subtitle: AppMode.receiver.subtitle,
                isDisabled: isSelecting,
                onTap: () => _selectMode(AppMode.receiver),
              ),
              const SizedBox(height: 14),
              _ModeCard(
                icon: Icons.send_to_mobile,
                title: AppMode.sender.title,
                subtitle: AppMode.sender.subtitle,
                isDisabled: isSelecting,
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
  final bool isDisabled;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDisabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isDisabled ? 0.65 : 1,
      child: GestureDetector(
        onTap: isDisabled ? null : onTap,
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
              Icon(icon, color: AppColors.primary, size: 34),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
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
              const Icon(Icons.chevron_right, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}