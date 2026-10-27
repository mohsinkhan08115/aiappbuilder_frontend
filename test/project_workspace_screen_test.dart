import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:aiappbuilder/core/utils/selected_file.dart';
import 'package:aiappbuilder/data/models/build_job.dart';
import 'package:aiappbuilder/data/models/log_entry.dart';
import 'package:aiappbuilder/data/models/project.dart';
import 'package:aiappbuilder/data/models/project_file.dart';
import 'package:aiappbuilder/data/models/proposed_file_change.dart';
import 'package:aiappbuilder/data/models/github_repo.dart';
import 'package:aiappbuilder/data/repositories/project_repository.dart';
import 'package:aiappbuilder/data/services/api_service.dart';
import 'package:aiappbuilder/features/projects/view/project_workspace_screen.dart';
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
  List<BuildJob> _customBuildJobs = [];
  List<ProjectFile> _customFiles = [];
  final Map<String, List<LogEntry>> _customLogs = {};
  List<ProposedFileChange> _customProposals = [];
  ProjectFile? _customSelectedFile;
  String? _customOpenContent;
  String _customEditedContent = '';
  bool _customDirty = false;

  TestProjectViewModel() : super(StubProjectRepository(), ApiService());

  void setCustomProject(Project? p) {
    _customProject = p;
    notifyListeners();
  }

  void setCustomBuildJobs(List<BuildJob> jobs) {
    _customBuildJobs = jobs;
    notifyListeners();
  }

  void setCustomFiles(List<ProjectFile> files) {
    _customFiles = files;
    notifyListeners();
  }

  void setCustomLogs(String projectId, List<LogEntry> logs) {
    _customLogs[projectId] = logs;
    notifyListeners();
  }

  void setCustomProposals(List<ProposedFileChange> changes) {
    _customProposals = changes;
    notifyListeners();
  }

  void setCustomSelectedFile(ProjectFile? file, String? content) {
    _customSelectedFile = file;
    _customOpenContent = content;
    _customEditedContent = content ?? '';
    _customDirty = false;
    notifyListeners();
  }

  @override
  Project? get selectedProject => _customProject;

  @override
  List<BuildJob> get buildJobs => _customBuildJobs;

  @override
  List<ProjectFile> get projectFiles => _customFiles;

  @override
  Map<String, List<LogEntry>> get projectLogs => _customLogs;

  @override
  List<ProposedFileChange> get proposedChanges => _customProposals;

  @override
  ProjectFile? get selectedFile => _customSelectedFile;

  @override
  String? get openFileContent => _customOpenContent;

  @override
  String get editedContent => _customEditedContent;

  @override
  bool get isDirty => _customDirty;

  @override
  Future<void> openFile(String projectId, ProjectFile file) async {
    _customSelectedFile = file;
    _customOpenContent = 'void main() => runApp(const App());';
    _customEditedContent = _customOpenContent!;
    _customDirty = false;
    notifyListeners();
  }

  @override
  void updateEditedContent(String content) {
    _customEditedContent = content;
    _customDirty = (_customEditedContent != _customOpenContent);
    notifyListeners();
  }

  @override
  void cancelEdits() {
    _customEditedContent = _customOpenContent ?? '';
    _customDirty = false;
    notifyListeners();
  }

  @override
  Future<void> saveFile(String projectId) async {
    _customOpenContent = _customEditedContent;
    _customDirty = false;
    notifyListeners();
  }

  @override
  void discardAIProposal() {
    _customProposals = [];
    notifyListeners();
  }

  @override
  Future<void> applyAIProposal(String projectId) async {
    _customProposals = [];
    notifyListeners();
  }

  @override
  Future<void> triggerBuild(String projectId, String platform) async {
    _customBuildJobs.insert(
      0,
      BuildJob(
        id: 'job-new-123',
        projectId: projectId,
        targetPlatform: platform,
        status: 'building',
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }
}

void main() {
  group('ProjectWorkspaceScreen Tests', () {
    late TestProjectViewModel testVm;
    String? navigatedRoute;

    setUp(() {
      testVm = TestProjectViewModel();
      navigatedRoute = null;
    });

    Widget buildSubject() {
      return ChangeNotifierProvider<ProjectViewModel>.value(
        value: testVm,
        child: MaterialApp(
          home: Scaffold(
            body: ProjectWorkspaceScreen(
              onNavigate: (route) => navigatedRoute = route,
              onNotify: (_) {},
            ),
          ),
        ),
      );
    }

    testWidgets('Renders empty state when selectedProject == null with disabled actions and no fake metrics', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      testVm.setCustomProject(null);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Truthful empty state titles
      expect(find.text('No Project Selected'), findsOneWidget);
      expect(find.text('No Project Loaded in Workspace'), findsOneWidget);
      expect(find.text('Browse Projects'), findsOneWidget);
      expect(find.text('Create New Project'), findsOneWidget);

      // Verifies no fabricated metrics or hardcoded 'Nova Mobile'
      expect(find.text('Nova Mobile'), findsNothing);
      expect(find.text('68% complete · 7 files changed'), findsNothing);
      expect(find.text('18 of 24 passed'), findsNothing);

      // Actions are disabled
      final settingsButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Settings'),
      );
      expect(settingsButton.onPressed, isNull);

      final openAgentsButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Open agents'),
      );
      expect(openAgentsButton.onPressed, isNull);

      // Clicking Browse Projects navigates to Projects
      await tester.tap(find.text('Browse Projects'));
      expect(navigatedRoute, 'Projects');
    });

    testWidgets('Renders truthful project information when a project is active', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      final testProject = Project(
        id: 'proj-456',
        name: 'Finance App Pro',
        description: 'Personal budgeting and crypto tracking',
        status: 'completed',
        workspacePath: 'D:\\workspace\\finance_app',
        projectType: 'flutter',
        createdAt: DateTime(2026, 3, 15, 10, 30),
        updatedAt: DateTime(2026, 3, 15, 11, 00),
      );

      testVm.setCustomProject(testProject);
      testVm.setCustomFiles([
        ProjectFile(path: 'lib/main.dart', name: 'main.dart', isDir: false, size: 1024),
        ProjectFile(path: 'lib/app.dart', name: 'app.dart', isDir: false, size: 512),
      ]);
      testVm.setCustomBuildJobs([
        BuildJob(
          id: 'job-789',
          projectId: 'proj-456',
          targetPlatform: 'apk',
          status: 'completed',
          createdAt: DateTime(2026, 3, 15, 10, 45),
        ),
      ]);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Confirms real project title & attributes
      expect(find.text('Finance App Pro'), findsWidgets);
      expect(find.text('Personal budgeting and crypto tracking'), findsOneWidget);
      expect(find.text('Completed'), findsWidgets);

      // Confirms truthful metrics
      expect(find.text('2 files'), findsOneWidget);
      expect(find.text('1 builds'), findsOneWidget);

      // Actions are enabled
      final settingsButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Settings'),
      );
      expect(settingsButton.onPressed, isNotNull);

      final openAgentsButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Open agents'),
      );
      expect(openAgentsButton.onPressed, isNotNull);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Open agents'));
      expect(navigatedRoute, 'Agent Workspace');
    });

    testWidgets('Tab switching between Overview, Code & Files, AI Proposals, Build & Test, and Logs works smoothly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      final testProject = Project(
        id: 'proj-777',
        name: 'Omni Workspace',
        status: 'created',
        workspacePath: 'D:\\workspace\\omni',
        projectType: 'flutter',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      testVm.setCustomProject(testProject);
      testVm.setCustomFiles([
        ProjectFile(path: 'lib/main.dart', name: 'main.dart', isDir: false, size: 1024),
      ]);
      testVm.setCustomLogs('proj-777', [
        LogEntry(
          id: 1,
          projectId: 'proj-777',
          logLevel: 'INFO',
          message: 'Project workspace initialized',
          createdAt: DateTime(2026, 1, 1, 12, 0),
        ),
      ]);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Starts on Overview
      expect(find.text('Latest Activity & Execution Logs'), findsOneWidget);

      // Switch to Code & Files
      await tester.tap(find.text('Code & Files').first);
      await tester.pumpAndSettle();
      expect(find.text('main.dart'), findsOneWidget);

      // Switch to AI Proposals
      await tester.tap(find.text('AI Proposals').first);
      await tester.pumpAndSettle();
      expect(find.text('No Pending AI Proposals'), findsOneWidget);

      // Switch to Build & Test
      await tester.tap(find.text('Build & Test').first);
      await tester.pumpAndSettle();
      expect(find.text('Build History'), findsOneWidget);
      expect(find.text('Trigger Build'), findsOneWidget);

      // Switch to Execution Logs
      await tester.tap(find.text('Execution Logs').first);
      await tester.pumpAndSettle();
      expect(find.text('Project workspace initialized'), findsOneWidget);
      expect(find.text('Search logs...'), findsOneWidget);
    });

    testWidgets('Responsive rendering works without layout errors on desktop, tablet, and mobile', (tester) async {
      final testProject = Project(
        id: 'proj-responsive',
        name: 'Responsive Check',
        status: 'generating',
        workspacePath: 'D:\\workspace\\resp',
        projectType: 'flutter',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      testVm.setCustomProject(testProject);

      // Desktop
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Tablet
      await tester.binding.setSurfaceSize(const Size(768, 1024));
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Mobile
      await tester.binding.setSurfaceSize(const Size(375, 812));
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('File explorer, reading, editing, dirty state, save and discard work as expected', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      final testProject = Project(
        id: 'proj-editor-test',
        name: 'Editor Project',
        status: 'created',
        workspacePath: 'D:\\workspace\\editor',
        projectType: 'flutter',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      testVm.setCustomProject(testProject);
      testVm.setCustomFiles([
        ProjectFile(path: 'lib/main.dart', name: 'main.dart', isDir: false, size: 512),
      ]);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Navigate to Code & Files tab
      await tester.tap(find.text('Code & Files').first);
      await tester.pumpAndSettle();

      // Click on main.dart to open
      await tester.tap(find.text('main.dart'));
      await tester.pumpAndSettle();

      // Verifies editor displays file and content
      expect(find.text('lib/main.dart'), findsOneWidget);
      expect(find.text('void main() => runApp(const App());'), findsOneWidget);
      expect(find.text('Modified'), findsNothing);

      // Edit content
      final editorField = find.byType(TextField).last;
      await tester.enterText(editorField, 'void main() => runApp(const ModifiedApp());');
      await tester.pumpAndSettle();

      // Dirty state is activated
      expect(testVm.isDirty, isTrue);
      expect(find.text('Modified'), findsOneWidget);

      // Test Discard action
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(testVm.isDirty, isFalse);
      expect(find.text('Modified'), findsNothing);

      // Edit again and test Save action
      await tester.enterText(editorField, 'void main() => runApp(const SavedApp());');
      await tester.pumpAndSettle();
      expect(testVm.isDirty, isTrue);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(testVm.isDirty, isFalse);
      expect(find.text('Modified'), findsNothing);
    });

    testWidgets('AI proposal review, apply, discard, and build trigger work as expected', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      final testProject = Project(
        id: 'proj-proposal-test',
        name: 'Proposal Project',
        status: 'created',
        workspacePath: 'D:\\workspace\\prop',
        projectType: 'flutter',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      testVm.setCustomProject(testProject);
      testVm.setCustomProposals([
        ProposedFileChange(
          path: 'lib/theme.dart',
          action: 'create',
          proposedContent: 'const primaryColor = Colors.cyan;',
        ),
      ]);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Navigate to AI Proposals tab
      await tester.tap(find.text('AI Proposals').first);
      await tester.pumpAndSettle();

      // Verifies proposal content and badges
      expect(find.text('CREATE'), findsOneWidget);
      expect(find.text('lib/theme.dart'), findsOneWidget);
      expect(find.text('const primaryColor = Colors.cyan;'), findsOneWidget);

      // Discard proposal
      await tester.tap(find.text('Discard Proposal'));
      await tester.pumpAndSettle();
      expect(testVm.proposedChanges.isEmpty, isTrue);
      expect(find.text('No Pending AI Proposals'), findsOneWidget);

      // Navigate to Build & Test tab
      await tester.tap(find.text('Build & Test').first);
      await tester.pumpAndSettle();

      // Trigger build
      await tester.tap(find.text('Trigger Build'));
      await tester.pumpAndSettle();

      // Verifies new build job is created in history
      expect(testVm.buildJobs.isNotEmpty, isTrue);
      expect(find.text('BUILDING'), findsOneWidget);
    });
  });
}
