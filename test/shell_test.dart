import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:aiappbuilder/core/components/app_shell.dart';
import 'package:aiappbuilder/core/components/brand_logo.dart';
import 'package:aiappbuilder/core/theme/theme_provider.dart';
import 'package:aiappbuilder/core/localization/language_provider.dart';
import 'package:aiappbuilder/data/services/api_service.dart';
import 'package:aiappbuilder/data/repositories/project_repository.dart';
import 'package:aiappbuilder/features/projects/viewmodel/project_viewmodel.dart';

void main() {
  testWidgets('AppShell renders with home navigation and branding', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final apiService = ApiService();
    final projectRepo = ProjectRepositoryImpl(apiService);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ChangeNotifierProvider<LanguageProvider>(create: (_) => LanguageProvider()),
          ChangeNotifierProvider<ProjectViewModel>(
            create: (_) => ProjectViewModel(projectRepo, apiService),
          ),
        ],
        child: const MaterialApp(
          home: AppShell(),
        ),
      ),
    );

    await tester.pump();

    // Verify BrandLogo widget and Workspace breadcrumb
    expect(find.byType(BrandLogo), findsWidgets);
    expect(find.text('Workspace'), findsWidgets);
    expect(find.text('Good evening, Developer.'), findsOneWidget);
  });

  testWidgets('AppShell header renders GitHub Token Config button and opens dialog', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final apiService = ApiService();
    final projectRepo = ProjectRepositoryImpl(apiService);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ChangeNotifierProvider<LanguageProvider>(create: (_) => LanguageProvider()),
          ChangeNotifierProvider<ProjectViewModel>(
            create: (_) => ProjectViewModel(projectRepo, apiService),
          ),
        ],
        child: const MaterialApp(
          home: AppShell(),
        ),
      ),
    );

    await tester.pump();

    // Dismiss splash overlay if present
    final enterStudioBtn = find.text('Enter studio');
    if (enterStudioBtn.evaluate().isNotEmpty) {
      await tester.tap(enterStudioBtn);
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Verify Settings/GitHub config button in header by tooltip
    final githubConfigBtn = find.byTooltip('GitHub Token Config');
    expect(githubConfigBtn, findsOneWidget);

    // Tap the GitHub Token Config button
    await tester.tap(githubConfigBtn);
    await tester.pump(const Duration(milliseconds: 200));

    // Verify GitHub Token Config dialog opened
    expect(find.text('GitHub Token Config'), findsOneWidget);
    expect(find.text('Token Requirements:'), findsOneWidget);
  });

  testWidgets('AppShell sidebar can collapse and expand smoothly with tooltips', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final apiService = ApiService();
    final projectRepo = ProjectRepositoryImpl(apiService);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ChangeNotifierProvider<LanguageProvider>(create: (_) => LanguageProvider()),
          ChangeNotifierProvider<ProjectViewModel>(
            create: (_) => ProjectViewModel(projectRepo, apiService),
          ),
        ],
        child: const MaterialApp(
          home: AppShell(),
        ),
      ),
    );

    await tester.pump();

    // Dismiss splash overlay if present
    final enterStudioBtn = find.text('Enter studio');
    if (enterStudioBtn.evaluate().isNotEmpty) {
      await tester.tap(enterStudioBtn);
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Verify initial expanded state
    final collapseBtn = find.byTooltip('Collapse sidebar');
    expect(collapseBtn, findsOneWidget);
    expect(find.text('Create New Project'), findsWidgets);
    expect(find.text('AI Chat'), findsOneWidget);

    // Tap collapse button
    await tester.tap(collapseBtn);
    await tester.pump(const Duration(milliseconds: 300));

    // Verify collapsed state: toggle becomes 'Expand sidebar', labels collapsed into icon buttons with tooltips
    final expandBtn = find.byTooltip('Expand sidebar');
    expect(expandBtn, findsOneWidget);
    expect(find.byTooltip('Create New Project'), findsOneWidget);
    expect(find.byTooltip('AI Chat'), findsOneWidget);

    // Tap expand button to restore
    await tester.tap(expandBtn);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byTooltip('Collapse sidebar'), findsOneWidget);
    expect(find.text('Create New Project'), findsWidgets);
  });
}
