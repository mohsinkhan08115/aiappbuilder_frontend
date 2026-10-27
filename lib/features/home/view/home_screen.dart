import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/components/neural_orb.dart';
import '../../../core/components/composer_card.dart';
import '../../../core/components/status_pill.dart';
import '../../../data/models/project.dart';
import '../../projects/viewmodel/project_viewmodel.dart';

import '../../chat/view/chat_screen.dart';

class HomeScreen extends StatefulWidget {
  final void Function(String route) onNavigate;
  final VoidCallback onOpenWizard;
  final VoidCallback onOpenVoice;
  final void Function(String message) onNotify;

  const HomeScreen({
    super.key,
    required this.onNavigate,
    required this.onOpenWizard,
    required this.onOpenVoice,
    required this.onNotify,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _promptController = TextEditingController();
  bool _isThinking = false;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _promptController.text.trim();
    if (text.isEmpty) {
      widget.onNotify('Describe what you want to build first.');
      return;
    }
    setState(() => _isThinking = true);
    ChatSessionMemory.pendingInitialPrompt = text;
    _promptController.clear();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() => _isThinking = false);
        widget.onNavigate('AI Chat');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final projectVm = context.watch<ProjectViewModel>();
    final projects = projectVm.projects;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Welcome Section with Neural Orb
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 700;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Eyebrow
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.cyan,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.cyan,
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'AI WORKSPACE ONLINE',
                                  style: TextStyle(
                                    color: AppColors.cyan,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Title with gradient text
                            Text(
                              'Good evening, Developer.',
                              style: TextStyle(
                                fontSize: isWide ? 32 : 24,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -1.0,
                              ),
                            ),
                            ShaderMask(
                              shaderCallback: (bounds) => AppColors.titleGradient.createShader(bounds),
                              child: Text(
                                'What will we build?',
                                style: TextStyle(
                                  fontSize: isWide ? 36 : 28,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1.2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Turn an idea into working software with a team of AI agents by your side.',
                              style: TextStyle(
                                color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isWide) ...[
                        const SizedBox(width: 24),
                        NeuralOrb(isThinking: _isThinking, size: 116),
                      ],
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // Composer Card
              ComposerCard(
                controller: _promptController,
                isThinking: _isThinking,
                activeProjectName: projectVm.selectedProject?.name,
                onSelectProject: () => widget.onNavigate('Projects'),
                onAddContext: () => widget.onNotify('File picker opened for context.'),
                onToggleDevMode: () => widget.onNotify('Developer mode toggled.'),
                onOpenVoice: widget.onOpenVoice,
                onSubmit: _submit,
              ),

              const SizedBox(height: 36),

              // Starters Section: "Start with an idea"
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Start with an idea',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Choose a starting point, then make it entirely yours.',
                          style: TextStyle(
                            color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: widget.onOpenWizard,
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.arrow_forward, size: 14),
                    label: const Text('Explore all templates'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryBright,
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 4 Starter Cards
              LayoutBuilder(
                builder: (context, constraints) {
                  final cols = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 550 ? 2 : 1);
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: cols,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: cols == 4 ? 2.3 : 2.8,
                    children: [
                      _buildStarterCard(
                        title: 'Web application',
                        subtitle: 'Responsive, fast, and ready to ship',
                        icon: Icons.web_asset,
                        color: const Color(0xFFA698FF),
                        bgTint: const Color(0x217562EF),
                        isDark: isDark,
                      ),
                      _buildStarterCard(
                        title: 'Flutter app',
                        subtitle: 'Beautiful across every platform',
                        icon: Icons.phone_android,
                        color: AppColors.cyan,
                        bgTint: const Color(0x1F22CFE5),
                        isDark: isDark,
                      ),
                      _buildStarterCard(
                        title: 'Fix a code error',
                        subtitle: 'Analyze, explain, and safely repair',
                        icon: Icons.bug_report,
                        color: AppColors.amber,
                        bgTint: const Color(0x1FF3A442),
                        isDark: isDark,
                      ),
                      _buildStarterCard(
                        title: 'Connect a repository',
                        subtitle: 'Build from an existing codebase',
                        icon: Icons.code,
                        color: AppColors.blue,
                        bgTint: const Color(0x21477DE7),
                        isDark: isDark,
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 32),

              // Dashboard Grid: Recent Projects (left) & Active Agent Task (right)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 850;
                  return isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: _buildRecentProjectsPanel(projects, isDark)),
                            const SizedBox(width: 14),
                            Expanded(flex: 2, child: _buildActiveTaskPanel(isDark)),
                          ],
                        )
                      : Column(
                          children: [
                            _buildRecentProjectsPanel(projects, isDark),
                            const SizedBox(height: 14),
                            _buildActiveTaskPanel(isDark),
                          ],
                        );
                },
              ),

              const SizedBox(height: 18),

              // Verification Activity Strip
              InkWell(
                onTap: () => widget.onNavigate('Testing & Verification'),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final isWideStrip = box.maxWidth > 520;
                      return Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: AppColors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(Icons.check, color: AppColors.green, size: 18),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Verification passed',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Finflow Dashboard · 32 tests passed',
                                  style: TextStyle(color: AppColors.darkMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          if (isWideStrip) ...[
                            const SizedBox(width: 12),
                            Wrap(
                              spacing: 12,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: const [
                                StatusPill(label: 'Tests 32/32', type: StatusType.success),
                                StatusPill(label: 'Build passed', type: StatusType.success),
                              ],
                            ),
                          ],
                          const SizedBox(width: 12),
                          const Icon(Icons.chevron_right, size: 16, color: AppColors.darkMuted2),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStarterCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgTint,
    required bool isDark,
  }) {
    return InkWell(
      onTap: widget.onOpenWizard,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: bgTint,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, size: 14, color: AppColors.darkMuted2),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentProjectsPanel(List<Project> projects, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent projects',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Pick up where you left off',
                    style: TextStyle(color: AppColors.darkMuted, fontSize: 11),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => widget.onNavigate('Projects'),
                child: const Text('View all', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Render real projects if available, otherwise display the prototype showcase projects
          if (projects.isNotEmpty)
            ...projects.take(4).map((p) => _buildProjectRow(
                  mark: p.name.isNotEmpty ? p.name[0].toUpperCase() : 'P',
                  title: p.name,
                  stack: p.description ?? 'Flutter · Dart',
                  status: p.status == 'completed' ? 'Ready' : (p.status == 'generating' ? 'Building' : 'Draft'),
                  statusType: p.status == 'completed'
                      ? StatusType.success
                      : (p.status == 'generating' ? StatusType.running : StatusType.neutral),
                  time: 'Active',
                  gradient: AppColors.violetMarkGradient,
                  onTap: () {
                    context.read<ProjectViewModel>().selectProject(p.id);
                    widget.onNavigate('Project Workspace');
                  },
                  isDark: isDark,
                ))
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.folder_open, size: 36, color: AppColors.darkMuted),
                  const SizedBox(height: 10),
                  const Text(
                    'No projects created yet',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Create your first Flutter project using the wizard or prompt above.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.darkMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: widget.onOpenWizard,
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Create New Project'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProjectRow({
    required String mark,
    required String title,
    required String stack,
    required String status,
    required StatusType statusType,
    required String time,
    required LinearGradient gradient,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                mark,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stack,
                    style: TextStyle(
                      color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            StatusPill(label: status, type: statusType, fontSize: 10),
            const SizedBox(width: 14),
            Text(
              time,
              style: TextStyle(
                color: isDark ? AppColors.darkMuted2 : AppColors.lightMuted2,
                fontSize: 10,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 16, color: AppColors.darkMuted2),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTaskPanel(bool isDark) {
    final vm = context.watch<ProjectViewModel>();
    final proj = vm.selectedProject;
    final isBusy = vm.isThinking || vm.isApplyingChanges || vm.isLoading;
    final hasActiveBuild = vm.buildJobs.any((j) => j.status == 'queued' || j.status == 'building');

    return Container(
      padding: const EdgeInsets.all(20),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Active workspace task',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      proj != null ? proj.name : 'No project active',
                      style: const TextStyle(color: AppColors.darkMuted, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (proj != null && (isBusy || hasActiveBuild))
                const StatusPill(label: 'Running', type: StatusType.running)
              else if (proj != null)
                const StatusPill(label: 'Ready', type: StatusType.success)
              else
                const StatusPill(label: 'Idle', type: StatusType.neutral),
            ],
          ),
          const SizedBox(height: 12),

          if (proj != null) ...[
            InkWell(
              onTap: () => widget.onNavigate('Agent Workspace'),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.cyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.code, color: AppColors.cyan, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isBusy ? 'AI Agent Pipeline' : 'Project Workspace',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isBusy
                                ? 'Generating & validating code…'
                                : (hasActiveBuild ? 'Compilation in progress…' : 'Workspace synced and up-to-date'),
                            style: TextStyle(
                              color: isBusy ? AppColors.cyan : AppColors.green,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Container(
                height: 4,
                color: isDark ? AppColors.darkSurface3 : AppColors.lightSurface3,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: isBusy ? 0.75 : (proj.status == 'completed' ? 1.0 : 0.35),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isBusy ? 'Processing AI request' : (proj.description ?? 'Flutter application'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'Inspect and review project files, tests, and agent plans in the Agent Workspace.',
              style: TextStyle(
                color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => widget.onNavigate('Agent Workspace'),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward, size: 13),
                  label: const Text('Open workspace'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryBright,
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  const Icon(Icons.touch_app, size: 28, color: AppColors.darkMuted),
                  const SizedBox(height: 8),
                  const Text(
                    'Select a project to inspect live agent tasks',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Once a project is active, its build status, file changes, and agent tasks will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.darkMuted, fontSize: 10),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => widget.onNavigate('Projects'),
                    child: const Text('Go to Projects', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
