class GitHubRepo {
  final String id;
  final String projectId;
  final String repoName;
  final String repoUrl;
  final String syncStatus;
  final DateTime createdAt;

  GitHubRepo({
    required this.id,
    required this.projectId,
    required this.repoName,
    required this.repoUrl,
    required this.syncStatus,
    required this.createdAt,
  });

  factory GitHubRepo.fromJson(Map<String, dynamic> json) {
    return GitHubRepo(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      repoName: json['repo_name'] as String,
      repoUrl: json['repo_url'] as String,
      syncStatus: json['sync_status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'repo_name': repoName,
      'repo_url': repoUrl,
      'sync_status': syncStatus,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
