import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:aiappbuilder/core/theme/theme_provider.dart';
import 'package:aiappbuilder/core/localization/language_provider.dart';
import 'package:aiappbuilder/data/services/api_service.dart';
import 'package:aiappbuilder/data/repositories/auth_repository.dart';
import 'package:aiappbuilder/data/repositories/project_repository.dart';
import 'package:aiappbuilder/features/auth/viewmodel/auth_viewmodel.dart';
import 'package:aiappbuilder/features/projects/viewmodel/project_viewmodel.dart';
import 'package:aiappbuilder/features/settings/view/settings_screen.dart';
import 'package:aiappbuilder/core/components/app_shell.dart';
import 'package:aiappbuilder/app/routes/app_routes.dart';

void main() {
  group('SettingsScreen & Auth Profile Integration', () {
    late ApiService apiService;
    late AuthRepository authRepo;
    late AuthViewModel authVm;
    late ProjectRepository projectRepo;
    late ProjectViewModel projectVm;

    setUp(() {
      apiService = ApiService();
      authRepo = AuthRepositoryImpl(apiService);
      authVm = AuthViewModel(authRepo);
      projectRepo = ProjectRepositoryImpl(apiService);
      projectVm = ProjectViewModel(projectRepo, apiService);
    });

    testWidgets('SettingsScreen displays guest state when unauthenticated',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
            ChangeNotifierProvider<LanguageProvider>(create: (_) => LanguageProvider()),
            ChangeNotifierProvider<AuthViewModel>.value(value: authVm),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SettingsScreen(
                onNavigate: (_) {},
                onNotify: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SETTINGS'), findsOneWidget);
      expect(find.text('Guest / Unauthenticated'), findsOneWidget);
      expect(find.text('Sign in to access private projects.'), findsOneWidget);
      expect(find.text('Sign in'), findsWidgets);
    });

    testWidgets('SettingsScreen displays real user email when authenticated',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      authVm.setCurrentUserEmail('dev@example.com');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
            ChangeNotifierProvider<LanguageProvider>(create: (_) => LanguageProvider()),
            ChangeNotifierProvider<AuthViewModel>.value(value: authVm),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SettingsScreen(
                onNavigate: (_) {},
                onNotify: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SETTINGS'), findsOneWidget);
      expect(find.text('Authenticated'), findsOneWidget);
      expect(find.text('Signed in as dev@example.com. Session details are secured.'), findsOneWidget);
      expect(find.text('Sign out'), findsWidgets);
    });

    testWidgets('AppShell reflects user email initials in sidebar and header',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      authVm.setCurrentUserEmail('sarah.connor@sky.net');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
            ChangeNotifierProvider<LanguageProvider>(create: (_) => LanguageProvider()),
            ChangeNotifierProvider<AuthViewModel>.value(value: authVm),
            ChangeNotifierProvider<ProjectViewModel>.value(value: projectVm),
          ],
          child: const MaterialApp(
            home: AppShell(),
          ),
        ),
      );
      await tester.pump();

      // Check initials and user email
      expect(find.text('SA'), findsWidgets);
      expect(find.text('sarah.connor@sky.net'), findsOneWidget);
    });

    testWidgets('SettingsScreen logout button shows confirmation dialog and cancels safely',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      authVm.setCurrentUserEmail('dev@example.com');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
            ChangeNotifierProvider<LanguageProvider>(create: (_) => LanguageProvider()),
            ChangeNotifierProvider<AuthViewModel>.value(value: authVm),
          ],
          child: MaterialApp(
            routes: {
              AppRoutes.auth: (context) => const Scaffold(body: Text('AuthScreenRoute')),
            },
            home: Scaffold(
              body: SettingsScreen(
                onNavigate: (_) {},
                onNotify: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap first Sign out button
      final signOutFinder = find.text('Sign out').first;
      await tester.tap(signOutFinder);
      await tester.pumpAndSettle();

      // Confirmation dialog should be visible
      expect(find.text('Log Out'), findsWidgets);
      expect(find.text('Are you sure you want to log out of your account?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog dismissed, user is still authenticated
      expect(find.text('Are you sure you want to log out of your account?'), findsNothing);
      expect(authVm.isAuthenticated, isTrue);
      expect(authVm.currentUserEmail, 'dev@example.com');
    });

    testWidgets('SettingsScreen logout confirmation clears auth state and navigates to AppRoutes.auth',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      authVm.setCurrentUserEmail('dev@example.com');
      String? notifiedMessage;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
            ChangeNotifierProvider<LanguageProvider>(create: (_) => LanguageProvider()),
            ChangeNotifierProvider<AuthViewModel>.value(value: authVm),
          ],
          child: MaterialApp(
            routes: {
              AppRoutes.auth: (context) => const Scaffold(body: Text('AuthScreenRoute')),
            },
            home: Scaffold(
              body: SettingsScreen(
                onNavigate: (_) {},
                onNotify: (msg) => notifiedMessage = msg,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Sign out button
      final signOutFinder = find.text('Sign out').first;
      await tester.tap(signOutFinder);
      await tester.pumpAndSettle();

      // Confirmation dialog visible
      expect(find.text('Log Out'), findsWidgets);

      // Tap confirm 'Log Out' button in dialog
      final confirmButton = find.widgetWithText(ElevatedButton, 'Log Out');
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      // Auth state cleared
      expect(authVm.isAuthenticated, isFalse);
      expect(authVm.currentUserEmail, isNull);
      expect(notifiedMessage, 'Signed out safely.');

      // Navigated to AppRoutes.auth
      expect(find.text('AuthScreenRoute'), findsOneWidget);
    });
  });
}
