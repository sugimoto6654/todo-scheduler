import 'package:flutter/foundation.dart';

class AppSettings extends ChangeNotifier {
  static final AppSettings _instance = AppSettings._internal();
  factory AppSettings() => _instance;
  AppSettings._internal();

  bool _showJsonActions = false;

  bool get showJsonActions => _showJsonActions;

  void setShowJsonActions(bool value) {
    _showJsonActions = value;
    notifyListeners();
  }

  void toggleJsonActions() {
    _showJsonActions = !_showJsonActions;
    notifyListeners();
  }
}