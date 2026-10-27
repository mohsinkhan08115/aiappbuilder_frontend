import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_provider.dart';
import '../data/services/api_service.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/project_repository.dart';
import '../features/auth/viewmodel/auth_viewmodel.dart';
import '../features/projects/viewmodel/project_viewmodel.dart';
import 'routes/app_routes.dart';

import '../core/localization/language_provider.dart';
import '../data/services/preferences_service.dart';

class MyApp extends StatelessWidget {
  final PreferencesService? preferencesService;

  const MyApp({super.key, this.preferencesService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Preferences Service
        Provider<PreferencesService?>.value(value: preferencesService),

        // Theme Manager with persistence
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(preferencesService),
        ),

        // Language & Localization Manager with persistence
        ChangeNotifierProvider<LanguageProvider>(
          create: (_) => LanguageProvider(preferencesService),
        ),

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
            preferencesService,
          ),
          update: (_, projectRepo, apiService, projectViewModel) =>
              projectViewModel ?? ProjectViewModel(projectRepo, apiService, preferencesService),
        ),
      ],
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (context, themeProvider, langProvider, child) {
          return MaterialApp(
            title: AppConstants.appTitle,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            locale: Locale(langProvider.currentLanguage),
            initialRoute: AppRoutes.auth,
            routes: AppRoutes.routes,
          );
        },
      ),
    );
  }
}
