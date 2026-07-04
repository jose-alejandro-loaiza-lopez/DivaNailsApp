import 'package:flutter/foundation.dart';

class AppData extends ChangeNotifier {
  static final AppData instance = AppData._();
  AppData._();

  bool devMode = false;
  DateTime? _navigateToDate;

  void toggleDevMode() {
    devMode = !devMode;
    notifyListeners();
  }

  void notifyChanged() => notifyListeners();

  DateTime? get navigateToDate => _navigateToDate;

  void requestNavigateToDate(DateTime date) {
    _navigateToDate = date;
    notifyListeners();
  }

  DateTime? consumeNavigateToDate() {
    final date = _navigateToDate;
    _navigateToDate = null;
    return date;
  }
}
