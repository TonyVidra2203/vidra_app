import 'package:shared_preferences/shared_preferences.dart';

class SenderSettingsService {
  static const String _smsForwardingKey = 'sender_sms_forwarding';
  static const String _pushForwardingKey = 'sender_push_forwarding';
  static const String _backgroundModeKey = 'sender_background_mode';
  static const String _onlyWithInternetKey = 'sender_only_with_internet';

  const SenderSettingsService();

  Future<SenderSettingsState> load() async {
    final prefs = await SharedPreferences.getInstance();

    return SenderSettingsState(
      smsForwarding: prefs.getBool(_smsForwardingKey) ?? true,
      pushForwarding: prefs.getBool(_pushForwardingKey) ?? true,
      backgroundMode: prefs.getBool(_backgroundModeKey) ?? true,
      onlyWithInternet: prefs.getBool(_onlyWithInternetKey) ?? false,
    );
  }

  Future<void> save(SenderSettingsState settings) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_smsForwardingKey, settings.smsForwarding);
    await prefs.setBool(_pushForwardingKey, settings.pushForwarding);
    await prefs.setBool(_backgroundModeKey, settings.backgroundMode);
    await prefs.setBool(_onlyWithInternetKey, settings.onlyWithInternet);
  }
}

class SenderSettingsState {
  final bool smsForwarding;
  final bool pushForwarding;
  final bool backgroundMode;
  final bool onlyWithInternet;

  const SenderSettingsState({
    required this.smsForwarding,
    required this.pushForwarding,
    required this.backgroundMode,
    required this.onlyWithInternet,
  });

  SenderSettingsState copyWith({
    bool? smsForwarding,
    bool? pushForwarding,
    bool? backgroundMode,
    bool? onlyWithInternet,
  }) {
    return SenderSettingsState(
      smsForwarding: smsForwarding ?? this.smsForwarding,
      pushForwarding: pushForwarding ?? this.pushForwarding,
      backgroundMode: backgroundMode ?? this.backgroundMode,
      onlyWithInternet: onlyWithInternet ?? this.onlyWithInternet,
    );
  }
}