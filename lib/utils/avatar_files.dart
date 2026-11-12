import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'app_directories.dart';
import 'sandbox_path_resolver.dart';

/// Imports a selected image only when its owning editor is saved.
/// Files already in managed storage may be shared by copied configurations.
Future<String> importAvatarFile(String path) async {
  final source = File(SandboxPathResolver.fix(path));
  final directory = await AppDirectories.getAvatarsDirectory();
  if (p.isWithin(directory.path, source.path)) return source.path;
  await directory.create(recursive: true);
  final destination = p.join(
    directory.path,
    'model_${const Uuid().v4()}${p.extension(source.path).toLowerCase()}',
  );
  await source.copy(destination);
  return destination;
}
