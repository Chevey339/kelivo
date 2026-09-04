import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/features/workspace/widgets/environment/environment_labels.dart';

void main() {
  group('formatDistroVersion', () {
    test('strips alpine package prefix and revision', () {
      expect(formatDistroVersion('alpine-3.21.3-r4'), '3.21.3');
    });

    test('keeps ubuntu-style dotted versions', () {
      expect(formatDistroVersion('24.04.3'), '24.04.3');
    });

    test('keeps a short alpine-style version', () {
      expect(formatDistroVersion('3.21'), '3.21');
    });

    test('strips a name prefix without a revision', () {
      expect(formatDistroVersion('alpine-3.21'), '3.21');
      expect(formatDistroVersion('ubuntu-24.04.3'), '24.04.3');
    });

    test('strips a bare revision suffix', () {
      expect(formatDistroVersion('3.21.3-r4'), '3.21.3');
    });

    test('empty and whitespace become empty', () {
      expect(formatDistroVersion(null), '');
      expect(formatDistroVersion(''), '');
      expect(formatDistroVersion('   '), '');
    });
  });

  group('workspaceEnvDisplayVersion', () {
    test('uses fallback when raw is empty', () {
      expect(workspaceEnvDisplayVersion(null, fallback: '3.21'), '3.21');
      expect(
        workspaceEnvDisplayVersion('alpine-3.21.3-r4', fallback: '3.21'),
        '3.21.3',
      );
    });
  });
}
