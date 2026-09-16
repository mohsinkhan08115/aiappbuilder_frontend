class ProjectFile {
  final String path;
  final String name;
  final bool isDir;
  final int size;

  ProjectFile({
    required this.path,
    required this.name,
    required this.isDir,
    required this.size,
  });

  factory ProjectFile.fromJson(Map<String, dynamic> json) {
    return ProjectFile(
      path: json['path'] as String,
      name: json['name'] as String,
      isDir: json['is_dir'] as bool,
      size: json['size'] as int,
    );
  }
}
