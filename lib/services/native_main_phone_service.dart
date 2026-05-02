import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

class NativeMainPhoneService {
  static const MethodChannel _channel = MethodChannel('vidra/android_permissions');
  static const EventChannel _eventsChannel = EventChannel('vidra/native_events');

  const NativeMainPhoneService();

  Stream<void> get messageUpdates {
    return _eventsChannel.receiveBroadcastStream().where((event) {
      return event == 'messagesUpdated';
    }).map((_) => null);
  }

  Future<bool> requestSmsPermissions() async {
    return _invokeBool('requestSmsPermissions');
  }

  Future<bool> hasSmsPermissions() async {
    return _invokeBool('hasSmsPermissions');
  }

  Future<bool> requestPostNotificationPermission() async {
    return _invokeBool('requestPostNotificationPermission');
  }

  Future<bool> hasPostNotificationPermission() async {
    return _invokeBool('hasPostNotificationPermission');
  }

  Future<bool> isNotificationListenerEnabled() async {
    return _invokeBool('isNotificationListenerEnabled');
  }

  Future<void> openNotificationListenerSettings() async {
    await _channel.invokeMethod('openNotificationListenerSettings');
  }

  Future<bool> isBatteryOptimizationDisabled() async {
    return _invokeBool('isBatteryOptimizationDisabled');
  }

  Future<void> openBatteryOptimizationSettings() async {
    await _channel.invokeMethod('openBatteryOptimizationSettings');
  }

  Future<void> openAppSettings() async {
    await _channel.invokeMethod('openAppSettings');
  }

  Future<MainPhoneNativeStatus> getStatus() async {
    try {
      final value = await _channel.invokeMethod<String>('getMainPhoneStatus');
      final map = jsonDecode(value ?? '{}') as Map<String, dynamic>;

      return MainPhoneNativeStatus.fromJson(map);
    } catch (_) {
      return const MainPhoneNativeStatus();
    }
  }

  Future<MainPhoneFilterSettings> getFilterSettings() async {
    try {
      final value = await _channel.invokeMethod<String>('getFilterSettings');
      final map = jsonDecode(value ?? '{}') as Map<String, dynamic>;

      return MainPhoneFilterSettings.fromJson(map);
    } catch (_) {
      return const MainPhoneFilterSettings();
    }
  }

  Future<void> saveFilterSettings(MainPhoneFilterSettings settings) async {
    await _channel.invokeMethod('saveFilterSettings', settings.toJson());
  }

  Future<List<NativeForwardedMessage>> getMessages() async {
    try {
      final value = await _channel.invokeMethod<String>('getNativeMessages');
      final list = jsonDecode(value ?? '[]') as List;

      final messages = list
          .whereType<Map>()
          .map((item) {
        return NativeForwardedMessage.fromJson(
          Map<String, dynamic>.from(item),
        );
      })
          .where((message) {
        return message.type.isNotEmpty &&
            (message.text.isNotEmpty ||
                message.title.isNotEmpty ||
                message.sender.isNotEmpty ||
                message.app.isNotEmpty);
      })
          .toList();

      messages.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));

      return _removeDuplicates(messages);
    } catch (_) {
      return [];
    }
  }

  Future<void> clearMessages() async {
    await _channel.invokeMethod('clearNativeMessages');
  }

  Future<bool> _invokeBool(String method) async {
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } catch (_) {
      return false;
    }
  }

  List<NativeForwardedMessage> _removeDuplicates(
      List<NativeForwardedMessage> messages,
      ) {
    final seen = <String>{};
    final uniqueMessages = <NativeForwardedMessage>[];

    for (final message in messages) {
      final key = message.dedupeKey;

      if (seen.contains(key)) {
        continue;
      }

      seen.add(key);
      uniqueMessages.add(message);
    }

    return uniqueMessages;
  }
}

class MainPhoneFilterSettings {
  final bool verificationCodes;
  final bool bankMessages;
  final bool adSms;
  final bool internationalNumbers;
  final bool cryptoSpam;
  final bool blacklist;

  const MainPhoneFilterSettings({
    this.verificationCodes = true,
    this.bankMessages = true,
    this.adSms = false,
    this.internationalNumbers = true,
    this.cryptoSpam = false,
    this.blacklist = true,
  });

  factory MainPhoneFilterSettings.fromJson(Map<String, dynamic> json) {
    return MainPhoneFilterSettings(
      verificationCodes: json['verificationCodes'] != false,
      bankMessages: json['bankMessages'] != false,
      adSms: json['adSms'] == true,
      internationalNumbers: json['internationalNumbers'] != false,
      cryptoSpam: json['cryptoSpam'] == true,
      blacklist: json['blacklist'] != false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'verificationCodes': verificationCodes,
      'bankMessages': bankMessages,
      'adSms': adSms,
      'internationalNumbers': internationalNumbers,
      'cryptoSpam': cryptoSpam,
      'blacklist': blacklist,
    };
  }

