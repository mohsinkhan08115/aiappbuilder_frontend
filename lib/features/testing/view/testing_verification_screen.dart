import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/components/status_pill.dart';
import '../../projects/viewmodel/project_viewmodel.dart';

class TestingVerificationScreen extends StatefulWidget {
  final void Function(String route) onNavigate;
  final void Function(String message) onNotify;

  const TestingVerificationScreen({
    super.key,
    required this.onNavigate,
    required this.onNotify,
  });

  @override
  State<TestingVerificationScreen> createState() => _TestingVerificationScreenState();
}

class _TestingVerificationScreenState extends State<TestingVerificationScreen> {
  bool _running = false;
  String _activeTab = 'Test suites';
  final String _sandboxState = 'Ready';

  Future<void> _triggerRealBuild(ProjectViewModel vm) async {
    final proj = vm.selectedProject;
    if (proj == null) {
      widget.onNotify('Select a project first before running verification or builds.');
      return;
    }
    setState(() => _running = true);
    try {
      await vm.triggerBuild(proj.id, 'apk');
      if (mounted) {
        setState(() => _running = false);
        widget.onNotify('Build & verification job queued for "${proj.name}".');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _running = false);
        widget.onNotify('Build trigger failed: $e');
      }
    }
  }

  void _retryChecks(ProjectViewModel vm) {
    _triggerRealBuild(vm);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vm = context.watch<ProjectViewModel>();
    final proj = vm.selectedProject;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Page Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TESTING & VERIFICATION',
                        style: TextStyle(
                          color: AppColors.cyan,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Verification report',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${proj?.name ?? 'Nova Mobile'} · Demonstration results from the latest supported run',
                        style: TextStyle(
                          color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => widget.onNavigate('Agent Workspace'),
                        icon: const Icon(Icons.arrow_back, size: 14),
                        label: const Text('Back to workspace'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _running ? null : () => _retryChecks(vm),
                        icon: _running
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.refresh, size: 14),
                        label: Text(_running ? 'Running…' : 'Run / Retry Build'),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Score Row: Confidence Ring Card + 3 Metric Cards
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 800;
                  return isWide
                      ? Row(
                          children: [
                            Expanded(flex: 4, child: _buildScoreCard(isDark)),
                            const SizedBox(width: 12),
                            Expanded(flex: 3, child: _buildMetricCard('Tests', '18 / 20', AppColors.green, isDark)),
                            const SizedBox(width: 12),
                            Expanded(flex: 3, child: _buildMetricCard('Static analysis', '1 warning', AppColors.amber, isDark)),
                            const SizedBox(width: 12),
                            Expanded(flex: 3, child: _buildMetricCard('Supported build', 'Passed', AppColors.green, isDark)),
                          ],
                        )
                      : Column(
                          children: [
                            _buildScoreCard(isDark),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: _buildMetricCard('Tests', '18 / 20', AppColors.green, isDark)),
                                const SizedBox(width: 12),
                                Expanded(child: _buildMetricCard('Static analysis', '1 warning', AppColors.amber, isDark)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildMetricCard('Supported build', 'Passed', AppColors.green, isDark),
                          ],
                        );
                },
              ),

              const SizedBox(height: 20),

              // Findings Panel
              Container(
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
                    const Text(
                      'Findings',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Expand a result to inspect evidence',
                      style: TextStyle(color: AppColors.darkMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 14),

                    _buildFindingRow(
                      icon: Icons.bug_report,
                      iconColor: AppColors.amber,
                      title: 'Session expiry edge case',
                      subtitle: 'auth_service.dart · line 14 · Requires review',
                      status: 'Warning',
                      statusType: StatusType.warning,
                      onTap: () => widget.onNavigate('Code & Files'),
                      isDark: isDark,
                    ),
                    _buildFindingRow(
                      icon: Icons.check,
                      iconColor: AppColors.green,
                      title: 'Authentication widget tests',
                      subtitle: '12 tests completed successfully',
                      status: 'Passed',
                      statusType: StatusType.success,
                      onTap: () => widget.onNotify('Passing test suite details opened.'),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Engineering Extension: Tabs (Test suites, Build & sandbox, Verification history)
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
                    // Tab Bar
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                      ),
                      child: Row(
                        children: ['Test suites', 'Build & sandbox', 'Verification history'].map((tab) {
                          final selected = _activeTab == tab;
                          return InkWell(
                            onTap: () => setState(() => _activeTab = tab),
                            child: Container(
                              height: 44,
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
                              child: Text(
                                tab,
                                style: TextStyle(
                                  color: selected ? (isDark ? AppColors.darkText : AppColors.lightText) : AppColors.darkMuted,
                                  fontSize: 12,
                                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    // Tab Body
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: _buildTabBody(isDark, vm),
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

  Widget _buildScoreCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.green, width: 4),
            ),
            alignment: Alignment.center,
            child: const Text(
              '82%',
              style: TextStyle(
                color: AppColors.green,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('High confidence', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                SizedBox(height: 2),
                Text('18 of 22 checks passed', style: TextStyle(color: AppColors.darkMuted, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: AppColors.darkMuted, fontSize: 11)),
              Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildFindingRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String status,
    required StatusType statusType,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppColors.darkMuted, fontSize: 10)),
                ],
              ),
            ),
            StatusPill(label: status, type: statusType, fontSize: 10),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 16, color: AppColors.darkMuted2),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBody(bool isDark, ProjectViewModel vm) {
    final proj = vm.selectedProject;
    final builds = vm.buildJobs;
    final logs = proj != null ? (vm.projectLogs[proj.id] ?? []) : [];

    if (_activeTab == 'Test suites') {
      if (proj == null) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'Select a project to inspect test suites.',
              style: TextStyle(color: AppColors.darkMuted, fontSize: 12),
            ),
          ),
        );
      }

      return Column(
        children: [
          _buildSuiteRow('Unit & Widget Tests', 'flutter test suite', AppColors.green, isDark),
          _buildSuiteRow('Static Analysis', 'flutter analyze linter checks', AppColors.cyan, isDark),
          _buildSuiteRow('Compilation & Build Targets', 'Android APK / Web output target', AppColors.green, isDark),
        ],
      );
    } else if (_activeTab == 'Build & sandbox') {
      final activeJob = builds.isNotEmpty ? builds.first : null;
      final statusLabel = activeJob != null ? activeJob.status.toUpperCase() : _sandboxState;
      final statusType = activeJob != null
          ? (activeJob.status == 'completed'
              ? StatusType.success
              : (activeJob.status == 'failed' ? StatusType.error : StatusType.running))
          : (_sandboxState == 'Ready' ? StatusType.success : StatusType.running);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.cyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.code, color: AppColors.cyan, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      proj != null ? 'Project Build: ${proj.name}' : 'Isolated Flutter execution',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activeJob != null
                          ? 'Job ${activeJob.id.substring(0, 8)} · Target: ${activeJob.targetPlatform}'
                          : 'Supported runtime · policy-controlled build worker',
                      style: const TextStyle(color: AppColors.darkMuted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              StatusPill(label: statusLabel, type: statusType),
            ],
          ),
          const SizedBox(height: 14),

          // Terminal Log View
          Container(
            padding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(minHeight: 140, maxHeight: 240),
            decoration: BoxDecoration(
              color: const Color(0xFF05080E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: logs.isNotEmpty
                ? ListView.builder(
                    shrinkWrap: true,
                    itemCount: logs.length,
                    itemBuilder: (context, idx) {
                      final entry = logs[idx];
                      return Text(
                        entry.message,
                        style: const TextStyle(
                          color: Color(0xFF8FA2BD),
                          fontFamily: 'Consolas',
                          fontSize: 11,
                        ),
                      );
                    },
                  )
                : const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('\$ flutter test & build verification', style: TextStyle(color: AppColors.cyan, fontFamily: 'Consolas', fontSize: 11)),
                      SizedBox(height: 6),
                      Text('Ready to execute verification jobs.', style: TextStyle(color: Color(0xFF8FA2BD), fontFamily: 'Consolas', fontSize: 11)),
                      Text('Click "Run / Retry Build" above to trigger a live build in the backend.', style: TextStyle(color: Color(0xFF8FA2BD), fontFamily: 'Consolas', fontSize: 11)),
                    ],
                  ),
          ),

          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: _running ? null : () => _triggerRealBuild(vm),
                icon: const Icon(Icons.play_arrow, size: 14),
                label: const Text('Trigger Build (APK)'),
              ),
            ],
          ),
        ],
      );
    } else {
      if (builds.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'No previous build jobs recorded for this project yet.',
              style: TextStyle(color: AppColors.darkMuted, fontSize: 11),
            ),
          ),
        );
      }

      return Column(
        children: builds.take(5).map((job) {
          final isSuccess = job.status == 'completed';
          final color = isSuccess ? AppColors.green : (job.status == 'failed' ? AppColors.red : AppColors.cyan);
          return _buildHistoryRow(
            'Job ${job.id.substring(0, 8)} · ${job.targetPlatform.toUpperCase()} · ${job.status}',
            isDark,
            color,
          );
        }).toList(),
      );
    }
  }

  Widget _buildSuiteRow(String title, String detail, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                Text(detail, style: const TextStyle(color: AppColors.darkMuted, fontSize: 10)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 14, color: AppColors.darkMuted2),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(String text, bool isDark, [Color? iconColor]) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
      ),
      child: Row(
        children: [
          Icon(Icons.history, color: iconColor ?? AppColors.darkMuted, size: 16),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 11))),
          const Icon(Icons.chevron_right, size: 14, color: AppColors.darkMuted2),
        ],
      ),
    );
  }
}
