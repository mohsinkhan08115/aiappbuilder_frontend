import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'dart:io' as io;
import '../../auth/viewmodel/auth_viewmodel.dart';
import '../viewmodel/project_viewmodel.dart';
import '../../../app/routes/app_routes.dart';
import '../../../data/models/project.dart';
import '../../../core/utils/selected_file.dart';
import '../../../core/utils/web_file_picker.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Load projects on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProjectViewModel>().fetchProjects();
    });
  }

  void _showCreateProjectDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return CreateProjectDialog(parentContext: context);
      },
    );
  }

  void _showGithubTokenDialog() {
    final tokenController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.vpn_key),
              SizedBox(width: 8),
              Text('GitHub Token Config'),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter your GitHub Personal Access Token (PAT). This is required to push generated applications to GitHub repositories.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: tokenController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'GitHub PAT Token',
                    hintText: 'ghp_...',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a token';
                    }
                    if (!value.trim().startsWith('ghp_') &&
                        !value.trim().startsWith('github_pat_')) {
                      return 'Token should start with ghp_ or github_pat_';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final token = tokenController.text.trim();
                Navigator.pop(dialogContext);

                if (!mounted) return;
                final vm = Provider.of<ProjectViewModel>(
                  context,
                  listen: false,
                );
                await vm.updateGitHubToken(token);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        vm.error != null
                            ? 'Failed to save token: ${vm.error}'
                            : 'GitHub Token saved successfully!',
                      ),
                      backgroundColor: vm.error != null
                          ? Colors.red
                          : Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _signOut() {
    context.read<AuthViewModel>().logout();
    Navigator.pushReplacementNamed(context, AppRoutes.auth);
  }

  @override
  Widget build(BuildContext context) {
    final projectVm = context.watch<ProjectViewModel>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Icon(
              Icons.auto_awesome,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            const Text(
              'App Builder Workspace',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'GitHub Token Config',
            onPressed: _showGithubTokenDialog,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh list',
            onPressed: () => projectVm.fetchProjects(),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: _signOut,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: projectVm.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => projectVm.fetchProjects(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const Text(
                      'Your Projects',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select a project to initiate generation, monitor build status, or browse logs.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: projectVm.projects.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.layers_clear_outlined,
                                    size: 64,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No projects created yet',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Get started by creating your first Flutter app project configuration.',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: _showCreateProjectDialog,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Create New Project'),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: projectVm.projects.length,
                              itemBuilder: (context, index) {
                                final project = projectVm.projects[index];
                                return _buildProjectCard(project);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: projectVm.projects.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _showCreateProjectDialog,
              icon: const Icon(Icons.add),
              label: const Text('New Project'),
            ),
    );
  }

  Widget _buildProjectCard(Project project) {
    Color statusColor;
    IconData statusIcon;

    switch (project.status) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'failed':
        statusColor = Colors.red;
        statusIcon = Icons.error_outline;
        break;
      case 'created':
        statusColor = Colors.blue;
        statusIcon = Icons.info_outline;
        break;
      default:
        statusColor = Colors.amber;
        statusIcon = Icons.sync;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        onTap: () async {
          final vm = Provider.of<ProjectViewModel>(context, listen: false);
          await vm.selectProject(project.id);
          if (mounted) {
            await Navigator.pushNamed(context, AppRoutes.projectDetails);
            if (mounted) {
              vm.fetchProjects();
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      project.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (project.isActive)
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.amber,
                              ),
                            ),
                          )
                        else
                          Icon(statusIcon, color: statusColor, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          project.statusDisplay,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (project.description != null) ...[
                Text(
                  project.description!,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Workspace ID: ${project.id.substring(0, 8)}...',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  Row(
                    children: [
                      Text(
                        _formatDate(project.createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                        onPressed: () => _confirmDelete(project),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(Project project) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text(
          'Are you sure you want to delete ${project.name} and clean up its workspace directory?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ProjectViewModel>().deleteProject(project.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class CreateProjectDialog extends StatefulWidget {
  final BuildContext parentContext;

  const CreateProjectDialog({super.key, required this.parentContext});

  @override
  State<CreateProjectDialog> createState() => _CreateProjectDialogState();
}

enum _CreateFlow { main, createNew, importFolder, importZip, uploadProgress }

enum ImportProgressState {
  uploading,
  processing,
  extracting,
  detecting,
  importing,
  success,
  error,
}

class _CreateProjectDialogState extends State<CreateProjectDialog> {
  _CreateFlow _currentFlow = _CreateFlow.main;
  ImportProgressState _importProgressState = ImportProgressState.uploading;
  _CreateFlow _lastImportFlow = _CreateFlow.main;

  // Forms & inputs
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  // Picking states
  bool _isValidating = false;
  bool _isUploading = false;
  String? _selectedFileName;
  String? _validationError;
  double _uploadProgress = 0.0;

  // Data loaded in memory
  List<SelectedFile> _pickedFolderFiles = [];
  PlatformFile? _pickedZipFile;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  String _sanitizeProjectName(String original) {
    String sanitized = original
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (sanitized.isNotEmpty && RegExp(r'^[0-9]').hasMatch(sanitized)) {
      sanitized = 'project_$sanitized';
    }
    if (sanitized.isEmpty) {
      sanitized = 'my_project';
    }
    return sanitized;
  }

  // Action: Pick ZIP file
  Future<void> _pickZipFile() async {
    setState(() {
      _validationError = null;
      _pickedZipFile = null;
      _selectedFileName = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (!file.name.toLowerCase().endsWith('.zip')) {
          setState(() {
            _currentFlow = _CreateFlow.uploadProgress;
            _importProgressState = ImportProgressState.error;
            _validationError = 'Please select a valid .zip archive file.';
          });
          return;
        }
        List<int>? bytes = file.bytes;
        if (bytes == null && file.path != null) {
          try {
            bytes = io.File(file.path!).readAsBytesSync();
          } catch (e) {
            setState(() {
              _currentFlow = _CreateFlow.uploadProgress;
              _importProgressState = ImportProgressState.error;
              _validationError = 'Failed to read ZIP file from disk: $e';
            });
            return;
          }
        }
        if (bytes == null) {
          setState(() {
            _currentFlow = _CreateFlow.uploadProgress;
            _importProgressState = ImportProgressState.error;
            _validationError = 'Failed to read selected ZIP file data.';
          });
          return;
        }
        _lastImportFlow = _CreateFlow.importZip;
        _pickedZipFile = file;
        _selectedFileName = file.name;

        // Start import immediately without prompting for name/description!
        _startImport(bytes, file.name);
      } else {
        setState(() {
          _currentFlow = _CreateFlow.main;
        });
      }
    } catch (e) {
      setState(() {
        _currentFlow = _CreateFlow.uploadProgress;
        _importProgressState = ImportProgressState.error;
        _validationError = 'Error picking file: $e';
      });
    }
  }

  // Action: Pick Directory (Folder)
  Future<void> _pickDirectoryFlow() async {
    setState(() {
      _isValidating = true;
      _validationError = null;
      _pickedFolderFiles = [];
      _selectedFileName = null;
    });
    try {
      final files = await pickDirectory();
      if (files.isEmpty) {
        setState(() {
          _isValidating = false;
          _currentFlow = _CreateFlow.main;
        });
        return;
      }

      // Validate project structure
      bool hasPubspec = false;
      bool hasLib = false;
      String? detectedRootFolder;

      for (final file in files) {
        final path = file.relativePath.replaceAll('\\', '/');
        final parts = path.split('/');

        if (parts.last == 'pubspec.yaml') {
          hasPubspec = true;
          // Determine root folder name
          if (parts.length > 1) {
            detectedRootFolder = parts[parts.length - 2];
          }
        }
        if (parts.contains('lib')) {
          hasLib = true;
        }
      }

      if (!hasPubspec || !hasLib) {
        setState(() {
          _currentFlow = _CreateFlow.uploadProgress;
          _importProgressState = ImportProgressState.error;
          _validationError =
              'Invalid Flutter project structure. The selected folder must contain a "pubspec.yaml" and a "lib/" directory.';
          _isValidating = false;
        });
        return;
      }

      setState(() {
        _pickedFolderFiles = files;
        final rootName = detectedRootFolder ?? 'imported_project';
        _selectedFileName = rootName;
        _isValidating = false;
        _lastImportFlow = _CreateFlow.importFolder;
      });

      // Start direct folder upload
      _startFolderUpload();
    } catch (e) {
      setState(() {
        _currentFlow = _CreateFlow.uploadProgress;
        _importProgressState = ImportProgressState.error;
        _validationError = 'Error reading directory: $e';
        _isValidating = false;
      });
    }
  }

  // Start import process
  Future<void> _startImport(List<int> bytes, String filename) async {
    setState(() {
      _currentFlow = _CreateFlow.uploadProgress;
      _importProgressState = ImportProgressState.uploading;
      _uploadProgress = 0.0;
      _validationError = null;
    });

    final vm = Provider.of<ProjectViewModel>(
      widget.parentContext,
      listen: false,
    );
    bool requestDone = false;

    Future<void> runProgressStates() async {
      final steps = [
        ImportProgressState.processing,
        ImportProgressState.extracting,
        ImportProgressState.detecting,
        ImportProgressState.importing,
      ];
      for (final step in steps) {
        if (requestDone) break;
        await Future.delayed(const Duration(milliseconds: 700));
        if (requestDone) break;
        setState(() {
          _importProgressState = step;
        });
      }
    }

    try {
      runProgressStates();

      await vm.uploadAndImportProject(bytes, filename);

      requestDone = true;

      setState(() {
        _importProgressState = ImportProgressState.success;
      });

      await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted) {
        Navigator.pop(context); // Close dialog
      }
      if (widget.parentContext.mounted) {
        Navigator.pushNamed(
          widget.parentContext,
          AppRoutes.projectDetails,
        );
      }
    } catch (e) {
      requestDone = true;
      setState(() {
        _importProgressState = ImportProgressState.error;
        _validationError = e.toString();
      });
    }
  }

  // Start direct folder upload (without zipping)
  Future<void> _startFolderUpload() async {
    setState(() {
      _currentFlow = _CreateFlow.uploadProgress;
      _importProgressState = ImportProgressState.uploading;
      _uploadProgress = 0.0;
      _validationError = null;
    });

    final vm = Provider.of<ProjectViewModel>(
      widget.parentContext,
      listen: false,
    );
    bool requestDone = false;

    Future<void> runProgressStates() async {
      final steps = [
        ImportProgressState.processing,
        ImportProgressState.detecting,
        ImportProgressState.importing,
      ];
      for (final step in steps) {
        if (requestDone) break;
        await Future.delayed(const Duration(milliseconds: 700));
        if (requestDone) break;
        setState(() {
          _importProgressState = step;
        });
      }
    }

    try {
      runProgressStates();

      // Filter out build/temp files before upload
      final filteredFiles = _pickedFolderFiles.where((f) {
        final path = f.relativePath.replaceAll('\\', '/');
        final parts = path.split('/');
        // Remove the root folder prefix if present
        if (parts.contains('build') ||
            parts.contains('.dart_tool') ||
            parts.contains('.git') ||
            parts.contains('.vscode') ||
            parts.contains('.idea') ||
            parts.contains('__MACOSX')) {
          return false;
        }
        final basename = parts.last;
        if (basename == '.DS_Store' || basename == 'Thumbs.db') {
          return false;
        }
        return true;
      }).toList();

      // Strip the root folder prefix from relative paths
      String prefix = '';
      for (final file in filteredFiles) {
        final path = file.relativePath.replaceAll('\\', '/');
        if (path.endsWith('pubspec.yaml')) {
          final index = path.lastIndexOf('pubspec.yaml');
          prefix = path.substring(0, index);
          break;
        }
      }

      final normalizedFiles = filteredFiles.map((f) {
        String archivePath = f.relativePath.replaceAll('\\', '/');
        if (prefix.isNotEmpty && archivePath.startsWith(prefix)) {
          archivePath = archivePath.substring(prefix.length);
        }
        while (archivePath.startsWith('/')) {
          archivePath = archivePath.substring(1);
        }
        return SelectedFile(
          name: f.name,
          relativePath: archivePath,
          bytes: f.bytes,
        );
      }).toList();

      await vm.uploadFolder(
        _selectedFileName ?? 'imported_project',
        normalizedFiles,
      );

      requestDone = true;

      setState(() {
        _importProgressState = ImportProgressState.success;
      });

      await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted) {
        Navigator.pop(context);
      }
      if (widget.parentContext.mounted) {
        Navigator.pushNamed(
          widget.parentContext,
          AppRoutes.projectDetails,
        );
      }
    } catch (e) {
      requestDone = true;
      setState(() {
        _importProgressState = ImportProgressState.error;
        _validationError = e.toString();
      });
    }
  }

  void _retryImport() {
    if (_lastImportFlow == _CreateFlow.importFolder) {
      _pickDirectoryFlow();
    } else if (_lastImportFlow == _CreateFlow.importZip) {
      _pickZipFile();
    } else {
      setState(() {
        _currentFlow = _CreateFlow.main;
      });
    }
  }

  // Action: Submit creation for NEW project flow
  Future<void> _submitFlow() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final desc = _descController.text.trim();
    final vm = Provider.of<ProjectViewModel>(
      widget.parentContext,
      listen: false,
    );

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _validationError = null;
    });

    try {
      // Create new project
      final newProj = await vm.createProject(
        name,
        desc.isEmpty ? null : desc,
        initializeFlutter: true,
      );
      if (newProj == null) {
        throw Exception(vm.error ?? 'Failed to create project configuration.');
      }

      // Open workspace automatically & close dialog
      await vm.selectProject(newProj.id);

      if (mounted) {
        Navigator.pop(context); // Close dialog
      }

      if (widget.parentContext.mounted) {
        Navigator.pushNamed(widget.parentContext, AppRoutes.projectDetails);
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _validationError = e.toString();
      });
    }
  }

  // Archive picked files into a standard zip in memory
  List<int> _createZipFromPickedFiles() {
    final archive = Archive();

    // Find the prefix to strip
    String prefix = '';
    for (final file in _pickedFolderFiles) {
      final path = file.relativePath.replaceAll('\\', '/');
      if (path.endsWith('pubspec.yaml')) {
        final index = path.lastIndexOf('pubspec.yaml');
        prefix = path.substring(0, index);
        break;
      }
    }

    for (final file in _pickedFolderFiles) {
      String archivePath = file.relativePath.replaceAll('\\', '/');
      if (prefix.isNotEmpty && archivePath.startsWith(prefix)) {
        archivePath = archivePath.substring(prefix.length);
      }
      
      while (archivePath.startsWith('/')) {
        archivePath = archivePath.substring(1);
      }

      // Filter out build files, temporary files, etc.
      final parts = archivePath.split('/');
      if (parts.contains('build') ||
          parts.contains('.dart_tool') ||
          parts.contains('.git') ||
          parts.contains('.vscode') ||
          parts.contains('.idea') ||
          parts.first.startsWith('.')) {
        continue;
      }

      archive.addFile(ArchiveFile(archivePath, file.bytes.length, file.bytes));
    }

    return ZipEncoder().encode(archive) ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final titleText = _currentFlow == _CreateFlow.main
        ? 'Create New Project'
        : _currentFlow == _CreateFlow.createNew
        ? 'Create New Flutter Project'
        : _currentFlow == _CreateFlow.uploadProgress
        ? 'Importing Project'
        : 'Import Existing Project';

    return Dialog(
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Row
            Row(
              children: [
                if (_currentFlow != _CreateFlow.main)
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed:
                        (_isUploading ||
                            _importProgressState ==
                                ImportProgressState.uploading ||
                            (_currentFlow == _CreateFlow.uploadProgress &&
                                _importProgressState !=
                                    ImportProgressState.error &&
                                _importProgressState !=
                                    ImportProgressState.success))
                        ? null
                        : () {
                            setState(() {
                              _currentFlow = _CreateFlow.main;
                              _validationError = null;
                              _selectedFileName = null;
                              _nameController.clear();
                              _descController.clear();
                            });
                          },
                  ),
                Expanded(
                  child: Text(
                    titleText,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed:
                      (_isUploading ||
                          (_currentFlow == _CreateFlow.uploadProgress &&
                              _importProgressState !=
                                  ImportProgressState.error &&
                              _importProgressState !=
                                  ImportProgressState.success))
                      ? null
                      : () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_validationError != null &&
                _currentFlow != _CreateFlow.uploadProgress) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color:
                      Colors.red[900]?.withOpacity(0.2) ??
                      Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[900] ?? Colors.red),
                ),
                child: Text(
                  _validationError!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),
            ],

            // Flow body
            Flexible(child: SingleChildScrollView(child: _buildFlowBody())),
          ],
        ),
      ),
    );
  }

  Widget _buildFlowBody() {
    switch (_currentFlow) {
      case _CreateFlow.main:
        return _buildMainSelector();
      case _CreateFlow.createNew:
        return _buildInputForm();
      case _CreateFlow.uploadProgress:
        return _buildProgressView();
      default:
        return _buildMainSelector();
    }
  }

  Widget _buildMainSelector() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRow = constraints.maxWidth > 450;
        final children = [
          _buildSelectionCard(
            title: 'Create New Flutter Project',
            subtitle: 'Start a project from an AI prompt',
            buttonLabel: 'Create Project',
            icon: Icons.auto_awesome,
            onPressed: () {
              setState(() {
                _currentFlow = _CreateFlow.createNew;
              });
            },
          ),
          _buildSelectionCard(
            title: 'Import Existing Project',
            subtitle: 'Upload a .zip containing an existing Flutter project',
            buttonLabel: 'Import Project',
            icon: Icons.folder_zip_outlined,
            onPressed: () {
              _pickZipFile();
            },
          ),
          _buildSelectionCard(
            title: 'Import Existing Project (Folder)',
            subtitle: 'Select a folder containing a Flutter project',
            buttonLabel: 'Import Folder',
            icon: Icons.folder_open,
            onPressed: () {
              _pickDirectoryFlow();
            },
          ),
        ];

        return useRow
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children
                    .map(
                      (c) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: c,
                        ),
                      ),
                    )
                    .toList(),
              )
            : Column(
                children: children
                    .map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: c,
                      ),
                    )
                    .toList(),
              );
      },
    );
  }

  Widget _buildSelectionCard({
    required String title,
    required String subtitle,
    required String buttonLabel,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputForm() {
    final submitButtonText = _isUploading ? 'Creating...' : 'Create Project';

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nameController,
            enabled: !_isUploading,
            decoration: const InputDecoration(
              labelText: 'App Name (identifier, e.g. todo_app)',
              hintText: 'Must be lowercase alphanumeric/underscore',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter an application name';
              }
              if (!RegExp(r'^[a-z_][a-z0-9_]*$').hasMatch(value)) {
                return 'Must be lowercase snake_case identifier';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descController,
            enabled: !_isUploading,
            decoration: const InputDecoration(
              labelText: 'Description (Optional)',
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isUploading ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isUploading ? null : _submitFlow,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(120, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(submitButtonText),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressView() {
    final vm = Provider.of<ProjectViewModel>(widget.parentContext);
    final progress = vm.importProgress ?? _uploadProgress;
    final percent = (progress * 100).toInt();

    String title = '';
    Widget statusIcon = const CircularProgressIndicator();
    List<Widget> stepsList = [];

    Widget buildStepLine(String text, bool isDone, bool isActive) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          children: [
            if (isDone)
              const Icon(
                Icons.check_circle,
                color: Colors.greenAccent,
                size: 16,
              )
            else if (isActive)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                ),
              )
            else
              const Icon(Icons.circle_outlined, color: Colors.grey, size: 16),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                color: isDone
                    ? Colors.white70
                    : (isActive ? Colors.white : Colors.grey),
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    switch (_importProgressState) {
      case ImportProgressState.uploading:
        title = 'Uploading project...';
        statusIcon = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Uploading files...',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  '$percent%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.greenAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress),
          ],
        );
        stepsList = [
          buildStepLine('Uploading project files', false, true),
          buildStepLine('Processing package files', false, false),
          buildStepLine('Extracting structure', false, false),
          buildStepLine('Detecting Flutter configuration', false, false),
          buildStepLine('Importing project', false, false),
        ];
        break;

      case ImportProgressState.processing:
        title = 'Processing project...';
        stepsList = [
          buildStepLine('Uploading project files', true, false),
          buildStepLine('Processing package files', false, true),
          buildStepLine('Extracting structure', false, false),
          buildStepLine('Detecting Flutter configuration', false, false),
          buildStepLine('Importing project', false, false),
        ];
        break;

      case ImportProgressState.extracting:
        title = 'Extracting project...';
        stepsList = [
          buildStepLine('Uploading project files', true, false),
          buildStepLine('Processing package files', true, false),
          buildStepLine('Extracting structure', false, true),
          buildStepLine('Detecting Flutter configuration', false, false),
          buildStepLine('Importing project', false, false),
        ];
        break;

      case ImportProgressState.detecting:
        title = 'Detecting Flutter project...';
        stepsList = [
          buildStepLine('Uploading project files', true, false),
          buildStepLine('Processing package files', true, false),
          buildStepLine('Extracting structure', true, false),
          buildStepLine('Detecting Flutter configuration', false, true),
          buildStepLine('Importing project', false, false),
        ];
        break;

      case ImportProgressState.importing:
        title = 'Importing project files...';
        stepsList = [
          buildStepLine('Uploading project files', true, false),
          buildStepLine('Processing package files', true, false),
          buildStepLine('Extracting structure', true, false),
          buildStepLine('Detecting Flutter configuration', true, false),
          buildStepLine('Importing project', false, true),
        ];
        break;

      case ImportProgressState.success:
        title = 'Import completed';
        statusIcon = const Icon(
          Icons.check_circle,
          color: Colors.greenAccent,
          size: 48,
        );
        stepsList = [
          const Text(
            '✓ Project imported successfully',
            style: TextStyle(
              color: Colors.greenAccent,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '${vm.projectFiles.length} files detected',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                if (widget.parentContext.mounted) {
                  Navigator.pushNamed(
                    widget.parentContext,
                    AppRoutes.projectDetails,
                  );
                }
              },
              icon: const Icon(Icons.folder_open),
              label: const Text('Open Project'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(180, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ];
        break;

      case ImportProgressState.error:
        title = 'Import failed';
        statusIcon = const Icon(
          Icons.error_outline,
          color: Colors.redAccent,
          size: 48,
        );
        stepsList = [
          const Text(
            '✗ Import failed',
            style: TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[900]?.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.red[900]?.withOpacity(0.3) ?? Colors.red,
              ),
            ),
            child: Text(
              _validationError ?? 'Unknown error occurred during import.',
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _retryImport,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(120, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ];
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_importProgressState != ImportProgressState.success &&
              _importProgressState != ImportProgressState.error) ...[
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Center(child: statusIcon),
            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            const SizedBox(height: 12),
            ...stepsList,
          ] else ...[
            Center(child: statusIcon),
            const SizedBox(height: 16),
            ...stepsList,
          ],
        ],
      ),
    );
  }
}
