import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _keyThemeMode = 'app_theme_mode';
  static const String _keyLanguage = 'app_language';
  static const String _keyChatLanguage = 'app_chat_language';
  static const String _keySelectedProjectId = 'app_selected_project_id';
  static const String _keySidebarCollapsed = 'app_sidebar_collapsed';
  static const String _keyChatSidebarWidth = 'app_chat_sidebar_width';
  static const double defaultChatSidebarWidth = 260.0;
  static const double minChatSidebarWidth = 180.0;
  static const double maxChatSidebarWidth = 420.0;
  static const String _keyEvidencePanelHeight = 'app_evidence_panel_height';
  static const double defaultEvidencePanelHeight = 180.0;
  static const double minEvidencePanelHeight = 110.0;
  static const double maxEvidencePanelHeight = 420.0;

  final SharedPreferences _prefs;

  PreferencesService(this._prefs);

  static Future<PreferencesService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PreferencesService(prefs);
  }

  // Theme Mode: 'dark', 'light', 'system'
  String getThemeMode() {
    return _prefs.getString(_keyThemeMode) ?? 'dark';
  }

  Future<bool> setThemeMode(String mode) async {
    return await _prefs.setString(_keyThemeMode, mode);
  }

  // Language: 'en' (English), 'ur' (اردو)
  String getLanguage() {
    return _prefs.getString(_keyLanguage) ?? 'en';
  }

  Future<bool> setLanguage(String lang) async {
    return await _prefs.setString(_keyLanguage, lang);
  }

  // Chat Preferred Language: 'auto', 'en', 'ur', 'ps'
  String getChatLanguage() {
    return _prefs.getString(_keyChatLanguage) ?? 'auto';
  }

  Future<bool> setChatLanguage(String lang) async {
    return await _prefs.setString(_keyChatLanguage, lang);
  }

  // Selected Project ID
  String? getSelectedProjectId() {
    return _prefs.getString(_keySelectedProjectId);
  }

  Future<bool> setSelectedProjectId(String? projectId) async {
    if (projectId == null || projectId.isEmpty) {
      return await _prefs.remove(_keySelectedProjectId);
    }
    return await _prefs.setString(_keySelectedProjectId, projectId);
  }

  // Sidebar Collapsed Preference
  bool getSidebarCollapsed() {
    return _prefs.getBool(_keySidebarCollapsed) ?? false;
  }

  Future<bool> setSidebarCollapsed(bool collapsed) async {
    return await _prefs.setBool(_keySidebarCollapsed, collapsed);
  }

  // Chat Sidebar Width Preference (ChatGPT-style resizable panel)
  double getChatSidebarWidth() {
    return (_prefs.getDouble(_keyChatSidebarWidth) ?? defaultChatSidebarWidth)
        .clamp(minChatSidebarWidth, maxChatSidebarWidth);
  }

  Future<bool> setChatSidebarWidth(double width) async {
    return await _prefs.setDouble(
      _keyChatSidebarWidth,
      width.clamp(minChatSidebarWidth, maxChatSidebarWidth),
    );
  }

  // Evidence Panel Height Preference (Project-linked response resizable panel)
  double getEvidencePanelHeight() {
    return (_prefs.getDouble(_keyEvidencePanelHeight) ??
            defaultEvidencePanelHeight)
        .clamp(minEvidencePanelHeight, maxEvidencePanelHeight);
  }

  Future<bool> setEvidencePanelHeight(double height) async {
    return await _prefs.setDouble(
      _keyEvidencePanelHeight,
      height.clamp(minEvidencePanelHeight, maxEvidencePanelHeight),
    );
  }
}
