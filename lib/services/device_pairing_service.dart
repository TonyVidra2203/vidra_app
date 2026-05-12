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
  final String phoneNumber;
  final String pairCode;
  final String pairedDeviceName;
  final String pairedPhoneNumber;
  final String relayUrl;
  final String relayApiKey;
  final DateTime? createdAt;

  const DevicePairingState({
    required this.role,
    required this.status,
    required this.deviceName,
    required this.phoneNumber,
    required this.pairCode,
    required this.pairedDeviceName,
    required this.pairedPhoneNumber,
    required this.relayUrl,
    required this.relayApiKey,
    required this.createdAt,
  });

  const DevicePairingState.empty()
      : role = DevicePairingRole.none,
        status = DevicePairingStatus.notPaired,
        deviceName = '',
        phoneNumber = '',
        pairCode = '',
        pairedDeviceName = '',
        pairedPhoneNumber = '',
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
    String? phoneNumber,
    String? pairCode,
    String? pairedDeviceName,
    String? pairedPhoneNumber,
    String? relayUrl,
    String? relayApiKey,
    DateTime? createdAt,
  }) {
    return DevicePairingState(
      role: role ?? this.role,
      status: status ?? this.status,
      deviceName: deviceName ?? this.deviceName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      pairCode: pairCode ?? this.pairCode,
      pairedDeviceName: pairedDeviceName ?? this.pairedDeviceName,
      pairedPhoneNumber: pairedPhoneNumber ?? this.pairedPhoneNumber,
      relayUrl: relayUrl ?? this.relayUrl,
      relayApiKey: relayApiKey ?? this.relayApiKey,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role.name,
      'status': status.name,
      'deviceName': deviceName,
      'phoneNumber': phoneNumber,
      'pairCode': pairCode,
      'pairedDeviceName': pairedDeviceName,
      'pairedPhoneNumber': pairedPhoneNumber,
      'relayUrl': relayUrl,
      'relayApiKey': relayApiKey,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory DevicePairingState.fromJson(Map<String, dynamic> json) {
    return DevicePairingState(
      role: _roleFromString(json['role']?.toString()),
      status: _statusFromString(json['status']?.toString()),
      deviceName: json['deviceName']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      pairCode: json['pairCode']?.toString() ?? '',
      pairedDeviceName: json['pairedDeviceName']?.toString() ?? '',
      pairedPhoneNumber: json['pairedPhoneNumber']?.toString() ?? '',
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

  bool get isValid => pairCode.trim().isNotEmpty;

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
        final serverUrl =
            decoded['serverUrl']?.toString() ??
                DevicePairingService.defaultServerUrl;
        final mainDeviceName = decoded['mainDeviceName']?.toString() ?? '';

        if (type == 'vidra_pairing' && pairCode.isNotEmpty) {
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
      final serverUrl =
          uri.queryParameters['server'] ?? DevicePairingService.defaultServerUrl;
      final mainDeviceName = uri.queryParameters['name'] ?? '';

      if (pairCode.isNotEmpty) {
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

class WorkerPairingQrPayload {
  final String deviceName;
  final String phoneNumber;
  final String deviceId;
  final DateTime createdAt;

  const WorkerPairingQrPayload({
    required this.deviceName,
    required this.phoneNumber,
    required this.deviceId,
    required this.createdAt,
  });

  String toQrValue() {
    return jsonEncode({
      'type': 'vidra_worker_pairing_request',
      'version': 2,
      'deviceName': deviceName,
      'phoneNumber': phoneNumber,
      'deviceId': deviceId,
      'createdAt': createdAt.toIso8601String(),
    });
  }

  static WorkerPairingQrPayload? fromQrValue(String value) {
    final trimmed = value.trim();

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        final type = decoded['type']?.toString();
        final deviceName = decoded['deviceName']?.toString() ?? '';
        final phoneNumber = decoded['phoneNumber']?.toString() ?? '';
        final deviceId = decoded['deviceId']?.toString() ?? '';
        final createdAt = DateTime.tryParse(
          decoded['createdAt']?.toString() ?? '',
        );

        if (type == 'vidra_worker_pairing_request' &&
            deviceName.isNotEmpty &&
            deviceId.isNotEmpty &&
            createdAt != null) {
          return WorkerPairingQrPayload(
            deviceName: deviceName,
            phoneNumber: phoneNumber,
            deviceId: deviceId,
            createdAt: createdAt,
          );
        }
      }
    } catch (_) {}

    return null;
  }
}

class DevicePairingService {
  static const String defaultServerUrl = 'http://45.80.68.83:3000';

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
        final state = DevicePairingState.fromJson(
          Map<String, dynamic>.from(decoded),
        );
        return _normalizeLoadedState(state);
      }
    } catch (_) {}

    return const DevicePairingState.empty();
  }

  Future<DevicePairingState> createMainPhonePairCode({
    required String deviceName,
    String phoneNumber = '',
    String pairedDeviceName = '',
    String pairedPhoneNumber = '',
  }) async {
    final pairCode = _generatePairCode();
    final relayUrl = _buildRelayUrl(pairCode);
    final cleanDeviceName = _cleanName(
      deviceName,
      fallback: 'Главный телефон',
    );

    final state = DevicePairingState(
      role: DevicePairingRole.mainPhone,
      status: DevicePairingStatus.waitingForWorker,
      deviceName: cleanDeviceName,
      phoneNumber: _cleanPhoneNumber(phoneNumber),
      pairCode: pairCode,
      pairedDeviceName: pairedDeviceName.trim(),
      pairedPhoneNumber: _cleanPhoneNumber(pairedPhoneNumber),
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
    String phoneNumber = '',
    required String pairCode,
  }) async {
    final cleanedCode = _cleanPairCode(pairCode);

    if (!_isValidPairCode(cleanedCode)) {
      throw const DevicePairingException(
        'Введите код из 6 цифр с главного телефона.',
      );
    }

    final relayUrl = _buildRelayUrl(cleanedCode);
    final cleanDeviceName = _cleanName(
      deviceName,
      fallback: 'Телефон передачи',
    );
    final cleanPhoneNumber = _cleanPhoneNumber(phoneNumber);
    final deviceId = await _getOrCreateDeviceId();

    final state = DevicePairingState(
      role: DevicePairingRole.workerPhone,
      status: DevicePairingStatus.paired,
      deviceName: cleanDeviceName,
      phoneNumber: cleanPhoneNumber,
      pairCode: cleanedCode,
      pairedDeviceName: 'Главный телефон',
      pairedPhoneNumber: '',
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

    final isRegistered = await _sendWorkerPairingEvent(
      relayUrl: relayUrl,
      relayApiKey: _relayApiKey,
      pairCode: cleanedCode,
      deviceName: cleanDeviceName,
      phoneNumber: cleanPhoneNumber,
      deviceId: deviceId,
    );

    if (!isRegistered) {
      throw const DevicePairingException(
        'Рабочий телефон сохранил код, но не смог отправить подтверждение '
            'на главный телефон.\nПроверьте интернет и попробуйте ещё раз.',
      );
    }

    return state;
  }

  Future<DevicePairingState> connectWorkerPhoneFromQr({
    required String deviceName,
    String phoneNumber = '',
    required DevicePairingQrPayload payload,
  }) {
    return connectWorkerPhone(
      deviceName: deviceName,
      phoneNumber: phoneNumber,
      pairCode: payload.pairCode,
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
    if (workerName.trim().isEmpty) {
      throw const DevicePairingException(
        'Телефон передачи ещё не подключился по этому коду.',
      );
    }

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

    final syncedState = await syncRemoteUnpair();
    if (!syncedState.isMainPhone) {
      return syncedState;
    }

    if (syncedState.isPaired && syncedState.pairedDeviceName.trim().isNotEmpty) {
      return syncedState;
    }

    final workerName = await detectWorkerDeviceName(syncedState);
    if (workerName.trim().isEmpty) {
      return syncedState;
    }

    final state = syncedState.copyWith(
      status: DevicePairingStatus.paired,
      pairedDeviceName: workerName,
    );

    await _saveState(state);
    await _saveMainPhoneSettings(state);

    return state;
  }

  Future<DevicePairingState> syncRemoteUnpair() async {
    final currentState = await loadState();

    if (!currentState.isPaired || currentState.relayUrl.trim().isEmpty) {
      return currentState;
    }

    final deviceId = await _getOrCreateDeviceId();
    final hasRemoteUnpair = await _hasRemoteUnpairEvent(
      state: currentState,
      localDeviceId: deviceId,
    );

    if (!hasRemoteUnpair) {
      return currentState;
    }

    await resetPairing(notifyRemote: false);
    return const DevicePairingState.empty();
  }

  DevicePairingQrPayload createQrPayload(DevicePairingState state) {
    if (!state.isMainPhone ||
        state.pairCode.trim().isEmpty ||
        state.relayUrl.trim().isEmpty) {
      throw const DevicePairingException(
        'Сначала создайте код на главном телефоне.',
      );
    }

    return DevicePairingQrPayload(
      pairCode: state.pairCode,
      serverUrl: defaultServerUrl,
      mainDeviceName: state.deviceName,
    );
  }

  Future<WorkerPairingQrPayload> createWorkerQrPayload({
    required String deviceName,
    String phoneNumber = '',
  }) async {
    final cleanDeviceName = _cleanName(
      deviceName,
      fallback: 'Телефон передачи',
    );
    final deviceId = await _getOrCreateDeviceId();

    return WorkerPairingQrPayload(
      deviceName: cleanDeviceName,
      phoneNumber: _cleanPhoneNumber(phoneNumber),
      deviceId: deviceId,
      createdAt: DateTime.now(),
    );
  }

  Future<String> detectWorkerDeviceName(DevicePairingState state) async {
    final events = await _loadRelayEvents(state.relayUrl);

    for (final event in events) {
      if (!_isValidWorkerEventForState(event, state)) {
        continue;
      }

      final deviceName = event['deviceName']?.toString().trim() ?? '';
      if (deviceName.isNotEmpty && deviceName != state.deviceName) {
        return deviceName;
      }
    }

    return '';
  }

  Future<void> resetPairing({bool notifyRemote = true}) async {
    final currentState = await loadState();

    if (notifyRemote && currentState.isPaired) {
      await sendUnpairEvent(currentState);
    }

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

  Future<bool> sendUnpairEvent(
      DevicePairingState state, {
        String targetDeviceId = '',
      }) async {
    if (state.relayUrl.trim().isEmpty || state.pairCode.trim().isEmpty) {
      return false;
    }

    final localDeviceId = await _getOrCreateDeviceId();
    final now = DateTime.now();

    final payload = {
      'type': 'unpair',
      'eventType': 'unpair',
      'source': 'flutter',
      'client': 'vidra',
      'pairCode': state.pairCode,
      'deviceName': state.deviceName,
      'phoneNumber': state.phoneNumber,
      'deviceId': localDeviceId,
      'targetDeviceId': targetDeviceId.trim(),
      'sender': state.phoneNumber,
      'title': 'VidRA unpair',
      'body': 'Связка телефонов сброшена',
      'message': 'Связка телефонов сброшена',
      'receivedAt': now.millisecondsSinceEpoch,
      'sentAt': now.millisecondsSinceEpoch,
      'createdAt': now.toIso8601String(),
    };

    final sentToPairUrl = await _postJson(
      relayUrl: state.relayUrl,
      relayApiKey: state.relayApiKey,
      payload: payload,
    );

    if (sentToPairUrl) {
      return true;
    }

    final fallbackUrl = _buildEventsFallbackUrl(state.relayUrl);
    if (fallbackUrl.isEmpty || fallbackUrl == state.relayUrl) {
      return false;
    }

    return _postJson(
      relayUrl: fallbackUrl,
      relayApiKey: state.relayApiKey,
      payload: payload,
    );
  }

  DevicePairingState _normalizeLoadedState(DevicePairingState state) {
    if (!state.isMainPhone || !state.isPaired) {
      return state;
    }

    final pairedName = state.pairedDeviceName.trim();

    if (pairedName.isEmpty ||
        pairedName == 'Рабочий телефон' ||
        pairedName == 'Телефон передачи') {
      return state.copyWith(
        status: DevicePairingStatus.waitingForWorker,
        pairedDeviceName: '',
        pairedPhoneNumber: '',
      );
    }

    return state;
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

  Future<bool> _sendWorkerPairingEvent({
    required String relayUrl,
    required String relayApiKey,
    required String pairCode,
    required String deviceName,
    required String phoneNumber,
    required String deviceId,
  }) async {
    final now = DateTime.now();

    final payload = {
      'type': 'pairing',
      'eventType': 'pairing',
      'source': 'flutter',
      'client': 'vidra',
      'pairCode': pairCode,
      'deviceName': deviceName,
      'phoneNumber': phoneNumber,
      'deviceId': deviceId,
      'sender': phoneNumber,
      'title': 'VidRA pairing',
      'body': 'Рабочий телефон подключён',
      'message': 'Рабочий телефон подключён',
      'receivedAt': now.millisecondsSinceEpoch,
      'sentAt': now.millisecondsSinceEpoch,
      'createdAt': now.toIso8601String(),
    };

    final sentToPairUrl = await _postJson(
      relayUrl: relayUrl,
      relayApiKey: relayApiKey,
      payload: payload,
    );

    if (sentToPairUrl) {
      return true;
    }

    final fallbackUrl = _buildEventsFallbackUrl(relayUrl);
    if (fallbackUrl.isEmpty || fallbackUrl == relayUrl) {
      return false;
    }

    return _postJson(
      relayUrl: fallbackUrl,
      relayApiKey: relayApiKey,
      payload: payload,
    );
  }

  Future<bool> _postJson({
    required String relayUrl,
    required String relayApiKey,
    required Map<String, dynamic> payload,
  }) async {
    final cleanedRelayUrl = relayUrl.trim();

    if (cleanedRelayUrl.isEmpty) {
      return false;
    }

    HttpClient? client;

    try {
      final uri = Uri.parse(cleanedRelayUrl);
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);

      final request = await client.postUrl(uri).timeout(
        const Duration(seconds: 8),
      );

      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json; charset=utf-8',
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.userAgentHeader, 'VidRA-Flutter');

      if (relayApiKey.trim().isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer ${relayApiKey.trim()}',
        );
        request.headers.set('X-Api-Key', relayApiKey.trim());
      }

      request.write(jsonEncode(payload));

      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      await response.drain();

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  Future<List<Map<String, dynamic>>> _loadRelayEvents(String relayUrl) async {
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
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return [];
    } finally {
      client?.close(force: true);
    }
  }

  List<dynamic> _extractEventsList(Object? decoded) {
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

  bool _isValidWorkerEventForState(
      Map<String, dynamic> event,
      DevicePairingState state,
      ) {
    final eventType = _eventType(event);
    if (eventType == 'unpair') {
      return false;
    }

    final deviceName = event['deviceName']?.toString().trim() ?? '';
    if (deviceName.isEmpty) {
      return false;
    }

    if (deviceName == state.deviceName) {
      return false;
    }

    final pairCode = event['pairCode']?.toString().trim() ?? '';
    if (pairCode.isNotEmpty && pairCode != state.pairCode) {
      return false;
    }

    final createdAt = state.createdAt;
    if (createdAt == null) {
      return true;
    }

    final receivedAt = _eventReceivedAt(event);
    if (receivedAt == null) {
      return true;
    }

    return !receivedAt.isBefore(
      createdAt.subtract(const Duration(seconds: 10)),
    );
  }

  Future<bool> _hasRemoteUnpairEvent({
    required DevicePairingState state,
    required String localDeviceId,
  }) async {
    final events = await _loadRelayEvents(state.relayUrl);

    for (final event in events) {
      if (!_isValidUnpairEventForState(
        event: event,
        state: state,
        localDeviceId: localDeviceId,
      )) {
        continue;
      }

      return true;
    }

    return false;
  }

  bool _isValidUnpairEventForState({
    required Map<String, dynamic> event,
    required DevicePairingState state,
    required String localDeviceId,
  }) {
    if (_eventType(event) != 'unpair') {
      return false;
    }

    final pairCode = event['pairCode']?.toString().trim() ?? '';
    if (pairCode.isNotEmpty && pairCode != state.pairCode) {
      return false;
    }

    final eventDeviceId = event['deviceId']?.toString().trim() ?? '';
    if (eventDeviceId.isNotEmpty && eventDeviceId == localDeviceId) {
      return false;
    }

    final targetDeviceId = event['targetDeviceId']?.toString().trim() ?? '';
    if (targetDeviceId.isNotEmpty && targetDeviceId != localDeviceId) {
      return false;
    }

    final createdAt = state.createdAt;
    if (createdAt == null) {
      return true;
    }

    final receivedAt = _eventReceivedAt(event);
    if (receivedAt == null) {
      return true;
    }

    return !receivedAt.isBefore(
      createdAt.subtract(const Duration(seconds: 10)),
    );
  }

  String _eventType(Map<String, dynamic> event) {
    return (event['eventType'] ?? event['type'] ?? '').toString().trim();
  }

  DateTime? _eventReceivedAt(Map<String, dynamic> event) {
    final rawReceivedAt = event['receivedAt'];

    if (rawReceivedAt is int) {
      return DateTime.fromMillisecondsSinceEpoch(rawReceivedAt);
    }

    if (rawReceivedAt is num) {
      return DateTime.fromMillisecondsSinceEpoch(rawReceivedAt.toInt());
    }

    final asInt = int.tryParse(rawReceivedAt?.toString() ?? '');
    if (asInt != null && asInt > 0) {
      return DateTime.fromMillisecondsSinceEpoch(asInt);
    }

    return DateTime.tryParse(
      event['createdAt']?.toString() ??
          event['timestamp']?.toString() ??
          event['time']?.toString() ??
          '',
    );
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

  String _buildRelayUrl(String pairCode) {
    final base = defaultServerUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base/events/$pairCode';
  }

  String _buildEventsFallbackUrl(String relayUrl) {
    try {
      final uri = Uri.parse(relayUrl);
      if (!uri.hasScheme || uri.host.isEmpty) {
        return '';
      }

      return Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
        path: '/events',
      ).toString();
    } catch (_) {
      return '';
    }
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

  String _cleanPhoneNumber(String value) {
    return value.trim();
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