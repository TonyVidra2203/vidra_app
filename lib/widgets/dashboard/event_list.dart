import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/event_model.dart';

class EventList extends StatelessWidget {
  final List<EventModel> events;

  const EventList({
    super.key,
    required this.events,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: events.map((event) {
        final color = _getColor(event.type);
        final textColor = _getTextColor(event.type);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(
                    _getIcon(event.type),
                    color: color,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      event.title,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: event.type == EventType.device
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  Text(
                    event.time,
                    style: TextStyle(
                      color: event.type == EventType.device
                          ? AppColors.success
                          : AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.cardBorder),
          ],
        );
      }).toList(),
    );
  }

  IconData _getIcon(EventType type) {
    switch (type) {
      case EventType.device:
        return Icons.phone_android;
      case EventType.sms:
        return Icons.sms_outlined;
      case EventType.push:
        return Icons.notifications_none;
      case EventType.error:
        return Icons.warning_amber_rounded;
      case EventType.warning:
        return Icons.info_outline;
    }
  }

  Color _getColor(EventType type) {
    switch (type) {
      case EventType.sms:
      case EventType.push:
        return AppColors.primary;
      case EventType.device:
        return AppColors.success;
      case EventType.error:
        return AppColors.danger;
      case EventType.warning:
        return AppColors.warning;
    }
  }

  Color _getTextColor(EventType type) {
    if (type == EventType.device) {
      return AppColors.success;
    }

    return AppColors.textPrimary;
  }
}