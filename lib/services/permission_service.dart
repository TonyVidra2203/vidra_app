class PermissionService {
  Future<bool> requestSmsPermission() async {
    // Позже здесь будет запрос разрешения на чтение SMS.
    return false;
  }

  Future<bool> requestNotificationPermission() async {
    // Позже здесь будет запрос разрешения на уведомления.
    return false;
  }

  Future<bool> checkSmsPermission() async {
    // Позже здесь будет проверка разрешения SMS.
    return false;
  }

  Future<bool> checkNotificationPermission() async {
    // Позже здесь будет проверка разрешения уведомлений.
    return false;
  }
}