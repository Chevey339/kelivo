import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/environment_state.dart';

void main() {
  group('EnvironmentState', () {
    test('JSON round trip', () {
      final state = EnvironmentState(
        phase: EnvironmentPhase.extracting,
        distro: 'ubuntu',
        version: '24.04',
        arch: 'arm64',
        installedAt: DateTime.utc(2026, 9, 2),
        errorMessage: 'disk full',
        progress: 0.42,
      );
      final decoded = EnvironmentState.fromJson(state.toJson());
      expect(decoded.phase, EnvironmentPhase.extracting);
      expect(decoded.distro, 'ubuntu');
      expect(decoded.version, '24.04');
      expect(decoded.arch, 'arm64');
      expect(decoded.installedAt, DateTime.utc(2026, 9, 2));
      expect(decoded.errorMessage, 'disk full');
      expect(decoded.progress, 0.42);
    });

    test('extended fields JSON round trip', () {
      final state = EnvironmentState(
        phase: EnvironmentPhase.downloading,
        availableVersion: '24.04.3',
        bytesDownloaded: 12,
        bytesTotal: 48,
        lastMirrorBase:
            'https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release',
        rootfsDir: '/tmp/environment/rootfs',
      );
      final decoded = EnvironmentState.fromJson(state.toJson());
      expect(decoded.availableVersion, '24.04.3');
      expect(decoded.bytesDownloaded, 12);
      expect(decoded.bytesTotal, 48);
      expect(
        decoded.lastMirrorBase,
        'https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release',
      );
      expect(decoded.rootfsDir, '/tmp/environment/rootfs');
    });

    test('defaults to notInstalled', () {
      const state = EnvironmentState();
      expect(state.phase, EnvironmentPhase.notInstalled);
      expect(EnvironmentState.fromJson(state.toJson()).phase, state.phase);
    });
  });

  group('MirrorSelection', () {
    test('JSON round trip', () {
      const selection = MirrorSelection(
        selectedBaseUrl: 'https://mirrors.example/apt',
        useMirror: true,
        mirrorId: 'apt.tuna',
        displayName: 'Tsinghua TUNA',
        manual: true,
      );
      final decoded = MirrorSelection.fromJson(selection.toJson());
      expect(decoded.selectedBaseUrl, selection.selectedBaseUrl);
      expect(decoded.useMirror, isTrue);
      expect(decoded.mirrorId, 'apt.tuna');
      expect(decoded.displayName, 'Tsinghua TUNA');
      expect(decoded.manual, isTrue);
      expect(decoded.hasManualPick, isTrue);
    });

    test('category names round trip', () {
      for (final category in MirrorCategory.values) {
        expect(MirrorSelection.categoryFromString(category.name), category);
      }
    });
  });
}
