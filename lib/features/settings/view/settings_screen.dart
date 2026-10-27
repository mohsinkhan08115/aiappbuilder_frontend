import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/localization/language_provider.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/components/status_pill.dart';
import '../../auth/viewmodel/auth_viewmodel.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/components/github_token_dialog.dart';

class SettingsScreen extends StatefulWidget {
  final void Function(String message) onNotify;
  final void Function(String route) onNavigate;

  const SettingsScreen({
    super.key,
    required this.onNotify,
    required this.onNavigate,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedCategory = 'Profile & account';
  bool _isLoggingOut = false;

  final List<String> _categories = [
    'Profile & account',
    'AI preferences',
    'Accessibility',
    'Privacy & security',
    'Connected integrations',
  ];

  Future<void> _confirmAndLogout(BuildContext context, AuthViewModel authVm) async {
    if (_isLoggingOut) return;

    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.logout, color: AppColors.red, size: 20),
              SizedBox(width: 8),
              Text('Log Out', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Are you sure you want to log out of your account?',
            style: TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isLoggingOut = true);
    try {
      authVm.logout();
      widget.onNotify('Signed out safely.');
      navigator.pushNamedAndRemoveUntil(
        AppRoutes.auth,
        (route) => false,
      );
    } catch (_) {
      authVm.logout();
      navigator.pushNamedAndRemoveUntil(
        AppRoutes.auth,
        (route) => false,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final authVm = context.watch<AuthViewModel>();
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
                    'SETTINGS',
                    style: TextStyle(
                      color: AppColors.cyan,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Make it yours',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Appearance, language, accessibility, and supported preferences.',
                    style: TextStyle(
                      color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Settings Layout: Category nav (left) & Panels (right)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 750;
                  return isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 230, child: _buildCategoryNav(isDark)),
                            const SizedBox(width: 14),
                            Expanded(child: _buildPreferencePanel(themeProvider, authVm, isDark)),
                          ],
                        )
                      : Column(
                          children: [
                            _buildCategoryNav(isDark),
                            const SizedBox(height: 14),
                            _buildPreferencePanel(themeProvider, authVm, isDark),
                          ],
                        );
                },
              ),

              const SizedBox(height: 20),

              // Engineering Extension: Implementation Handoff & Session state
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
                            'ACCOUNT & IMPLEMENTATION HANDOFF',
                            style: TextStyle(
                              color: Color(0xFF9B91FF),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text('Authentication and product map', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          SizedBox(height: 2),
                          Text('Frontend state is mapped directly to verified backend contracts.', style: TextStyle(color: AppColors.darkMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // Grid of 4 handoff cards
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final cols = constraints.maxWidth > 750 ? 2 : 1;
                          return GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: cols,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: cols == 2 ? 1.85 : 2.2,
                            children: [
                              _buildHandoffCard(
                                title: 'Session state',
                                subtitle: authVm.isAuthenticated ? 'Authenticated' : 'Guest / Unauthenticated',
                                statusType: authVm.isAuthenticated ? StatusType.success : StatusType.neutral,
                                desc: authVm.isAuthenticated
                                    ? 'Signed in as ${authVm.currentUserEmail ?? "authenticated user"}. Session details are secured.'
                                    : 'Sign in to access private projects.',
                                buttonLabel: authVm.isAuthenticated ? 'Sign out' : 'Sign in',
                                onAction: () {
                                  if (authVm.isAuthenticated) {
                                    _confirmAndLogout(context, authVm);
                                  } else {
                                    Navigator.pushReplacementNamed(context, AppRoutes.auth);
                                  }
                                },
                                isDark: isDark,
                              ),
                              _buildHandoffCard(
                                title: 'Frontend platforms',
                                subtitle: 'Web + Desktop + Mobile',
                                statusType: StatusType.success,
                                desc: 'One unified Flutter product with responsive layouts across browser windows and app screens.',
                                buttonLabel: 'View responsive notes',
                                onAction: () => widget.onNotify('Responsive breakpoints: Wide (>1024px), Medium, Mobile (<768px).'),
                                isDark: isDark,
                              ),
                              _buildHandoffCard(
                                title: 'Navigation inventory',
                                subtitle: '10 Core Destinations',
                                statusType: StatusType.success,
                                desc: 'Home, Chat, Projects, Workspace, Agents, Code, Verification, History, Integrations, and Settings.',
                                buttonLabel: 'Open navigation map',
                                onAction: () => widget.onNavigate('Home'),
                                isDark: isDark,
                              ),
                              _buildHandoffCard(
                                title: 'Backend contracts',
                                subtitle: 'FastAPI Verified',
                                statusType: StatusType.success,
                                desc: 'Connected to FastAPI backend on localhost:8000 via Dio interceptor with JWT tokens.',
                                buttonLabel: 'Open checklist',
                                onAction: () => widget.onNotify('All API contracts verified against backend routers.'),
                                isDark: isDark,
                              ),
                            ],
                          );
                        },
                      ),
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

  Widget _buildCategoryNav(bool isDark) {
    return Column(
      children: _categories.map((cat) {
        final selected = _selectedCategory == cat;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6.0),
          child: InkWell(
            onTap: () {
              setState(() => _selectedCategory = cat);
              widget.onNotify('$cat opened.');
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected
                      ? AppColors.primary
                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                        color: selected ? (isDark ? AppColors.darkText : AppColors.lightText) : AppColors.darkMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, size: 14, color: AppColors.darkMuted2),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPreferencePanel(ThemeProvider themeProvider, AuthViewModel authVm, bool isDark) {
    final email = authVm.currentUserEmail;
    final isAuth = authVm.isAuthenticated;
    final initials = (email != null && email.isNotEmpty)
        ? email.substring(0, email.length >= 2 ? 2 : 1).toUpperCase()
        : (isAuth ? 'US' : 'GU');

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile & Account Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B65DB), Color(0xFF3A6BD6)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            email ?? (isAuth ? 'Authenticated Developer' : 'Guest Developer'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isAuth
                                ? 'Signed in with active JWT session'
                                : 'Not signed in · Local demonstration mode',
                            style: TextStyle(
                              color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusPill(
                      label: isAuth ? 'Active' : 'Guest',
                      type: isAuth ? StatusType.success : StatusType.neutral,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isAuth ? 'Account: $email' : 'No backend session attached.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkMuted : AppColors.lightMuted,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isLoggingOut
                          ? null
                          : () {
                              if (isAuth) {
                                _confirmAndLogout(context, authVm);
                              } else {
                                Navigator.pushReplacementNamed(context, AppRoutes.auth);
                              }
                            },
                      icon: Icon(isAuth ? Icons.logout : Icons.login, size: 13),
                      label: Text(isAuth ? 'Sign out' : 'Sign in'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 30),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        textStyle: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // GitHub Personal Access Token Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface3 : AppColors.lightSurface3,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.vpn_key, size: 20, color: Color(0xFF9B91FF)),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GitHub Personal Access Token (PAT)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Configure credentials for repository synchronization and Git pushes.',
                        style: TextStyle(color: AppColors.darkMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => GitHubTokenDialog(
                        onSuccess: (username) {
                          widget.onNotify(username != null
                              ? 'GitHub token verified for "$username" and saved!'
                              : 'GitHub token saved successfully!');
                        },
                      ),
                    );
                  },
                  icon: const Icon(Icons.settings, size: 14),
                  label: const Text('Configure PAT'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 20),

          const Text('Appearance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 2),
          Text(
            'Choose how AI App Builder looks across this device.',
            style: TextStyle(color: isDark ? AppColors.darkMuted : AppColors.lightMuted, fontSize: 11),
          ),
          const SizedBox(height: 16),

          // Theme Preview Options (Dark, Light, System)
          Row(
            children: [
              Expanded(
                child: _buildThemePreviewCard(
                  label: 'Dark',
                  selected: themeProvider.themeMode == ThemeMode.dark,
                  gradient: const LinearGradient(colors: [Color(0xFF090E19), Color(0xFF121A29)]),
                  onTap: () => themeProvider.setThemeMode(ThemeMode.dark),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildThemePreviewCard(
                  label: 'Light',
                  selected: themeProvider.themeMode == ThemeMode.light,
                  gradient: const LinearGradient(colors: [Color(0xFFE9EDF4), Color(0xFFFFFFFF)]),
                  onTap: () => themeProvider.setThemeMode(ThemeMode.light),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildThemePreviewCard(
                  label: 'System',
                  selected: themeProvider.themeMode == ThemeMode.system,
                  gradient: const LinearGradient(colors: [Color(0xFF0B111D), Color(0xFFFFFFFF)]),
                  onTap: () => themeProvider.setThemeMode(ThemeMode.system),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 20),

          const Text('Language & region', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 2),
          Text(
            'Urdu uses a mirrored right-to-left prototype layout.',
            style: TextStyle(color: isDark ? AppColors.darkMuted : AppColors.lightMuted, fontSize: 11),
          ),
          const SizedBox(height: 14),

          Consumer<LanguageProvider>(
            builder: (context, langProvider, _) {
              final languages = [
                {'name': 'English', 'code': 'en'},
                {'name': 'اردو (Urdu)', 'code': 'ur'},
              ];

              return Column(
                children: languages.map((lang) {
                  final isSelected = langProvider.currentLanguage == lang['code'];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () {
                        langProvider.setLanguage(lang['code']!);
                        widget.onNotify('${lang['name']} interface selected.');
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(lang['name']!, style: const TextStyle(fontSize: 12)),
                            if (isSelected)
                              const Icon(Icons.check, size: 16, color: AppColors.primaryBright),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildThemePreviewCard({
    required String label,
    required bool selected,
    required LinearGradient gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.darkBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 55,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: gradient,
                border: Border.all(color: AppColors.darkBorder),
              ),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildHandoffCard({
    required String title,
    required String subtitle,
    required StatusType statusType,
    required String desc,
    required String buttonLabel,
    required VoidCallback onAction,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              StatusPill(label: subtitle, type: statusType, fontSize: 10),
            ],
          ),
          Text(desc, style: TextStyle(color: isDark ? AppColors.darkMuted : AppColors.lightMuted, fontSize: 10, height: 1.4)),
          OutlinedButton(
            onPressed: onAction,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: const TextStyle(fontSize: 10),
            ),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}
