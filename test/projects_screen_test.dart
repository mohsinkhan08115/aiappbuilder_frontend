import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:aiappbuilder/core/utils/selected_file.dart';
import 'package:aiappbuilder/data/models/build_job.dart';
import 'package:aiappbuilder/data/models/log_entry.dart';
import 'package:aiappbuilder/data/models/project.dart';
import 'package:aiappbuilder/data/models/project_file.dart';
import 'package:aiappbuilder/data/models/github_repo.dart';
import 'package:aiappbuilder/data/repositories/project_repository.dart';
import 'package:aiappbuilder/data/services/api_service.dart';
import 'package:aiappbuilder/features/projects/view/projects_screen.dart';
import 'package:aiappbuilder/features/projects/viewmodel/project_viewmodel.dart';

class StubProjectRepository implements ProjectRepository {
  @override
  Future<Project> applyAIProposal(String projectId, List<String> dependenciesToAdd, List<Map<String, dynamic>> filesToUpdate) => throw UnimplementedError();
  @override
  Future<BuildJob> buildProject(String projectId, String platform) => throw UnimplementedError();
  @override
  Future<Project> createProject(String name, String? description, {bool initializeFlutter = false}) => throw UnimplementedError();
  @override
  Future<void> deleteProject(String projectId) => throw UnimplementedError();
  @override
  Future<void> exportProject(String projectId, String destinationPath) => throw UnimplementedError();
  @override
  Future<List<ProjectFile>> fetchProjectFiles(String projectId) async => [];
  @override
  Future<Project> generateProject(String projectId, String prompt) => throw UnimplementedError();
  @override
  Future<String> getAIAnalysis(String projectId, String prompt, String? filePath) => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> getAIProposal(String projectId, String prompt, String? activeFilePath) => throw UnimplementedError();
  @override
  Future<List<BuildJob>> getBuilds(String projectId) async => [];
  @override
  Future<String> getFileContent(String projectId, String filePath) => throw UnimplementedError();
  @override
  Future<List<LogEntry>> getLogs(String projectId) async => [];
  @override
  Future<Project> getProject(String projectId) => throw UnimplementedError();
  @override
  Future<void> importProjectZip(String projectId, List<int> zipBytes, String fileName, {void Function(int sent, int total)? onSendProgress}) => throw UnimplementedError();
  @override
  Future<List<Project>> listProjects() async => [];
  @override
  Future<Project> modifyProject(String projectId, String prompt) => throw UnimplementedError();
  @override
  Future<GitHubRepo> pushToGithub(String projectId, String repoName, bool isPrivate) => throw UnimplementedError();
  @override
  Future<GitHubRepo?> getGithubRepo(String projectId) async => null;
  @override
  Future<void> saveFileContent(String projectId, String filePath, String content) => throw UnimplementedError();
  @override
  Future<Project> uploadFolder(String folderName, List<SelectedFile> files, {void Function(int sent, int total)? onSendProgress}) => throw UnimplementedError();
  @override
  Future<Project> uploadProjectZip(String name, String? description, List<int> zipBytes, String fileName, {void Function(int sent, int total)? onSendProgress}) => throw UnimplementedError();
}

class TestProjectViewModel extends ProjectViewModel {
  List<Project> _customProjects = [];
  String? lastSelectedId;

  TestProjectViewModel() : super(StubProjectRepository(), ApiService());

  void setCustomProjects(List<Project> p) {
    _customProjects = p;
    notifyListeners();
  }

  @override
  List<Project> get projects => _customProjects;

  @override
  Future<void> selectProject(String projectId) async {
    lastSelectedId = projectId;
  }
}

void main() {
  group('ProjectsScreen Responsive & Interaction Tests', () {
    late TestProjectViewModel testVm;

    setUp(() {
      testVm = TestProjectViewModel();
    });

    Widget buildSubject({
      VoidCallback? onOpenWizard,
      void Function(String)? onNavigate,
      void Function(String)? onNotify,
    }) {
      return ChangeNotifierProvider<ProjectViewModel>.value(
        value: testVm,
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: ProjectsScreen(
              onOpenWizard: onOpenWizard ?? () {},
              onNavigate: onNavigate ?? (_) {},
              onNotify: onNotify ?? (_) {},
            ),
          ),
        ),
      );
    }

    testWidgets('renders properly on Desktop width (1280x900)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('PROJECTS'), findsOneWidget);
      expect(find.text('Your software, in one place'), findsOneWidget);
      expect(find.text('Create project'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
    });

    testWidgets('renders properly on Mobile width (375x812) without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('PROJECTS'), findsOneWidget);
      expect(find.text('Create project'), findsOneWidget);
    });

    testWidgets('filters projects when typing into search input',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final p1 = Project(
        id: 'p1',
        name: 'Alpha Mobile',
        description: 'Flutter app',
        status: 'completed',
        workspacePath: 'D:/tmp/alpha',
        projectType: 'flutter',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final p2 = Project(
        id: 'p2',
        name: 'Beta Backend',
        description: 'FastAPI python',
        status: 'generating',
        workspacePath: 'D:/tmp/beta',
        projectType: 'python',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      testVm.setCustomProjects([p1, p2]);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Alpha Mobile'), findsOneWidget);
      expect(find.text('Beta Backend'), findsOneWidget);

      // Search for Alpha
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Alpha');
      await tester.pumpAndSettle();

      expect(find.text('Alpha Mobile'), findsOneWidget);
      expect(find.text('Beta Backend'), findsNothing);

      // Clear search
      final clearBtn = find.byTooltip('Clear search');
      expect(clearBtn, findsOneWidget);
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      expect(find.text('Alpha Mobile'), findsOneWidget);
      expect(find.text('Beta Backend'), findsOneWidget);
    });

    testWidgets('shows empty state when search finds no results',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final p1 = Project(
        id: 'p1',
        name: 'Alpha Mobile',
        description: 'Flutter app',
        status: 'completed',
        workspacePath: 'D:/tmp/alpha',
        projectType: 'flutter',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      testVm.setCustomProjects([p1]);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'NonExistentProject');
      await tester.pumpAndSettle();

      expect(find.text('No projects matching "NonExistentProject"'), findsOneWidget);
      expect(find.text('Clear search'), findsOneWidget);
    });

    testWidgets('wires action button to select project and navigate',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      String navigatedTo = '';
      final p1 = Project(
        id: 'p1',
        name: 'Alpha Mobile',
        description: 'Flutter app',
        status: 'completed',
        workspacePath: 'D:/tmp/alpha',
        projectType: 'flutter',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      testVm.setCustomProjects([p1]);

      await tester.pumpWidget(buildSubject(
        onNavigate: (route) => navigatedTo = route,
      ));
      await tester.pumpAndSettle();

      final filesButton = find.widgetWithText(TextButton, 'Files');
      expect(filesButton, findsOneWidget);
      await tester.tap(filesButton);
      await tester.pumpAndSettle();

      expect(testVm.lastSelectedId, 'p1');
      expect(navigatedTo, 'Code & Files');
    });
  });
}
