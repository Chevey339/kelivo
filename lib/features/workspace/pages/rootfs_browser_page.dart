import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/services/haptics.dart';
import 'package:Kelivo/core/services/sandbox/rootfs_disk_usage.dart';
import 'package:Kelivo/features/workspace/widgets/environment/environment_labels.dart';
import 'package:Kelivo/features/workspace/widgets/files/file_browser.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/theme/app_font_weights.dart';

/// Host directory shown as guest `/`. iOS fakefs files live under `data/`.
Future<Directory> resolveRootfsBrowserDir({String? rootfsDir}) async {
  final usage = await resolveRootfsUsageDir(rootfsDir: rootfsDir);
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    return Directory(p.join(usage.path, 'data'));
  }
  return usage;
}

class RootfsBrowserPage extends StatefulWidget {
  const RootfsBrowserPage({super.key});

  @override
  State<RootfsBrowserPage> createState() => _RootfsBrowserPageState();
}

class _RootfsBrowserPageState extends State<RootfsBrowserPage> {
  final GlobalKey<FileBrowserState> _browserKey = GlobalKey<FileBrowserState>();
  Directory? _root;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_resolve());
  }

  Future<void> _resolve() async {
    try {
      final rootfsDir = context.read<EnvironmentProvider>().state.rootfsDir;
      final dir = await resolveRootfsBrowserDir(rootfsDir: rootfsDir);
      if (!mounted) return;
      setState(() {
        _root = dir;
        _error = null;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final root = _root;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        leading: Tooltip(
          message: l10n.settingsPageBackButton,
          child: IosIconButton(
            icon: Lucide.ArrowLeft,
            color: cs.onSurface,
            size: 22,
            minSize: 44,
            semanticLabel: l10n.settingsPageBackButton,
            onTap: () {
              Haptics.light();
              Navigator.of(context).maybePop();
            },
          ),
        ),
        title: Text(l10n.workspaceEnvRootfsTitle),
        actions: [
          if (_browserKey.currentState != null)
            ...fileBrowserToolbarActions(_browserKey.currentState!),
          const SizedBox(width: 12),
        ],
      ),
      body: _loading
          ? const Center(child: CupertinoActivityIndicator(radius: 12))
          : _error != null || root == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.workspaceEnvBrowserUnavailable,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: AppFontWeights.medium,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            )
          : FileBrowser(
              key: _browserKey,
              root: root,
              rootLabel: l10n.workspaceEnvRootfsTitle,
              readOnly: true,
              showToolbar: false,
              modelPathOf: (host) => workspaceEnvGuestPath(host, root.path),
            ),
    );
  }
}
