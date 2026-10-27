import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../../data/models/project.dart';
import '../../data/models/github_repo.dart';
import '../../features/projects/viewmodel/project_viewmodel.dart';
import 'github_token_dialog.dart';

class PushToGitHubDialog extends StatefulWidget {
  final Project project;
  final void Function(String repoUrl)? onSuccess;

  const PushToGitHubDialog({super.key, required this.project, this.onSuccess});

  @override
  State<PushToGitHubDialog> createState() => _PushToGitHubDialogState();
}

class _PushToGitHubDialogState extends State<PushToGitHubDialog> {
  late final TextEditingController _repoNameController;
  bool _isPrivate = true;
  bool _isPushing = false;
  String? _validationError;
  String? _pushError;
  GitHubRepo? _createdRepo;

  @override
  void initState() {
    super.initState();
    final sanitizedDefault = _sanitizeRepoName(widget.project.name);
    _repoNameController = TextEditingController(text: sanitizedDefault);
    _repoNameController.addListener(_validateInput);
  }

  @override
  void dispose() {
    _repoNameController.removeListener(_validateInput);
    _repoNameController.dispose();
    super.dispose();
  }

  String _sanitizeRepoName(String name) {
    var sanitized = name.toLowerCase().trim();
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), '-');
    sanitized = sanitized.replaceAll(RegExp(r'[^a-z0-9._-]'), '-');
    sanitized = sanitized.replaceAll(RegExp(r'-+'), '-');
    sanitized = sanitized.replaceAll(RegExp(r'^[._-]+'), '');
    sanitized = sanitized.replaceAll(RegExp(r'[._-]+$'), '');
    if (sanitized.isEmpty) return 'flutter-app';
    if (sanitized.length > 100) return sanitized.substring(0, 100);
    return sanitized;
  }

  void _validateInput() {
    final text = _repoNameController.text.trim();
    if (text.isEmpty) {
      setState(() => _validationError = 'Repository name cannot be empty.');
      return;
    }
    if (text.length > 100) {
      setState(
        () =>
            _validationError = 'Repository name cannot exceed 100 characters.',
      );
      return;
    }
    if (text.startsWith('.') || text.startsWith('-')) {
      setState(
        () => _validationError =
            'Repository name cannot start with a dot or hyphen.',
      );
      return;
    }
    if (text.toLowerCase().endsWith('.git')) {
      setState(
        () => _validationError = 'Repository name cannot end with .git.',
      );
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(text)) {
      setState(
        () => _validationError =
            'Only alphanumeric characters, hyphens, underscores, and periods are allowed.',
      );
      return;
    }
    if (_validationError != null) {
      setState(() => _validationError = null);
    }
  }

  Future<void> _handlePush() async {
    _validateInput();
    if (_validationError != null) return;

    final repoName = _repoNameController.text.trim();
    setState(() {
      _isPushing = true;
      _pushError = null;
    });

    final vm = context.read<ProjectViewModel>();
    try {
      final repo = await vm.pushToGithub(
        widget.project.id,
        repoName,
        _isPrivate,
      );

      if (!mounted) return;
      setState(() {
        _isPushing = false;
        _createdRepo = repo;
      });
      widget.onSuccess?.call(repo.repoUrl);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isPushing = false;
        _pushError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _openTokenConfig() {
    showDialog(
      context: context,
      builder: (_) => const GitHubTokenDialog(),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _copyRepoUrl() {
    if (_createdRepo != null) {
      Clipboard.setData(ClipboardData(text: _createdRepo!.repoUrl));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Repository URL copied to clipboard!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vm = context.watch<ProjectViewModel>();

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.cyan.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.cloud_upload_outlined,
              size: 20,
              color: AppColors.cyan,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Push to GitHub',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Publish project source code to a GitHub repository',
                  style: TextStyle(fontSize: 11, color: AppColors.darkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: _createdRepo != null
              ? _buildSuccessView(isDark)
              : _buildFormView(context, isDark, vm),
        ),
      ),
      actions: _createdRepo != null
          ? [
              OutlinedButton.icon(
                onPressed: _copyRepoUrl,
                icon: const Icon(Icons.copy, size: 14),
                label: const Text('Copy URL'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ]
          : [
              TextButton(
                onPressed: _isPushing
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: (_isPushing || _validationError != null)
                    ? null
                    : _handlePush,
                icon: _isPushing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.arrow_upward, size: 14),
                label: Text(_isPushing ? 'Pushing...' : 'Push to GitHub'),
              ),
            ],
    );
  }

  Widget _buildFormView(
    BuildContext context,
    bool isDark,
    ProjectViewModel vm,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Project summary box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.folder_outlined,
                    size: 15,
                    color: AppColors.cyan,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.project.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.call_split, size: 11, color: AppColors.cyan),
                        SizedBox(width: 4),
                        Text(
                          'branch: main',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.cyan,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Source path: ${widget.project.workspacePath}',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // GitHub Token status banner
        _buildTokenStatusBanner(isDark, vm),

        const SizedBox(height: 14),

        // Repository Name Input
        TextField(
          controller: _repoNameController,
          enabled: !_isPushing,
          decoration: InputDecoration(
            labelText: 'GitHub Repository Name',
            hintText: 'e.g. my-flutter-app',
            prefixIcon: const Icon(Icons.code, size: 16),
            errorText: _validationError,
          ),
        ),

        const SizedBox(height: 14),

        // Visibility Selection
        const Text(
          'Repository Visibility',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Column(
            children: [
              RadioListTile<bool>(
                title: const Text(
                  'Private repository (Recommended)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Only you and users you invite can view this repository.',
                  style: TextStyle(fontSize: 10, color: AppColors.darkMuted),
                ),
                value: true,
                groupValue: _isPrivate,
                onChanged: _isPushing
                    ? null
                    : (val) => setState(() => _isPrivate = val ?? true),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 0,
                ),
                dense: true,
              ),
              const Divider(height: 1),
              RadioListTile<bool>(
                title: const Text(
                  'Public repository',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Anyone on the internet can view this repository.',
                  style: TextStyle(fontSize: 10, color: AppColors.darkMuted),
                ),
                value: false,
                groupValue: _isPrivate,
                onChanged: _isPushing
                    ? null
                    : (val) => setState(() => _isPrivate = val ?? false),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 0,
                ),
                dense: true,
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Security / Secret exclusion note
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.green.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, size: 15, color: AppColors.green),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Security Protection: Sensitive files (.env, *.db, keys, certificates) and build caches are automatically excluded via .gitignore before pushing.',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.green,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_pushError != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, size: 15, color: AppColors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _pushError!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.red,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (_isPushing) ...[
          const SizedBox(height: 16),
          const Center(
            child: Column(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                SizedBox(height: 8),
                Text(
                  'Pushing to GitHub in background...',
                  style: TextStyle(fontSize: 11, color: AppColors.darkMuted),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTokenStatusBanner(bool isDark, ProjectViewModel vm) {
    final diag = vm.githubDiagnostics;
    final username = diag?['username'] as String?;

    if (username != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.green.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.green.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 14,
              color: AppColors.green,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Connected to GitHub as @$username',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            InkWell(
              onTap: _openTokenConfig,
              child: const Text(
                'Change',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.primaryBright,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.vpn_key_outlined, size: 14, color: AppColors.amber),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'A valid GitHub PAT is required to push.',
              style: TextStyle(fontSize: 11, color: AppColors.amber),
            ),
          ),
          TextButton(
            onPressed: _openTokenConfig,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 24),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('Configure PAT', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(bool isDark) {
    final repoUrl = _createdRepo?.repoUrl ?? '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.green.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle,
            size: 36,
            color: AppColors.green,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Project Pushed to GitHub!',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        const Text(
          'The repository has been initialized and synchronized on GitHub.',
          style: TextStyle(fontSize: 11, color: AppColors.darkMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.link, size: 16, color: AppColors.primaryBright),
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  repoUrl,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primaryBright,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: _copyRepoUrl,
                tooltip: 'Copy URL',
                icon: const Icon(Icons.copy, size: 14),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
