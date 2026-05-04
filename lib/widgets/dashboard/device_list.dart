import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/device_model.dart';

class DeviceList extends StatefulWidget {
  final List<DeviceModel> devices;
  final ValueChanged<DeviceModel> onDeleteDevice;

  const DeviceList({
    super.key,
    required this.devices,
    required this.onDeleteDevice,
  });

  @override
  State<DeviceList> createState() => _DeviceListState();
}

class _DeviceListState extends State<DeviceList> {
  int? expandedIndex;

  void _toggleDevice(int index) {
    setState(() {
      expandedIndex = expandedIndex == index ? null : index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: widget.devices.asMap().entries.map((entry) {
        final index = entry.key;
        final device = entry.value;
        final isExpanded = expandedIndex == index;

        return Column(
          children: [
            InkWell(
              onTap: () => _toggleDevice(index),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    _DeleteDeviceButton(
                      onPressed: () => widget.onDeleteDevice(device),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.phone_android,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            device.name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            device.system,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: device.isOnline
                                ? AppColors.success
                                : AppColors.danger,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          device.isOnline ? 'online' : 'offline',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Text(
                      device.battery,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(
                        Icons.chevron_right,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _DeviceDetails(device: device),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 180),
            ),
            const Divider(color: AppColors.cardBorder),
          ],
        );
      }).toList(),
    );
  }
}

class _DeleteDeviceButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _DeleteDeviceButton({
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.danger.withOpacity(0.16),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 34,
          height: 34,
          child: Icon(
            Icons.close,
            color: AppColors.danger,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _DeviceDetails extends StatelessWidget {
  final DeviceModel device;

  const _DeviceDetails({
    required this.device,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DeviceDetailRow(
            icon: Icons.access_time,
            title: 'Последняя активность',
            value: device.lastSeen,
          ),
          const SizedBox(height: 8),
          _DeviceDetailRow(
            icon: Icons.memory,
            title: 'Устройство',
            value: device.system,
          ),
          const SizedBox(height: 8),
          _DeviceDetailRow(
            icon: Icons.phone,
            title: 'Номер телефона',
            value: device.phoneNumber,
          ),
        ],
      ),
    );
  }
}

class _DeviceDetailRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _DeviceDetailRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppColors.primary,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          '$title: ',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}