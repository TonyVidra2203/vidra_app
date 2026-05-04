import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/app_mode.dart';
import '../../navigation/app_routes.dart';
import '../../services/app_mode_service.dart';
import '../../widgets/common/app_bottom_nav_bar.dart';
import '../../widgets/common/mode_switch_header.dart';
import '../dashboard/dashboard_screen.dart';

class SenderStatusScreen extends StatefulWidget {
  const SenderStatusScreen({super.key});

  @override
  State<SenderStatusScreen> createState() => _SenderStatusScreenState();
}

class _SenderStatusScreenState extends State<SenderStatusScreen> {
  bool pushNotificationsEnabled = true;

  void _onModeChanged(AppMode mode) {
    if (mode == AppMode.sender) return;

    AppModeService.setMode(AppMode.receiver);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const DashboardScreen(),
      ),
    );
  }

  void _onPushNotificationsChanged(bool value) {
    setState(() {
      pushNotificationsEnabled = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ModeSwitchHeader(
              currentMode: AppMode.sender,
              onModeChanged: _onModeChanged,
              pushNotificationsEnabled: pushNotificationsEnabled,
              onPushNotificationsChanged: _onPushNotificationsChanged,
            ),
            const Expanded(
              child: Center(
                child: Text(
                  'Sender Mode Active',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const AppBottomNavBar(
              currentRoute: AppRoutes.dashboard,
            ),
          ],
        ),
      ),
    );
  }
}