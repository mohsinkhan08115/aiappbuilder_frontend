class LogEntry {
  final int id;
  final String projectId;
  final String logLevel; // INFO, WARNING, ERROR
  final String message;
  final DateTime createdAt;

  LogEntry({
    required this.id,
    required this.projectId,
    required this.logLevel,
    required this.message,
    required this.createdAt,
  });

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      id: json['id'] as int,
      projectId: json['project_id'] as String,
      logLevel: json['log_level'] as String,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'log_level': logLevel,
      'message': message,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
