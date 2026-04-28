class DeviceModel {
  final String name;
  final String system;
  final bool isOnline;
  final String lastSeen;
  final String battery;

  const DeviceModel({
    required this.name,
    required this.system,
    required this.isOnline,
    required this.lastSeen,
    required this.battery,
  });
}