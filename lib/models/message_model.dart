enum MessageType {
  sms,
  push,
}

enum MessageStatus {
  received,
  sent,
  error,
}

class MessageModel {
  final String sender;
  final String text;
  final String deviceName;
  final String time;
  final MessageType type;
  final MessageStatus status;
  final DateTime date;

  const MessageModel({
    required this.sender,
    required this.text,
    required this.deviceName,
    required this.time,
    required this.type,
    required this.status,
    required this.date,
  });
}