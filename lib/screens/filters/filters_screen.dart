import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../navigation/app_routes.dart';
import '../../widgets/common/app_bottom_nav_bar.dart';
import '../../widgets/common/app_card.dart';

class FiltersScreen extends StatefulWidget {
  const FiltersScreen({super.key});

  @override
  State<FiltersScreen> createState() => _FiltersScreenState();
}

class _FiltersScreenState extends State<FiltersScreen> {
  final List<_FilterItemData> filters = [
    _FilterItemData(
      icon: Icons.verified_user_outlined,
      title: 'Коды подтверждения',
      subtitle: 'Включены',
      enabled: true,
    ),
    _FilterItemData(
      icon: Icons.account_balance_outlined,
      title: 'Банковские сообщения',
      subtitle: 'Включены',
      enabled: true,
    ),
    _FilterItemData(
      icon: Icons.sms_outlined,
      title: 'Рекламные SMS',
      subtitle: 'Отключены',
      enabled: false,
    ),
    _FilterItemData(
      icon: Icons.public_outlined,
      title: 'Международные номера',
      subtitle: 'Включены',
      enabled: true,
    ),
    _FilterItemData(
      icon: Icons.block_outlined,
      title: 'Крипто-спам',
      subtitle: 'Отключены',
      enabled: false,
    ),
    _FilterItemData(
      icon: Icons.visibility_off_outlined,
      title: 'Черный список',
      subtitle: 'Включены',
      enabled: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const _Header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppCard(
                    child: Column(
                      children: [
                        for (int i = 0; i < filters.length; i++) ...[
                          _FilterItem(
                            data: filters[i],
                            onChanged: (value) {
                              setState(() {
                                filters[i] = filters[i].copyWith(
                                  enabled: value,
                                  subtitle:
                                  value ? 'Включены' : 'Отключены',
                                );
                              });
                            },
                          ),
                          if (i != filters.length - 1)
                            const SizedBox(height: 14),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(
        currentRoute: AppRoutes.filters,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(18, 14, 18, 8),
      child: Row(
        children: [
          SizedBox(width: 24),
          Expanded(
            child: Text(
              'Фильтры',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 24),
        ],
      ),
    );
  }
}

class _FilterItem extends StatelessWidget {
  final _FilterItemData data;
  final ValueChanged<bool> onChanged;

  const _FilterItem({
    required this.data,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary.withOpacity(0.45),
            ),
          ),
          child: Icon(
            data.icon,
            color: AppColors.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                data.subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: data.enabled,
          activeColor: AppColors.primary,
          inactiveThumbColor: AppColors.textSecondary,
          inactiveTrackColor: AppColors.cardBorder,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _FilterItemData {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;

  const _FilterItemData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
  });

  _FilterItemData copyWith({
    String? subtitle,
    bool? enabled,
  }) {
    return _FilterItemData(
      icon: icon,
      title: title,
      subtitle: subtitle ?? this.subtitle,
      enabled: enabled ?? this.enabled,
    );
  }
}