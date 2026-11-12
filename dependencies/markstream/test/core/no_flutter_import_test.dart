import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('core imports and exports stay inside pure Dart core', () {
    final core = Directory('lib/src/core').absolute;
    final violations = <String>[];
    final directives = RegExp(r'''\b(?:import|export|part)\s+[^;]+;''');
    final uris = RegExp(r'''['"]([^'"]+)['"]''');
    final files = core
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .followedBy([File('lib/markstream_core.dart').absolute]);
    expect(files, isNotEmpty);
    for (final file in files) {
      for (final directive in directives.allMatches(file.readAsStringSync())) {
        for (final literal in uris.allMatches(directive.group(0)!)) {
          final value = literal.group(1)!;
          final uri = Uri.parse(value);
          final dartLibrary = uri.scheme == 'dart' && value != 'dart:ui';
          final localCore =
              !uri.hasScheme &&
              file.uri
                  .resolve(value)
                  .normalizePath()
                  .path
                  .startsWith(core.uri.path);
          if (!dartLibrary && !localCore) {
            violations.add('${file.path}: $value');
          }
        }
      }
    }
    expect(
      violations,
      isEmpty,
      reason: 'Core must not depend on Flutter, the rendering layer, or third-party packages.',
    );
  });
}
