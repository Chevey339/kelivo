import 'dart:async';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Holds an actual file read so tests can navigate while import is copying.
class GatedXFile extends XFile {
  GatedXFile(super.path);

  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Stream<Uint8List> openRead([int? start, int? end]) async* {
    if (!started.isCompleted) started.complete();
    await release.future;
    yield* super.openRead(start, end);
  }
}
