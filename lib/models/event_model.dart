class EventModel {
  final String title;
  final String time;
  final EventType type;

  const EventModel({
    required this.title,
    required this.time,
    required this.type,
  });
}

enum EventType {
  device,
  sms,
  push,
  error,
  warning,
}