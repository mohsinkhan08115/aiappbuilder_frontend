import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class ActivityHistoryScreen extends StatefulWidget {
  final void Function(String route) onNavigate;
  final void Function(String message) onNotify;

  const ActivityHistoryScreen({
    super.key,
    required this.onNavigate,
    required this.onNotify,
  });

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  String _filter = 'All';

  final List<(IconData, String, String, String, Color)> _events = [
    (Icons.check, 'Verification passed', 'Finflow Dashboard · 32 tests', 'Testing & Verification', AppColors.green),
    (Icons.psychology, 'Authentication task running', 'Nova Mobile · Coding Agent', 'Agent Workspace', AppColors.cyan),
    (Icons.chat_bubble_outline, 'Build a finance dashboard', 'Conversation · 12 minutes ago', 'AI Chat', const Color(0xFF9B91FF)),
    (Icons.folder_open, 'Atlas API created', 'Python · FastAPI', 'Project Workspace', AppColors.amber),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ACTIVITY & HISTORY',
                    style: TextStyle(
                      color: AppColors.cyan,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Everything that happened',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Reopen conversations, tasks, projects, and verification results.',
                    style: TextStyle(
                      color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Filter Bar
              Row(
                children: ['All', 'Tasks', 'Chats', 'Projects'].map((tab) {
                  final selected = _filter == tab;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: InkWell(
                      onTap: () {
                        setState(() => _filter = tab);
                        widget.onNotify('$tab activity filter applied.');
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 36,
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
              ),

              const SizedBox(height: 20),

              // Activity Feed List
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Column(
                  children: _events.map((e) {
                    return InkWell(
                      onTap: () => widget.onNavigate(e.$4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: e.$5.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(e.$1, color: e.$5, size: 16),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.$2, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  const SizedBox(height: 2),
                                  Text(e.$3, style: const TextStyle(color: AppColors.darkMuted, fontSize: 10)),
                                ],
                              ),
                            ),
                            const Text('Today', style: TextStyle(color: AppColors.darkMuted2, fontSize: 10)),
                            const SizedBox(width: 12),
                            const Icon(Icons.chevron_right, size: 16, color: AppColors.darkMuted2),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
