import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class SenderPermissionService {
  static const MethodChannel _channel = MethodChannel(
    'vidra/android_permissions',
  );

  const SenderPermissionService();

  bool get _isAndroid {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  }

  Future<bool> isSmsGranted() async {
    try {
      final status = await Permission.sms.status.timeout(
        const Duration(seconds: 3),
      );
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestSms() async {
    try {
      final status = await Permission.sms.request().timeout(
        const Duration(seconds: 10),
      );
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isNotificationListenerEnabled() async {
    return _invokeBool('isNotificationListenerEnabled');
  }

  Future<void> openNotificationListenerSettings() async {
    await _invokeVoid('openNotificationListenerSettings');
  }

  Future<bool> isBatteryOptimizationDisabled() async {
    return _invokeBool('isBatteryOptimizationDisabled');
  }

  Future<void> openBatteryOptimizationSettings() async {
    await _invokeVoid('openBatteryOptimizationSettings');
  }

  Future<void> moveAppToBackground() async {
    await _invokeVoid('moveAppToBackground');
  }

  Future<void> openAppSettingsSafe() async {
    try {
      await openAppSettings().timeout(const Duration(seconds: 3));
    } catch (_) {
      return;
    }
  }

  Future<bool> _invokeBool(String method) async {
    if (!_isAndroid) return false;

    try {
      final result = await _channel.invokeMethod<bool>(method).timeout(
        const Duration(seconds: 3),
      );

      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _invokeVoid(String method) async {
    if (!_isAndroid) return;

    try {
      await _channel.invokeMethod(method).timeout(
        const Duration(seconds: 3),
      );
    } catch (_) {
      return;
    }
  }
}