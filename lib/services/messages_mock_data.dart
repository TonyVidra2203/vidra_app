import '../models/message_model.dart';

class MessagesMockData {
  static final List<MessageModel> messages = [
    MessageModel(
      sender: '+7 999 123-45-67',
      text: 'Ваш код подтверждения: 1234',
      deviceName: 'Redmi Note 11',
      time: '10:45',
      date: DateTime.now(),
      type: MessageType.sms,
      status: MessageStatus.received,
    ),
    MessageModel(
      sender: 'Telegram',
      text: 'Новое сообщение от пользователя',
      deviceName: 'Samsung S21',
      time: '10:44',
      date: DateTime.now(),
      type: MessageType.push,
      status: MessageStatus.received,
    ),
    MessageModel(
      sender: 'Bank',
      text: 'Списание 500₽',
      deviceName: 'iPhone 12',
      time: '18:20',
      date: DateTime.now().subtract(const Duration(days: 1)),
      type: MessageType.sms,
      status: MessageStatus.sent,
    ),
    MessageModel(
      sender: 'System',
      text: 'Ошибка отправки PUSH',
      deviceName: 'Pixel 6',
      time: '09:10',
      date: DateTime.now().subtract(const Duration(days: 1)),
      type: MessageType.push,
      status: MessageStatus.error,
    ),
  ];
}