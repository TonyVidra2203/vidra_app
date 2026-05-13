import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/message_filter_model.dart';

class MessageFilterBar extends StatelessWidget {
  final MessageFilter selectedFilter;
  final ValueChanged<MessageFilter> onChanged;

  const MessageFilterBar({
    super.key,
    required this.selectedFilter,
    required this.onChanged,
  });

  static const List<MessageFilter> visibleFilters = [
    MessageFilter.all,
    MessageFilter.sms,
    MessageFilter.push,
  ];

  IconData _iconForFilter(MessageFilter filter) {
    switch (filter) {
      case MessageFilter.all:
        return Icons.all_inbox_outlined;
      case MessageFilter.sms:
        return Icons.sms_outlined;
      case MessageFilter.push:
        return Icons.notifications_none_rounded;
      case MessageFilter.errors:
        return Icons.error_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: AppColors.card.withOpacity(0.72),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: visibleFilters.map((filter) {
            final isSelected = filter == selectedFilter;

            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(filter),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary.withOpacity(0.45)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _iconForFilter(filter),
                        size: 18,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        filter.title,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}