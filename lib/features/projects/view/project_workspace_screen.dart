import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/components/status_pill.dart';
import '../../../data/models/project.dart';
import '../../../data/models/project_file.dart';
import '../../../data/models/build_job.dart';
import '../../../data/models/log_entry.dart';
import '../../../data/models/proposed_file_change.dart';
import '../../../core/components/push_to_github_dialog.dart';
import '../viewmodel/project_viewmodel.dart';

class ProjectWorkspaceScreen extends StatefulWidget {
  final void Function(String route) onNavigate;
  final void Function(String message) onNotify;

  const ProjectWorkspaceScreen({
    super.key,
    required this.onNavigate,
    required this.onNotify,
  });

  @override
  State<ProjectWorkspaceScreen> createState() => _ProjectWorkspaceScreenState();
}

class _ProjectWorkspaceScreenState extends State<ProjectWorkspaceScreen> {
  String _activeTab = 'Overview';
  String _selectedPlatform = 'apk';
  String _logLevelFilter = 'ALL';
  final _fileSearchController = TextEditingController();
  final _logSearchController = TextEditingController();
  final _codeEditorController = TextEditingController();
  String? _lastOpenedFilePath;

  @override
  void dispose() {
    _fileSearchController.dispose();
    _logSearchController.dispose();
    _codeEditorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vm = context.watch<ProjectViewModel>();
    final proj = vm.selectedProject;

    // Sync editor text controller when a new file content is loaded
    if (vm.openFileContent != null && vm.selectedFile?.path != _lastOpenedFilePath) {
      _lastOpenedFilePath = vm.selectedFile?.path;
      _codeEditorController.text = vm.editedContent;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, isDark, vm, proj),
              const SizedBox(height: 24),
              if (proj == null)
                _buildEmptyState(context, isDark)
              else
                _buildProjectWorkspace(context, isDark, vm, proj),
            ],
          ),
        ),
      ),
    );
  }

  // --- HEADER SECTION ---

  Widget _buildHeader(BuildContext context, bool isDark, ProjectViewModel vm, Project? proj) {
    final hasProject = proj != null;
    final title = hasProject ? proj.name : 'No Project Selected';
    final subtitle = hasProject
        ? (proj.description?.isNotEmpty == true
            ? proj.description!
            : 'Workspace active · Flutter Project')
        : 'Select or create a project to inspect code, run builds, and manage tasks';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 720;

        final titleSection = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                const Text(
                  'PROJECT WORKSPACE',
                  style: TextStyle(
                    color: AppColors.cyan,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                if (hasProject)
                  _buildStatusBadge(proj),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                fontSize: 12,
              ),
            ),
          ],
        );

        final actionButtons = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: hasProject
                  ? () => _showProjectSettingsDialog(context, vm, proj)
                  : null,
              icon: const Icon(Icons.settings, size: 14),
              label: const Text('Settings'),
              style: OutlinedButton.styleFrom(
                disabledForegroundColor: isDark ? AppColors.darkMuted2 : AppColors.lightMuted2,
              ),
            ),
            OutlinedButton.icon(
              onPressed: hasProject
                  ? () => _showGithubSyncDialog(context, vm, proj)
                  : null,
              icon: const Icon(Icons.cloud_upload_outlined, size: 14),
              label: const Text('Push to GitHub'),
              style: OutlinedButton.styleFrom(
                disabledForegroundColor: isDark ? AppColors.darkMuted2 : AppColors.lightMuted2,
              ),
            ),
            ElevatedButton.icon(
              onPressed: hasProject
                  ? () => widget.onNavigate('Agent Workspace')
                  : null,
              icon: const Icon(Icons.psychology, size: 14),
              label: const Text('Open agents'),
              style: ElevatedButton.styleFrom(
                disabledBackgroundColor: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                disabledForegroundColor: isDark ? AppColors.darkMuted : AppColors.lightMuted,
              ),
            ),
          ],
        );

        return isWide
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: titleSection),
                  const SizedBox(width: 16),
                  actionButtons,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleSection,
                  const SizedBox(height: 16),
                  actionButtons,
                ],
              );
      },
    );
  }

  Widget _buildStatusBadge(Project proj) {
    final statusType = switch (proj.status) {
      'completed' => StatusType.success,
      'failed' => StatusType.error,
      'created' => StatusType.neutral,
      _ => StatusType.running,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: switch (statusType) {
          StatusType.success => AppColors.green.withValues(alpha: 0.12),
          StatusType.error => AppColors.red.withValues(alpha: 0.12),
          StatusType.running => AppColors.cyan.withValues(alpha: 0.12),
          _ => AppColors.darkMuted.withValues(alpha: 0.12),
        },
        borderRadius: BorderRadius.circular(12),
      ),
      child: StatusPill(
        label: proj.statusDisplay,
        type: statusType,
        fontSize: 10,
      ),
    );
  }

  // --- EMPTY STATE (WHEN NO PROJECT SELECTED) ---

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: const Icon(
              Icons.folder_open_outlined,
              size: 32,
              color: AppColors.primaryBright,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Project Loaded in Workspace',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Text(
              'Select an existing project or create a new one to open source files, run builds, inspect execution logs, and collaborate with AI agents.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => widget.onNavigate('Projects'),
                icon: const Icon(Icons.folder, size: 16),
                label: const Text('Browse Projects'),
              ),
              OutlinedButton.icon(
                onPressed: () => widget.onNavigate('Projects'),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Create New Project'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- POPULATED PROJECT WORKSPACE ---

  Widget _buildProjectWorkspace(
    BuildContext context,
    bool isDark,
    ProjectViewModel vm,
    Project proj,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Navigation Tabs Shell
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tab Header Bar
              Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      'Overview',
                      'Code & Files',
                      'AI Proposals',
                      'Build & Test',
                      'Execution Logs',
                    ].map((tab) {
                      final selected = _activeTab == tab;
                      int badgeCount = 0;
                      if (tab == 'AI Proposals') {
                        badgeCount = vm.proposedChanges.length;
                      } else if (tab == 'Build & Test') {
                        badgeCount = vm.buildJobs.length;
                      }

                      return InkWell(
                        onTap: () => setState(() => _activeTab = tab),
                        child: Container(
                          height: 46,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: selected ? AppColors.primaryBright : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tab,
                                style: TextStyle(
                                  color: selected
                                      ? (isDark ? AppColors.darkText : AppColors.lightText)
                                      : AppColors.darkMuted,
                                  fontSize: 12,
                                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                              if (badgeCount > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppColors.primaryBright.withValues(alpha: 0.2)
                                        : (isDark ? AppColors.darkSurface3 : AppColors.lightSurface3),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$badgeCount',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: selected ? AppColors.primaryBright : AppColors.darkMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Tab View Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: _buildActiveTabContent(context, isDark, vm, proj),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveTabContent(
    BuildContext context,
    bool isDark,
    ProjectViewModel vm,
    Project proj,
  ) {
    switch (_activeTab) {
      case 'Overview':
        return _buildOverviewTab(context, isDark, vm, proj);
      case 'Code & Files':
        return _buildCodeAndFilesTab(context, isDark, vm, proj);
      case 'AI Proposals':
        return _buildAIProposalsTab(context, isDark, vm, proj);
      case 'Build & Test':
        return _buildBuildAndTestTab(context, isDark, vm, proj);
      case 'Execution Logs':
        return _buildExecutionLogsTab(context, isDark, vm, proj);
      default:
        return _buildOverviewTab(context, isDark, vm, proj);
    }
  }

  // --- TAB 1: OVERVIEW ---

  Widget _buildOverviewTab(
    BuildContext context,
    bool isDark,
    ProjectViewModel vm,
    Project proj,
  ) {
    final logs = vm.projectLogs[proj.id] ?? <LogEntry>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Project Hero card with truthful project status
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.cyanMarkGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  proj.name.isNotEmpty ? proj.name[0].toUpperCase() : 'P',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      proj.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Type: ${proj.projectType} · Path: ${proj.workspacePath}',
                      style: TextStyle(
                        color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Status: ${proj.statusDisplay} · Created: ${proj.createdAt.toLocal().toString().split('.')[0]}',
                      style: const TextStyle(color: AppColors.cyan, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Truthful Project Metrics Grid
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 600;
            final stats = [
              _buildStatCard(
                Icons.folder,
                '${vm.projectFiles.length} files',
                'Indexed in workspace',
                isDark,
                onTap: () => setState(() => _activeTab = 'Code & Files'),
              ),
              _buildStatCard(
                Icons.build_circle_outlined,
                '${vm.buildJobs.length} builds',
                'Recorded build jobs',
                isDark,
                onTap: () => setState(() => _activeTab = 'Build & Test'),
              ),
              _buildStatCard(
                Icons.list_alt,
                '${logs.length} log lines',
                'System & agent output',
                isDark,
                onTap: () => setState(() => _activeTab = 'Execution Logs'),
              ),
              _buildStatCard(
                Icons.auto_awesome,
                '${vm.proposedChanges.length} proposals',
                'Pending AI changes',
                isDark,
                onTap: () => setState(() => _activeTab = 'AI Proposals'),
              ),
            ];

            return isWide
                ? Row(
                    children: stats
                        .map((w) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: w,
                              ),
                            ))
                        .toList(),
                  )
                : Column(
                    children: stats
                        .map((w) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: w,
                            ))
                        .toList(),
                  );
          },
        ),

        const SizedBox(height: 20),

        // Recent Logs Preview
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  const Text(
                    'Latest Activity & Execution Logs',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _activeTab = 'Execution Logs'),
                    child: const Text('View all logs', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (logs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No execution logs recorded yet for this project.',
                    style: TextStyle(
                      color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                ...logs.reversed.take(4).map((entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: entry.logLevel.toUpperCase() == 'ERROR'
                                  ? AppColors.red
                                  : entry.logLevel.toUpperCase() == 'WARNING'
                                      ? AppColors.amber
                                      : AppColors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            entry.createdAt.toLocal().toString().split(' ')[1].split('.')[0],
                            style: const TextStyle(
                              color: AppColors.darkMuted,
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.message,
                              style: const TextStyle(fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    IconData icon,
    String title,
    String subtitle,
    bool isDark, {
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryBright, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.darkMuted, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 2: CODE & FILES ---

  Widget _buildCodeAndFilesTab(
    BuildContext context,
    bool isDark,
    ProjectViewModel vm,
    Project proj,
  ) {
    final files = vm.projectFiles;
    final filteredFiles = files.where((f) {
      final query = _fileSearchController.text.trim().toLowerCase();
      if (query.isEmpty) return true;
      return f.name.toLowerCase().contains(query) || f.path.toLowerCase().contains(query);
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;

        return SizedBox(
          height: 520,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 260,
                        child: _buildFileTreePanel(context, isDark, vm, proj, filteredFiles),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: _buildCodeEditorPanel(context, isDark, vm, proj),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 180,
                        child: _buildFileTreePanel(context, isDark, vm, proj, filteredFiles),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: _buildCodeEditorPanel(context, isDark, vm, proj),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildFileTreePanel(
    BuildContext context,
    bool isDark,
    ProjectViewModel vm,
    Project proj,
    List<ProjectFile> files,
  ) {
    return Container(
      color: isDark ? AppColors.darkSidebar : AppColors.lightSidebar,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search & Reload bar
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 14, color: AppColors.darkMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: _fileSearchController,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(fontSize: 11),
                          decoration: const InputDecoration(
                            hintText: 'Filter files...',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            fillColor: Colors.transparent,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: () => vm.fetchFiles(proj.id),
                icon: const Icon(Icons.refresh, size: 16),
                tooltip: 'Refresh files',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // File List
          Expanded(
            child: files.isEmpty
                ? Center(
                    child: Text(
                      'No files loaded',
                      style: TextStyle(
                        color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                        fontSize: 11,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: files.length,
                    itemBuilder: (context, index) {
                      final file = files[index];
                      final isSelected = vm.selectedFile?.path == file.path;

                      return InkWell(
                        onTap: () => vm.openFile(proj.id, file),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          height: 30,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          margin: const EdgeInsets.only(bottom: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark ? AppColors.darkSurface3 : AppColors.lightSurface3)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                file.isDir ? Icons.folder : Icons.insert_drive_file_outlined,
                                size: 14,
                                color: file.isDir
                                    ? const Color(0xFF9B91FF)
                                    : (isSelected ? AppColors.primaryBright : AppColors.darkMuted),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  file.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected
                                        ? (isDark ? AppColors.darkText : AppColors.lightText)
                                        : (isDark ? AppColors.darkMuted : AppColors.lightMuted),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeEditorPanel(
    BuildContext context,
    bool isDark,
    ProjectViewModel vm,
    Project proj,
  ) {
    final activeFile = vm.selectedFile;

    return Column(
      children: [
        // Editor Header / Actions
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.code,
                      size: 14,
                      color: activeFile != null ? AppColors.primaryBright : AppColors.darkMuted,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        activeFile?.path ?? 'Select a file to edit',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (vm.isDirty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Modified',
                          style: TextStyle(color: AppColors.amber, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (vm.isDirty)
                    TextButton(
                      onPressed: vm.cancelEdits,
                      child: const Text('Discard', style: TextStyle(fontSize: 11)),
                    ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    onPressed: (activeFile != null && vm.isDirty && !vm.isSavingFile)
                        ? () async {
                            await vm.saveFile(proj.id);
                            widget.onNotify('Saved ${activeFile.name}');
                          }
                        : null,
                    icon: vm.isSavingFile
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save, size: 12),
                    label: Text(vm.isSavingFile ? 'Saving...' : 'Save', style: const TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(60, 28),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Editor Body
        Expanded(
          child: vm.isFileLoading
              ? const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : activeFile == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.code_off, size: 36, color: AppColors.darkMuted),
                          const SizedBox(height: 8),
                          Text(
                            'Select a file from the explorer to view and edit code',
                            style: TextStyle(
                              color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: _codeEditorController,
                        onChanged: (text) => vm.updateEditedContent(text),
                        maxLines: null,
                        expands: true,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.5,
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

  // --- TAB 3: AI PROPOSALS ---

  Widget _buildAIProposalsTab(
    BuildContext context,
    bool isDark,
    ProjectViewModel vm,
    Project proj,
  ) {
    final changes = vm.proposedChanges;
    final deps = vm.proposedDependencies;

    if (changes.isEmpty && deps.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          children: [
            const Icon(Icons.auto_awesome, size: 40, color: AppColors.primaryBright),
            const SizedBox(height: 16),
            const Text(
              'No Pending AI Proposals',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Text(
                'When you request changes from the AI Chat or Agent Workspace, proposed file modifications and package additions will appear here for side-by-side review.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => widget.onNavigate('AI Chat'),
              icon: const Icon(Icons.chat_bubble_outline, size: 14),
              label: const Text('Open AI Chat to Propose Changes'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Proposal Header & Action Bar
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            Text(
              '${changes.length} proposed file change(s) · ${deps.length} package(s)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: vm.isApplyingChanges ? null : vm.discardAIProposal,
                  child: const Text('Discard Proposal'),
                ),
                ElevatedButton.icon(
                  onPressed: vm.isApplyingChanges
                      ? null
                      : () async {
                          await vm.applyAIProposal(proj.id);
                          widget.onNotify('AI Proposal applied to ${proj.name}');
                        },
                  icon: vm.isApplyingChanges
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check, size: 14),
                  label: Text(vm.isApplyingChanges ? 'Applying...' : 'Accept & Apply All'),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 16),

        if (deps.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.extension_outlined, size: 16, color: AppColors.cyan),
                const SizedBox(width: 8),
                const Text('Dependencies to add: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Expanded(
                  child: Text(
                    deps.join(', '),
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Proposed Changes List
        ...changes.map((change) => _buildProposedChangeCard(isDark, change)),
      ],
    );
  }

  Widget _buildProposedChangeCard(bool isDark, ProposedFileChange change) {
    final actionColor = switch (change.action.toLowerCase()) {
      'create' => AppColors.green,
      'delete' => AppColors.red,
      _ => AppColors.amber,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: actionColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    change.action.toUpperCase(),
                    style: TextStyle(color: actionColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    change.path,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (change.proposedContent != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Text(
                  change.proposedContent!,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.4),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- TAB 4: BUILD & TEST ---

  Widget _buildBuildAndTestTab(
    BuildContext context,
    bool isDark,
    ProjectViewModel vm,
    Project proj,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Runner Action Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 620;

              final platformSelector = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Platform: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _selectedPlatform,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'apk', child: Text('Android APK')),
                      DropdownMenuItem(value: 'web', child: Text('Flutter Web')),
                      DropdownMenuItem(value: 'appbundle', child: Text('App Bundle')),
                      DropdownMenuItem(value: 'ios', child: Text('iOS')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedPlatform = val);
                    },
                  ),
                ],
              );

              final runButtons = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      widget.onNotify('Verification triggered for ${proj.name}');
                      widget.onNavigate('Testing & Verification');
                    },
                    icon: const Icon(Icons.checklist, size: 14),
                    label: const Text('Run Tests'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      widget.onNotify('Triggering $_selectedPlatform build for ${proj.name}...');
                      await vm.triggerBuild(proj.id, _selectedPlatform);
                    },
                    icon: const Icon(Icons.play_arrow, size: 14),
                    label: const Text('Trigger Build'),
                  ),
                ],
              );

              return isWide
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [platformSelector, runButtons],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        platformSelector,
                        const SizedBox(height: 12),
                        runButtons,
                      ],
                    );
            },
          ),
        ),

        const SizedBox(height: 20),

        // Build Jobs History List
        const Text('Build History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),

        if (vm.buildJobs.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Center(
              child: Text(
                'No builds triggered yet for this project. Select a platform and click "Trigger Build".',
                style: TextStyle(
                  color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                  fontSize: 12,
                ),
              ),
            ),
          )
        else
          ...vm.buildJobs.map((job) => _buildJobCard(isDark, job)),
      ],
    );
  }

  Widget _buildJobCard(bool isDark, BuildJob job) {
    final statusColor = switch (job.status.toLowerCase()) {
      'completed' => AppColors.green,
      'failed' => AppColors.red,
      'building' => AppColors.cyan,
      _ => AppColors.amber,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Build #${job.id.substring(0, job.id.length > 8 ? 8 : job.id.length)} (${job.targetPlatform.toUpperCase()})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  'Created: ${job.createdAt.toLocal().toString().split('.')[0]}',
                  style: const TextStyle(color: AppColors.darkMuted, fontSize: 10),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              job.status.toUpperCase(),
              style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 5: EXECUTION LOGS ---

  Widget _buildExecutionLogsTab(
    BuildContext context,
    bool isDark,
    ProjectViewModel vm,
    Project proj,
  ) {
    final logs = vm.projectLogs[proj.id] ?? <LogEntry>[];
    final search = _logSearchController.text.trim().toLowerCase();

    final filteredLogs = logs.where((entry) {
      if (_logLevelFilter != 'ALL' && entry.logLevel.toUpperCase() != _logLevelFilter) {
        return false;
      }
      if (search.isNotEmpty && !entry.message.toLowerCase().contains(search)) {
        return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Controls Bar
        Row(
          children: [
            Expanded(
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 14, color: AppColors.darkMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _logSearchController,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(
                          hintText: 'Search logs...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            DropdownButton<String>(
              value: _logLevelFilter,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All Levels')),
                DropdownMenuItem(value: 'INFO', child: Text('INFO')),
                DropdownMenuItem(value: 'WARNING', child: Text('WARNING')),
                DropdownMenuItem(value: 'ERROR', child: Text('ERROR')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _logLevelFilter = val);
              },
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => vm.fetchLogs(proj.id),
              icon: const Icon(Icons.refresh, size: 16),
              tooltip: 'Refresh logs',
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Terminal Log Console
        Container(
          height: 440,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: filteredLogs.isEmpty
              ? const Center(
                  child: Text(
                    'No log entries matching the criteria.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                )
              : ListView.builder(
                  itemCount: filteredLogs.length,
                  itemBuilder: (context, index) {
                    final entry = filteredLogs[index];
                    final level = entry.logLevel.toUpperCase();
                    final levelColor = switch (level) {
                      'ERROR' => const Color(0xFFEF4444),
                      'WARNING' => const Color(0xFFF59E0B),
                      _ => const Color(0xFF10B981),
                    };

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${entry.createdAt.toLocal().toString().split(' ')[1].split('.')[0]} ',
                            style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'monospace'),
                          ),
                          Text(
                            '[$level] ',
                            style: TextStyle(color: levelColor, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                          ),
                          Expanded(
                            child: SelectableText(
                              entry.message,
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- DIALOGS ---

  void _showProjectSettingsDialog(BuildContext context, ProjectViewModel vm, Project proj) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${proj.name} Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Project ID: ${proj.id}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            const SizedBox(height: 8),
            Text('Workspace: ${proj.workspacePath}', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Text('Type: ${proj.projectType}', style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showGithubSyncDialog(BuildContext context, ProjectViewModel vm, Project project) {
    showDialog(
      context: context,
      builder: (ctx) => PushToGitHubDialog(
        project: project,
        onSuccess: (repoUrl) {
          widget.onNotify('Successfully pushed to GitHub: $repoUrl');
        },
      ),
    );
  }
}
