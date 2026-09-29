import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/services/native_file_save.dart';

/// Saves an existing file without loading its contents into Dart memory.
/// Returns the destination path on desktop, the suggested name on mobile,
/// or null when the picker is cancelled.
Future<String?> saveHostFileWithPicker({
  required File file,
  String? fileName,
  String? dialogTitle,
}) async {
  final name = fileName ?? p.basename(file.path);
  final platform = defaultTargetPlatform;
  if (platform == TargetPlatform.android || platform == TargetPlatform.iOS) {
    Directory? staging;
    try {
      var source = file;
      // iOS exports the source URL's name. Stage only when a different name
      // was requested; File.copy does not buffer the file in Dart memory.
      if (platform == TargetPlatform.iOS && name != p.basename(file.path)) {
        if (name.isEmpty ||
            name == '.' ||
            name == '..' ||
            name.contains('/') ||
            name.contains('\\')) {
          throw ArgumentError.value(name, 'fileName', 'Invalid file name');
        }
        staging = await Directory.systemTemp.createTemp('kelivo_file_export_');
        source = await file.copy(p.join(staging.path, name));
      }
      final saved = await NativeFileSave.saveFileFromPath(
        sourcePath: source.path,
        fileName: name,
      );
      return saved ? name : null;
    } finally {
      await staging?.delete(recursive: true);
    }
  }

  final ext = p.extension(name).replaceFirst('.', '');
  final custom = ext.isNotEmpty;
  final savePath = await FilePicker.platform.saveFile(
    dialogTitle: dialogTitle,
    fileName: name,
    type: custom ? FileType.custom : FileType.any,
    allowedExtensions: custom ? <String>[ext] : null,
  );
  if (savePath == null) return null;
  if (await File(savePath).exists() &&
      await FileSystemEntity.identical(file.path, savePath)) {
    return savePath;
  }
  await File(savePath).parent.create(recursive: true);
  await file.copy(savePath);
  return savePath;
}
