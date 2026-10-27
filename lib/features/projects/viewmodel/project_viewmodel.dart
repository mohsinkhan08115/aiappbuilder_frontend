import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/utils/selected_file.dart';
import '../../../data/models/project.dart';
import '../../../data/models/log_entry.dart';
import '../../../data/models/build_job.dart';
import '../../../data/models/project_file.dart';
import '../../../data/models/proposed_file_change.dart';
import '../../../data/models/github_repo.dart';
import '../../../data/repositories/project_repository.dart';
import '../../../data/services/api_service.dart';
import '../../../core/errors/app_error_handler.dart';

import '../../../data/services/preferences_service.dart';

class ProjectViewModel extends ChangeNotifier {
  final ProjectRepository _projectRepository;
  final ApiService _apiService;
  final PreferencesService? _preferencesService;

  List<Project> _projects = [];
  List<BuildJob> _buildJobs = [];
  final Map<String, List<LogEntry>> _projectLogs = {};
  Project? _selectedProject;
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _githubDiagnostics;

  // Workspace File Explorer & Editing state
  List<ProjectFile> _projectFiles = [];
  ProjectFile? _selectedFile;
  String? _openFileContent;
  String _editedContent = '';
  bool _isFileLoading = false;
  bool _isSavingFile = false;
  bool _isImportingZip = false;
  double? _importProgress;
  bool _isDirty = false;

  // AI Proposed Changes & analysis state
  List<ProposedFileChange> _proposedChanges = [];
  List<String> _proposedDependencies = [];
  bool _isApplyingChanges = false;
  String? _aiAnalysisText;
  bool _isAnalyzing = false;

  Timer? _pollingTimer;

  ProjectViewModel(this._projectRepository, this._apiService, [this._preferencesService]);

  List<Project> get projects => _projects;
  List<BuildJob> get buildJobs => _buildJobs;
  Map<String, List<LogEntry>> get projectLogs => _projectLogs;
  bool _isThinking = false;
  bool get isThinking => _isThinking;

  Project? get selectedProject => _selectedProject;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get githubDiagnostics => _githubDiagnostics;

  List<ProjectFile> get projectFiles => _projectFiles;
  ProjectFile? get selectedFile => _selectedFile;
  String? get openFileContent => _openFileContent;
  String get editedContent => _editedContent;
  bool get isFileLoading => _isFileLoading;
  bool get isSavingFile => _isSavingFile;
  bool get isImportingZip => _isImportingZip;
  double? get importProgress => _importProgress;
  bool get isDirty => _isDirty;

