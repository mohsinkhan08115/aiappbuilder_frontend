import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ComposerCard extends StatelessWidget {
  final TextEditingController controller;
  final bool isThinking;
  final String? activeProjectName;
  final VoidCallback onSelectProject;
  final VoidCallback onAddContext;
  final VoidCallback onToggleDevMode;
  final VoidCallback onOpenVoice;
  final VoidCallback onSubmit;

  const ComposerCard({
    super.key,
    required this.controller,
    this.isThinking = false,
    this.activeProjectName,
    required this.onSelectProject,
    required this.onAddContext,
    required this.onToggleDevMode,
    required this.onOpenVoice,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgGrad = isDark
        ? const LinearGradient(
            colors: [
              Color(0xFF0F1523),
              Color(0xFF0A0F1A),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFF7F9FD),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return Container(
      decoration: BoxDecoration(
        gradient: bgGrad,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorderBright : AppColors.lightBorderBright,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: "BUILD WITH AI" and Context selector pill
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF9B91FF)),
                    const SizedBox(width: 8),
                    const Text(
                      'BUILD WITH AI',
                      style: TextStyle(
                        color: Color(0xFF9B91FF),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: onSelectProject,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: activeProjectName != null ? AppColors.cyan : AppColors.darkMuted2,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          activeProjectName ?? 'No project selected',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 14,
                          color: isDark ? AppColors.darkMuted2 : AppColors.lightMuted2,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main Text Input Area
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: controller,
              minLines: 3,
              maxLines: 6,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
              decoration: InputDecoration(
                hintText: 'Describe the app you want to build, or ask anything...',
                hintStyle: TextStyle(
                  color: isDark ? AppColors.darkMuted2 : AppColors.lightMuted2,
                  fontSize: 14,
                ),
                fillColor: Colors.transparent,
                filled: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          // Divider
          Divider(
            height: 1,
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),

          // Action toolbar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left tools: Add context, Developer mode
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: onAddContext,
                      icon: const Icon(Icons.add, size: 15),
                      label: const Text('Add context'),
                      style: TextButton.styleFrom(
                        foregroundColor: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: onToggleDevMode,
                      icon: const Icon(Icons.code, size: 15),
                      label: const Text('Developer mode'),
                      style: TextButton.styleFrom(
                        foregroundColor: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ],
                ),

                // Right actions: Mic + Start building button
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: onOpenVoice,
                      tooltip: 'Talk to AI',
                      icon: const Icon(Icons.mic_none, size: 18),
                      color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: isThinking ? null : onSubmit,
                      icon: isThinking
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.arrow_forward, size: 15),
                      iconAlignment: IconAlignment.end,
                      label: Text(isThinking ? 'Planning…' : 'Start building'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
