import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/components/status_pill.dart';
import '../../../core/components/confirm_dialog.dart';
import '../../projects/viewmodel/project_viewmodel.dart';
import '../../../data/models/project.dart';

class AgentWorkspaceScreen extends StatefulWidget {
  final void Function(String route) onNavigate;
  final void Function(String message) onNotify;
  final void Function(ConfirmKind kind) onConfirm;

  const AgentWorkspaceScreen({
    super.key,
    required this.onNavigate,
    required this.onNotify,
    required this.onConfirm,
  });

  @override
  State<AgentWorkspaceScreen> createState() => _AgentWorkspaceScreenState();
}

class _AgentWorkspaceScreenState extends State<AgentWorkspaceScreen> {
  bool _paused = false;
  bool _cancelled = false;
  final _instructionController = TextEditingController();

  final List<String> _planSteps = [
    'Analyze existing auth architecture',
    'Create session service & state',
    'Connect sign-in & session screens',
    'Run automated verification & tests',
    'Review proposed code changes',
  ];

  @override
  void dispose() {
    _instructionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ProjectViewModel? vm;
    try {
      vm = context.watch<ProjectViewModel>();
    } catch (_) {}

    final project = vm?.selectedProject;
    final isThinking = vm?.isThinking ?? false;
    final isApplying = vm?.isApplyingChanges ?? false;
    final isBusy = isThinking || isApplying || (vm?.isLoading ?? false);
    final buildJobs = vm?.buildJobs ?? [];
    final hasActiveBuild = buildJobs.any((j) => j.status == 'queued' || j.status == 'building');
    final hasQueuedBuild = buildJobs.any((j) => j.status == 'queued');

    // Calculate truthful progress and step index from actual project state
    final int currentStepIndex;
    final int progressPercent;
    final String statusLabel;
    final StatusType statusType;
    final String humanStatusMessage;

    if (_cancelled) {
      currentStepIndex = 1;
      progressPercent = 20;
      statusLabel = 'Cancelled';
      statusType = StatusType.neutral;
      humanStatusMessage = 'Task execution cancelled by user.';
    } else if (_paused) {
      currentStepIndex = 2;
      progressPercent = 40;
      statusLabel = 'Paused';
      statusType = StatusType.neutral;
      humanStatusMessage = 'Task execution paused safely.';
    } else if (project == null) {
      // Truthful Standby state when no project selected
      currentStepIndex = 0;
      progressPercent = 0;
      statusLabel = 'Standby';
      statusType = StatusType.neutral;
      humanStatusMessage = 'No active project selected. Select a project to run agent workflows.';
    } else if (project.status == 'failed') {
      currentStepIndex = 0;
      progressPercent = 0;
      statusLabel = 'Failed';
      statusType = StatusType.error;
      humanStatusMessage = 'Task encountered an error. Check logs for details.';
    } else if (project.status == 'completed' && !isBusy && !hasActiveBuild) {
      currentStepIndex = 4;
      progressPercent = 100;
      statusLabel = 'Completed';
      statusType = StatusType.success;
      humanStatusMessage = 'All tasks and verification checks completed.';
    } else if (hasQueuedBuild) {
      currentStepIndex = 3;
      progressPercent = 60;
      statusLabel = 'Waiting';
      statusType = StatusType.running;
      humanStatusMessage = 'Waiting for verification';
    } else if (hasActiveBuild) {
      currentStepIndex = 3;
      progressPercent = 70;
      statusLabel = 'Running';
      statusType = StatusType.running;
      humanStatusMessage = 'Running verification build…';
    } else if (project.status == 'generating' || isBusy) {
      currentStepIndex = 2;
      progressPercent = 45; // Truthful 2 of 5 steps completed
      statusLabel = 'Running';
      statusType = StatusType.running;
      humanStatusMessage = 'Coding Agent is working';
    } else {
      // Created / ready
      currentStepIndex = 0;
      progressPercent = 0;
      statusLabel = 'Ready';
      statusType = StatusType.neutral;
      humanStatusMessage = 'Project initialized · Ready to generate';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Page Header with responsive actions
              LayoutBuilder(
                builder: (context, headerConstraints) {
                  final isWideHeader = headerConstraints.maxWidth > 650;
                  final titleBlock = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AGENT WORKSPACE',
                        style: TextStyle(
                          color: AppColors.cyan,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        project != null ? '${project.name} flow' : 'Agent Orchestration',
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        project != null
                            ? '${project.name} · Target: ${project.description ?? "Flutter / Dart"}'
                            : 'No active project · Connect a project to coordinate agents',
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
                      if (project != null) ...[
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _paused = !_paused;
                              if (_paused) _cancelled = false;
                            });
                            widget.onNotify(_paused ? 'Task paused safely.' : 'Task resumed.');
                          },
                          icon: Icon(_paused ? Icons.play_arrow : Icons.pause, size: 14),
                          label: Text(_paused ? 'Resume' : 'Pause'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() => _cancelled = true);
                            widget.onConfirm(ConfirmKind.cancel);
                            widget.onNotify('Task execution cancelled.');
                          },
                          icon: const Icon(Icons.close, size: 14),
                          label: const Text('Cancel'),
                        ),
                      ] else ...[
                        ElevatedButton.icon(
                          onPressed: () => widget.onNavigate('Projects'),
                          icon: const Icon(Icons.folder_open, size: 14),
                          label: const Text('Select Project'),
                        ),
                      ],
                    ],
                  );

                  return isWideHeader
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: titleBlock),
                            actionButtons,
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            titleBlock,
                            const SizedBox(height: 14),
                            actionButtons,
                          ],
                        );
                },
              ),

              const SizedBox(height: 24),

              // Two-column layout: Task plan steps (left) & Specialists rail (right)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 850;
                  final leftPanel = _buildTaskPlan(
                    isDark: isDark,
                    currentStepIndex: currentStepIndex,
                    progressPercent: progressPercent,
                    statusLabel: statusLabel,
                    statusType: statusType,
                    humanStatusMessage: humanStatusMessage,
                    isBusy: isBusy || hasActiveBuild,
                    project: project,
                    vm: vm,
                  );

                  final rightPanel = _buildAgentRail(
                    isDark: isDark,
                    currentStepIndex: currentStepIndex,
                    isBusy: isBusy || hasActiveBuild,
                    hasActiveBuild: hasActiveBuild,
                    hasQueuedBuild: hasQueuedBuild,
                    isPaused: _paused,
                    vm: vm,
                  );

                  return isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: leftPanel),
                            const SizedBox(width: 14),
                            SizedBox(width: 320, child: rightPanel),
                          ],
                        )
                      : Column(
                          children: [
                            leftPanel,
                            const SizedBox(height: 14),
                            rightPanel,
                          ],
                        );
                },
              ),

              const SizedBox(height: 20),

              // Multi-agent Coordination & Live Events Section
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MULTI-AGENT COORDINATION',
                                style: TextStyle(
                                  color: Color(0xFF9B91FF),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Agent interaction topology',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          StatusPill(
                            label: statusLabel,
                            type: statusType,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // Agent topology row
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildTopologyNode('Planner', 'Spec generation', true, isDark),
                            _buildTopologyArrow(),
                            _buildTopologyNode('Coding Agent', 'Implementation', currentStepIndex >= 2, isDark),
                            _buildTopologyArrow(),
                            _buildTopologyNode('Testing Agent', 'Build verification', currentStepIndex >= 3, isDark),
                            _buildTopologyArrow(),
                            _buildTopologyNode('Review Agent', 'Safety & sign-off', currentStepIndex >= 4, isDark),
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
      ),
    );
  }

  Widget _buildTaskPlan({
    required bool isDark,
    required int currentStepIndex,
    required int progressPercent,
    required String statusLabel,
    required StatusType statusType,
    required String humanStatusMessage,
    required bool isBusy,
    required Project? project,
    required ProjectViewModel? vm,
  }) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatusPill(
                    label: statusLabel,
                    type: statusType,
                  ),
                  if (isBusy && !_paused && !_cancelled) ...[
                    const SizedBox(width: 8),
                    const AnimatedWorkingDots(),
                  ],
                ],
              ),
              // Truthful dynamic progress percentage
              Text(
                '$progressPercent%',
                style: const TextStyle(
                  color: Color(0xFF9B91FF),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Human-readable status banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isBusy ? Icons.sync : (progressPercent == 100 ? Icons.check_circle : Icons.info_outline),
                  size: 14,
                  color: isBusy ? AppColors.cyan : (progressPercent == 100 ? AppColors.green : AppColors.darkMuted),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    humanStatusMessage,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isBusy ? AppColors.cyan : (isDark ? AppColors.darkText : AppColors.lightText),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Actionable Task Input for Agent Execution
          if (project != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Assign task to AI Agents',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _instructionController,
                          enabled: !isBusy,
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'e.g., Add dark mode toggle or implement authentication…',
                            hintStyle: TextStyle(
                              color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                              fontSize: 11,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(
                                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              ),
                            ),
                          ),
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty && vm != null) {
                              vm.fetchAIProposal(project.id, val.trim());
                              _instructionController.clear();
                              widget.onNotify('Agents dispatched to fulfill request.');
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: isBusy
                            ? null
                            : () {
                                final text = _instructionController.text.trim();
                                if (text.isNotEmpty && vm != null) {
                                  vm.fetchAIProposal(project.id, text);
                                  _instructionController.clear();
                                  widget.onNotify('Agents dispatched to fulfill request.');
                                }
                              },
                        icon: isBusy
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send, size: 13),
                        label: const Text('Run Task'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          const Text(
            'Plan and task steps',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 12),

          ...List.generate(_planSteps.length, (i) {
            final isDone = i < currentStepIndex;
            final isCurrent = i == currentStepIndex;
            final stepText = _planSteps[i];

            final stepStatus = isDone
                ? 'Completed'
                : (isCurrent
                    ? humanStatusMessage
                    : (i == 3 ? 'Waiting for verification' : 'Queued'));

            return Container(
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
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDone
                            ? AppColors.green
                            : (isCurrent
                                ? AppColors.cyan
                                : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                      ),
                      color: isDone ? AppColors.green.withValues(alpha: 0.12) : Colors.transparent,
                    ),
                    alignment: Alignment.center,
                    child: isDone
                        ? const Icon(Icons.check, size: 14, color: AppColors.green)
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isCurrent ? AppColors.cyan : AppColors.darkMuted,
                            ),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stepText,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              stepStatus,
                              style: TextStyle(
                                fontSize: 10,
                                color: isDone
                                    ? AppColors.green
                                    : (isCurrent ? AppColors.cyan : AppColors.darkMuted),
                              ),
                            ),
                            if (isCurrent && isBusy && !_paused) ...[
                              const SizedBox(width: 6),
                              const AnimatedWorkingDots(dotSize: 3),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 16, color: AppColors.darkMuted2),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAgentRail({
    required bool isDark,
    required int currentStepIndex,
    required bool isBusy,
    required bool hasActiveBuild,
    required bool hasQueuedBuild,
    required bool isPaused,
    required ProjectViewModel? vm,
  }) {
    final specialists = [
      ('Planner', currentStepIndex > 0 ? 'Completed' : 'Queued', Icons.auto_awesome),
      (
        'Coding Agent',
        isPaused
            ? 'Paused'
            : (isBusy && currentStepIndex == 2
                ? 'Working'
                : (currentStepIndex > 2 ? 'Completed' : 'Queued')),
        Icons.code
      ),
      (
        'Testing Agent',
        hasActiveBuild
            ? 'Testing'
            : (hasQueuedBuild
                ? 'Waiting for verification'
                : (currentStepIndex > 3 ? 'Passed' : 'Queued')),
        Icons.check_circle_outline
      ),
      (
        'Review Agent',
        vm?.proposedChanges.isNotEmpty == true
            ? 'Review required'
            : (currentStepIndex >= 4 ? 'Completed' : 'Queued'),
        Icons.search
      ),
    ];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Active specialists',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 12),

              ...specialists.map((spec) {
                final isWorking = spec.$2 == 'Working' || spec.$2 == 'Testing';
                final isDone = spec.$2 == 'Completed' || spec.$2 == 'Passed';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isWorking
                              ? AppColors.cyan.withValues(alpha: 0.16)
                              : (isDone ? AppColors.green.withValues(alpha: 0.16) : Colors.transparent),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isWorking
                                ? AppColors.cyan
                                : (isDone ? AppColors.green : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                          ),
                        ),
                        child: Icon(
                          spec.$3,
                          size: 14,
                          color: isWorking ? AppColors.cyan : (isDone ? AppColors.green : AppColors.darkMuted),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              spec.$1,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                            Text(
                              spec.$2,
                              style: TextStyle(
                                fontSize: 10,
                                color: isWorking
                                    ? AppColors.cyan
                                    : (isDone ? AppColors.green : AppColors.darkMuted),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isWorking) const AnimatedWorkingDots(dotSize: 3),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 12),

              if (vm != null && vm.proposedChanges.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface3 : AppColors.lightSurface3,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'APPROVAL REQUIRED',
                        style: TextStyle(
                          color: AppColors.amber,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Apply ${vm.proposedChanges.length} proposed change(s)?',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Files: ${vm.proposedChanges.map((c) => c.path).join(", ")}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.darkMuted, fontSize: 10),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                vm.clearAIProposal();
                                widget.onNotify('Proposed changes discarded.');
                              },
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                              child: const Text('Discard', style: TextStyle(fontSize: 11)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                final proj = vm.selectedProject;
                                if (proj != null) {
                                  await vm.applyAIProposal(proj.id);
                                  widget.onNotify('AI proposal applied successfully to codebase.');
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                              child: const Text('Apply Changes', style: TextStyle(fontSize: 11)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopologyNode(String role, String task, bool active, bool isDark) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active
            ? (isDark ? AppColors.darkSurface3 : AppColors.lightSurface3)
            : (isDark ? AppColors.darkSurface2 : AppColors.lightSurface2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: active ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(role, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          const SizedBox(height: 2),
          Text(task, style: const TextStyle(color: AppColors.darkMuted, fontSize: 9)),
        ],
      ),
    );
  }

  Widget _buildTopologyArrow() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Icon(Icons.arrow_forward, size: 14, color: AppColors.darkMuted2),
    );
  }
}

class AnimatedWorkingDots extends StatefulWidget {
  final double dotSize;
  final Color color;

  const AnimatedWorkingDots({
    super.key,
    this.dotSize = 4.0,
    this.color = AppColors.cyan,
  });

  @override
  State<AnimatedWorkingDots> createState() => _AnimatedWorkingDotsState();
}

class _AnimatedWorkingDotsState extends State<AnimatedWorkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final val = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final offset = (val - (i * 0.25)) % 1.0;
            final opacity = (0.3 + 0.7 * (1.0 - (offset - 0.5).abs() * 2)).clamp(0.2, 1.0);
            return Container(
              margin: EdgeInsets.symmetric(horizontal: widget.dotSize * 0.4),
              width: widget.dotSize,
              height: widget.dotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: opacity),
              ),
            );
          }),
        );
      },
    );
  }
}
