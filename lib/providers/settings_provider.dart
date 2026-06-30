import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class SettingsProvider extends ChangeNotifier {
  late SharedPreferences _prefs;

  double _detectionRadius = AppConstants.defaultDetectionRadius;
  bool _darkMode = false;

  double get detectionRadius => _detectionRadius;
  bool get darkMode => _darkMode;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _detectionRadius = _prefs.getDouble(AppConstants.keyDetectionRadius) ??
        AppConstants.defaultDetectionRadius;
    _darkMode = _prefs.getBool(AppConstants.keyDarkMode) ?? false;
    notifyListeners();
  }

  Future<void> setDetectionRadius(double value) async {
    _detectionRadius = value;
    await _prefs.setDouble(AppConstants.keyDetectionRadius, value);
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    await _prefs.setBool(AppConstants.keyDarkMode, value);
    notifyListeners();
  }

  Future<void> clearPreferences() async {
    await _prefs.clear();
    _detectionRadius = AppConstants.defaultDetectionRadius;
    _darkMode = false;
    notifyListeners();
  }
}
