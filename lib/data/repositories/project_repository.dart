import '../../core/utils/selected_file.dart';
import '../models/project.dart';
import '../models/log_entry.dart';
import '../models/build_job.dart';
import '../models/project_file.dart';
import '../models/github_repo.dart';
import '../services/api_service.dart';

abstract class ProjectRepository {
  Future<List<Project>> listProjects();
  Future<Project> createProject(String name, String? description, {bool initializeFlutter = false});
  Future<Project> getProject(String projectId);
  Future<void> deleteProject(String projectId);
  Future<Project> uploadFolder(String folderName, List<SelectedFile> files, {void Function(int sent, int total)? onSendProgress});
  Future<Project> uploadProjectZip(String name, String? description, List<int> zipBytes, String fileName, {void Function(int sent, int total)? onSendProgress});
  Future<void> importProjectZip(String projectId, List<int> zipBytes, String fileName, {void Function(int sent, int total)? onSendProgress});
  Future<Project> generateProject(String projectId, String prompt);
  Future<Project> modifyProject(String projectId, String prompt);
  Future<List<LogEntry>> getLogs(String projectId);
  Future<BuildJob> buildProject(String projectId, String platform);
  Future<List<BuildJob>> getBuilds(String projectId);
  Future<GitHubRepo> pushToGithub(String projectId, String repoName, bool isPrivate);
  Future<GitHubRepo?> getGithubRepo(String projectId);
  Future<List<ProjectFile>> fetchProjectFiles(String projectId);
  Future<String> getFileContent(String projectId, String filePath);
  Future<void> saveFileContent(String projectId, String filePath, String content);
  Future<Map<String, dynamic>> getAIProposal(String projectId, String prompt, String? activeFilePath);
  Future<Project> applyAIProposal(String projectId, List<String> dependenciesToAdd, List<Map<String, dynamic>> filesToUpdate);
  Future<String> getAIAnalysis(String projectId, String prompt, String? filePath);
  Future<void> exportProject(String projectId, String destinationPath);
}

class ProjectRepositoryImpl implements ProjectRepository {
  final ApiService _apiService;

  ProjectRepositoryImpl(this._apiService);

  @override
  Future<List<Project>> listProjects() => _apiService.listProjects();

  @override
  Future<Project> createProject(String name, String? description, {bool initializeFlutter = false}) =>
      _apiService.createProject(name, description, initializeFlutter: initializeFlutter);

  @override
  Future<Project> getProject(String projectId) => _apiService.getProject(projectId);

  @override
  Future<void> deleteProject(String projectId) => _apiService.deleteProject(projectId);

  @override
  Future<Project> uploadFolder(String folderName, List<SelectedFile> files, {void Function(int sent, int total)? onSendProgress}) =>
      _apiService.uploadFolder(folderName, files, onSendProgress: onSendProgress);

  @override
  Future<Project> uploadProjectZip(String name, String? description, List<int> zipBytes, String fileName, {void Function(int sent, int total)? onSendProgress}) =>
      _apiService.uploadProjectZip(name, description, zipBytes, fileName, onSendProgress: onSendProgress);

  @override
  Future<void> importProjectZip(String projectId, List<int> zipBytes, String fileName, {void Function(int sent, int total)? onSendProgress}) =>
      _apiService.importProjectZip(projectId, zipBytes, fileName, onSendProgress: onSendProgress);

  @override
  Future<Project> generateProject(String projectId, String prompt) =>
      _apiService.generateProject(projectId, prompt);

  @override
  Future<Project> modifyProject(String projectId, String prompt) =>
      _apiService.modifyProject(projectId, prompt);

  @override
  Future<List<LogEntry>> getLogs(String projectId) => _apiService.getLogs(projectId);

  @override
  Future<BuildJob> buildProject(String projectId, String platform) =>
      _apiService.buildProject(projectId, platform);

  @override
  Future<List<BuildJob>> getBuilds(String projectId) => _apiService.getBuilds(projectId);

  @override
  Future<GitHubRepo> pushToGithub(String projectId, String repoName, bool isPrivate) =>
      _apiService.pushToGithub(projectId, repoName, isPrivate);

  @override
  Future<GitHubRepo?> getGithubRepo(String projectId) =>
      _apiService.getGithubRepo(projectId);

  @override
  Future<List<ProjectFile>> fetchProjectFiles(String projectId) =>
      _apiService.fetchProjectFiles(projectId);

  @override
  Future<String> getFileContent(String projectId, String filePath) =>
      _apiService.getFileContent(projectId, filePath);

  @override
  Future<void> saveFileContent(String projectId, String filePath, String content) =>
      _apiService.saveFileContent(projectId, filePath, content);

  @override
  Future<Map<String, dynamic>> getAIProposal(String projectId, String prompt, String? activeFilePath) =>
      _apiService.getAIProposal(projectId, prompt, activeFilePath);

  @override
  Future<Project> applyAIProposal(String projectId, List<String> dependenciesToAdd, List<Map<String, dynamic>> filesToUpdate) =>
      _apiService.applyAIProposal(projectId, dependenciesToAdd, filesToUpdate);

  @override
  Future<String> getAIAnalysis(String projectId, String prompt, String? filePath) =>
      _apiService.getAIAnalysis(projectId, prompt, filePath);

  @override
  Future<void> exportProject(String projectId, String destinationPath) =>
      _apiService.exportProject(projectId, destinationPath);
}
