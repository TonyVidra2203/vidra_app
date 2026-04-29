import '../models/message_model.dart';

class SmsService {
  Future<List<MessageModel>> getInitialMessages() async {
    return [];
  }

  Future<bool> requestSmsPermission() async {
    return false;
  }

  Future<void> startListening() async {
    // Позже здесь подключим реальное прослушивание SMS.
  }

  Future<void> stopListening() async {
    // Позже здесь остановим прослушивание SMS.
  }
}