  MainPhoneFilterSettings copyWith({
    bool? verificationCodes,
    bool? bankMessages,
    bool? adSms,
    bool? internationalNumbers,
    bool? cryptoSpam,
    bool? blacklist,
  }) {
    return MainPhoneFilterSettings(
      verificationCodes: verificationCodes ?? this.verificationCodes,
      bankMessages: bankMessages ?? this.bankMessages,
      adSms: adSms ?? this.adSms,
      internationalNumbers: internationalNumbers ?? this.internationalNumbers,
      cryptoSpam: cryptoSpam ?? this.cryptoSpam,
      blacklist: blacklist ?? this.blacklist,
    );
  }
}

class MainPhoneNativeStatus {
  final bool smsPermission;
  final bool postNotificationPermission;
  final bool notificationListener;
  final bool batteryOptimizationDisabled;
  final bool smsForwarding;
  final bool pushForwarding;
  final bool backgroundMode;
  final bool onlyWithInternet;
  final bool relayConfigured;
  final String deviceName;
  final String deviceId;
  final int smsCount;
  final int pushCount;

  const MainPhoneNativeStatus({
    this.smsPermission = false,
    this.postNotificationPermission = false,
    this.notificationListener = false,
    this.batteryOptimizationDisabled = false,
    this.smsForwarding = true,
    this.pushForwarding = true,
    this.backgroundMode = true,
    this.onlyWithInternet = false,
    this.relayConfigured = false,
    this.deviceName = '',
    this.deviceId = '',
    this.smsCount = 0,
    this.pushCount = 0,
  });

  factory MainPhoneNativeStatus.fromJson(Map<String, dynamic> json) {
    return MainPhoneNativeStatus(
      smsPermission: json['smsPermission'] == true,
      postNotificationPermission: json['postNotificationPermission'] == true,
      notificationListener: json['notificationListener'] == true,
      batteryOptimizationDisabled: json['batteryOptimizationDisabled'] == true,
      smsForwarding: json['smsForwarding'] != false,
      pushForwarding: json['pushForwarding'] != false,
      backgroundMode: json['backgroundMode'] != false,
      onlyWithInternet: json['onlyWithInternet'] == true,
      relayConfigured: json['relayConfigured'] == true,
      deviceName: (json['deviceName'] ?? '').toString(),
      deviceId: (json['deviceId'] ?? '').toString(),
      smsCount: _toInt(json['smsCount']),
      pushCount: _toInt(json['pushCount']),
    );
  }

  int get totalCount => smsCount + pushCount;

  bool get isReadyForSms => smsPermission && smsForwarding;

  bool get isReadyForPush => notificationListener && pushForwarding;

  bool get isFullyReady {
    return isReadyForSms && isReadyForPush && batteryOptimizationDisabled;
  }

  static int _toInt(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class NativeForwardedMessage {
  final String id;
  final String type;
  final String sender;
  final String app;
  final String packageName;
  final String title;
  final String text;
  final String deviceName;
  final String deviceId;
  final String status;
  final int receivedAt;

  const NativeForwardedMessage({
    required this.id,
    required this.type,
    required this.sender,
    required this.app,
    required this.packageName,
    required this.title,
    required this.text,
    required this.deviceName,
    required this.deviceId,
    required this.status,
    required this.receivedAt,
  });

  factory NativeForwardedMessage.fromJson(Map<String, dynamic> json) {
    return NativeForwardedMessage(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      sender: (json['sender'] ?? '').toString(),
      app: (json['app'] ?? '').toString(),
      packageName: (json['packageName'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      deviceName: (json['deviceName'] ?? '').toString(),
      deviceId: (json['deviceId'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      receivedAt: MainPhoneNativeStatus._toInt(json['receivedAt']),
    );
  }

  bool get isSms => type == 'sms';

  bool get isPush => type == 'push';

  String get displayTitle {
    if (isSms) {
      return sender.isEmpty ? 'SMS' : sender;
    }

    if (title.isNotEmpty) {
      return title;
    }

    if (app.isNotEmpty) {
      return app;
    }

    return sender.isEmpty ? 'PUSH' : sender;
  }

  String get displaySubtitle {
    if (isSms) {
      return text;
    }

    if (text.isNotEmpty) {
      return text;
    }

    return packageName;
  }

  String get dedupeKey {
    return [
      type.trim().toLowerCase(),
      sender.trim().toLowerCase(),
      app.trim().toLowerCase(),
      packageName.trim().toLowerCase(),
      title.trim().toLowerCase(),
      text.trim().toLowerCase(),
    ].join('|');
  }
}