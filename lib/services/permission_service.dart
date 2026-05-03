import 'device_pairing_service.dart';
import 'native_main_phone_service.dart';

class PermissionService {
  final DevicePairingService _pairingService = DevicePairingService();
  final NativeMainPhoneService _nativeService = const NativeMainPhoneService();

  Future<bool> requestSmsPermission() async {
    final canUseForwarding = await _canUseForwarding();

    if (!canUseForwarding) {
      return false;
    }

    return _nativeService.requestSmsPermissions();
  }

  Future<bool> requestNotificationPermission() async {
    final canUseForwarding = await _canUseForwarding();

    if (!canUseForwarding) {
      return false;
    }

    return _nativeService.requestPostNotificationPermission();
  }

  Future<bool> checkSmsPermission() async {
    final canUseForwarding = await _canUseForwarding();

    if (!canUseForwarding) {
      return false;
    }

    return _nativeService.hasSmsPermissions();
  }

  Future<bool> checkNotificationPermission() async {
    final canUseForwarding = await _canUseForwarding();

    if (!canUseForwarding) {
      return false;
    }

    final hasPostNotificationPermission =
    await _nativeService.hasPostNotificationPermission();

    final hasNotificationListener =
    await _nativeService.isNotificationListenerEnabled();

    return hasPostNotificationPermission && hasNotificationListener;
  }

  Future<bool> checkNotificationListenerPermission() async {
    final canUseForwarding = await _canUseForwarding();

    if (!canUseForwarding) {
      return false;
    }

    return _nativeService.isNotificationListenerEnabled();
  }

  Future<void> openNotificationListenerSettings() async {
    final canUseForwarding = await _canUseForwarding();

    if (!canUseForwarding) {
      return;
    }

    await _nativeService.openNotificationListenerSettings();
  }

  Future<bool> checkBatteryOptimizationDisabled() async {
    final canUseForwarding = await _canUseForwarding();

    if (!canUseForwarding) {
      return false;
    }

    return _nativeService.isBatteryOptimizationDisabled();
  }

  Future<void> openBatteryOptimizationSettings() async {
    final canUseForwarding = await _canUseForwarding();

    if (!canUseForwarding) {
      return;
    }

    await _nativeService.openBatteryOptimizationSettings();
  }

  Future<bool> _canUseForwarding() async {
    final pairingState = await _pairingService.loadState();

    return pairingState.isWorkerPhone && pairingState.isPaired;
  }
}