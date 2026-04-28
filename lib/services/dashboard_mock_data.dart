import '../models/device_model.dart';
import '../models/event_model.dart';

class DashboardMockData {
  static List<DeviceModel> devices = const [
    DeviceModel(
      name: 'Redmi Note 11',
      system: 'Android 13',
      isOnline: true,
      lastSeen: '10:45',
      battery: '87%',
    ),
    DeviceModel(
      name: 'Samsung S21',
      system: 'Android 12',
      isOnline: true,
      lastSeen: '10:43',
      battery: '65%',
    ),
    DeviceModel(
      name: 'iPhone 12',
      system: 'iOS 16.3',
      isOnline: true,
      lastSeen: '10:42',
      battery: '75%',
    ),
    DeviceModel(
      name: 'Pixel 6',
      system: 'Android 14',
      isOnline: false,
      lastSeen: 'Вчера 22:15',
      battery: '-',
    ),
    DeviceModel(
      name: 'OnePlus 9',
      system: 'Android 11',
      isOnline: false,
      lastSeen: '2 дня назад',
      battery: '-',
    ),
  ];

  static List<EventModel> events = const [
    EventModel(
      title: 'Redmi Note 11 подключился',
      time: '10:45:12',
      type: EventType.device,
    ),
    EventModel(
      title: 'SMS от +7 999 123-45-67',
      time: '10:45:10',
      type: EventType.sms,
    ),
    EventModel(
      title: 'PUSH уведомление отправлено',
      time: '10:44:55',
      type: EventType.push,
    ),
    EventModel(
      title: 'Ошибка отправки SMS на iPhone 12',
      time: '10:44:32',
      type: EventType.error,
    ),
    EventModel(
      title: 'Устройство iPhone 12 отключено',
      time: '10:44:10',
      type: EventType.warning,
    ),
  ];
}