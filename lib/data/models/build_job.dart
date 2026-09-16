class BuildJob {
  final String id;
  final String projectId;
  final String targetPlatform;
  final String status;
  final String? artifactPath;
  final String? logPath;
  final DateTime createdAt;

  BuildJob({
    required this.id,
    required this.projectId,
    required this.targetPlatform,
    required this.status,
    this.artifactPath,
    this.logPath,
    required this.createdAt,
  });

  factory BuildJob.fromJson(Map<String, dynamic> json) {
    return BuildJob(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      targetPlatform: json['target_platform'] as String,
      status: json['status'] as String,
      artifactPath: json['artifact_path'] as String?,
      logPath: json['log_path'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'target_platform': targetPlatform,
      'status': status,
      'artifact_path': artifactPath,
      'log_path': logPath,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
