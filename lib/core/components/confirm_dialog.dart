import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum ConfirmKind { cancel, approve, reject, disconnect }

class ConfirmDialog extends StatelessWidget {
  final ConfirmKind kind;
  final VoidCallback onConfirm;

  const ConfirmDialog({
    super.key,
    required this.kind,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (title, desc, actionLabel, icon, color) = switch (kind) {
      ConfirmKind.approve => (
          'Review proposed changes',
          '3 files will be modified. Review diffs and allow the agent to continue.',
          'Approve changes',
          Icons.check,
          AppColors.green,
        ),
      ConfirmKind.reject => (
          'Reject proposed changes?',
          'The task will return to the planning agent with your feedback.',
          'Reject changes',
          Icons.close,
          AppColors.amber,
        ),
      ConfirmKind.cancel => (
          'Cancel this task?',
          'The current agent will stop safely. Completed changes remain available for review.',
          'Cancel task',
          Icons.pause_circle_outline,
          AppColors.red,
        ),
      ConfirmKind.disconnect => (
          'Disconnect GitHub?',
          'Repository access will be removed from this workspace.',
          'Disconnect',
          Icons.link_off,
          AppColors.red,
        ),
    };

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? AppColors.darkBorderBright : AppColors.lightBorderBright),
      ),
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                desc,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.darkMuted, fontSize: 11, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go back'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onConfirm();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kind == ConfirmKind.approve
                          ? AppColors.primary
                          : (kind == ConfirmKind.reject ? AppColors.amber : AppColors.red),
                    ),
                    child: Text(actionLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
