import 'dart:convert';
import 'dart:io';
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

  DevicePairingState copyWith({
    DevicePairingRole? role,
    DevicePairingStatus? status,
    String? deviceName,
    String? pairCode,
    String? pairedDeviceName,
    String? relayUrl,
    String? relayApiKey,
    DateTime? createdAt,
  }) {
    return DevicePairingState(
      role: role ?? this.role,
      status: status ?? this.status,
      deviceName: deviceName ?? this.deviceName,
      pairCode: pairCode ?? this.pairCode,
      pairedDeviceName: pairedDeviceName ?? this.pairedDeviceName,
      relayUrl: relayUrl ?? this.relayUrl,
      relayApiKey: relayApiKey ?? this.relayApiKey,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toJson() {
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

  factory DevicePairingState.fromJson(Map<String, Object?> json) {
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

class DevicePairingQrPayload {
  final String pairCode;
  final String serverUrl;
  final String mainDeviceName;

  const DevicePairingQrPayload({
    required this.pairCode,
    required this.serverUrl,
    required this.mainDeviceName,
  });

  bool get isValid => pairCode.trim().isNotEmpty && serverUrl.trim().isNotEmpty;

  String toQrValue() {
    return jsonEncode({
      'type': 'vidra_pairing',
      'version': 1,
      'pairCode': pairCode,
      'serverUrl': serverUrl,
      'mainDeviceName': mainDeviceName,
    });
  }

  static DevicePairingQrPayload? fromQrValue(String value) {
    final trimmed = value.trim();

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        final type = decoded['type']?.toString();
        final pairCode = decoded['pairCode']?.toString() ?? '';
        final serverUrl = decoded['serverUrl']?.toString() ?? '';
        final mainDeviceName = decoded['mainDeviceName']?.toString() ?? '';

        if (type == 'vidra_pairing' && pairCode.isNotEmpty && serverUrl.isNotEmpty) {
          return DevicePairingQrPayload(
            pairCode: pairCode,
            serverUrl: serverUrl,
            mainDeviceName: mainDeviceName,
          );
        }
      }
    } catch (_) {}

    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.scheme == 'vidra' && uri.host == 'pair') {
      final pairCode = uri.queryParameters['code'] ?? '';
      final serverUrl = uri.queryParameters['server'] ?? '';
      final mainDeviceName = uri.queryParameters['name'] ?? '';

      if (pairCode.isNotEmpty && serverUrl.isNotEmpty) {
        return DevicePairingQrPayload(
          pairCode: pairCode,
          serverUrl: serverUrl,
          mainDeviceName: mainDeviceName,
        );
      }
    }

    return null;
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
        return DevicePairingState.fromJson(Map<String, Object?>.from(decoded));
      }
    } catch (_) {}

    return const DevicePairingState.empty();
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

  Future<DevicePairingState> connectWorkerPhoneFromQr({
    required String deviceName,
    required DevicePairingQrPayload payload,
  }) {
    return connectWorkerPhone(
      deviceName: deviceName,
      pairCode: payload.pairCode,
      serverUrl: payload.serverUrl,
    );
  }

  Future<DevicePairingState> confirmWorkerPhone() async {
    final currentState = await loadState();

    if (!currentState.isMainPhone || !currentState.hasPairCode) {
      throw const DevicePairingException(
        'Сначала создайте код на главном телефоне.',
      );
    }

    final workerName = await detectWorkerDeviceName(currentState);
    final state = currentState.copyWith(
      status: DevicePairingStatus.paired,
      pairedDeviceName: workerName,
    );

    await _saveState(state);
    await _saveMainPhoneSettings(state);

    return state;
  }

  Future<DevicePairingState> refreshMainPhonePairing() async {
    final currentState = await loadState();

    if (!currentState.isMainPhone || currentState.relayUrl.trim().isEmpty) {
      return currentState;
    }

    final workerName = await detectWorkerDeviceName(currentState);

    if (workerName.trim().isEmpty) {
      return currentState;
    }

    final state = currentState.copyWith(
      status: DevicePairingStatus.paired,
      pairedDeviceName: workerName,
    );

    await _saveState(state);
    await _saveMainPhoneSettings(state);

    return state;
  }

  DevicePairingQrPayload createQrPayload(DevicePairingState state) {
    if (!state.isMainPhone || state.pairCode.trim().isEmpty || state.relayUrl.trim().isEmpty) {
      throw const DevicePairingException(
        'Сначала создайте код на главном телефоне.',
      );
    }

    return DevicePairingQrPayload(
      pairCode: state.pairCode,
      serverUrl: _extractServerUrl(state.relayUrl),
      mainDeviceName: state.deviceName,
    );
  }

  Future<String> detectWorkerDeviceName(DevicePairingState state) async {
    final events = await _loadRelayEvents(state.relayUrl);

    for (final event in events) {
      final deviceName = event['deviceName']?.toString().trim() ?? '';
      final deviceId = event['deviceId']?.toString().trim() ?? '';

      if (deviceName.isNotEmpty && deviceName != state.deviceName) {
        return deviceName;
      }

      if (deviceId.isNotEmpty) {
        return 'Рабочий телефон';
      }
    }

    return 'Рабочий телефон';
  }

  Future<void> resetPairing() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_storageKey);
    await prefs.remove(_senderRelayUrlKey);
    await prefs.remove(_senderRelayApiKeyKey);

    await _saveNativeSenderSettings(
      smsForwarding: false,
      pushForwarding: false,
      backgroundMode: false,
      onlyWithInternet: false,
      deviceName: '',
      deviceId: '',
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

    await prefs.setBool(_senderSmsForwardingKey, false);
    await prefs.setBool(_senderPushForwardingKey, false);
    await prefs.setBool(_senderBackgroundModeKey, false);
    await prefs.setBool(_senderOnlyWithInternetKey, false);
    await prefs.setString(_senderDeviceNameKey, state.deviceName);
    await prefs.setString(_senderDeviceIdKey, '');
    await prefs.setString(_senderRelayUrlKey, state.relayUrl);
    await prefs.setString(_senderRelayApiKeyKey, state.relayApiKey);

    await _saveNativeSenderSettings(
      smsForwarding: false,
      pushForwarding: false,
      backgroundMode: false,
      onlyWithInternet: false,
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
      smsForwarding: true,
      pushForwarding: true,
      backgroundMode: true,
      onlyWithInternet: false,
      deviceName: deviceName,
      deviceId: deviceId,
      relayUrl: relayUrl,
      relayApiKey: relayApiKey,
    );
  }

  Future<void> _saveNativeSenderSettings({
    required bool smsForwarding,
    required bool pushForwarding,
    required bool backgroundMode,
    required bool onlyWithInternet,
    required String deviceName,
    required String deviceId,
    required String relayUrl,
    required String relayApiKey,
  }) async {
    try {
      await _channel.invokeMethod('saveSenderSettings', {
        'smsForwarding': smsForwarding,
        'pushForwarding': pushForwarding,
        'backgroundMode': backgroundMode,
        'onlyWithInternet': onlyWithInternet,
        'deviceName': deviceName,
        'deviceId': deviceId,
        'relayUrl': relayUrl,
        'relayApiKey': relayApiKey,
      }).timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  Future<List<Map<String, Object?>>> _loadRelayEvents(String relayUrl) async {
    final cleanedRelayUrl = relayUrl.trim();

    if (cleanedRelayUrl.isEmpty) {
      return [];
    }

    HttpClient? client;

    try {
      final uri = Uri.parse(cleanedRelayUrl);

      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 6);

      final request = await client.getUrl(uri).timeout(
        const Duration(seconds: 6),
      );

      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final response = await request.close().timeout(
        const Duration(seconds: 6),
      );

      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return [];
      }

      final decoded = jsonDecode(body);
      final list = _extractEventsList(decoded);

      return list
          .whereType<Map>()
          .map((item) => Map<String, Object?>.from(item))
          .toList();
    } catch (_) {
      return [];
    } finally {
      client?.close(force: true);
    }
  }

  List<Object?> _extractEventsList(Object? decoded) {
    if (decoded is List) {
      return decoded;
    }

    if (decoded is Map) {
      final events = decoded['events'];
      final messages = decoded['messages'];
      final data = decoded['data'];

      if (events is List) {
        return events;
      }

      if (messages is List) {
        return messages;
      }

      if (data is List) {
        return data;
      }
    }

    return [];
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

  String _extractServerUrl(String relayUrl) {
    final cleaned = relayUrl.trim();

    if (cleaned.isEmpty) {
      return '';
    }

    const marker = '/events/';

    if (!cleaned.contains(marker)) {
      return cleaned;
    }

    return cleaned.split(marker).first;
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