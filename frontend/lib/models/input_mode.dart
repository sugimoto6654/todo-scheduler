enum InputMode {
  task,
  chat,
}

extension InputModeExtension on InputMode {
  String get displayName {
    switch (this) {
      case InputMode.task:
        return 'タスク';
      case InputMode.chat:
        return 'チャット';
    }
  }
  
  String get placeholder {
    switch (this) {
      case InputMode.task:
        return 'タスクを追加してください';
      case InputMode.chat:
        return 'ChatGPTと対話してください';
    }
  }
}