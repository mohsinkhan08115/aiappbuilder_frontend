import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'neural_orb.dart';

class WizardDialog extends StatefulWidget {
  final Future<void> Function(String name, String description, String target)
  onComplete;

  const WizardDialog({super.key, required this.onComplete});

  @override
  State<WizardDialog> createState() => _WizardDialogState();
}

class _WizardDialogState extends State<WizardDialog> {
  int _step = 1;
  final _nameController = TextEditingController(text: 'Finflow');
  final _descController = TextEditingController(
    text:
        'A personal finance dashboard with secure sign-in and spending insights.',
  );
  String _selectedTarget = 'Flutter / Dart';
  bool _creating = false;

  final List<String> _targets = [
    'Flutter / Dart',
    'Android / Kotlin',
    'Java',
    'JavaScript / TypeScript',
    'Node.js',
    'Python / FastAPI',
  ];

  final Map<String, bool> _requirements = {
    'Authentication': true,
    'Responsive layouts': true,
    'Testing & verification': true,
    'GitHub-ready structure': true,
  };

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _next() async {
    if (_step < 5) {
      setState(() => _step++);
    } else {
      setState(() => _creating = true);
      await widget.onComplete(
        _nameController.text.trim(),
        _descController.text.trim(),
        _selectedTarget,
      );
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isDark
              ? AppColors.darkBorderBright
              : AppColors.lightBorderBright,
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 620),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CREATE NEW PROJECT',
                        style: TextStyle(
                          color: Color(0xFF9B91FF),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Step $_step of 5',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),

            // Step Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: List.generate(5, (i) {
                  final active = i + 1 <= _step;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.primary
                            : (isDark
                                  ? AppColors.darkSurface3
                                  : AppColors.lightSurface3),
                        borderRadius: BorderRadius.circular(2),
                        gradient: active ? AppColors.primaryGradient : null,
                      ),
                    ),
                  );
                }),
              ),
            ),

            const Divider(height: 1),

            // Step Content Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: _buildStepBody(isDark),
              ),
            ),

            const Divider(height: 1),

            // Footer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_step > 1 && !_creating)
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: OutlinedButton(
                            onPressed: () => setState(() => _step--),
                            child: const Text('Back'),
                          ),
                        ),
                      ElevatedButton.icon(
                        onPressed: _creating ? null : _next,
                        icon: _creating
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                _step == 5
                                    ? Icons.auto_awesome
                                    : Icons.arrow_forward,
                                size: 14,
                              ),
                        iconAlignment: IconAlignment.end,
                        label: Text(
                          _step == 5
                              ? (_creating ? 'Creating…' : 'Create project')
                              : 'Continue',
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
    );
  }

  Widget _buildStepBody(bool isDark) {
    switch (_step) {
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What do you want to build?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Describe the experience, users, and essential outcomes.',
              style: TextStyle(color: AppColors.darkMuted, fontSize: 12),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _descController,
              minLines: 5,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText:
                    'e.g. A cross-platform finance app with charts and authentication...',
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'PROJECT NAME',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.darkMuted,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(hintText: 'Finflow'),
            ),
          ],
        );

      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose a supported target',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Capabilities shown reflect supported generation targets; execution is backend-confirmed.',
              style: TextStyle(color: AppColors.darkMuted, fontSize: 12),
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.6,
              ),
              itemCount: _targets.length,
              itemBuilder: (context, i) {
                final t = _targets[i];
                final selected = _selectedTarget == t;
                return InkWell(
                  onTap: () => setState(() => _selectedTarget = t),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : (isDark
                                ? AppColors.darkSurface2
                                : AppColors.lightSurface2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : (isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder),
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          t.contains('Flutter') || t.contains('Android')
                              ? Icons.phone_android
                              : Icons.code,
                          color: selected
                              ? AppColors.primaryBright
                              : AppColors.cyan,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                t,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Text(
                                'Available',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (selected)
                          const Icon(
                            Icons.check_circle,
                            size: 16,
                            color: AppColors.primaryBright,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );

      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Project requirements',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Refine scope before AI proposes the architecture and plan.',
              style: TextStyle(color: AppColors.darkMuted, fontSize: 12),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: _requirements.keys.map((k) {
                final checked = _requirements[k] ?? false;
                return FilterChip(
                  label: Text(k),
                  selected: checked,
                  onSelected: (val) {
                    setState(() => _requirements[k] = val);
                  },
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  checkmarkColor: AppColors.primaryBright,
                  side: BorderSide(
                    color: checked
                        ? AppColors.primary
                        : (isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text(
              'ADDITIONAL REQUIREMENTS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.darkMuted,
              ),
            ),
            const SizedBox(height: 6),
            const TextField(
              minLines: 3,
              maxLines: 4,
              decoration: InputDecoration(
                hintText:
                    'e.g. Use accessible components, clear loading and empty states.',
              ),
            ),
          ],
        );

      case 4:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Review specification',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Confirm all details before initializing the workspace.',
              style: TextStyle(color: AppColors.darkMuted, fontSize: 12),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurface2
                    : AppColors.lightSurface2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PROJECT SUMMARY',
                    style: TextStyle(
                      color: Color(0xFF9B91FF),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_nameController.text} · $_selectedTarget',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _descController.text,
                    style: const TextStyle(
                      color: AppColors.darkMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurface2
                    : AppColors.lightSurface2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PROPOSED WORKFLOW PLAN',
                    style: TextStyle(
                      color: Color(0xFF9B91FF),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Establish project architecture and design tokens',
                    style: TextStyle(fontSize: 11),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '2. Build authentication and core application flows',
                    style: TextStyle(fontSize: 11),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '3. Run supported analysis, tests, and review code diffs',
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        );

      case 5:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NeuralOrb(isThinking: _creating, size: 100),
              const SizedBox(height: 20),
              Text(
                _creating
                    ? 'Creating ${_nameController.text}…'
                    : 'Ready to create ${_nameController.text}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _creating
                    ? 'Preparing workspace, generating structure, and initializing repository…'
                    : 'Your specification and plan are complete. Click "Create project" to begin.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.darkMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}
