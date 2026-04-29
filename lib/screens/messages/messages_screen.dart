import 'package:flutter/material.dart';
import '../../widgets/common/app_bottom_nav_bar.dart';
import '../../navigation/app_routes.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Сообщения'),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentRoute: AppRoutes.messages,
      ),
    );
  }
}