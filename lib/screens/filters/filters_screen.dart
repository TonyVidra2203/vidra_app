import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../navigation/app_routes.dart';
import '../../services/native_main_phone_service.dart';
import '../../widgets/common/app_bottom_nav_bar.dart';
import '../../widgets/common/app_card.dart';

class FiltersScreen extends StatefulWidget {
  const FiltersScreen({super.key});

  @override
  State<FiltersScreen> createState() => _FiltersScreenState();
}

class _FiltersScreenState extends State<FiltersScreen> {
  final NativeMainPhoneService nativeService = const NativeMainPhoneService();

  MainPhoneFilterSettings settings = const MainPhoneFilterSettings();

  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  Future<void> _loadFilters() async {
    final loadedSettings = await nativeService.getFilterSettings();

    if (!mounted) {
      return;
    }

    setState(() {
      settings = loadedSettings;
      isLoading = false;
    });
  }

  Future<void> _saveFilters(MainPhoneFilterSettings newSettings) async {
    setState(() {
      settings = newSettings;
      isSaving = true;
    });

    await nativeService.saveFilterSettings(newSettings);

    if (!mounted) {
      return;
    }

    setState(() {
      isSaving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filters = [
      _FilterItemData(
        icon: Icons.verified_user_outlined,
        title: 'Коды подтверждения',
        subtitle: settings.verificationCodes ? 'Включены' : 'Отключены',
        enabled: settings.verificationCodes,
        onChanged: (value) {
          _saveFilters(settings.copyWith(verificationCodes: value));
        },
      ),
      _FilterItemData(
        icon: Icons.account_balance_outlined,
        title: 'Банковские сообщения',
        subtitle: settings.bankMessages ? 'Включены' : 'Отключены',
        enabled: settings.bankMessages,
        onChanged: (value) {
          _saveFilters(settings.copyWith(bankMessages: value));
        },
      ),
      _FilterItemData(
        icon: Icons.sms_outlined,
        title: 'Рекламные SMS',
        subtitle: settings.adSms ? 'Включены' : 'Отключены',
        enabled: settings.adSms,
        onChanged: (value) {
          _saveFilters(settings.copyWith(adSms: value));
        },
      ),
      _FilterItemData(
        icon: Icons.public_outlined,
        title: 'Международные номера',
        subtitle: settings.internationalNumbers ? 'Включены' : 'Отключены',
        enabled: settings.internationalNumbers,
        onChanged: (value) {
          _saveFilters(settings.copyWith(internationalNumbers: value));
        },
      ),
      _FilterItemData(
        icon: Icons.block_outlined,
        title: 'Крипто-спам',
        subtitle: settings.cryptoSpam ? 'Включены' : 'Отключены',
        enabled: settings.cryptoSpam,
        onChanged: (value) {
          _saveFilters(settings.copyWith(cryptoSpam: value));
        },
      ),
      _FilterItemData(
        icon: Icons.visibility_off_outlined,
        title: 'Черный список',
        subtitle: settings.blacklist ? 'Включены' : 'Отключены',
        enabled: settings.blacklist,
        onChanged: (value) {
          _saveFilters(settings.copyWith(blacklist: value));
        },
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(isSaving: isSaving),
            Expanded(
              child: isLoading
                  ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              )
                  : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppCard(
                    child: Column(
                      children: [
                        for (int i = 0; i < filters.length; i++) ...[
                          _FilterItem(data: filters[i]),
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
  final bool isSaving;

  const _Header({
    required this.isSaving,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card.withOpacity(0.9),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.35),
                ),
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Фильтры',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Правила отбора входящих сообщений',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            if (isSaving)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            else
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.background.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterItem extends StatelessWidget {
  final _FilterItemData data;

  const _FilterItem({
    required this.data,
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
          onChanged: data.onChanged,
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
  final ValueChanged<bool> onChanged;

  const _FilterItemData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onChanged,
  });
}