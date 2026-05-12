import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_mode.dart';

class AppModeService {
  static const String _activatedModeKey = 'activated_app_mode';

  static AppMode currentMode = AppMode.receiver;
  static AppMode? activatedMode;

  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_activatedModeKey);

    activatedMode = _modeFromName(savedMode);
    currentMode = activatedMode ?? AppMode.receiver;
    _initialized = true;
  }

  static Future<bool> activateMode(AppMode mode) async {
    await ensureInitialized();

    if (activatedMode != null && activatedMode != mode) {
      return false;
    }

    activatedMode = mode;
    currentMode = mode;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activatedModeKey, mode.name);

    return true;
  }

  static void setMode(AppMode mode) {
    if (activatedMode != null && activatedMode != mode) {
      return;
    }

    currentMode = mode;
  }

  static AppMode getMode() {
    return currentMode;
  }

  static bool canUseMode(AppMode mode) {
    return activatedMode == null || activatedMode == mode;
  }

  static bool get isActivated => activatedMode != null;

  static bool get isReceiver => currentMode == AppMode.receiver;

  static bool get isSender => currentMode == AppMode.sender;

  static Future<void> resetActivation() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_activatedModeKey);

    activatedMode = null;
    currentMode = AppMode.receiver;
  }

  static AppMode? _modeFromName(String? value) {
    if (value == AppMode.receiver.name) {
      return AppMode.receiver;
    }

    if (value == AppMode.sender.name) {
      return AppMode.sender;
    }

    return null;
  }
}