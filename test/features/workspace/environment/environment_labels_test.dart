import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/features/workspace/widgets/environment/environment_labels.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';

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

  group('workspaceEnvEngineIcon', () {
    test('uses the package icon for alpine and ubuntu', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      expect(
        workspaceEnvEngineIcon(
          state: const EnvironmentState(distro: 'alpine'),
          status: const RuntimeStatus(
            ready: true,
            engine: 'ish',
            sandboxed: true,
          ),
        ),
        Lucide.Package,
      );
      expect(
        workspaceEnvEngineIcon(
          state: const EnvironmentState(distro: 'ubuntu'),
          status: const RuntimeStatus(
            ready: true,
            engine: 'proot',
            sandboxed: true,
          ),
        ),
        Lucide.Package,
      );
    });

    test('uses the terminal icon for desktop native shells', () {
      expect(
        workspaceEnvEngineIcon(
          state: const EnvironmentState(),
          desktopNative: true,
        ),
        Lucide.SquareTerminal,
      );
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
