import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/message_model.dart';

class MessageCard extends StatefulWidget {
  final MessageModel message;

  const MessageCard({
    super.key,
    required this.message,
  });

  @override
  State<MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<MessageCard> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isError = message.status == MessageStatus.error;

    return GestureDetector(
      onTap: () {
        setState(() {
          isExpanded = !isExpanded;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isError ? AppColors.danger : AppColors.cardBorder,
          ),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  message.type == MessageType.sms
                      ? Icons.sms_outlined
                      : Icons.notifications_none,
                  color: isError ? AppColors.danger : AppColors.primary,
                  size: 28,
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.sender,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        message.text,
                        maxLines: isExpanded ? null : 2,
                        overflow: isExpanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Text(
                            message.deviceName,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            message.time,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppColors.primary,
                ),
              ],
            ),

            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: _MessageDetails(message: message),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageDetails extends StatelessWidget {
  final MessageModel message;

  const _MessageDetails({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 14),
        const Divider(color: AppColors.cardBorder),
        const SizedBox(height: 10),

        _DetailRow(
          title: 'Тип',
          value: message.type == MessageType.sms ? 'SMS' : 'PUSH',
        ),

        const SizedBox(height: 8),

        _DetailRow(
          title: 'Статус',
          value: _statusText(message.status),
        ),

        const SizedBox(height: 8),

        _DetailRow(
          title: 'Устройство',
          value: message.deviceName,
        ),

        const SizedBox(height: 8),

        _DetailRow(
          title: 'Время',
          value: message.time,
        ),
        if (message.text.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Сообщение',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              message.text,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                height: 1.35,
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _statusText(MessageStatus status) {
    switch (status) {
      case MessageStatus.received:
        return 'Получено';
      case MessageStatus.sent:
        return 'Отправлено';
      case MessageStatus.error:
        return 'Ошибка';
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String title;
  final String value;

  const _DetailRow({
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
            fontSize: 13,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}