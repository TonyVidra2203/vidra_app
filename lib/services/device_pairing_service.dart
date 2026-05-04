import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DevicePairingRole {
  none,
  mainPhone,
  workerPhone,
}

enum DevicePairingStatus {
  notPaired,
  waitingForWorker,
  paired,
}

class DevicePairingState {
  final DevicePairingRole role;
  final DevicePairingStatus status;
  final String deviceName;
  final String pairCode;
  final String pairedDeviceName;
  final String relayUrl;
  final String relayApiKey;
  final DateTime? createdAt;

  const DevicePairingState({
    required this.role,
    required this.status,
    required this.deviceName,
    required this.pairCode,
    required this.pairedDeviceName,
    required this.relayUrl,
    required this.relayApiKey,
    required this.createdAt,
  });

  const DevicePairingState.empty()
      : role = DevicePairingRole.none,
        status = DevicePairingStatus.notPaired,
        deviceName = '',
        pairCode = '',
        pairedDeviceName = '',
        relayUrl = '',
        relayApiKey = '',
        createdAt = null;

  bool get hasPairCode => pairCode.isNotEmpty;

  bool get isMainPhone => role == DevicePairingRole.mainPhone;

  bool get isWorkerPhone => role == DevicePairingRole.workerPhone;

  bool get isPaired => status == DevicePairingStatus.paired;

  Map<String, dynamic> toJson() {
    return {
      'role': role.name,
      'status': status.name,
      'deviceName': deviceName,
      'pairCode': pairCode,
      'pairedDeviceName': pairedDeviceName,
      'relayUrl': relayUrl,
      'relayApiKey': relayApiKey,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory DevicePairingState.fromJson(Map json) {
    return DevicePairingState(
      role: _roleFromString(json['role']?.toString()),
      status: _statusFromString(json['status']?.toString()),
      deviceName: json['deviceName']?.toString() ?? '',
      pairCode: json['pairCode']?.toString() ?? '',
      pairedDeviceName: json['pairedDeviceName']?.toString() ?? '',
      relayUrl: json['relayUrl']?.toString() ?? '',
      relayApiKey: json['relayApiKey']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }

  static DevicePairingRole _roleFromString(String? value) {
    return DevicePairingRole.values.firstWhere(
          (role) => role.name == value,
      orElse: () => DevicePairingRole.none,
    );
  }

  static DevicePairingStatus _statusFromString(String? value) {
    return DevicePairingStatus.values.firstWhere(
          (status) => status.name == value,
      orElse: () => DevicePairingStatus.notPaired,
    );
  }
}

class DevicePairingService {
  static const MethodChannel _channel = MethodChannel(
    'vidra/android_permissions',
  );

  static const String _storageKey = 'device_pairing_state';

  static const String _senderSmsForwardingKey = 'sender_sms_forwarding';
  static const String _senderPushForwardingKey = 'sender_push_forwarding';
  static const String _senderBackgroundModeKey = 'sender_background_mode';
  static const String _senderOnlyWithInternetKey = 'sender_only_with_internet';
  static const String _senderDeviceNameKey = 'sender_device_name';
  static const String _senderDeviceIdKey = 'sender_device_id';
  static const String _senderRelayUrlKey = 'sender_relay_url';
  static const String _senderRelayApiKeyKey = 'sender_relay_api_key';

  static const String _relayApiKey = '';

  Future<DevicePairingState> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString(_storageKey);

    if (rawValue == null || rawValue.trim().isEmpty) {
      return const DevicePairingState.empty();
    }

    try {
      final decoded = jsonDecode(rawValue);

      if (decoded is Map) {
        return DevicePairingState.fromJson(decoded);
      }

      return const DevicePairingState.empty();
    } catch (_) {
      return const DevicePairingState.empty();
    }
  }

  Future<DevicePairingState> createMainPhonePairCode({
    required String deviceName,
    required String serverUrl,
  }) async {
    final cleanedServerUrl = _cleanServerUrl(serverUrl);

    if (cleanedServerUrl.isEmpty) {
      throw const DevicePairingException('Введите адрес сервера.');
    }

    final pairCode = _generatePairCode();
    final relayUrl = _buildRelayUrl(cleanedServerUrl, pairCode);
    final cleanDeviceName = _cleanName(
      deviceName,
      fallback: 'Главный телефон',
    );

    final state = DevicePairingState(
      role: DevicePairingRole.mainPhone,
      status: DevicePairingStatus.waitingForWorker,
      deviceName: cleanDeviceName,
      pairCode: pairCode,
      pairedDeviceName: '',
      relayUrl: relayUrl,
      relayApiKey: _relayApiKey,
      createdAt: DateTime.now(),
    );

    await _saveState(state);
    await _saveMainPhoneSettings(state);

    return state;
  }

  Future<DevicePairingState> connectWorkerPhone({
    required String deviceName,
    required String pairCode,
    required String serverUrl,
  }) async {
    final cleanedCode = _cleanPairCode(pairCode);
    final cleanedServerUrl = _cleanServerUrl(serverUrl);

    if (!_isValidPairCode(cleanedCode)) {
      throw const DevicePairingException(
        'Введите код из 6 цифр с главного телефона.',
      );
    }

    if (cleanedServerUrl.isEmpty) {
      throw const DevicePairingException(
        'Введите адрес сервера. Например: http://45.80.68.83:3000',
      );
    }

    final relayUrl = _buildRelayUrl(cleanedServerUrl, cleanedCode);
    final cleanDeviceName = _cleanName(
      deviceName,
      fallback: 'Рабочий телефон',
    );
    final deviceId = await _getOrCreateDeviceId();

    final state = DevicePairingState(
      role: DevicePairingRole.workerPhone,
      status: DevicePairingStatus.paired,
      deviceName: cleanDeviceName,
      pairCode: cleanedCode,
      pairedDeviceName: 'Главный телефон',
      relayUrl: relayUrl,
      relayApiKey: _relayApiKey,
      createdAt: DateTime.now(),
    );

    await _saveState(state);
    await _saveWorkerPhoneSettings(
      deviceName: cleanDeviceName,
      deviceId: deviceId,
      relayUrl: relayUrl,
      relayApiKey: _relayApiKey,
    );

    return state;
  }

  Future<DevicePairingState> confirmWorkerPhone({
    required String workerDeviceName,
  }) async {
    final currentState = await loadState();

    if (!currentState.isMainPhone || !currentState.hasPairCode) {
      throw const DevicePairingException(
        'Сначала создайте код на главном телефоне.',
      );
    }

    final state = DevicePairingState(
      role: DevicePairingRole.mainPhone,
      status: DevicePairingStatus.paired,
      deviceName: currentState.deviceName,
      pairCode: currentState.pairCode,
      pairedDeviceName: _cleanName(
        workerDeviceName,
        fallback: 'Рабочий телефон',
      ),
      relayUrl: currentState.relayUrl,
      relayApiKey: currentState.relayApiKey,
      createdAt: currentState.createdAt,
    );

    await _saveState(state);
    await _saveMainPhoneSettings(state);

    return state;
  }

  Future<void> resetPairing() async {
    final prefs = await SharedPreferences.getInstance();

    final savedDeviceName = prefs.getString(_senderDeviceNameKey) ?? '';
    final savedDeviceId = prefs.getString(_senderDeviceIdKey) ?? '';

    await prefs.remove(_storageKey);
    await prefs.remove(_senderRelayUrlKey);
    await prefs.remove(_senderRelayApiKeyKey);

    await _saveNativeSenderSettings(
      deviceName: savedDeviceName,
      deviceId: savedDeviceId,
      relayUrl: '',
      relayApiKey: '',
    );
  }

  Future<void> _saveState(DevicePairingState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(state.toJson()));
  }

  Future<void> _saveMainPhoneSettings(DevicePairingState state) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_senderRelayUrlKey, state.relayUrl);
    await prefs.setString(_senderRelayApiKeyKey, state.relayApiKey);

