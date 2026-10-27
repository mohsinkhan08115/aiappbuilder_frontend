import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum StatusType { success, running, warning, neutral, error }

class StatusPill extends StatelessWidget {
  final String label;
  final StatusType type;
  final double fontSize;

  const StatusPill({
    super.key,
    required this.label,
    this.type = StatusType.neutral,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = switch (type) {
      StatusType.success => AppColors.green,
      StatusType.running => AppColors.cyan,
      StatusType.warning => AppColors.amber,
      StatusType.error => AppColors.red,
      StatusType.neutral => AppColors.darkMuted,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: type == StatusType.running || type == StatusType.success
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.6),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
