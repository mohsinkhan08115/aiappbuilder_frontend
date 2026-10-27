import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/components/status_pill.dart';
import '../../../core/components/confirm_dialog.dart';
import '../../projects/viewmodel/project_viewmodel.dart';
import '../../../data/models/project_file.dart';

class CodeFilesScreen extends StatefulWidget {
  final void Function(String route) onNavigate;
  final void Function(String message) onNotify;
  final void Function(ConfirmKind kind) onConfirm;

  const CodeFilesScreen({
    super.key,
    required this.onNavigate,
    required this.onNotify,
    required this.onConfirm,
  });

  @override
  State<CodeFilesScreen> createState() => _CodeFilesScreenState();
}

class _CodeFilesScreenState extends State<CodeFilesScreen> {
  String _activeFile = 'auth_service.dart';
  String _activeTab = 'Diff review';
  bool _showDiff = false;
  bool _showMobileFiles = false;
  final _searchController = TextEditingController();

  final List<String> _demoFiles = [
    'main.dart',
    'auth_service.dart',
    'login_screen.dart',
    'session_model.dart',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ProjectViewModel? vm;
    try {
      vm = context.watch<ProjectViewModel>();
    } catch (_) {}
    final proj = vm?.selectedProject;
    final realFiles = vm?.projectFiles ?? const <ProjectFile>[];

    final codeContent = vm?.openFileContent ??
        '''import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  const AuthService(this._storage);

  final FlutterSecureStorage _storage;

  Future<Session?> restoreSession() async {
    final token = await _storage.read(key: 'session_token');
    if (token == null) return null;
    return Session.fromToken(token);
  }
}''';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Page Header with responsive layout for narrow screens
              LayoutBuilder(
                builder: (context, headerConstraints) {
                  final isWideHeader = headerConstraints.maxWidth > 650;
                  final titleBlock = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CODE & FILES',
                        style: TextStyle(
                          color: AppColors.cyan,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${proj?.name ?? 'Nova Mobile'} / source',
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Representative code preview · 7 unreviewed changes',
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
                      OutlinedButton.icon(
                        onPressed: () => widget.onNavigate('Project Workspace'),
                        icon: const Icon(Icons.arrow_back, size: 14),
                        label: const Text('Back to project'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => widget.onConfirm(ConfirmKind.approve),
                        icon: const Icon(Icons.check, size: 14),
                        label: const Text('Review changes'),
                      ),
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

              // Code Workspace Shell: File tree + Editor with intentional bounded heights
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 680;
                    return isWide
                        ? SizedBox(
                            height: 520,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  width: 230,
                                  child: _buildFileTree(realFiles, isDark, vm, proj?.id),
                                ),
                                const VerticalDivider(width: 1),
                                Expanded(
                                  child: _buildEditor(
                                    codeContent,
                                    isDark,
                                    realFiles: realFiles,
                                    vm: vm,
                                    projId: proj?.id,
                                    isMobile: false,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : SizedBox(
                            height: _showMobileFiles ? 660 : 490,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_showMobileFiles) ...[
                                  SizedBox(
                                    height: 180,
                                    child: _buildFileTree(realFiles, isDark, vm, proj?.id),
                                  ),
                                  const Divider(height: 1),
                                ],
                                Expanded(
                                  child: _buildEditor(
                                    codeContent,
                                    isDark,
                                    realFiles: realFiles,
                                    vm: vm,
                                    projId: proj?.id,
                                    isMobile: true,
                                  ),
                                ),
                              ],
                            ),
                          );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Engineering Extension: Diff Review / Symbols / Comments
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
                    // Tab Bar with horizontal scrolling for narrow screens
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
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['Diff review', 'Code intelligence', 'Review comments'].map((tab) {
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
                    ),

                    // Tab Body
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: _buildExtensionBody(isDark),
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

  Widget _buildFileTree(List<ProjectFile> realFiles, bool isDark, ProjectViewModel? vm, String? projId) {
    return Container(
      color: isDark ? AppColors.darkSidebar : AppColors.lightSidebar,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search box
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, size: 14, color: AppColors.darkMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 11),
                    decoration: const InputDecoration(
                      hintText: 'Search files',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Folder Header
          Row(
            children: const [
              Icon(Icons.keyboard_arrow_down, size: 14, color: AppColors.darkMuted),
              SizedBox(width: 4),
              Icon(Icons.folder_open, size: 15, color: Color(0xFF9B91FF)),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'lib / services',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // File List (Real files if present or demo showcase files)
          Expanded(
            child: ListView(
              children: (realFiles.isNotEmpty ? realFiles.map((f) => f.name).toList() : _demoFiles).map((fileName) {
                final isSelected = _activeFile == fileName;
                return InkWell(
                  onTap: () {
                    setState(() => _activeFile = fileName);
                    if (realFiles.isNotEmpty && projId != null && vm != null) {
                      final target = realFiles.firstWhere((f) => f.name == fileName, orElse: () => realFiles.first);
                      vm.openFile(projId, target);
                    }
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    margin: const EdgeInsets.only(bottom: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? (isDark ? AppColors.darkSurface3 : AppColors.lightSurface3) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.insert_drive_file_outlined, size: 14, color: AppColors.darkMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            fileName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? (isDark ? AppColors.darkText : AppColors.lightText) : AppColors.darkMuted,
                            ),
                          ),
                        ),
                        if (fileName == 'auth_service.dart' || fileName == 'login_screen.dart')
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.amber,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor(
    String code,
    bool isDark, {
    required List<ProjectFile> realFiles,
    required ProjectViewModel? vm,
    required String? projId,
    required bool isMobile,
  }) {
    final availableFiles = realFiles.isNotEmpty ? realFiles.map((f) => f.name).toList() : _demoFiles;

    return Column(
      children: [
        // Tabs with horizontal scrolling support
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: availableFiles.map((fileName) {
                final isSelected = _activeFile == fileName;
                return InkWell(
                  onTap: () {
                    setState(() => _activeFile = fileName);
                    if (realFiles.isNotEmpty && projId != null && vm != null) {
                      final target = realFiles.firstWhere((f) => f.name == fileName, orElse: () => realFiles.first);
                      vm.openFile(projId, target);
                    }
                  },
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark ? AppColors.darkSurface : AppColors.lightSurface)
                          : Colors.transparent,
                      border: Border(
                        top: BorderSide(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                          width: 2,
                        ),
                        right: BorderSide(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          fileName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected
                                ? (isDark ? AppColors.darkText : AppColors.lightText)
                                : AppColors.darkMuted,
                          ),
                        ),
                        if (fileName == 'auth_service.dart' || fileName == 'login_screen.dart') ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: AppColors.amber,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Toolbar
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isMobile ? _activeFile : 'lib/services/$_activeFile',
                  style: const TextStyle(
                    color: AppColors.darkMuted,
                    fontSize: 11,
                    fontFamily: 'Consolas',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              if (isMobile)
                TextButton.icon(
                  onPressed: () => setState(() => _showMobileFiles = !_showMobileFiles),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    foregroundColor: AppColors.cyan,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: Icon(
                    _showMobileFiles ? Icons.folder_open : Icons.folder_outlined,
                    size: 13,
                  ),
                  label: Text(
                    _showMobileFiles ? 'Hide files' : 'Browse files',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _showDiff = !_showDiff;
                    if (_showDiff) _activeTab = 'Diff review';
                  });
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  foregroundColor: AppColors.primaryBright,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(_showDiff ? 'Hide diff' : 'View diff', style: const TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),

        // Code Area with finite bounded height from parent Flex
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: isDark ? const Color(0xFF070B14) : const Color(0xFFFAFBFC),
            child: SingleChildScrollView(
              child: SelectableText(
                code,
                style: const TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 12,
                  height: 1.7,
                  color: Color(0xFFB9C8DF),
                ),
              ),
            ),
          ),
        ),

        // Status Footer
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 5, height: 5, decoration: const BoxDecoration(color: AppColors.amber, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  const Text('Modified', style: TextStyle(color: AppColors.darkMuted, fontSize: 10)),
                ],
              ),
              Flexible(
                child: TextButton.icon(
                  onPressed: () => widget.onNavigate('Testing & Verification'),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward, size: 12),
                  label: Text(
                    isMobile ? 'Verification' : 'View related verification',
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: AppColors.primaryBright,
                    textStyle: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExtensionBody(bool isDark) {
    if (_activeTab == 'Diff review') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: const [
              Text('+18 additions', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.bold, fontSize: 11)),
              Text('−6 deletions', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.bold, fontSize: 11)),
              StatusPill(label: 'Unverified changes', type: StatusType.warning),
            ],
          ),
          const SizedBox(height: 14),

          // Split Diff Container
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildDiffColumn(
                              'Before',
                              "- Future restore() async {\n-   return storage.read('token');\n- }",
                              AppColors.red.withValues(alpha: 0.05),
                              isDark,
                            ),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(
                            child: _buildDiffColumn(
                              'After',
                              "+ Future<Session?> restoreSession() async {\n+   final token = await storage.read(\n+     key: 'session_token');\n+   return Session.fromToken(token);\n+ }",
                              AppColors.green.withValues(alpha: 0.05),
                              isDark,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _buildDiffColumn(
                            'Before',
                            "- Future restore() async {\n-   return storage.read('token');\n- }",
                            AppColors.red.withValues(alpha: 0.05),
                            isDark,
                          ),
                          const Divider(height: 1),
                          _buildDiffColumn(
                            'After',
                            "+ Future<Session?> restoreSession() async {\n+   final token = await storage.read(\n+     key: 'session_token');\n+   return Session.fromToken(token);\n+ }",
                            AppColors.green.withValues(alpha: 0.05),
                            isDark,
                          ),
                        ],
                      ),
              );
            },
          ),

          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => widget.onConfirm(ConfirmKind.reject),
                child: const Text('Request changes'),
              ),
              OutlinedButton.icon(
                onPressed: () => widget.onNavigate('Testing & Verification'),
                icon: const Icon(Icons.check, size: 14),
                label: const Text('Re-verify'),
              ),
              ElevatedButton.icon(
                onPressed: () => widget.onConfirm(ConfirmKind.approve),
                icon: const Icon(Icons.check, size: 14),
                label: const Text('Approve changes'),
              ),
            ],
          ),
        ],
      );
    } else if (_activeTab == 'Code intelligence') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SYMBOL RELATIONSHIPS', style: TextStyle(color: AppColors.darkMuted, fontSize: 9, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _symbolChip('AuthService', 'Selected class', AppColors.primaryBright),
              _symbolChip('Session', 'Returns', AppColors.cyan),
              _symbolChip('FlutterSecureStorage', 'Depends on', AppColors.amber),
              _symbolChip('LoginController', 'Called by', AppColors.green),
            ],
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCommentCard('RA', 'Review Agent', '· Requires change', 'Handle malformed token values before constructing the session object.', isDark),
          const SizedBox(height: 10),
          _buildCommentCard('AM', 'Alex Morgan', '· Just now', 'Add a guarded parser, then re-run the authentication tests.', isDark),
        ],
      );
    }
  }

  Widget _buildDiffColumn(String header, String code, Color bg, bool isDark) {
    return Container(
      color: bg,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(header, style: const TextStyle(color: AppColors.darkMuted, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            code,
            style: const TextStyle(fontFamily: 'Consolas', fontSize: 11, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _symbolChip(String name, String rel, Color dotColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x11172133),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              Text(rel, style: const TextStyle(color: AppColors.darkMuted, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentCard(String avatar, String author, String tag, String comment, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(7),
            ),
            alignment: Alignment.center,
            child: Text(avatar, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(author, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(width: 6),
                    Text(tag, style: const TextStyle(color: AppColors.amber, fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(comment, style: const TextStyle(fontSize: 11, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
