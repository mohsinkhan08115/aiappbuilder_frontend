import 'package:flutter/material.dart';
import '../../features/auth/view/auth_screen.dart';
import '../../features/projects/view/dashboard_screen.dart';
import '../../features/ai_builder/view/project_details_screen.dart';

class AppRoutes {
  static const String auth = '/auth';
  static const String dashboard = '/dashboard';
  static const String projectDetails = '/project';

  static Map<String, WidgetBuilder> get routes {
    return {
      auth: (context) => const AuthScreen(),
      dashboard: (context) => const DashboardScreen(),
      projectDetails: (context) => const ProjectDetailsScreen(),
    };
  }
}
