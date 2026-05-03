import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SenderSettingsService {
  static const MethodChannel _channel = MethodChannel(
    'vidra/android_permissions',
  );

  static const String _smsForwardingKey = 'sender_sms_forwarding';
  static const String _pushForwardingKey = 'sender_push_forwarding';
  static const String _backgroundModeKey = 'sender_background_mode';
  static const String _onlyWithInternetKey = 'sender_only_with_internet';
  static const String _deviceNameKey = 'sender_device_name';
  static const String _deviceIdKey = 'sender_device_id';
  static const String _relayUrlKey = 'sender_relay_url';
  static const String _relayApiKeyKey = 'sender_relay_api_key';

  const SenderSettingsService();

  Future<SenderSettingsState> load() async {
    final prefs = await SharedPreferences.getInstance();

    return SenderSettingsState(
      smsForwarding: prefs.getBool(_smsForwardingKey) ?? true,
      pushForwarding: prefs.getBool(_pushForwardingKey) ?? true,
      backgroundMode: prefs.getBool(_backgroundModeKey) ?? true,
      onlyWithInternet: prefs.getBool(_onlyWithInternetKey) ?? false,
      deviceName: prefs.getString(_deviceNameKey) ?? 'Рабочий телефон',
      deviceId: prefs.getString(_deviceIdKey) ?? '',
      relayUrl: prefs.getString(_relayUrlKey) ?? '',
      relayApiKey: prefs.getString(_relayApiKeyKey) ?? '',
    );
  }

  Future<void> save(SenderSettingsState settings) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_smsForwardingKey, settings.smsForwarding);
    await prefs.setBool(_pushForwardingKey, settings.pushForwarding);
    await prefs.setBool(_backgroundModeKey, settings.backgroundMode);
    await prefs.setBool(_onlyWithInternetKey, settings.onlyWithInternet);
    await prefs.setString(_deviceNameKey, settings.deviceName);
    await prefs.setString(_deviceIdKey, settings.deviceId);
    await prefs.setString(_relayUrlKey, settings.relayUrl);
    await prefs.setString(_relayApiKeyKey, settings.relayApiKey);

    await _saveNativeSettings(settings);
  }

  Future<void> _saveNativeSettings(SenderSettingsState settings) async {
    try {
      await _channel.invokeMethod('saveSenderSettings', {
        'smsForwarding': settings.smsForwarding,
        'pushForwarding': settings.pushForwarding,
        'backgroundMode': settings.backgroundMode,
        'onlyWithInternet': settings.onlyWithInternet,
        'deviceName': settings.deviceName,
        'deviceId': settings.deviceId,
        'relayUrl': settings.relayUrl,
        'relayApiKey': settings.relayApiKey,
      });
    } catch (_) {
      // Flutter-настройки сохранены. Native-слой обновится после следующего сохранения.
    }
  }
}

class SenderSettingsState {
  final bool smsForwarding;
  final bool pushForwarding;
  final bool backgroundMode;
  final bool onlyWithInternet;
  final String deviceName;
  final String deviceId;
  final String relayUrl;
  final String relayApiKey;

  const SenderSettingsState({
    required this.smsForwarding,
    required this.pushForwarding,
    required this.backgroundMode,
    required this.onlyWithInternet,
    this.deviceName = 'Рабочий телефон',
    this.deviceId = '',
    this.relayUrl = '',
    this.relayApiKey = '',
  });

  SenderSettingsState copyWith({
    bool? smsForwarding,
    bool? pushForwarding,
    bool? backgroundMode,
    bool? onlyWithInternet,
    String? deviceName,
    String? deviceId,
    String? relayUrl,
    String? relayApiKey,
  }) {
    return SenderSettingsState(
      smsForwarding: smsForwarding ?? this.smsForwarding,
      pushForwarding: pushForwarding ?? this.pushForwarding,
      backgroundMode: backgroundMode ?? this.backgroundMode,
      onlyWithInternet: onlyWithInternet ?? this.onlyWithInternet,
      deviceName: deviceName ?? this.deviceName,
      deviceId: deviceId ?? this.deviceId,
      relayUrl: relayUrl ?? this.relayUrl,
      relayApiKey: relayApiKey ?? this.relayApiKey,
    );
  }
}