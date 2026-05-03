import 'dart:convert';
import 'dart:math';

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
  final DateTime? createdAt;

  const DevicePairingState({
    required this.role,
    required this.status,
    required this.deviceName,
    required this.pairCode,
    required this.pairedDeviceName,
    required this.createdAt,
  });

  const DevicePairingState.empty()
      : role = DevicePairingRole.none,
        status = DevicePairingStatus.notPaired,
        deviceName = '',
        pairCode = '',
        pairedDeviceName = '',
        createdAt = null;

  bool get hasPairCode => pairCode.isNotEmpty;

  bool get isMainPhone => role == DevicePairingRole.mainPhone;

  bool get isWorkerPhone => role == DevicePairingRole.workerPhone;

  bool get isPaired => status == DevicePairingStatus.paired;

  Map<String, Object?> toJson() {
    return {
      'role': role.name,
      'status': status.name,
      'deviceName': deviceName,
      'pairCode': pairCode,
      'pairedDeviceName': pairedDeviceName,
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
  static const String _storageKey = 'device_pairing_state';

  Future<DevicePairingState> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString(_storageKey);

    if (rawValue == null || rawValue.isEmpty) {
      return const DevicePairingState.empty();
    }

    try {
      final decoded = jsonDecode(rawValue);

      if (decoded is Map<String, Object?>) {
        return DevicePairingState.fromJson(decoded);
      }

      if (decoded is Map) {
        return DevicePairingState.fromJson(
          decoded.map(
                (key, value) => MapEntry(key.toString(), value),
          ),
        );
      }

      return const DevicePairingState.empty();
    } catch (_) {
      return const DevicePairingState.empty();
    }
  }

  Future<DevicePairingState> createMainPhonePairCode({
    required String deviceName,
  }) async {
    final state = DevicePairingState(
      role: DevicePairingRole.mainPhone,
      status: DevicePairingStatus.waitingForWorker,
      deviceName: _cleanName(deviceName),
      pairCode: _generatePairCode(),
      pairedDeviceName: '',
      createdAt: DateTime.now(),
    );

    await _saveState(state);
    return state;
  }

  Future<DevicePairingState> connectWorkerPhone({
    required String deviceName,
    required String pairCode,
  }) async {
    final cleanedCode = _cleanPairCode(pairCode);

    if (!_isValidPairCode(cleanedCode)) {
      throw const DevicePairingException(
        'Введите код из 6 цифр с главного телефона.',
      );
    }

    final state = DevicePairingState(
      role: DevicePairingRole.workerPhone,
      status: DevicePairingStatus.paired,
      deviceName: _cleanName(deviceName),
      pairCode: cleanedCode,
      pairedDeviceName: 'Главный телефон',
      createdAt: DateTime.now(),
    );

    await _saveState(state);
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
      pairedDeviceName: _cleanName(workerDeviceName),
      createdAt: currentState.createdAt,
    );

    await _saveState(state);
    return state;
  }

  Future<void> resetPairing() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  Future<void> _saveState(DevicePairingState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(state.toJson()));
  }

  String _generatePairCode() {
    final random = Random.secure();
    final value = 100000 + random.nextInt(900000);
    return value.toString();
  }

  String _cleanName(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return 'Этот телефон';
    }

    return trimmed;
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