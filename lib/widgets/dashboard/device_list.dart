import 'package:flutter/material.dart';
import '../../models/device_model.dart';
import '../../core/constants/app_colors.dart';

class DeviceList extends StatelessWidget {
  final List<DeviceModel> devices;

  const DeviceList({super.key, required this.devices});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: devices
          .map((d) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.phone_android,
                    color: AppColors.textPrimary),
                const SizedBox(width: 10),

                /// Название + система
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        d.system,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                /// Статус
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: d.isOnline
                            ? AppColors.success
                            : AppColors.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      d.isOnline ? 'Онлайн' : 'Оффлайн',
                      style: const TextStyle(
                          color: AppColors.textPrimary),
                    ),
                  ],
                ),

                const SizedBox(width: 10),

                /// Батарея
                Text(
                  d.battery,
                  style: const TextStyle(
                      color: AppColors.textPrimary),
                ),

                const Icon(Icons.chevron_right,
                    color: AppColors.primary),
              ],
            ),
          ),
          const Divider(color: AppColors.cardBorder),
        ],
      ))
          .toList(),
    );
  }
}