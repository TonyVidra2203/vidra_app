import '../models/app_mode.dart';

class AppModeService {
  static AppMode currentMode = AppMode.receiver;

  static void setMode(AppMode mode) {
    currentMode = mode;
  }

  static AppMode getMode() {
    return currentMode;
  }

  static bool get isReceiver => currentMode == AppMode.receiver;

  static bool get isSender => currentMode == AppMode.sender;
}