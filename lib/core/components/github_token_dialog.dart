import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../errors/app_error_handler.dart';
import '../../features/projects/viewmodel/project_viewmodel.dart';

/// Reusable modal dialog for configuring and validating GitHub Personal Access Tokens.
class GitHubTokenDialog extends StatefulWidget {
  final void Function(String? username)? onSuccess;

  const GitHubTokenDialog({
    super.key,
    this.onSuccess,
  });

  @override
  State<GitHubTokenDialog> createState() => _GitHubTokenDialogState();
}

class _GitHubTokenDialogState extends State<GitHubTokenDialog> {
  final TextEditingController _tokenController = TextEditingController();
  String? _validationMessage;
  bool _isSubmitting = false;
  bool _obscureToken = true;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final token = _tokenController.text.trim();
    final localError = AppErrorHandler.validateGithubToken(token);
    if (localError != null) {
      setState(() => _validationMessage = localError);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _validationMessage = null;
    });

    final vm = context.read<ProjectViewModel>();
    final res = await vm.updateGitHubToken(token);

    if (!mounted) return;

    if (res != null) {
      Navigator.of(context).pop();
      final username = res['username'] as String?;
      widget.onSuccess?.call(username);
    } else {
      final errorMsg = vm.error ?? 'Failed to validate GitHub token.';
      setState(() {
        _isSubmitting = false;
        _validationMessage = errorMsg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.vpn_key, size: 20, color: AppColors.primaryBright),
          SizedBox(width: 8),
          Text(
            'GitHub Token Config',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your GitHub Personal Access Token (PAT). Required to synchronize and push projects to GitHub repositories.',
              style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.darkMuted),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.cyan.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.cyan.withValues(alpha: 0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Token Requirements:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.cyan),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• Classic PAT (starts with "ghp_") or Fine-grained PAT ("github_pat_")\n'
                    '• Required Scope: "repo" (Full control of repositories)\n'
                    '• Generate at: https://github.com/settings/tokens',
                    style: TextStyle(fontSize: 10, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _tokenController,
              obscureText: _obscureToken,
              enabled: !_isSubmitting,
              onChanged: (val) {
                if (_validationMessage != null) {
                  setState(() {
                    _validationMessage = AppErrorHandler.validateGithubToken(val);
                  });
                }
              },
              decoration: InputDecoration(
                hintText: 'ghp_... or github_pat_...',
                labelText: 'Personal Access Token',
                errorText: _validationMessage,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureToken
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  tooltip: _obscureToken ? 'Show token' : 'Hide token',
                  onPressed: () {
                    setState(() {
                      _obscureToken = !_obscureToken;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
