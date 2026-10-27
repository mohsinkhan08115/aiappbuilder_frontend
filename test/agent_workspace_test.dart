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
import 'package:aiappbuilder/features/agents/view/agent_workspace_screen.dart';
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
  Project? _customProject;
  List<BuildJob> _customBuilds = [];
  bool _customBusy = false;

  TestProjectViewModel() : super(StubProjectRepository(), ApiService());

  void setCustomProject(Project? p) {
    _customProject = p;
    notifyListeners();
  }

  void setCustomBuilds(List<BuildJob> b) {
    _customBuilds = b;
    notifyListeners();
  }

  void setCustomBusy(bool busy) {
    _customBusy = busy;
    notifyListeners();
  }

  @override
  Project? get selectedProject => _customProject;

  @override
  List<BuildJob> get buildJobs => _customBuilds;

  @override
  bool get isAnalyzing => _customBusy;
}

void main() {
  group('AgentWorkspaceScreen Dynamic Progress Tests', () {
    late TestProjectViewModel testVm;

    setUp(() {
      testVm = TestProjectViewModel();
    });

    Widget buildSubject() {
      return ChangeNotifierProvider<ProjectViewModel>.value(
        value: testVm,
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: AgentWorkspaceScreen(
              onNavigate: (_) {},
              onConfirm: (_) {},
              onNotify: (_) {},
            ),
          ),
        ),
      );
    }

    testWidgets('shows Standby state and 0% when no project is active',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      testVm.setCustomProject(null);

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // Standby verification
      expect(find.text('Standby'), findsWidgets);
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('No active project selected. Select a project to run agent workflows.'), findsWidgets);
      // Hardcoded 68% must NOT exist
      expect(find.text('68%'), findsNothing);
    });

    testWidgets('shows Coding Agent is working and dynamic 45% when generating',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final project = Project(
        id: 'proj-1',
        name: 'Finance Tracker',
        description: 'Flutter finance app',
        status: 'generating',
        workspacePath: 'D:/tmp/finance',
        projectType: 'flutter',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      testVm.setCustomProject(project);

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.text('Coding Agent is working'), findsWidgets);
      expect(find.text('45%'), findsOneWidget);
      expect(find.text('68%'), findsNothing);
    });

    testWidgets('shows Waiting for verification and 60% when build is queued',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final project = Project(
        id: 'proj-2',
        name: 'E-Commerce App',
        status: 'created',
        workspacePath: 'D:/tmp/ecommerce',
        projectType: 'flutter',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      testVm.setCustomProject(project);
      testVm.setCustomBuilds([
        BuildJob(
          id: 'b-1',
          projectId: 'proj-2',
          targetPlatform: 'web',
          status: 'queued',
          createdAt: DateTime.now(),
        ),
      ]);

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.text('Waiting for verification'), findsWidgets);
      expect(find.text('60%'), findsOneWidget);
    });

    testWidgets('shows Completed and 100% when project is completed',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final project = Project(
        id: 'proj-3',
        name: 'Portfolio App',
        status: 'completed',
        workspacePath: 'D:/tmp/portfolio',
        projectType: 'flutter',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      testVm.setCustomProject(project);

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.text('Completed'), findsWidgets);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('All tasks and verification checks completed.'), findsWidgets);
    });

    testWidgets('shows Ready and 0% when project is created without active build',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final project = Project(
        id: 'proj-ready',
        name: 'Fresh App',
        status: 'created',
        workspacePath: 'D:/tmp/fresh',
        projectType: 'flutter',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      testVm.setCustomProject(project);

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.text('Ready'), findsWidgets);
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('Project initialized · Ready to generate'), findsWidgets);
    });

    testWidgets('shows Failed and 0% without fabricated progress when project status is failed',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final project = Project(
        id: 'proj-failed',
        name: 'Broken App',
        status: 'failed',
        workspacePath: 'D:/tmp/broken',
        projectType: 'flutter',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      testVm.setCustomProject(project);

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.text('Failed'), findsWidgets);
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('Task encountered an error. Check logs for details.'), findsWidgets);
    });
  });
}
