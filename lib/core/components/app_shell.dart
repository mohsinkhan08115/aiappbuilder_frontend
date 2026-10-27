import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/theme_provider.dart';
import '../../features/auth/viewmodel/auth_viewmodel.dart';
import '../../features/projects/viewmodel/project_viewmodel.dart';
import 'brand_logo.dart';
import 'splash_screen.dart';
import 'wizard_dialog.dart';
import 'voice_dialog.dart';
import 'confirm_dialog.dart';
import 'github_token_dialog.dart';

import '../../features/home/view/home_screen.dart';
import '../../features/chat/view/chat_screen.dart';
import '../../features/projects/view/projects_screen.dart';
import '../../features/projects/view/project_workspace_screen.dart';
import '../../features/agents/view/agent_workspace_screen.dart';
import '../../features/code/view/code_files_screen.dart';
import '../../features/testing/view/testing_verification_screen.dart';
import '../../features/activity/view/activity_history_screen.dart';
import '../../features/integrations/view/integrations_screen.dart';
import '../../features/settings/view/settings_screen.dart';
import '../../data/services/preferences_service.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String _activePage = 'Home';
  bool _showSplash = true;
  bool _showNotifications = false;
  String? _toastMessage;
  bool _isSidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          final prefs = context.read<PreferencesService?>();
          if (prefs != null) {
            setState(() {
              _isSidebarCollapsed = prefs.getSidebarCollapsed();
            });
          }
        } catch (_) {}
      }
    });
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
    });
    try {
      final prefs = context.read<PreferencesService?>();
      prefs?.setSidebarCollapsed(_isSidebarCollapsed);
    } catch (_) {}
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<(String, IconData, bool)> _navItems = [
    ('Home', Icons.home_outlined, false),
    ('AI Chat', Icons.chat_bubble_outline, false),
    ('Projects', Icons.folder_outlined, false),
    ('Agent Workspace', Icons.psychology_outlined, true),
    ('Code & Files', Icons.code, false),
    ('Testing & Verification', Icons.check_circle_outline, false),
    ('Activity & History', Icons.history, false),
    ('Integrations', Icons.link, false),
  ];

  void _notify(String msg) {
    setState(() => _toastMessage = msg);
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (mounted && _toastMessage == msg) {
        setState(() => _toastMessage = null);
      }
    });
  }

  void _navigateTo(String page) {
    setState(() {
      _activePage = page;
      _showNotifications = false;
    });
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  void _openWizard() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WizardDialog(
        onComplete: (name, desc, target) async {
          final vm = context.read<ProjectViewModel>();
          final newProj = await vm.createProject(name, desc);
          if (newProj != null) {
            await vm.selectProject(newProj.id);
            _navigateTo('Project Workspace');
            _notify('Project "$name" created successfully.');
          }
        },
      ),
    );
  }

  void _openVoice() {
    showDialog(
      context: context,
      builder: (ctx) =>
          VoiceDialog(onReturnToText: () => _navigateTo('AI Chat')),
    );
  }

  void _openConfirm(ConfirmKind kind) {
    showDialog(
      context: context,
      builder: (ctx) => ConfirmDialog(
        kind: kind,
        onConfirm: () => _notify('${kind.name} action completed.'),
      ),
    );
  }

  void _showGithubTokenDialog() {
    showDialog(
      context: context,
      builder: (ctx) => GitHubTokenDialog(
        onSuccess: (username) {
          _notify(
            username != null
                ? 'GitHub token verified for "$username" and saved successfully!'
                : 'GitHub token saved successfully!',
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      drawer: Drawer(
        backgroundColor: isDark
            ? AppColors.darkSidebar
            : AppColors.lightSidebar,
        child: SafeArea(child: _buildSidebarContent(isDark, isMobile: true)),
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          // Bottom bar on narrow mobile viewports
          if (MediaQuery.of(context).size.width >= 850) {
            return const SizedBox.shrink();
          }
          return NavigationBar(
            selectedIndex: _getMobileNavIndex(),
            onDestinationSelected: (idx) {
              if (idx == 0) _navigateTo('Home');
              if (idx == 1) _navigateTo('AI Chat');
              if (idx == 2) _navigateTo('Projects');
              if (idx == 3) _navigateTo('Agent Workspace');
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline),
                label: 'AI Chat',
              ),
              NavigationDestination(
                icon: Icon(Icons.folder_outlined),
                label: 'Projects',
              ),
              NavigationDestination(
                icon: Icon(Icons.psychology_outlined),
                label: 'Agents',
              ),
            ],
          );
        },
      ),
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 850;

              return Row(
                children: [
                  // Persistent Left Sidebar on Wide Screens
                  if (isWide)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOutCubic,
                      width: _isSidebarCollapsed ? 68 : 235,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSidebar
                            : AppColors.lightSidebar,
                        border: Border(
                          right: BorderSide(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: OverflowBox(
                        minWidth: _isSidebarCollapsed ? 68 : 235,
                        maxWidth: _isSidebarCollapsed ? 68 : 235,
                        alignment: Alignment.topLeft,
                        child: _buildSidebarContent(
                          isDark,
                          isMobile: false,
                          isCollapsed: _isSidebarCollapsed,
                        ),
                      ),
                    ),

                  // Main Content Area with Header
                  Expanded(
                    child: Column(
                      children: [
                        // Sticky Top Header
                        _buildHeader(isWide, isDark, themeProvider),

                        // Active View Screen
                        Expanded(child: _buildActivePage()),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          // Notifications Dropdown Popover
          if (_showNotifications)
            Positioned(
              top: 68,
              right: 32,
              child: _buildNotificationPopover(isDark),
            ),

          // Floating Toast Notification
          if (_toastMessage != null)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurface3
                        : AppColors.lightSurface3,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primaryBright.withValues(alpha: 0.3),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        color: AppColors.primaryBright,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _toastMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Initial Splash Screen Overlay
          if (_showSplash)
            SplashScreenOverlay(
              onDismiss: () => setState(() => _showSplash = false),
            ),
        ],
      ),
    );
  }

  Widget _buildSidebarContent(
    bool isDark, {
    required bool isMobile,
    bool isCollapsed = false,
  }) {
    final authVm = context.watch<AuthViewModel?>();
    final email = authVm?.currentUserEmail;
    final isAuth = authVm?.isAuthenticated ?? false;
    final displayName =
        email ?? (isAuth ? 'Authenticated Developer' : 'Alex Morgan');
    final subtitle = isAuth ? 'Active session' : 'Pro workspace';
    final initials = (email != null && email.isNotEmpty)
        ? email.substring(0, email.length >= 2 ? 2 : 1).toUpperCase()
        : 'AM';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isCollapsed ? 8 : 16,
        20,
        isCollapsed ? 8 : 16,
        16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Header: Brand Logo & Toggle Button
          if (isCollapsed)
            Center(
              child: IconButton(
                onPressed: _toggleSidebar,
                icon: const Icon(Icons.menu, size: 20),
                tooltip: 'Expand sidebar',
                color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: BrandLogo(isLight: !isDark)),
                if (isMobile)
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 18),
                  )
                else
                  IconButton(
                    onPressed: _toggleSidebar,
                    icon: const Icon(Icons.menu_open, size: 18),
                    tooltip: 'Collapse sidebar',
                    color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                  ),
              ],
            ),

          SizedBox(height: isCollapsed ? 16 : 20),

          // Primary "Create New Project" button
          if (isCollapsed)
            Center(
              child: IconButton.filled(
                onPressed: _openWizard,
                icon: const Icon(Icons.add, size: 18),
                tooltip: 'Create New Project',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(40, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _openWizard,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Create New Project'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(42),
              ),
            ),

          SizedBox(height: isCollapsed ? 16 : 20),

          // Nav Section Label
          if (!isCollapsed)
            Padding(
              padding: const EdgeInsets.only(left: 10, bottom: 8),
              child: Text(
                'WORKSPACE',
                style: TextStyle(
                  color: isDark ? AppColors.darkMuted2 : AppColors.lightMuted2,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),

          // 8 Navigation Destinations
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: _navItems.map((item) {
                final isSelected = _activePage == item.$1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Tooltip(
                    message: item.$1,
                    waitDuration: const Duration(milliseconds: 300),
                    child: InkWell(
                      onTap: () => _navigateTo(item.$1),
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        height: 40,
                        padding: EdgeInsets.symmetric(
                          horizontal: isCollapsed ? 0 : 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          border: isSelected
                              ? const Border(
                                  left: BorderSide(
                                    color: AppColors.primaryBright,
                                    width: 2.5,
                                  ),
                                )
                              : null,
                        ),
                        child: isCollapsed
                            ? Center(
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.center,
                                  children: [
                                    Icon(
                                      item.$2,
                                      size: 18,
                                      color: isSelected
                                          ? const Color(0xFF9B91FF)
                                          : (isDark
                                                ? AppColors.darkMuted
                                                : AppColors.lightMuted),
                                    ),
                                    if (item.$3) // Agent badge indicator dot
                                      Positioned(
                                        right: -4,
                                        top: -2,
                                        child: Container(
                                          width: 7,
                                          height: 7,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFA49AFF),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              )
                            : Row(
                                children: [
                                  Icon(
                                    item.$2,
                                    size: 17,
                                    color: isSelected
                                        ? const Color(0xFF9B91FF)
                                        : (isDark
                                              ? AppColors.darkMuted
                                              : AppColors.lightMuted),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      item.$1,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? (isDark
                                                  ? AppColors.darkText
                                                  : AppColors.lightText)
                                            : (isDark
                                                  ? AppColors.darkMuted
                                                  : AppColors.lightMuted),
                                      ),
                                    ),
                                  ),
                                  if (item.$3) // Agent badge
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      alignment: Alignment.center,
                                      child: const Text(
                                        '2',
                                        style: TextStyle(
                                          color: Color(0xFFA49AFF),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(height: 1),
          const SizedBox(height: 8),

          // Settings Nav item
          Tooltip(
            message: 'Settings',
            waitDuration: const Duration(milliseconds: 300),
            child: InkWell(
              onTap: () => _navigateTo('Settings'),
              borderRadius: BorderRadius.circular(9),
              child: Container(
                height: 40,
                padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 0 : 12),
                decoration: BoxDecoration(
                  color: _activePage == 'Settings'
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: isCollapsed
                    ? Center(
                        child: Icon(
                          Icons.settings_outlined,
                          size: 18,
                          color: _activePage == 'Settings'
                              ? const Color(0xFF9B91FF)
                              : (isDark
                                    ? AppColors.darkMuted
                                    : AppColors.lightMuted),
                        ),
                      )
                    : Row(
                        children: [
                          Icon(
                            Icons.settings_outlined,
                            size: 17,
                            color: _activePage == 'Settings'
                                ? const Color(0xFF9B91FF)
                                : (isDark
                                      ? AppColors.darkMuted
                                      : AppColors.lightMuted),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Settings',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // User Profile Card
          Tooltip(
            message: displayName,
            waitDuration: const Duration(milliseconds: 300),
            child: InkWell(
              onTap: () {
                _navigateTo('Settings');
                _notify('Profile settings opened.');
              },
              borderRadius: BorderRadius.circular(9),
              child: Container(
                padding: EdgeInsets.all(isCollapsed ? 4 : 8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: isCollapsed
                    ? Center(
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B65DB), Color(0xFF3A6BD6)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      )
                    : Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B65DB), Color(0xFF3A6BD6)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  subtitle,
                                  style: const TextStyle(
                                    color: AppColors.darkMuted,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            size: 14,
                            color: AppColors.darkMuted2,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isWide, bool isDark, ThemeProvider themeProvider) {
    final authVm = context.watch<AuthViewModel?>();
    final email = authVm?.currentUserEmail;
    final initials = (email != null && email.isNotEmpty)
        ? email.substring(0, email.length >= 2 ? 2 : 1).toUpperCase()
        : 'AM';

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.darkBg : AppColors.lightBg).withValues(
          alpha: 0.88,
        ),
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Drawer trigger (if mobile) + Breadcrumbs
          Row(
            children: [
              if (!isWide)
                IconButton(
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  icon: const Icon(Icons.menu, size: 18),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                ),
              TextButton(
                onPressed: () => _navigateTo('Home'),
                style: TextButton.styleFrom(
                  foregroundColor: isDark
                      ? AppColors.darkMuted
                      : AppColors.lightMuted,
                  textStyle: const TextStyle(fontSize: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: Size.zero,
                ),
                child: const Text('Workspace'),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                size: 14,
                color: AppColors.darkMuted2,
              ),
              const SizedBox(width: 4),
              Text(
                _activePage,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),

          // Right: Global search, Theme switch, Notifications, Avatar
          Row(
            children: [
              if (isWide)
                InkWell(
                  onTap: () => _notify('Global search opened (⌘ K).'),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 190,
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurface
                          : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search,
                          size: 14,
                          color: AppColors.darkMuted,
                        ),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Search anything',
                            style: TextStyle(
                              color: AppColors.darkMuted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            '⌘ K',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppColors.darkMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(width: 6),

              // Theme Switcher button
              IconButton(
                onPressed: themeProvider.toggleTheme,
                icon: Icon(
                  themeProvider.isDarkMode
                      ? Icons.wb_sunny_outlined
                      : Icons.nightlight_round,
                  size: 17,
                ),
                tooltip: 'Toggle Theme',
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),

              // Notifications Bell
              IconButton(
                onPressed: () =>
                    setState(() => _showNotifications = !_showNotifications),
                icon: const Icon(Icons.notifications_none, size: 17),
                tooltip: 'Notifications',
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),

              // GitHub Token Config Gear Icon
              IconButton(
                onPressed: _showGithubTokenDialog,
                icon: const Icon(Icons.settings_outlined, size: 17),
                tooltip: 'GitHub Token Config',
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
              ),

              const SizedBox(width: 6),

              // Compact User Avatar
              InkWell(
                onTap: () => _navigateTo('Settings'),
                borderRadius: BorderRadius.circular(7),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B65DB), Color(0xFF3A6BD6)],
                    ),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationPopover(bool isDark) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorderBright
              : AppColors.lightBorderBright,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Notifications',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.psychology,
              size: 16,
              color: AppColors.cyan,
            ),
            title: const Text(
              'Agent task needs review',
              style: TextStyle(fontSize: 11),
            ),
            onTap: () => _navigateTo('Agent Workspace'),
          ),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.check_circle,
              size: 16,
              color: AppColors.green,
            ),
            title: const Text(
              'Verification completed',
              style: TextStyle(fontSize: 11),
            ),
            onTap: () => _navigateTo('Testing & Verification'),
          ),
        ],
      ),
    );
  }

  Widget _buildActivePage() {
    switch (_activePage) {
      case 'Home':
        return HomeScreen(
          onNavigate: _navigateTo,
          onOpenWizard: _openWizard,
          onOpenVoice: _openVoice,
          onNotify: _notify,
        );
      case 'AI Chat':
        return ChatScreen(
          onNavigate: _navigateTo,
          onOpenVoice: _openVoice,
          onOpenWizard: _openWizard,
          onNotify: _notify,
        );
      case 'Projects':
        return ProjectsScreen(
          onNavigate: _navigateTo,
          onOpenWizard: _openWizard,
          onNotify: _notify,
        );
      case 'Project Workspace':
        return ProjectWorkspaceScreen(
          onNavigate: _navigateTo,
          onNotify: _notify,
        );
      case 'Agent Workspace':
        return AgentWorkspaceScreen(
          onNavigate: _navigateTo,
          onNotify: _notify,
          onConfirm: _openConfirm,
        );
      case 'Code & Files':
        return CodeFilesScreen(
          onNavigate: _navigateTo,
          onNotify: _notify,
          onConfirm: _openConfirm,
        );
      case 'Testing & Verification':
        return TestingVerificationScreen(
          onNavigate: _navigateTo,
          onNotify: _notify,
        );
      case 'Activity & History':
        return ActivityHistoryScreen(
          onNavigate: _navigateTo,
          onNotify: _notify,
        );
      case 'Integrations':
        return IntegrationsScreen(onNotify: _notify, onConfirm: _openConfirm);
      case 'Settings':
        return SettingsScreen(onNotify: _notify, onNavigate: _navigateTo);
      default:
        return HomeScreen(
          onNavigate: _navigateTo,
          onOpenWizard: _openWizard,
          onOpenVoice: _openVoice,
          onNotify: _notify,
        );
    }
  }

  int _getMobileNavIndex() {
    if (_activePage == 'Home') return 0;
    if (_activePage == 'AI Chat') return 1;
    if (_activePage == 'Projects') return 2;
    if (_activePage == 'Agent Workspace') return 3;
    return 0;
  }
}
