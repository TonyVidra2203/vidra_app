import '../models/device_model.dart';
import '../models/event_model.dart';

class DashboardMockData {
  static const List<DeviceModel> devices = [
    DeviceModel(
      id: 'samsung-a52',
      name: 'Samsung A52',
      system: 'Android 13',
      isOnline: true,
      lastSeen: 'Сейчас',
      battery: '82%',
      phoneNumber: '+7 999 111-22-33',
    ),
    DeviceModel(
      id: 'xiaomi-redmi-note-11',
      name: 'Xiaomi Redmi Note 11',
      system: 'Android 12',
      isOnline: true,
      lastSeen: '2 мин. назад',
      battery: '64%',
      phoneNumber: '+7 999 222-33-44',
    ),
    DeviceModel(
      id: 'pixel-6a',
      name: 'Google Pixel 6a',
      system: 'Android 14',
      isOnline: false,
      lastSeen: '1 ч. назад',
      battery: '41%',
      phoneNumber: '+7 999 333-44-55',
    ),
    DeviceModel(
      id: 'huawei-p30',
      name: 'Huawei P30',
      system: 'Android 10',
      isOnline: false,
      lastSeen: '3 ч. назад',
      battery: '28%',
      phoneNumber: '+7 999 444-55-66',
    ),
    DeviceModel(
      id: 'oppo-reno-8',
      name: 'OPPO Reno 8',
      system: 'Android 13',
      isOnline: true,
      lastSeen: '5 мин. назад',
      battery: '91%',
      phoneNumber: '+7 999 555-66-77',
    ),
  ];

  static const List<EventModel> events = [
    EventModel(
      title: 'SMS от Samsung A52',
      time: '12:42:10',
      type: EventType.sms,
    ),
    EventModel(
      title: 'PUSH от Xiaomi Redmi Note 11',
      time: '12:40:03',
      type: EventType.push,
    ),
    EventModel(
      title: 'Samsung A52 подключён',
      time: '12:35:18',
      type: EventType.device,
    ),
    EventModel(
      title: 'Google Pixel 6a offline',
      time: '11:28:44',
      type: EventType.warning,
    ),
  ];
}