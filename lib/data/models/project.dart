class Project {
  final String id;
  final String name;
  final String? description;
  String status; // created, generating, running_analyzer, fixing_errors, running_tests, building, completed, failed
  final String? failedStatus;
  final String workspacePath;
  final String projectType;
  final DateTime createdAt;
  final DateTime updatedAt;

  Project({
    required this.id,
    required this.name,
    this.description,
    required this.status,
    this.failedStatus,
    required this.workspacePath,
    required this.projectType,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      status: (json['status'] as String?) ?? 'created',
      failedStatus: json['failed_status'] as String?,
      workspacePath: json['workspace_path'] as String,
      projectType: (json['project_type'] as String?) ?? 'new',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'status': status,
      'failed_status': failedStatus,
      'workspace_path': workspacePath,
      'project_type': projectType,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get statusDisplay {
    switch (status) {
      case 'created':
        return 'Ready';
      case 'creating_project':
        return 'Creating Flutter Project';
      case 'generating':
        return 'Generating Files';
      case 'installing_dependencies':
        return 'Installing Dependencies';
      case 'running_analyzer':
        return 'Running Static Analysis';
      case 'fixing_errors':
        return 'Auto-Fixing Compile Issues';
      case 'running_tests':
        return 'Running Unit Tests';
      case 'building':
        return 'Building Application APK';
      case 'completed':
        return 'Completed';
      case 'failed':
        return 'Failed';
      default:
        return status;
    }
  }

  bool get isActive {
    return status != 'completed' && status != 'failed' && status != 'created';
  }
}
