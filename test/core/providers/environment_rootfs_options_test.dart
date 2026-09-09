import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/services/sandbox/rootfs_source.dart';
import '../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'system selection and PRoot options persist independently of installed state',
    () async {
      final prefs = createBusinessTestPreferences();
      final env = EnvironmentProvider(preferences: prefs);
      await env.loaded;
      await env.setRootfsSelection(
        imageId: 'alpine-3.24.1',
        source: RootfsDownloadSource.tuna,
      );
      await env.setProotOptions(
        shell: '/bin/sh',
        arguments: '-k\n5.10.0\n-b\n/storage/My Notes:/notes\n',
      );
      final restored = EnvironmentProvider(preferences: prefs);
      await restored.loaded;
      expect(restored.rootfsImage.distro, 'alpine');
      expect(restored.downloadSource, RootfsDownloadSource.tuna);
      expect(restored.prootShell, '/bin/sh');
      expect(restored.prootArguments, [
        '-k',
        '5.10.0',
        '-b',
        '/storage/My Notes:/notes',
      ]);
      expect(restored.state.distro, isNull);
      await expectLater(
        restored.setRootfsSelection(
          imageId: 'debian-13',
          source: RootfsDownloadSource.tuna,
        ),
        throwsFormatException,
      );
      await expectLater(
        restored.setProotOptions(shell: 'relative/sh', arguments: ''),
        throwsFormatException,
      );
      expect(restored.rootfsImage.distro, 'alpine');
    },
  );
}
