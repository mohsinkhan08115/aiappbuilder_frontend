import 'package:flutter/material.dart';
import '../../data/services/preferences_service.dart';

class LanguageProvider extends ChangeNotifier {
  final PreferencesService? _prefsService;
  String _currentLanguage = 'en'; // 'en' or 'ur'

  LanguageProvider([this._prefsService]) {
    _loadLanguage();
  }

  String get currentLanguage => _currentLanguage;
  bool get isUrdu => _currentLanguage == 'ur';

  void _loadLanguage() {
    if (_prefsService != null) {
      _currentLanguage = _prefsService.getLanguage();
      notifyListeners();
    }
  }

  void setLanguage(String lang) {
    if (lang != _currentLanguage) {
      _currentLanguage = lang;
      _prefsService?.setLanguage(lang);
      notifyListeners();
    }
  }

  // Localized string dictionary
  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'AI Flutter App Builder',
      'nav_home': 'Home',
      'nav_projects': 'Projects',
      'nav_chat': 'AI Chat',
      'nav_editor': 'Code Editor',
      'nav_agent': 'Agent Workspace',
      'nav_testing': 'Testing & Builds',
      'nav_integrations': 'GitHub & Integrations',
      'nav_settings': 'Settings',
      'workspace': 'Workspace',
      'active_project': 'Active Project',
      'no_project_selected': 'No Project Selected',
      'select_project': 'Select a Project',
      'settings': 'Settings',
      'appearance': 'Appearance',
      'dark': 'Dark',
      'light': 'Light',
      'system': 'System',
      'language_region': 'Language & Region',
      'github_integration': 'GitHub Integration',
      'configure_pat': 'Configure PAT',
      'push_to_github': 'Push to GitHub',
      'create_project': 'Create Project',
      'prompt_hint': 'Describe the Flutter app you want to build...',
      'generate': 'Generate App',
      'recent_projects': 'Recent Projects',
      'status_connected': 'Connected',
      'status_disconnected': 'Not Connected',
    },
    'ur': {
      'app_title': 'اے آئی فلٹر ایپ بلڈر',
      'nav_home': 'ہوم',
      'nav_projects': 'پروجیکٹس',
      'nav_chat': 'چیٹ',
      'nav_editor': 'کوڈ ایڈیٹر',
      'nav_agent': 'ایجنٹ ورک اسپیس',
      'nav_testing': 'ٹیسٹنگ اور بلڈز',
      'nav_integrations': 'گٹ ہب انٹیگریشن',
      'nav_settings': 'ترتیبات',
      'workspace': 'ورک اسپیس',
      'active_project': 'فعال پروجیکٹ',
      'no_project_selected': 'کوئی پروجیکٹ منتخب نہیں',
      'select_project': 'پروجیکٹ منتخب کریں',
      'settings': 'سیٹنگز',
      'appearance': 'ظاہری شکل',
      'dark': 'ڈارک موڈ',
      'light': 'لائٹ موڈ',
      'system': 'سسٹم موڈ',
      'language_region': 'زبان اور علاقہ',
      'github_integration': 'گٹ ہب انضمام',
      'configure_pat': 'ٹوکن ترتیب دیں',
      'push_to_github': 'گٹ ہب پر پش کریں',
      'create_project': 'نیا پروجیکٹ',
      'prompt_hint': 'فلٹر ایپ کی تفصیل لکھیں جو آپ بنانا چاہتے ہیں...',
      'generate': 'ایپ تیار کریں',
      'recent_projects': 'حالیہ پروجیکٹس',
      'status_connected': 'منسلک ہے',
      'status_disconnected': 'غیر منسلک',
    },
  };

  String translate(String key) {
    return _localizedValues[_currentLanguage]?[key] ??
        _localizedValues['en']?[key] ??
        key;
  }
}
