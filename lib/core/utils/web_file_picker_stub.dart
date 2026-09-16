import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'selected_file.dart';

Future<List<SelectedFile>> pickDirectory() async {
  final String? directoryPath = await FilePicker.platform.getDirectoryPath();
  if (directoryPath == null) {
    return [];
  }
  
  final dir = Directory(directoryPath);
  if (!await dir.exists()) {
    return [];
  }
  
  final List<SelectedFile> selectedFiles = [];
  var dirName = dir.path.split(Platform.pathSeparator).last;
  if (dirName.isEmpty) {
    final parts = dir.path.split(Platform.pathSeparator).where((s) => s.isNotEmpty).toList();
    if (parts.isNotEmpty) {
      dirName = parts.last;
    } else {
      dirName = 'project';
    }
  }
  
  try {
    final stream = dir.list(recursive: true, followLinks: false);
    await for (final entity in stream) {
      if (entity is File) {
        final file = entity;
        final relativePath = file.path.substring(dir.path.length);
        final cleanRelativePath = '$dirName${relativePath.replaceAll(Platform.pathSeparator, '/')}';
        try {
          final bytes = await file.readAsBytes();
          selectedFiles.add(SelectedFile(
            name: file.path.split(Platform.pathSeparator).last,
            relativePath: cleanRelativePath,
            bytes: bytes,
          ));
        } catch (e) {
          // Ignore files that fail to read
        }
      }
    }
  } catch (e) {
    // Ignore folder enumeration errors
  }
  
  return selectedFiles;
}
