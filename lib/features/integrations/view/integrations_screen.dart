import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/components/status_pill.dart';
import '../../../core/components/confirm_dialog.dart';
import '../../../core/components/github_token_dialog.dart';
import '../../../data/services/api_service.dart';

class IntegrationsScreen extends StatefulWidget {
  final void Function(String message) onNotify;
  final void Function(ConfirmKind kind) onConfirm;

  const IntegrationsScreen({
    super.key,
    required this.onNotify,
    required this.onConfirm,
  });

  @override
  State<IntegrationsScreen> createState() => _IntegrationsScreenState();
}

class _IntegrationsScreenState extends State<IntegrationsScreen> {
  bool _connected = false;
  String? _githubUsername;
  String? _tokenPreview;
  bool _isLoadingStatus = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchStatus();
    });
  }

  Future<void> _fetchStatus() async {
    setState(() => _isLoadingStatus = true);
    try {
      final api = context.read<ApiService>();
      if (api.isAuthenticated) {
        final status = await api.getGithubStatus();
        if (mounted) {
          setState(() {
            _connected = status['is_valid'] == true;
            _githubUsername = status['username'] as String?;
            _tokenPreview = status['token_preview'] as String?;
            _isLoadingStatus = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingStatus = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingStatus = false);
    }
  }

  void _showTokenDialog() {
    showDialog(
      context: context,
      builder: (ctx) => GitHubTokenDialog(
        onSuccess: (username) {
          _fetchStatus();
          final msg = username != null
              ? 'GitHub token verified for "$username" and connected successfully.'
              : 'GitHub token saved and connected successfully.';
          widget.onNotify(msg);
        },
      ),
    );
  }

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
                    'INTEGRATIONS',
                    style: TextStyle(
                      color: AppColors.cyan,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Connect your workflow',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Connection states are confirmed by the backend before being shown as active.',
                    style: TextStyle(
                      color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // GitHub Integration Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface3 : AppColors.lightSurface3,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.code, size: 28, color: Color(0xFF9B91FF)),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('GitHub', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          const Text(
                            'Import supported repositories and coordinate approved source-control workflows.',
                            style: TextStyle(color: AppColors.darkMuted, fontSize: 11),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              StatusPill(
                                label: _isLoadingStatus
                                    ? 'Checking...'
                                    : (_connected
                                        ? (_githubUsername != null ? 'Connected (@$_githubUsername)' : 'Connected')
                                        : 'Not connected'),
                                type: _connected ? StatusType.success : StatusType.neutral,
                              ),
                              if (_tokenPreview != null && _connected) ...[
                                const SizedBox(width: 8),
                                Text(
                                  _tokenPreview!,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'Consolas',
                                    color: AppColors.darkMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_connected)
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: () => widget.onNotify('Repository selector opened.'),
                            child: const Text('Select repository'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () {
                              widget.onConfirm(ConfirmKind.disconnect);
                              setState(() => _connected = false);
                            },
                            child: const Text('Disconnect'),
                          ),
                        ],
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: _showTokenDialog,
                        icon: const Icon(Icons.link, size: 15),
                        label: const Text('Connect GitHub'),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // State Showcase Cards
              Row(
                children: [
                  Expanded(
                    child: _buildStateCard('Connecting', 'Waiting for authorization', AppColors.cyan, isDark, null),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStateCard('Connection error', 'Retry authentication', AppColors.red, isDark, () {
                      widget.onNotify('GitHub connection retry started.');
                    }),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStateCard('Offline', 'Connection unavailable', AppColors.darkMuted, isDark, null),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Engineering Extension: Connected Repositories
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'REPOSITORY WORKFLOWS',
                            style: TextStyle(
                              color: Color(0xFF9B91FF),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text('Connected repository states', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          SizedBox(height: 2),
                          Text('Operations and permissions remain backend-confirmed.', style: TextStyle(color: AppColors.darkMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    _buildRepoRow('developer / nova-mobile', 'main · Synced 8 minutes ago', 'Available', StatusType.success, isDark),
                    _buildRepoRow('studio / finflow-dashboard', 'Access must be confirmed again', 'Permission error', StatusType.warning, isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStateCard(String title, String subtitle, Color dotColor, bool isDark, VoidCallback? onRetry) {
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
          Container(width: 7, height: 7, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: AppColors.darkMuted, fontSize: 10)),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: AppColors.primaryBright),
              child: const Text('Retry', style: TextStyle(fontSize: 10)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRepoRow(String name, String detail, String status, StatusType statusType, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
      ),
      child: Row(
        children: [
          const Icon(Icons.code, color: AppColors.darkMuted, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text(detail, style: const TextStyle(color: AppColors.darkMuted, fontSize: 10)),
              ],
            ),
          ),
          StatusPill(label: status, type: statusType, fontSize: 10),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 16, color: AppColors.darkMuted2),
        ],
      ),
    );
  }
}
