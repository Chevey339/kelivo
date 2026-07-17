import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

Future<File> createTemporaryRestoreFile(Directory directory) async {
  final file = File(
    p.join(directory.path, 'kelivo_restore_${const Uuid().v4()}.zip'),
  );
  await file.create(exclusive: true);
  return file;
}
