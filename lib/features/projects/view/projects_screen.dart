import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/components/status_pill.dart';
import '../../../core/components/push_to_github_dialog.dart';
import '../../../data/models/project.dart';
import '../viewmodel/project_viewmodel.dart';

class ProjectsScreen extends StatefulWidget {
  final void Function(String route) onNavigate;
  final VoidCallback onOpenWizard;
  final void Function(String message) onNotify;

  const ProjectsScreen({
    super.key,
    required this.onNavigate,
    required this.onOpenWizard,
    required this.onNotify,
  });

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  String _filter = 'All';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vm = context.watch<ProjectViewModel>();
    final projects = vm.projects;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Responsive Page Header
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 600;
                  final titleBlock = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PROJECTS',
                        style: TextStyle(
                          color: AppColors.cyan,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Your software, in one place',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Open a workspace, inspect files, or continue an agent task.',
                        style: TextStyle(
                          color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  );

                  final createBtn = ElevatedButton.icon(
                    onPressed: widget.onOpenWizard,
                    icon: const Icon(Icons.add, size: 15),
                    label: const Text('Create project'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        titleBlock,
                        const SizedBox(height: 16),
                        createBtn,
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: titleBlock),
                      const SizedBox(width: 16),
                      createBtn,
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // Responsive Filter & Search Bar
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 620;

                  final searchBox = Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 16, color: AppColors.darkMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(fontSize: 12),
                            decoration: InputDecoration(
                              hintText: 'Search projects by name or stack…',
                              hintStyle: TextStyle(
                                color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                                fontSize: 12,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              fillColor: Colors.transparent,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.close, size: 14),
                            onPressed: () => _searchController.clear(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Clear search',
                          ),
                      ],
                    ),
                  );

