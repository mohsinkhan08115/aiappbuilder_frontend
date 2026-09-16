import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'selected_file.dart';

Future<List<SelectedFile>> pickDirectory() async {
  final completer = Completer<List<SelectedFile>>();
  final input = html.FileUploadInputElement()
    ..multiple = true
    ..setAttribute('webkitdirectory', '')
    ..setAttribute('directory', '');

  input.onChange.listen((event) async {
    final files = input.files;
    if (files == null || files.isEmpty) {
      completer.complete([]);
      return;
    }

    final List<SelectedFile> selectedFiles = [];
    int readCount = 0;

    for (final file in files) {
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      reader.onLoadEnd.listen((loadEvent) {
        try {
          if (reader.result != null) {
            final buffer = reader.result as ByteBuffer;
            final bytes = Uint8List.view(buffer);
            final relativePath = (file as dynamic).webkitRelativePath as String? ?? file.name;
            selectedFiles.add(SelectedFile(
              name: file.name,
              relativePath: relativePath,
              bytes: bytes,
            ));
          }
        } catch (e) {
          // Ignore files that fail to read
        }

        readCount++;
        if (readCount == files.length) {
          completer.complete(selectedFiles);
        }
      });
      reader.onError.listen((error) {
        readCount++;
        if (readCount == files.length) {
          completer.complete(selectedFiles);
        }
      });
    }
  });

  input.click();
  return completer.future;
}
