import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/message_model.dart';
import 'message_card.dart';

class MessageList extends StatelessWidget {
  final List<MessageModel> messages;

  const MessageList({
    super.key,
    required this.messages,
  });

  @override
  Widget build(BuildContext context) {
    final groupedMessages = _groupMessagesByDate(messages);
    if (messages.isEmpty) {
      return Center(
        child: Text(
          'Ничего не найдено',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 16,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: groupedMessages.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DateHeader(title: entry.key),
            ...entry.value.map((message) {
              return MessageCard(message: message);
            }),
          ],
        );
      }).toList(),
    );
  }

  Map<String, List<MessageModel>> _groupMessagesByDate(
      List<MessageModel> messages,
      ) {
    final Map<String, List<MessageModel>> grouped = {};

    for (final message in messages) {
      final key = _dateTitle(message.date);

      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }

      grouped[key]!.add(message);
    }

    return grouped;
  }

  String _dateTitle(DateTime date) {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(date.year, date.month, date.day);
    final difference = today.difference(messageDay).inDays;

    if (difference == 0) {
      return 'Сегодня';
    }

    if (difference == 1) {
      return 'Вчера';
    }

    return '${date.day}.${date.month}.${date.year}';
  }
}

class _DateHeader extends StatelessWidget {
  final String title;

  const _DateHeader({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 6),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}