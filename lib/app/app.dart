import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../data/services/api_service.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/project_repository.dart';
import '../features/auth/viewmodel/auth_viewmodel.dart';
import '../features/projects/viewmodel/project_viewmodel.dart';
import 'theme/app_theme.dart';
import 'routes/app_routes.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Core API network service
        Provider<ApiService>(create: (_) => ApiService()),

        // Repositories
        ProxyProvider<ApiService, AuthRepository>(
          update: (_, apiService, _) => AuthRepositoryImpl(apiService),
        ),
        ProxyProvider<ApiService, ProjectRepository>(
          update: (_, apiService, _) => ProjectRepositoryImpl(apiService),
        ),

        // Auth management ViewModel
        ChangeNotifierProxyProvider<AuthRepository, AuthViewModel>(
          create: (context) => AuthViewModel(context.read<AuthRepository>()),
          update: (_, authRepo, authViewModel) =>
              authViewModel ?? AuthViewModel(authRepo),
        ),

        // Project list and orchestration ViewModel
        ChangeNotifierProxyProvider2<ProjectRepository, ApiService, ProjectViewModel>(
          create: (context) => ProjectViewModel(
            context.read<ProjectRepository>(),
            context.read<ApiService>(),
          ),
          update: (_, projectRepo, apiService, projectViewModel) =>
              projectViewModel ?? ProjectViewModel(projectRepo, apiService),
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appTitle,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        initialRoute: AppRoutes.auth,
        routes: AppRoutes.routes,
      ),
    );
  }
}
