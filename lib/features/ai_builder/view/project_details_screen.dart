import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/api_config.dart';
import '../../projects/viewmodel/project_viewmodel.dart';
import '../../../data/models/project.dart';
import '../../../data/models/log_entry.dart';
import '../../../data/models/build_job.dart';
import '../../../data/models/proposed_file_change.dart';
import '../../../data/models/project_file.dart';

class ProjectDetailsScreen extends StatefulWidget {
  const ProjectDetailsScreen({super.key});

  @override
  State<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends State<ProjectDetailsScreen> {
  final _promptController = TextEditingController();
  final _repoNameController = TextEditingController();
  final _scrollController = ScrollController();
  final _editorController = TextEditingController();

  ProjectFile? _lastOpenedFile;
  int _activeRightTab = 0; // 0: AI Assistant, 1: Terminal Logs, 2: Actions
  bool _autoScroll = true;
  bool _isPrivateRepo = false;
  String _selectedBuildPlatform = 'apk';
  String _logLevelFilter = 'ALL'; // ALL, INFO, WARNING, ERROR

  @override
  void initState() {
    super.initState();
    _promptController.text = "";
  }

  @override
  void dispose() {
    _promptController.dispose();
    _repoNameController.dispose();
    _scrollController.dispose();
    _editorController.dispose();
    super.dispose();
  }

  void _triggerAIProposal(Project project, ProjectViewModel vm) {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter instructions for the AI.')),
      );
      return;
    }
    vm.fetchAIProposal(
      project.id,
      prompt,
      activeFilePath: vm.selectedFile?.path,
    );
  }

  void _triggerAIAnalysis(Project project, ProjectViewModel vm) {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a question or topic.')),
      );
      return;
    }
    vm.askAIAnalysis(project.id, prompt, activeFilePath: vm.selectedFile?.path);
  }

  void _triggerBuild(Project project) {
    context.read<ProjectViewModel>().triggerBuild(
      project.id,
      _selectedBuildPlatform,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Build job queued for $_selectedBuildPlatform!')),
    );
  }

  void _triggerGitHubPush(Project project) {
    final repoName = _repoNameController.text.trim();
    if (repoName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a repository name.')),
      );
      return;
    }
    context.read<ProjectViewModel>().syncToGitHub(
      project.id,
      repoName,
      _isPrivateRepo,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Syncing codebase to GitHub repository...')),
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients && _autoScroll) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _downloadArtifact(Project project, BuildJob job) async {
    final downloadUrl =
        '${ApiConfig.baseUrl}/projects/${project.id}/builds/${job.id}/download';
    final uri = Uri.parse(downloadUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch download URL';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading artifact: $e')),
        );
      }
    }
  }

  List<LogEntry> _getFilteredLogs(List<LogEntry> logs) {
    if (_logLevelFilter == 'ALL') return logs;
    return logs
        .where((log) => log.logLevel.toUpperCase() == _logLevelFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final projectVm = context.watch<ProjectViewModel>();
    final project = projectVm.selectedProject;

    if (project == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Project Details')),
        body: const Center(child: Text('No project selected.')),
      );
    }

    // Keep code editor synced with active open file content
    if (projectVm.selectedFile != _lastOpenedFile) {
      _lastOpenedFile = projectVm.selectedFile;
      _editorController.text = projectVm.openFileContent ?? '';
    }

    final logs = _getFilteredLogs(projectVm.projectLogs[project.id] ?? []);
    if (project.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

    // Build the panels
    final fileExplorerPanel = Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: const Border(
          right: BorderSide(color: Colors.black26, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: const Text(
              'Files',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          Expanded(child: _buildFileExplorer(projectVm, project)),
        ],
      ),
    );

    final editorOrSpecPanel = _buildEditorOrSpecPanel(projectVm, project);
    final rightTabsPanel = _buildRightTabsPanel(project, projectVm, logs);

    return Scaffold(
      appBar: AppBar(
        title: Text('Workspace: ${project.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Workspace Status',
            onPressed: () => projectVm.selectProject(project.id),
          ),
        ],
      ),
      body: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 240, child: fileExplorerPanel),
                Expanded(child: editorOrSpecPanel),
                SizedBox(width: 400, child: rightTabsPanel),
              ],
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 250, child: fileExplorerPanel),
                  const Divider(),
                  SizedBox(height: 500, child: editorOrSpecPanel),
                  const Divider(),
                  SizedBox(height: 500, child: rightTabsPanel),
                ],
              ),
            ),
    );
  }

  Widget _buildFileExplorer(ProjectViewModel vm, Project project) {
    if (vm.projectFiles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.folder_open_outlined,
                color: Colors.grey,
                size: 36,
              ),
              const SizedBox(height: 12),
              const Text(
                'No files index found.',
                style: TextStyle(color: Colors.grey, fontSize: 11),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => vm.fetchFiles(project.id),
                child: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: vm.projectFiles.length,
      itemBuilder: (context, index) {
        final file = vm.projectFiles[index];
        final indent = (file.path.split('/').length - 1) * 12.0;
        final isSelected = vm.selectedFile?.path == file.path;

        return Padding(
          padding: EdgeInsets.only(left: indent),
          child: ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 0,
            ),
            visualDensity: VisualDensity.compact,
            leading: Icon(
              file.isDir ? Icons.folder : Icons.description_outlined,
              size: 16,
              color: file.isDir ? Colors.amber[700] : Colors.blueAccent,
            ),
            title: Text(
              file.name,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white70,
              ),
            ),
            onTap: file.isDir ? null : () => vm.openFile(project.id, file),
          ),
        );
      },
    );
  }

  Widget _buildEditorOrSpecPanel(ProjectViewModel vm, Project project) {
    if (vm.isFileLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final file = vm.selectedFile;
    if (file == null) {
      return _buildOverviewPanel(project, vm);
    }

    ProposedFileChange? proposedChange;
    for (final c in vm.proposedChanges) {
      if (c.path == file.path) {
        proposedChange = c;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Editor Header / Breadcrumbs
        Container(
          color: Theme.of(context).colorScheme.surfaceContainer,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.edit_note, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  file.path,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ),
              if (vm.isDirty) ...[
                TextButton.icon(
                  icon: const Icon(Icons.undo, size: 14),
                  label: const Text('Discard', style: TextStyle(fontSize: 11)),
                  onPressed: vm.cancelEdits,
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: vm.isSavingFile
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save, size: 14),
                  label: const Text('Save', style: TextStyle(fontSize: 11)),
                  onPressed: vm.isSavingFile
                      ? null
                      : () => vm.saveFile(project.id),
                ),
              ],
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: () {
                  vm.selectProject(project.id);
                },
              ),
            ],
          ),
        ),
        if (proposedChange != null) ...[
          // Proposed AI banner
          Container(
            color: Colors.green.withOpacity(0.15),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: Colors.greenAccent,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI proposed changes (${proposedChange.action.toUpperCase()}). Click Compare to review.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.greenAccent,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _showDiffDialog(proposedChange!),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                  ),
                  child: const Text(
                    'Compare Diff',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
        // Editor textarea
        Expanded(
          child: Container(
            color: const Color(0xFF0C0A12),
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _editorController,
              maxLines: null,
              onChanged: vm.updateEditedContent,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                color: Color(0xFFE2E0E7),
                height: 1.4,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewPanel(Project project, ProjectViewModel vm) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            project.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (project.description != null) ...[
            Text(
              project.description!,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
          ],
          const Divider(),
          const SizedBox(height: 16),
          const Text(
            'Project Setup & Status',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Workspace Status:'),
                Row(
                  children: [
                    if (project.isActive)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(
                        Icons.circle,
                        color: Colors.greenAccent,
                        size: 12,
                      ),
                    const SizedBox(width: 8),
                    Text(
                      project.statusDisplay,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Orchestrator Milestones',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  _buildMilestoneStep(
                    'Requirement Analysis',
                    _getStepState(project, ['analyzing_requirements']),
                  ),
                  _buildMilestoneStep(
                    'Flutter Workspace Creation',
                    _getStepState(project, ['creating_project']),
                  ),
                  _buildMilestoneStep(
                    'Adding pubspec.yaml Dependencies',
                    _getStepState(project, ['installing_dependencies']),
                  ),
                  _buildMilestoneStep(
                    'MVVM Structure & Code Generation',
                    _getStepState(project, ['generating_files']),
                  ),
                  _buildMilestoneStep(
                    'Static Analysis (flutter analyze)',
                    _getStepState(project, ['running_analyzer']),
                  ),
                  _buildMilestoneStep(
                    'Compile Error Correction (max 5 retries)',
                    _getStepState(project, ['fixing_errors']),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightTabsPanel(
    Project project,
    ProjectViewModel vm,
    List<LogEntry> logs,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF09070F),
        border: const Border(left: BorderSide(color: Colors.black26, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tab Headers
          Row(
            children: [
              _buildTabHeader(0, 'AI Assistant', Icons.auto_awesome),
              _buildTabHeader(1, 'Logs', Icons.terminal),
              _buildTabHeader(2, 'Actions', Icons.settings),
            ],
          ),
          const Divider(height: 1, color: Colors.white10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildRightTabContent(project, vm, logs),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabHeader(int tabIndex, String label, IconData icon) {
    final active = _activeRightTab == tabIndex;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _activeRightTab = tabIndex;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
            color: active ? Colors.white.withOpacity(0.03) : Colors.transparent,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: active ? Colors.white : Colors.grey),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  color: active ? Colors.white : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRightTabContent(
    Project project,
    ProjectViewModel vm,
    List<LogEntry> logs,
  ) {
    if (_activeRightTab == 0) {
      return _buildAIAssistantTab(project, vm);
    } else if (_activeRightTab == 1) {
      return _buildLogsTab(project, vm, logs);
    } else {
      return _buildActionsTab(project, vm);
    }
  }

  Widget _buildAIAssistantTab(Project project, ProjectViewModel vm) {
    if (vm.isApplyingChanges) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Applying files & running linter check...',
              style: TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Ask AI to Modify Project',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 6),
        Text(
          vm.selectedFile != null
              ? 'Instruct edits for current file:\n${vm.selectedFile!.path}'
              : 'Instruct edits for the whole project.',
          style: const TextStyle(color: Colors.grey, fontSize: 11),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _promptController,
          maxLines: 4,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            hintText:
                'e.g. Add Firebase authentication OR Change Todo UI screen colors to dark theme...',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: vm.isThinking
                    ? null
                    : () => _triggerAIProposal(project, vm),
                icon: const Icon(Icons.bolt, size: 14),
                label: const Text(
                  'Ask AI to Modify',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.help_outline, color: Colors.grey),
              tooltip: 'Explain / Analyze',
              onPressed: vm.isThinking
                  ? null
                  : () => _triggerAIAnalysis(project, vm),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (vm.isThinking) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'AI is planning and generating proposed updates...',
              style: TextStyle(fontSize: 11, color: Colors.amber),
            ),
          ),
        ],
        if (vm.error != null) ...[
          const SizedBox(height: 12),
          Text(
            'Error: ${vm.error}',
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
        ],
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Display proposed changes
                if (vm.proposedChanges.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.green.withOpacity(0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.green.withOpacity(0.2)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.auto_awesome,
                                color: Colors.greenAccent,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Proposed Updates (${vm.proposedChanges.length} files)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.greenAccent,
                                ),
                              ),
                            ],
                          ),
                          if (vm.proposedDependencies.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Packages to add: ${vm.proposedDependencies.join(", ")}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                          const Divider(height: 16),
                          ...vm.proposedChanges.map(
                            (change) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                change.path,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                ),
                              ),
                              subtitle: Text(
                                change.action.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: change.action == 'create'
                                      ? Colors.green
                                      : change.action == 'delete'
                                      ? Colors.red
                                      : Colors.amber,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.compare_arrows,
                                  size: 14,
                                ),
                                onPressed: () => _showDiffDialog(change),
                              ),
                              onTap: () {
                                // Find local file and select it
                                final localFile = vm.projectFiles
                                    .firstWhereOrNull(
                                      (f) => f.path == change.path,
                                    );
                                if (localFile != null) {
                                  vm.openFile(project.id, localFile);
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: vm.discardAIProposal,
                                child: const Text(
                                  'Discard',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => vm.applyAIProposal(project.id),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[800],
                                ),
                                child: const Text(
                                  'Apply Changes',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                // Display Analysis text
                if (vm.aiAnalysisText != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'AI Analysis Explanation',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 14),
                                onPressed: vm.clearAIAnalysis,
                              ),
                            ],
                          ),
                          const Divider(),
                          Text(
                            vm.aiAnalysisText!,
                            style: const TextStyle(fontSize: 12, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (vm.isAnalyzing) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'AI Companion is analyzing code...',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogsTab(
    Project project,
    ProjectViewModel vm,
    List<LogEntry> logs,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.terminal, color: Colors.greenAccent, size: 16),
                const SizedBox(width: 8),
                const Text(
                  'Terminal Logs',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Text(
                  'Auto-scroll',
                  style: TextStyle(color: Colors.grey, fontSize: 10),
                ),
                const SizedBox(width: 4),
                Switch(
                  value: _autoScroll,
                  onChanged: (val) {
                    setState(() {
                      _autoScroll = val;
                    });
                  },
                  activeThumbColor: Colors.greenAccent,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('ALL'),
              const SizedBox(width: 8),
              _buildFilterChip('INFO'),
              const SizedBox(width: 8),
              _buildFilterChip('WARNING'),
              const SizedBox(width: 8),
              _buildFilterChip('ERROR'),
            ],
          ),
        ),
        const Divider(color: Colors.white10),
        Expanded(
          child: logs.isEmpty
              ? const Center(
                  child: Text(
                    'No execution logs available.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return _buildTerminalLogLine(log);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildActionsTab(Project project, ProjectViewModel vm) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Binary Compilation Form
          const Text(
            'Binary Compilation (APK/AAB)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedBuildPlatform,
                  decoration: const InputDecoration(
                    labelText: 'Format',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 0,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'apk',
                      child: Text(
                        'Android APK (.apk)',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'appbundle',
                      child: Text(
                        'Android AppBundle (.aab)',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedBuildPlatform = val;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed:
                    project.status == 'completed' &&
                        !vm.buildJobs.any(
                          (j) => j.status == 'queued' || j.status == 'building',
                        )
                    ? () => _triggerBuild(project)
                    : null,
                child: const Text('Compile', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Build History',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const Divider(),
          if (vm.buildJobs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'No build runs recorded.',
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
            )
          else
            ...vm.buildJobs.map((job) => _buildBuildJobRow(project, job)),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          // GitHub Remote Push Form
          const Text(
            'GitHub Remote Push',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _repoNameController,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Repository Name',
              hintText: 'e.g. my-todo-app',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Private Repository', style: TextStyle(fontSize: 12)),
              Switch(
                value: _isPrivateRepo,
                onChanged: (val) {
                  setState(() {
                    _isPrivateRepo = val;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
            ),
            onPressed: project.status == 'completed'
                ? () => _triggerGitHubPush(project)
                : null,
            icon: const Icon(Icons.cloud_upload_outlined, size: 16),
            label: const Text(
              'Create & Push to GitHub',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final active = _logLevelFilter == label;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 10)),
      selected: active,
      selectedColor: Theme.of(context).colorScheme.primary,
      backgroundColor: Colors.transparent,
      onSelected: (val) {
        if (val) {
          setState(() {
            _logLevelFilter = label;
          });
        }
      },
    );
  }

  Widget _buildBuildJobRow(Project project, BuildJob job) {
    Color statusColor = Colors.grey;
    IconData icon = Icons.hourglass_empty;

    if (job.status == 'success') {
      statusColor = Colors.green;
      icon = Icons.check_circle_outline;
    } else if (job.status == 'failed') {
      statusColor = Colors.red;
      icon = Icons.error_outline;
    } else if (job.status == 'building') {
      statusColor = Colors.amber;
      icon = Icons.sync;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (job.status == 'building')
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                  ),
                )
              else
                Icon(icon, color: statusColor, size: 14),
              const SizedBox(width: 8),
              Text(
                '${job.targetPlatform.toUpperCase()} Build',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '(${job.status})',
                style: TextStyle(color: statusColor, fontSize: 10),
              ),
            ],
          ),
          if (job.status == 'success')
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(
                Icons.download,
                color: Colors.blueAccent,
                size: 16,
              ),
              tooltip: 'Download Artifact',
              onPressed: () => _downloadArtifact(project, job),
            ),
        ],
      ),
    );
  }

  Widget _buildTerminalLogLine(LogEntry log) {
    Color levelColor;
    switch (log.logLevel) {
      case 'ERROR':
        levelColor = Colors.redAccent;
        break;
      case 'WARNING':
        levelColor = Colors.amberAccent;
        break;
      default:
        levelColor = Colors.greenAccent;
    }

    final timestampStr =
        '${log.createdAt.hour.toString().padLeft(2, '0')}:${log.createdAt.minute.toString().padLeft(2, '0')}:${log.createdAt.second.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11.5,
            height: 1.4,
          ),
          children: [
            TextSpan(
              text: '[$timestampStr] ',
              style: const TextStyle(color: Colors.grey),
            ),
            TextSpan(
              text: '[${log.logLevel}] ',
              style: TextStyle(color: levelColor, fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text: log.message,
              style: const TextStyle(color: Color(0xFFE2E0E7)),
            ),
          ],
        ),
      ),
    );
  }

  int _getStepState(Project project, List<String> matchStatuses) {
    final status = project.status;
    if (status == 'failed') return -1;

    const orderedStates = [
      'analyzing_requirements',
      'creating_project',
      'installing_dependencies',
      'generating_files',
      'running_analyzer',
      'fixing_errors',
      'completed',
    ];

    final currentIndex = orderedStates.indexOf(status);
    final targetIndex = orderedStates.indexWhere(
      (s) => matchStatuses.contains(s),
    );

    if (currentIndex == -1) return 0;
    if (currentIndex > targetIndex) return 2;
    if (currentIndex == targetIndex) return 1;
    return 0;
  }

  Widget _buildMilestoneStep(String label, int state) {
    IconData icon = Icons.circle_outlined;
    Color color = Colors.grey;

    if (state == 1) {
      icon = Icons.sync;
      color = Colors.amber;
    } else if (state == 2) {
      icon = Icons.check_circle;
      color = Colors.green;
    } else if (state == -1) {
      icon = Icons.cancel;
      color = Colors.red;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          state == 1
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                  ),
                )
              : Icon(icon, color: color, size: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: state == 0 ? Colors.grey : Colors.white,
                fontWeight: state == 1 ? FontWeight.bold : FontWeight.normal,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDiffDialog(ProposedFileChange change) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF0F0E17),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Diff Review: ${change.path}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Original
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.03),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.15),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Original Code',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.redAccent,
                                  fontSize: 13,
                                ),
                              ),
                              const Divider(color: Colors.white12),
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Text(
                                    change.originalContent ?? '[New File]',
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11.5,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Proposed
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.03),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.15),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Proposed Code (AI)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.greenAccent,
                                  fontSize: 13,
                                ),
                              ),
                              const Divider(color: Colors.white12),
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Text(
                                    change.proposedContent ?? '[Deleted]',
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11.5,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

extension CollectionExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E element) test) {
    for (E element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
