import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<bool> requestSmsPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<bool> checkSmsPermission() async {
    final status = await Permission.sms.status;
    return status.isGranted;
  }

  Future<bool> checkNotificationPermission() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  Future<bool> requestMainPhonePermissions() async {
    final smsGranted = await requestSmsPermission();
    final notificationGranted = await requestNotificationPermission();

    return smsGranted && notificationGranted;
  }

  Future<bool> checkMainPhonePermissions() async {
    final smsGranted = await checkSmsPermission();
    final notificationGranted = await checkNotificationPermission();

    return smsGranted && notificationGranted;
  }

  Future<void> openAppSettingsPage() async {
    await openAppSettings();
  }
}