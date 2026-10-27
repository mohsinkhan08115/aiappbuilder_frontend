import 'package:flutter/material.dart';
import '../../data/services/preferences_service.dart';

class ThemeProvider extends ChangeNotifier {
  final PreferencesService? _prefsService;
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeProvider([this._prefsService]) {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void _loadTheme() {
    if (_prefsService != null) {
      final saved = _prefsService.getThemeMode();
      if (saved == 'light') {
        _themeMode = ThemeMode.light;
      } else if (saved == 'system') {
        _themeMode = ThemeMode.system;
      } else {
        _themeMode = ThemeMode.dark;
      }
      notifyListeners();
    }
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      if (_prefsService != null) {
        final modeStr = mode == ThemeMode.light
            ? 'light'
            : (mode == ThemeMode.system ? 'system' : 'dark');
        _prefsService.setThemeMode(modeStr);
      }
      notifyListeners();
    }
  }

  void toggleTheme() {
    final newMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    setThemeMode(newMode);
  }
}
