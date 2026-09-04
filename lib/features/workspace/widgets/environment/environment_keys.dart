import 'package:flutter/foundation.dart';

import 'package:Kelivo/core/models/environment_state.dart';

abstract final class EnvironmentPaneKeys {
  static const install = ValueKey<String>('workspace-env-install');
  static const cancel = ValueKey<String>('workspace-env-cancel');
  static const retry = ValueKey<String>('workspace-env-retry');
  static const repair = ValueKey<String>('workspace-env-repair');
  static const reset = ValueKey<String>('workspace-env-reset');
  static const checkUpdate = ValueKey<String>('workspace-env-check-update');
  static const update = ValueKey<String>('workspace-env-update');
  static const downloadProgress = ValueKey<String>(
    'workspace-env-download-progress',
  );
  static const detectingMirrors = ValueKey<String>(
    'workspace-env-detecting-mirrors',
  );
  static const restartBanner = ValueKey<String>('workspace-env-restart');
  static const nativeExplanation = ValueKey<String>(
    'workspace-env-native-explanation',
  );
  static const mirrorsSection = ValueKey<String>('workspace-env-mirrors');
  static const browse = ValueKey<String>('workspace-env-browse');
  static const detectAll = ValueKey<String>('workspace-env-detect-all');
  static const sizeRow = ValueKey<String>('workspace-env-size');
  static const pathRow = ValueKey<String>('workspace-env-path');
  static const sizeTimeout = ValueKey<String>('workspace-env-size-timeout');
  static const infoCopy = ValueKey<String>('workspace-env-info-copy');

  static Key detect(MirrorCategory category) =>
      ValueKey<String>('workspace-env-detect-${category.name}');

  static Key useMirror(MirrorCategory category) =>
      ValueKey<String>('workspace-env-use-mirror-${category.name}');
}
