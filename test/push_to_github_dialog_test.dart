import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:aiappbuilder/core/components/push_to_github_dialog.dart';
import 'package:aiappbuilder/core/utils/selected_file.dart';
import 'package:aiappbuilder/data/models/project.dart';
import 'package:aiappbuilder/data/models/build_job.dart';
import 'package:aiappbuilder/data/models/log_entry.dart';
import 'package:aiappbuilder/data/models/project_file.dart';
import 'package:aiappbuilder/data/models/github_repo.dart';
import 'package:aiappbuilder/data/repositories/project_repository.dart';
import 'package:aiappbuilder/data/services/api_service.dart';
import 'package:aiappbuilder/features/projects/viewmodel/project_viewmodel.dart';

class MockPushProjectRepository implements ProjectRepository {
  GitHubRepo? repoToReturn;
  Object? errorToThrow;
  int pushCalls = 0;
  String? lastRepoName;
  bool? lastIsPrivate;

  @override
  Future<GitHubRepo> pushToGithub(String projectId, String repoName, bool isPrivate) async {
    pushCalls++;
    lastRepoName = repoName;
    lastIsPrivate = isPrivate;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return repoToReturn ??
        GitHubRepo(
          id: 'repo-1',
          projectId: projectId,
          repoName: repoName,
          repoUrl: 'https://github.com/octocat/$repoName',
          syncStatus: 'synchronized',
          createdAt: DateTime.now(),
        );
  }

  @override
  Future<GitHubRepo?> getGithubRepo(String projectId) async => repoToReturn;

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
  Future<void> saveFileContent(String projectId, String filePath, String content) => throw UnimplementedError();
  @override
  Future<Project> uploadFolder(String folderName, List<SelectedFile> files, {void Function(int sent, int total)? onSendProgress}) => throw UnimplementedError();
  @override
  Future<Project> uploadProjectZip(String name, String? description, List<int> zipBytes, String fileName, {void Function(int sent, int total)? onSendProgress}) => throw UnimplementedError();
}

void main() {
  late MockPushProjectRepository mockRepo;
  late ProjectViewModel vm;

  final sampleProject = Project(
    id: 'proj-123',
    name: 'My Cool App',
    description: 'An AI-crafted flutter app',
    status: 'completed',
    workspacePath: 'D:\\workspace\\proj-123',
    projectType: 'new',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  Widget createTestWidget({required Widget child}) {
    return ChangeNotifierProvider<ProjectViewModel>.value(
      value: vm,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => child,
          ),
        ),
      ),
    );
  }

  setUp(() {
    mockRepo = MockPushProjectRepository();
    vm = ProjectViewModel(mockRepo, ApiService());
  });

  tearDown(() {
    vm.dispose();
  });

  testWidgets('renders dialog with sanitized prefilled repo name and default private selection', (tester) async {
    await tester.pumpWidget(
      createTestWidget(
        child: PushToGitHubDialog(project: sampleProject),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Push to GitHub'), findsWidgets);
    expect(find.text('My Cool App'), findsOneWidget);
    expect(find.text('branch: main'), findsOneWidget);
    expect(find.text('my-cool-app'), findsOneWidget); // Sanitized prefilled name
    expect(find.text('Private repository (Recommended)'), findsOneWidget);
    expect(find.text('Public repository'), findsOneWidget);
    expect(find.textContaining('Security Protection:'), findsOneWidget);
  });

  testWidgets('validates repository name and disables submit on invalid input', (tester) async {
    await tester.pumpWidget(
      createTestWidget(
        child: PushToGitHubDialog(project: sampleProject),
      ),
    );
    await tester.pumpAndSettle();

    final inputFinder = find.byType(TextField);
    expect(inputFinder, findsOneWidget);

    // Enter empty string
    await tester.enterText(inputFinder, '');
    await tester.pumpAndSettle();
    expect(find.text('Repository name cannot be empty.'), findsOneWidget);

    // Enter invalid characters
    await tester.enterText(inputFinder, 'bad name with spaces');
    await tester.pumpAndSettle();
    expect(find.text('Only alphanumeric characters, hyphens, underscores, and periods are allowed.'), findsOneWidget);

    // Enter trailing .git
    await tester.enterText(inputFinder, 'app.git');
    await tester.pumpAndSettle();
    expect(find.text('Repository name cannot end with .git.'), findsOneWidget);
  });

  testWidgets('successful push displays success view and clickable repository URL', (tester) async {
    String? notifiedUrl;
    await tester.pumpWidget(
      createTestWidget(
        child: PushToGitHubDialog(
          project: sampleProject,
          onSuccess: (url) => notifiedUrl = url,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Push to GitHub
    final pushBtn = find.widgetWithText(ElevatedButton, 'Push to GitHub');
    expect(pushBtn, findsOneWidget);
    await tester.tap(pushBtn);
    await tester.pumpAndSettle();

    expect(mockRepo.pushCalls, 1);
    expect(mockRepo.lastRepoName, 'my-cool-app');
    expect(mockRepo.lastIsPrivate, true);

    // Success screen
    expect(find.text('Project Pushed to GitHub!'), findsOneWidget);
    expect(find.text('https://github.com/octocat/my-cool-app'), findsOneWidget);
    expect(find.text('Copy URL'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(notifiedUrl, 'https://github.com/octocat/my-cool-app');
    vm.stopLogPolling();
  });

  testWidgets('failed push displays clear error message and enables retry', (tester) async {
    mockRepo.errorToThrow = Exception('GitHub repository "octocat/my-cool-app" already exists and contains existing commits.');

    await tester.pumpWidget(
      createTestWidget(
        child: PushToGitHubDialog(project: sampleProject),
      ),
    );
    await tester.pumpAndSettle();

    final pushBtn = find.widgetWithText(ElevatedButton, 'Push to GitHub');
    await tester.tap(pushBtn);
    await tester.pumpAndSettle();

    expect(mockRepo.pushCalls, 1);
    expect(find.textContaining('already exists and contains existing commits'), findsOneWidget);

    // Buttons should remain enabled for retry
    expect(find.widgetWithText(ElevatedButton, 'Push to GitHub'), findsOneWidget);
  });
}
