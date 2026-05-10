class DeviceModel {
  final String id;
  final String name;
  final String system;
  final bool isOnline;
  final String lastSeen;
  final String battery;
  final String phoneNumber;

  const DeviceModel({
    required this.id,
    required this.name,
    required this.system,
    required this.isOnline,
    required this.lastSeen,
    required this.battery,
    this.phoneNumber = 'Не указан',
  });
}