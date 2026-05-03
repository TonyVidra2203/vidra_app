import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NativeMainPhoneService {
  static const MethodChannel _channel = MethodChannel(
    'vidra/android_permissions',
  );

  static const EventChannel _eventsChannel = EventChannel(
    'vidra/native_events',
  );

  static const String _relayUrlKey = 'sender_relay_url';
  static const String _relayApiKeyKey = 'sender_relay_api_key';

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
      final map = jsonDecode(value ?? '{}') as Map;

      return MainPhoneNativeStatus.fromJson(map);
    } catch (_) {
      return const MainPhoneNativeStatus();
    }
  }

  Future<MainPhoneFilterSettings> getFilterSettings() async {
    try {
      final value = await _channel.invokeMethod<String>('getFilterSettings');
      final map = jsonDecode(value ?? '{}') as Map;

      return MainPhoneFilterSettings.fromJson(map);
    } catch (_) {
      return const MainPhoneFilterSettings();
    }
  }

  Future<void> saveFilterSettings(MainPhoneFilterSettings settings) async {
    await _channel.invokeMethod('saveFilterSettings', settings.toJson());
  }

  Future<List<NativeForwardedMessage>> getMessages() async {
    final localMessages = await _getLocalMessages();
    final relayMessages = await _getRelayMessages();

    final messages = [
      ...relayMessages,
      ...localMessages,
    ];

    messages.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));

    return _removeDuplicates(messages);
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

  Future<List<NativeForwardedMessage>> _getLocalMessages() async {
    try {
      final value = await _channel.invokeMethod<String>('getNativeMessages');

      return _parseMessages(value ?? '[]');
    } catch (_) {
      return [];
    }
  }

  Future<List<NativeForwardedMessage>> _getRelayMessages() async {
    final prefs = await SharedPreferences.getInstance();

    final relayUrl = prefs.getString(_relayUrlKey)?.trim() ?? '';
    final relayApiKey = prefs.getString(_relayApiKeyKey)?.trim() ?? '';

    if (relayUrl.isEmpty) {
      return [];
    }

    HttpClient? client;

    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);

      final request = await client.getUrl(Uri.parse(relayUrl)).timeout(
        const Duration(seconds: 8),
      );

      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.userAgentHeader, 'VidRA-Android');

      if (relayApiKey.isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $relayApiKey',
        );
        request.headers.set('X-Api-Key', relayApiKey);
      }

      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return [];
      }

      final body = await response.transform(utf8.decoder).join();

      return _parseMessages(body);
    } catch (_) {
      return [];
    } finally {
      client?.close(force: true);
    }
  }

  List<NativeForwardedMessage> _parseMessages(String rawValue) {
    try {
      final decoded = jsonDecode(rawValue);
      final list = _extractMessageList(decoded);

      return list
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
    } catch (_) {
      return [];
    }
  }

  List _extractMessageList(Object? decoded) {
    if (decoded is List) {
      return decoded;
    }

    if (decoded is Map) {
      final messages = decoded['messages'];
      if (messages is List) {
        return messages;
      }

      final events = decoded['events'];
      if (events is List) {
        return events;
      }

      final data = decoded['data'];
      if (data is List) {
        return data;
      }

      if (data is Map) {
        final dataMessages = data['messages'];
        if (dataMessages is List) {
          return dataMessages;
        }

        final dataEvents = data['events'];
        if (dataEvents is List) {
          return dataEvents;
        }
      }
    }

    return [];
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

  factory MainPhoneFilterSettings.fromJson(Map json) {
    return MainPhoneFilterSettings(
      verificationCodes: json['verificationCodes'] != false,
      bankMessages: json['bankMessages'] != false,
      adSms: json['adSms'] == true,
      internationalNumbers: json['internationalNumbers'] != false,
      cryptoSpam: json['cryptoSpam'] == true,
      blacklist: json['blacklist'] != false,
    );
  }

  Map<String, bool> toJson() {
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

  factory MainPhoneNativeStatus.fromJson(Map json) {
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
  final String deviceBrand;
  final String deviceModel;
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
    required this.deviceBrand,
    required this.deviceModel,
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
      deviceBrand: (json['deviceBrand'] ?? '').toString(),
      deviceModel: (json['deviceModel'] ?? '').toString(),
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
    if (id.trim().isNotEmpty) {
      return id.trim();
    }

    return [
      type.trim().toLowerCase(),
      sender.trim().toLowerCase(),
      app.trim().toLowerCase(),
      packageName.trim().toLowerCase(),
      title.trim().toLowerCase(),
      text.trim().toLowerCase(),
      receivedAt.toString(),
    ].join('|');
  }
}