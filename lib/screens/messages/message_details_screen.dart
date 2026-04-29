import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/message_model.dart';

class MessageDetailsScreen extends StatelessWidget {
  final MessageModel message;

  const MessageDetailsScreen({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isError = message.status == MessageStatus.error;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        iconTheme: const IconThemeData(color: AppColors.primary),
        title: const Text(
          'Детали сообщения',
          style: TextStyle(color: AppColors.textPrimary),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isError ? AppColors.danger : AppColors.cardBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.sender,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                message.text,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),

              const Spacer(),

              Row(
                children: [
                  Text(
                    message.deviceName,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const Spacer(),
                  Text(
                    message.time,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}