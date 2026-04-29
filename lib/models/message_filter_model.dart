enum MessageFilter {
  all,
  sms,
  push,
  errors,
}

extension MessageFilterTitle on MessageFilter {
  String get title {
    switch (this) {
      case MessageFilter.all:
        return 'Все';
      case MessageFilter.sms:
        return 'SMS';
      case MessageFilter.push:
        return 'PUSH';
      case MessageFilter.errors:
        return 'Ошибки';
    }
  }
}