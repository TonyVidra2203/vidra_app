enum AppMode {
  receiver,
  sender,
}

extension AppModeTitle on AppMode {
  String get title {
    switch (this) {
      case AppMode.receiver:
        return 'Главный телефон';
      case AppMode.sender:
        return 'Рабочий телефон';
    }
  }

  String get subtitle {
    switch (this) {
      case AppMode.receiver:
        return 'Принимает и показывает SMS/PUSH с других устройств';
      case AppMode.sender:
        return 'Отправляет SMS/PUSH на главный телефон';
    }
  }
}