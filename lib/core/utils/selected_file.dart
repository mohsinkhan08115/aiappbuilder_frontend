class SelectedFile {
  final String name;
  final String relativePath;
  final List<int> bytes;

  SelectedFile({
    required this.name,
    required this.relativePath,
    required this.bytes,
  });
}
