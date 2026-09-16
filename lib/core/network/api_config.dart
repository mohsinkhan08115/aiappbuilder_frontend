import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';

class ApiConfig {
  /// Resolves the API base URL depending on the platform and build configuration.
  static String get baseUrl {
    const String injectedUrl = String.fromEnvironment('API_BASE_URL');
    if (injectedUrl.isNotEmpty) {
      return injectedUrl;
    }

    if (kIsWeb) {
      return AppConstants.defaultApiUrl;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AppConstants.emulatorApiUrl;
      case TargetPlatform.iOS:
        return AppConstants.defaultApiUrl;
      default:
        return AppConstants.defaultApiUrl;
    }
  }
}
