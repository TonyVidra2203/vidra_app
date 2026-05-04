enum AppMode {
  receiver,
  sender,
}

extension AppModeTitle on AppMode {
  String get title {
    switch (this) {
      case AppMode.receiver:
        return 'Приём';
      case AppMode.sender:
        return 'Передача';
    }
  }

  String get subtitle {
    switch (this) {
      case AppMode.receiver:
        return 'Принимает и показывает SMS/PUSH';
      case AppMode.sender:
        return 'Отправляет SMS/PUSH на другой телефон';
    }
  }
}