                  final filterTabs = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: ['All', 'Active', 'Completed'].map((tab) {
                      final selected = _filter == tab;
                      return Padding(
                        padding: const EdgeInsets.only(left: 6.0),
                        child: InkWell(
                          onTap: () {
                            setState(() => _filter = tab);
                            widget.onNotify('$tab project filter applied.');
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: selected
                                    ? AppColors.primary
                                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              tab,
                              style: TextStyle(
                                color: selected ? AppColors.primaryBright : AppColors.darkMuted,
                                fontSize: 11,
                                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        searchBox,
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: filterTabs,
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: searchBox),
                      const SizedBox(width: 12),
                      filterTabs,
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              if (vm.isLoading) ...[
                const SizedBox(height: 48),
                const Center(
                  child: Column(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(height: 12),
                      Text('Loading projects…', style: TextStyle(fontSize: 12, color: AppColors.darkMuted)),
                    ],
                  ),
                ),
              ] else ...[
                _buildProjectsGrid(isDark, vm, projects),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProjectsGrid(bool isDark, ProjectViewModel vm, List<dynamic> projects) {
    final query = _searchController.text.trim().toLowerCase();

    // Prototype baseline projects used when no projects exist on the backend yet
    final prototypeProjects = [
      _ProjectItemData(
        id: null,
        title: 'Finflow Dashboard',
        stack: 'React · TypeScript',
        status: 'Verification passed',
        statusType: StatusType.success,
        gradient: AppColors.violetMarkGradient,
        isActive: false,
      ),
      _ProjectItemData(
        id: null,
        title: 'Nova Mobile',
        stack: 'Flutter · Dart',
        status: 'Agent running',
        statusType: StatusType.running,
        gradient: AppColors.cyanMarkGradient,
        isActive: true,
      ),
      _ProjectItemData(
        id: null,
        title: 'Atlas API',
        stack: 'Python · FastAPI',
        status: 'Draft',
        statusType: StatusType.neutral,
        gradient: AppColors.amberMarkGradient,
        isActive: true,
      ),
    ];

    List<_ProjectItemData> allItems;
    if (projects.isNotEmpty) {
      allItems = projects.map((p) {
        final isCompleted = p.status == 'completed';
        final isFailed = p.status == 'failed';
        final statusLabel = isCompleted
            ? 'Verification passed'
            : (isFailed ? 'Failed' : 'Agent running');
        final statusType = isCompleted
            ? StatusType.success
            : (isFailed ? StatusType.error : StatusType.running);

        return _ProjectItemData(
          id: p.id,
          project: p,
          title: p.name,
          stack: p.description ?? 'Flutter · Dart',
          status: statusLabel,
          statusType: statusType,
          gradient: isCompleted ? AppColors.violetMarkGradient : AppColors.cyanMarkGradient,
          isActive: !isCompleted && !isFailed,
        );
      }).toList();
    } else {
      allItems = prototypeProjects;
    }

    // Filter by query and tab
    final filtered = allItems.where((item) {
      final matchesQuery = query.isEmpty ||
          item.title.toLowerCase().contains(query) ||
          item.stack.toLowerCase().contains(query);
      if (!matchesQuery) return false;

      if (_filter == 'Active') {
        return item.isActive;
      } else if (_filter == 'Completed') {
        return !item.isActive && item.statusType == StatusType.success;
      }
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 40,
              color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
            ),
            const SizedBox(height: 12),
            Text(
              _searchController.text.trim().isNotEmpty
                  ? 'No projects matching "${_searchController.text.trim()}"'
                  : 'No projects in this category',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              query.isNotEmpty
                  ? 'Try checking for typos or searching a different stack keyword.'
                  : 'Switch filter to "All" or create a new project to get started.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (query.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => _searchController.clear(),
                icon: const Icon(Icons.clear, size: 14),
                label: const Text('Clear search'),
              )
            else
              ElevatedButton.icon(
                onPressed: widget.onOpenWizard,
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Create project'),
              ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 950 ? 3 : (constraints.maxWidth > 650 ? 2 : 1);
        final aspectRatio = cols == 1 ? 1.7 : 1.35;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: aspectRatio,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final item = filtered[index];
            return _buildProjectCard(
              title: item.title,
              stack: item.stack,
              status: item.status,
              statusType: item.statusType,
              gradient: item.gradient,
              isDark: isDark,
              onSelect: () {
                if (item.id != null) {
                  vm.selectProject(item.id!);
                }
                widget.onNavigate('Project Workspace');
              },
              onSelectFiles: () {
                if (item.id != null) {
                  vm.selectProject(item.id!);
                }
                widget.onNavigate('Code & Files');
              },
              onSelectAgents: () {
                if (item.id != null) {
                  vm.selectProject(item.id!);
                }
                widget.onNavigate('Agent Workspace');
              },
              onSelectTests: () {
                if (item.id != null) {
                  vm.selectProject(item.id!);
                }
                widget.onNavigate('Testing & Verification');
              },
              onPushGithub: () {
                if (item.project != null) {
                  showDialog(
                    context: context,
                    builder: (_) => PushToGitHubDialog(
                      project: item.project!,
                      onSuccess: (url) => widget.onNotify('Project pushed to GitHub: $url'),
                    ),
                  );
                } else {
                  widget.onNotify('Select or create a project before pushing to GitHub.');
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildProjectCard({
    required String title,
    required String stack,
    required String status,
    required StatusType statusType,
    required LinearGradient gradient,
    required bool isDark,
    required VoidCallback onSelect,
    required VoidCallback onSelectFiles,
    required VoidCallback onSelectAgents,
    required VoidCallback onSelectTests,
    required VoidCallback onPushGithub,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: InkWell(
              onTap: onSelect,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: gradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        title.isNotEmpty ? title[0].toUpperCase() : 'P',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          stack,
                          style: TextStyle(
                            color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    StatusPill(label: status, type: statusType, fontSize: 11),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onSelectFiles,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Files', style: TextStyle(fontSize: 11)),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: onSelectAgents,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Agents', style: TextStyle(fontSize: 11)),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: onSelectTests,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Run tests', style: TextStyle(fontSize: 11)),
                  ),
                ),
                IconButton(
                  onPressed: onPushGithub,
                  icon: const Icon(Icons.cloud_upload_outlined, size: 14),
                  tooltip: 'Push to GitHub',
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
                IconButton(
                  onPressed: () => widget.onNotify('Project settings for "$title" opened.'),
                  icon: const Icon(Icons.settings, size: 14),
                  tooltip: 'Settings',
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectItemData {
  final String? id;
  final Project? project;
  final String title;
  final String stack;
  final String status;
  final StatusType statusType;
  final LinearGradient gradient;
  final bool isActive;

  _ProjectItemData({
    required this.id,
    this.project,
    required this.title,
    required this.stack,
    required this.status,
    required this.statusType,
    required this.gradient,
    required this.isActive,
  });
}
