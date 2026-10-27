import 'package:flutter/material.dart';
import '../../features/auth/view/auth_screen.dart';
import '../../core/components/app_shell.dart';

class AppRoutes {
  static const String auth = '/auth';
  static const String dashboard = '/dashboard';
  static const String projectDetails = '/project';

  static Map<String, WidgetBuilder> get routes {
    return {
      auth: (context) => const AuthScreen(),
      dashboard: (context) => const AppShell(),
      projectDetails: (context) => const AppShell(),
    };
  }
}