  List<ProposedFileChange> get proposedChanges => _proposedChanges;
  List<String> get proposedDependencies => _proposedDependencies;
  bool get isApplyingChanges => _isApplyingChanges;
  String? get aiAnalysisText => _aiAnalysisText;
  bool get isAnalyzing => _isAnalyzing;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> fetchProjects() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _projects = await _projectRepository.listProjects();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = AppErrorHandler.parseError(e);
      notifyListeners();
    }
  }

  Future<Project?> createProject(
    String name,
    String? description, {
    bool initializeFlutter = false,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newProj = await _projectRepository.createProject(
        name,
        description,
        initializeFlutter: initializeFlutter,
      );
      _projects.insert(0, newProj);
      _isLoading = false;
      notifyListeners();
      return newProj;
    } catch (e) {
      _isLoading = false;
      _error = AppErrorHandler.parseError(e);
      notifyListeners();
      return null;
    }
  }

  Future<void> deleteProject(String projectId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _projectRepository.deleteProject(projectId);
      _projects.removeWhere((p) => p.id == projectId);
      if (_selectedProject?.id == projectId) {
        _selectedProject = null;
        _buildJobs = [];
        stopLogPolling();
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = AppErrorHandler.parseError(e);
      notifyListeners();
    }
  }

  Future<void> selectProject(String projectId) async {
    _selectedProject = null;
    _error = null;
    _buildJobs = [];
    _projectFiles = [];
    _selectedFile = null;
    _openFileContent = null;
    _editedContent = '';
    _isDirty = false;
    notifyListeners();

    try {
      _selectedProject = await _projectRepository.getProject(projectId);
      await fetchLogs(projectId);
      await fetchBuilds(projectId);
      await fetchFiles(projectId);

      final project = _selectedProject;
      if (project != null) {
        _preferencesService?.setSelectedProjectId(project.id);
      }
      if (project != null &&
          (project.isActive ||
              _buildJobs.any(
                (job) => job.status == 'queued' || job.status == 'building',
              ))) {
        startLogPolling(projectId);
      } else {
        stopLogPolling();
      }
      notifyListeners();
    } catch (e) {
      _error = AppErrorHandler.parseError(e);
      notifyListeners();
    }
  }

  Future<void> restoreSelectedProjectFromStorage() async {
    final savedId = _preferencesService?.getSelectedProjectId();
    if (savedId != null && savedId.isNotEmpty && _selectedProject == null) {
      await selectProject(savedId);
    }
  }

  Future<void> fetchFiles(String projectId) async {
    try {
      _projectFiles = await _projectRepository.fetchProjectFiles(projectId);
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching files for $projectId: $e");
    }
  }

  Future<void> openFile(String projectId, ProjectFile file) async {
    _selectedFile = file;
    _openFileContent = null;
    _editedContent = '';
    _isDirty = false;
    _isFileLoading = true;
    _error = null;
    notifyListeners();

    try {
      final content = await _projectRepository.getFileContent(projectId, file.path);
      _openFileContent = content;
      _editedContent = content;
      _isFileLoading = false;
      notifyListeners();
    } catch (e) {
      _isFileLoading = false;
      _error = AppErrorHandler.parseError(e);
      notifyListeners();
    }
  }

  void updateEditedContent(String content) {
    _editedContent = content;
    _isDirty = (_editedContent != _openFileContent);
    notifyListeners();
  }

  void cancelEdits() {
    _editedContent = _openFileContent ?? '';
    _isDirty = false;
    notifyListeners();
  }

  Future<void> saveFile(String projectId) async {
    final file = _selectedFile;
    if (file == null) return;
    _isSavingFile = true;
    _error = null;
    notifyListeners();

    try {
      await _projectRepository.saveFileContent(projectId, file.path, _editedContent);
      _openFileContent = _editedContent;
      _isDirty = false;
      _isSavingFile = false;
      await fetchFiles(projectId);
      notifyListeners();
    } catch (e) {
      _isSavingFile = false;
      _error = AppErrorHandler.parseError(e);
      notifyListeners();
    }
  }

  Future<void> importZip(
    String projectId,
    List<int> zipBytes,
    String filename,
  ) async {
    _isImportingZip = true;
    _importProgress = 0.0;
    _error = null;
    notifyListeners();

    try {
      await _projectRepository.importProjectZip(
        projectId,
        zipBytes,
        filename,
        onSendProgress: (sent, total) {
          if (total > 0) {
            _importProgress = sent / total;
            notifyListeners();
          }
        },
      );
      _isImportingZip = false;
      _importProgress = null;
      _selectedProject = await _projectRepository.getProject(projectId);
      final index = _projects.indexWhere((p) => p.id == projectId);
      if (index != -1) {
        final project = _selectedProject;
        if (project != null) {
          _projects[index] = project;
        }
      }
      await fetchFiles(projectId);
      notifyListeners();
    } catch (e) {
      _isImportingZip = false;
      _importProgress = null;
      _error = AppErrorHandler.parseError(e);
      notifyListeners();
      rethrow;
    }
  }

  Future<Project> uploadAndImportProject(
    List<int> zipBytes,
    String filename,
  ) async {
    _isImportingZip = true;
    _importProgress = 0.0;
    _error = null;
    notifyListeners();

    try {
      final derivedName = filename.replaceAll(
        RegExp(r'\.zip$', caseSensitive: false),
        '',
      );

      final importedProj = await _projectRepository.uploadProjectZip(
        derivedName,
        null,
        zipBytes,
        filename,
        onSendProgress: (sent, total) {
          if (total > 0) {
            _importProgress = sent / total;
            notifyListeners();
          }
        },
      );

      _projects.removeWhere((p) => p.id == importedProj.id);
      _projects.insert(0, importedProj);

      await selectProject(importedProj.id);

      _isImportingZip = false;
      _importProgress = null;
      notifyListeners();
      return importedProj;
    } catch (e) {
      _isImportingZip = false;
      _importProgress = null;
      _error = AppErrorHandler.parseError(e);
      notifyListeners();
      rethrow;
    }
  }

  Future<Project> uploadFolder(
    String folderName,
    List<SelectedFile> files,
  ) async {
    _isImportingZip = true;
    _importProgress = 0.0;
    _error = null;
    notifyListeners();

    try {
      final importedProj = await _projectRepository.uploadFolder(
        folderName,
        files,
        onSendProgress: (sent, total) {
          if (total > 0) {
            _importProgress = sent / total;
            notifyListeners();
          }
        },
      );

      _projects.removeWhere((p) => p.id == importedProj.id);
      _projects.insert(0, importedProj);

      await selectProject(importedProj.id);

      _isImportingZip = false;
      _importProgress = null;
      notifyListeners();
      return importedProj;
    } catch (e) {
      _isImportingZip = false;
      _importProgress = null;
      _error = AppErrorHandler.parseError(e);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> startModification(String projectId, String prompt) async {
    _error = null;
    _isThinking = true;
    final project = _selectedProject;
    if (project != null && project.id == projectId) {
      project.status = 'generating';
    }
    startLogPolling(projectId);
    notifyListeners();

    try {
      final updatedProject = await _projectRepository.modifyProject(projectId, prompt);
      _selectedProject = updatedProject;
      _isThinking = false;
      final index = _projects.indexWhere((p) => p.id == projectId);
      if (index != -1) {
        _projects[index] = updatedProject;
      }
      notifyListeners();
    } catch (e) {
      _error = AppErrorHandler.parseError(e);
      _isThinking = false;
      final projectRevert = _selectedProject;
      if (projectRevert != null && projectRevert.id == projectId) {
        projectRevert.status = 'completed';
      }
      stopLogPolling();
      notifyListeners();
    }
  }

  Future<void> startGeneration(String projectId, String prompt) async {
    _error = null;
    _isThinking = true;
    final project = _selectedProject;
    if (project != null && project.id == projectId) {
      project.status = 'generating';
    }
    startLogPolling(projectId);
    notifyListeners();

    try {
      final updatedProject = await _projectRepository.generateProject(
        projectId,
        prompt,
      );
      _selectedProject = updatedProject;
      _isThinking = false;
      final index = _projects.indexWhere((p) => p.id == projectId);
      if (index != -1) {
        _projects[index] = updatedProject;
      }
      notifyListeners();
    } catch (e) {
      _error = AppErrorHandler.parseError(e);
      _isThinking = false;
      final projectRevert = _selectedProject;
      if (projectRevert != null && projectRevert.id == projectId) {
        projectRevert.status = 'created';
      }
      stopLogPolling();
      notifyListeners();
    }
  }

  void discardAIProposal() {
    _proposedChanges = [];
    _proposedDependencies = [];
    notifyListeners();
  }

  void clearAIProposal() => discardAIProposal();

  Future<void> fetchAIProposal(
    String projectId,
    String prompt, {
    String? activeFilePath,
  }) async {
    _error = null;
    _isThinking = true;
    _proposedChanges = [];
    _proposedDependencies = [];
    notifyListeners();

    try {
      final data = await _projectRepository.getAIProposal(
        projectId,
        prompt,
        activeFilePath,
      );

      final changesList = data['changes'] as List;
      _proposedChanges = changesList
          .map(
            (item) => ProposedFileChange.fromJson(item as Map<String, dynamic>),
          )
          .toList();

      final depsList = data['dependencies_to_add'] as List;
      _proposedDependencies = depsList.map((e) => e.toString()).toList();

      _isThinking = false;
      notifyListeners();
    } catch (e) {
      _error = AppErrorHandler.parseError(e);
      _isThinking = false;
      notifyListeners();
    }
  }

  Future<void> applyAIProposal(String projectId) async {
    _error = null;
    _isApplyingChanges = true;
    notifyListeners();

    try {
      final filePayloads = _proposedChanges
          .map(
            (change) => {
              'path': change.path,
              'action': change.action,
              'content': change.proposedContent,
            },
          )
          .toList();

      final updatedProject = await _projectRepository.applyAIProposal(
        projectId,
        _proposedDependencies,
        filePayloads,
      );

      _selectedProject = updatedProject;
      final index = _projects.indexWhere((p) => p.id == projectId);
      if (index != -1) {
        _projects[index] = updatedProject;
      }

      _proposedChanges = [];
      _proposedDependencies = [];
      _isApplyingChanges = false;

      startLogPolling(projectId);
      notifyListeners();
    } catch (e) {
      _error = AppErrorHandler.parseError(e);
      _isApplyingChanges = false;
      notifyListeners();
    }
  }

  Future<void> askAIAnalysis(
    String projectId,
    String prompt, {
    String? activeFilePath,
  }) async {
    _error = null;
    _isAnalyzing = true;
    _aiAnalysisText = null;
    notifyListeners();

    try {
      final analysis = await _projectRepository.getAIAnalysis(
        projectId,
        prompt,
        activeFilePath,
      );
      _aiAnalysisText = analysis;
      _isAnalyzing = false;
      notifyListeners();
    } catch (e) {
      _error = AppErrorHandler.parseError(e);
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  void clearAIAnalysis() {
    _aiAnalysisText = null;
    notifyListeners();
  }

  Future<void> fetchLogs(String projectId) async {
    try {
      final logs = await _projectRepository.getLogs(projectId);
      _projectLogs[projectId] = logs;
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching logs for $projectId: $e");
    }
  }

  Future<void> fetchBuilds(String projectId) async {
    try {
      _buildJobs = await _projectRepository.getBuilds(projectId);
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching builds for $projectId: $e");
    }
  }

  Future<void> triggerBuild(String projectId, String platform) async {
    _error = null;
    notifyListeners();

    try {
      final newJob = await _projectRepository.buildProject(projectId, platform);
      _buildJobs.insert(0, newJob);
      startLogPolling(projectId);
      notifyListeners();
    } catch (e) {
      _error = AppErrorHandler.parseError(e);
      notifyListeners();
    }
  }

  Future<GitHubRepo?> fetchGithubRepo(String projectId) async {
    try {
      return await _projectRepository.getGithubRepo(projectId);
    } catch (e) {
      debugPrint("Error fetching GitHub repo status: $e");
      return null;
    }
  }

  Future<GitHubRepo> pushToGithub(
    String projectId,
    String repoName,
    bool isPrivate,
  ) async {
    _error = null;
    notifyListeners();

    try {
      final repo = await _projectRepository.pushToGithub(projectId, repoName, isPrivate);
      startLogPolling(projectId);
      notifyListeners();
      return repo;
    } catch (e) {
      final err = AppErrorHandler.parseError(e);
      _error = err;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> syncToGitHub(
    String projectId,
    String repoName,
    bool isPrivate,
  ) async {
    try {
      await pushToGithub(projectId, repoName, isPrivate);
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> updateGitHubToken(String token) async {
    _isLoading = true;
    _error = null;
    _githubDiagnostics = null;
    notifyListeners();

    try {
      final res = await _apiService.saveGithubToken(token);
      _isLoading = false;
      _githubDiagnostics = res;
      notifyListeners();
      return res;
    } catch (e) {
      _isLoading = false;
      _error = AppErrorHandler.parseError(e);
      notifyListeners();
      return null;
    }
  }

  void startLogPolling(String projectId) {
    stopLogPolling();

    _pollingTimer = Timer.periodic(const Duration(milliseconds: 1500), (
      timer,
    ) async {
      try {
        final currentProj = await _projectRepository.getProject(projectId);

        final index = _projects.indexWhere((p) => p.id == projectId);
        if (index != -1) {
          _projects[index] = currentProj;
        }

        final wasActive = _selectedProject?.isActive ?? false;

        if (_selectedProject?.id == projectId) {
          _selectedProject = currentProj;
        }

        await fetchLogs(projectId);
        await fetchBuilds(projectId);

        if (wasActive && !currentProj.isActive) {
          await fetchFiles(projectId);
          final openFileObj = _selectedFile;
          if (openFileObj != null) {
            await openFile(projectId, openFileObj);
          }
        }

        final hasActiveBuilds = _buildJobs.any(
          (job) => job.status == 'queued' || job.status == 'building',
        );
        if (!currentProj.isActive && !hasActiveBuilds) {
          stopLogPolling();
        }

        notifyListeners();
      } catch (e) {
        debugPrint("Error polling status: $e");
      }
    });
  }

  Future<void> exportProject(String projectId, String destinationPath) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _projectRepository.exportProject(projectId, destinationPath);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = AppErrorHandler.parseError(e);
      notifyListeners();
      rethrow;
    }
  }

  void stopLogPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  @override
  void dispose() {
    stopLogPolling();
    super.dispose();
  }
}
