import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:aiappbuilder/core/theme/theme_provider.dart';
import 'package:aiappbuilder/data/services/api_service.dart';
import 'package:aiappbuilder/data/repositories/project_repository.dart';
import 'package:aiappbuilder/features/projects/viewmodel/project_viewmodel.dart';
import 'package:aiappbuilder/features/code/view/code_files_screen.dart';

void main() {
  group('CodeFilesScreen Layout & Responsiveness Regression Tests', () {
    late ApiService apiService;
    late ProjectRepository projectRepo;
    late ProjectViewModel projectVm;

    setUp(() {
      apiService = ApiService();
      projectRepo = ProjectRepositoryImpl(apiService);
      projectVm = ProjectViewModel(projectRepo, apiService);
    });

    Widget buildSubject() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ChangeNotifierProvider<ProjectViewModel>.value(value: projectVm),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: CodeFilesScreen(
              onNavigate: (_) {},
              onNotify: (_) {},
              onConfirm: (_) {},
            ),
          ),
        ),
      );
    }

    testWidgets('Desktop width (1280x900): renders side-by-side file tree and editor without layout exceptions',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Verify header, file tree and editor contents
      expect(find.text('CODE & FILES'), findsOneWidget);
      expect(find.text('auth_service.dart'), findsWidgets);
      expect(find.text('Diff review'), findsWidgets);
      expect(find.text('Code intelligence'), findsOneWidget);
      expect(find.text('Review comments'), findsOneWidget);

      // Tap tab to switch extension
      await tester.tap(find.text('Code intelligence'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('SYMBOL RELATIONSHIPS'), findsOneWidget);
      expect(find.text('AuthService'), findsWidgets);

      // Tap on a file in file tree
      await tester.tap(find.text('login_screen.dart').first);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Tablet width (768x1024): renders cleanly without unbounded height or flex exceptions',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Verify header, editor, and engineering extensions are present
      expect(find.text('CODE & FILES'), findsOneWidget);
      expect(find.text('Review changes'), findsOneWidget);
      expect(find.text('Back to project'), findsOneWidget);
      expect(find.text('Modified'), findsOneWidget);

      // Tap View diff
      await tester.tap(find.text('View diff'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Hide diff'), findsOneWidget);
    });

    testWidgets('Mobile width (375x812): renders with intentional bounded constraints and supports file browsing',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Crucial: no RenderFlex unbounded height error
      expect(tester.takeException(), isNull);

      expect(find.text('CODE & FILES'), findsOneWidget);
      expect(find.text('Browse files'), findsOneWidget);

      // Toggle Browse files accordion on mobile
      await tester.tap(find.text('Browse files'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Hide files'), findsOneWidget);
      expect(find.text('Search files'), findsOneWidget);

      // Select file in mobile file tree
      await tester.tap(
        find.descendant(of: find.byType(ListView), matching: find.text('main.dart')),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Collapse files accordion
      await tester.tap(find.text('Hide files'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Browse files'), findsOneWidget);

      // Switch editor tab via horizontally scrollable tab bar
      final tabFinder = find.text('login_screen.dart').first;
      await tester.ensureVisible(tabFinder);
      await tester.tap(tabFinder);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