    await _saveNativeSenderSettings(
      deviceName: state.deviceName,
      deviceId: '',
      relayUrl: state.relayUrl,
      relayApiKey: state.relayApiKey,
    );
  }

  Future<void> _saveWorkerPhoneSettings({
    required String deviceName,
    required String deviceId,
    required String relayUrl,
    required String relayApiKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_senderSmsForwardingKey, true);
    await prefs.setBool(_senderPushForwardingKey, true);
    await prefs.setBool(_senderBackgroundModeKey, true);
    await prefs.setBool(_senderOnlyWithInternetKey, false);
    await prefs.setString(_senderDeviceNameKey, deviceName);
    await prefs.setString(_senderDeviceIdKey, deviceId);
    await prefs.setString(_senderRelayUrlKey, relayUrl);
    await prefs.setString(_senderRelayApiKeyKey, relayApiKey);

    await _saveNativeSenderSettings(
      deviceName: deviceName,
      deviceId: deviceId,
      relayUrl: relayUrl,
      relayApiKey: relayApiKey,
    );
  }

  Future<void> _saveNativeSenderSettings({
    required String deviceName,
    required String deviceId,
    required String relayUrl,
    required String relayApiKey,
  }) async {
    try {
      await _channel.invokeMethod('saveSenderSettings', {
        'smsForwarding': true,
        'pushForwarding': true,
        'backgroundMode': true,
        'onlyWithInternet': false,
        'deviceName': deviceName,
        'deviceId': deviceId,
        'relayUrl': relayUrl,
        'relayApiKey': relayApiKey,
      }).timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDeviceId = prefs.getString(_senderDeviceIdKey);

    if (savedDeviceId != null && savedDeviceId.trim().isNotEmpty) {
      return savedDeviceId.trim();
    }

    final deviceId = _generateDeviceId();
    await prefs.setString(_senderDeviceIdKey, deviceId);

    return deviceId;
  }

  String _buildRelayUrl(String serverUrl, String pairCode) {
    final base = serverUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return '$base/events/$pairCode';
  }

  String _generatePairCode() {
    final random = Random.secure();
    final value = 100000 + random.nextInt(900000);
    return value.toString();
  }

  String _generateDeviceId() {
    final random = Random.secure();
    final time = DateTime.now().millisecondsSinceEpoch;
    final randomPart = random.nextInt(999999).toString().padLeft(6, '0');
    return 'vidra_$time$randomPart';
  }

  String _cleanName(
      String value, {
        required String fallback,
      }) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return fallback;
    }

    return trimmed;
  }

  String _cleanServerUrl(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return '';
    }

    final withoutTrailingSlash = trimmed.replaceAll(RegExp(r'/+$'), '');

    if (withoutTrailingSlash.startsWith('http://') ||
        withoutTrailingSlash.startsWith('https://')) {
      return withoutTrailingSlash;
    }

    return 'http://$withoutTrailingSlash';
  }

  String _cleanPairCode(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  bool _isValidPairCode(String value) {
    return RegExp(r'^\d{6}$').hasMatch(value);
  }
}

class DevicePairingException implements Exception {
  final String message;

  const DevicePairingException(this.message);

  @override
  String toString() {
    return message;
  }
}