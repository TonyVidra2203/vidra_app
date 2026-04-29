import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class SenderPermissionService {
  static const MethodChannel _channel = MethodChannel(
    'vidra/android_permissions',
  );

  const SenderPermissionService();

  Future<bool> isSmsGranted() async {
    return Permission.sms.isGranted;
  }

  Future<bool> requestSms() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  Future<bool> isNotificationListenerEnabled() async {
    final result = await _channel.invokeMethod<bool>(
      'isNotificationListenerEnabled',
    );

    return result ?? false;
  }

  Future<void> openNotificationListenerSettings() async {
    await _channel.invokeMethod<bool>('openNotificationListenerSettings');
  }

  Future<bool> isBatteryOptimizationDisabled() async {
    final result = await _channel.invokeMethod<bool>(
      'isBatteryOptimizationDisabled',
    );

    return result ?? false;
  }

  Future<void> openBatteryOptimizationSettings() async {
    await _channel.invokeMethod<bool>('openBatteryOptimizationSettings');
  }
}