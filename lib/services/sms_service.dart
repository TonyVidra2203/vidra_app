import '../models/message_model.dart';
import 'device_pairing_service.dart';

class SmsService {
  final DevicePairingService _pairingService = DevicePairingService();

  bool _isListening = false;

  bool get isListening => _isListening;

  Future<List<MessageModel>> getInitialMessages() async {
    return [];
  }

  Future<bool> requestSmsPermission() async {
    final pairingState = await _pairingService.loadState();

    if (!pairingState.isWorkerPhone || !pairingState.isPaired) {
      return false;
    }

    return false;
  }

  Future<bool> canListenSms() async {
    final pairingState = await _pairingService.loadState();

    return pairingState.isWorkerPhone && pairingState.isPaired;
  }

  Future<void> startListening() async {
    final canListen = await canListenSms();

    if (!canListen) {
      _isListening = false;
      return;
    }

    _isListening = true;

    // Позже здесь подключим реальное прослушивание SMS.
  }

  Future<void> stopListening() async {
    _isListening = false;

    // Позже здесь остановим прослушивание SMS.
  }
}