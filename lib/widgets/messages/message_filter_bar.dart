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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: MessageFilter.values.map((filter) {
          final isSelected = filter == selectedFilter;

          return GestureDetector(
            onTap: () => onChanged(filter),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.cardBorder,
                ),
              ),
              child: Text(
                filter.title,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.background
                      : AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}