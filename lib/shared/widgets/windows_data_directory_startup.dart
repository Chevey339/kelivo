import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/services/storage/windows_data_directory.dart';
import '../../features/settings/widgets/windows_data_directory_tile.dart';
import '../../icons/lucide_adapter.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/theme_factory.dart';
import '../../theme/palettes.dart';
import 'ios_tile_button.dart';

/// Uses no business providers: the selected database has not been opened yet.
Future<void> initializeWindowsDataDirectory({
  required Future<void> Function() showWindow,
}) async {
  while (true) {
    WindowsDataDirectory? storage;
    try {
      storage = await WindowsDataDirectory.instance;
      await storage.initialize(
        onMoving: () {
          runApp(const _DataDirectoryStartupApp());
          unawaited(showWindow());
        },
      );
      return;
    } catch (error) {
      await showWindow();
      final retry = Completer<void>();
      WindowsDataDirectoryState? state;
      try {
        state = await storage?.state;
      } catch (_) {}
      runApp(
        _DataDirectoryStartupApp(
          error: error,
          path: state?.pending?.path ?? state?.active?.path,
          retry: () {
            if (!retry.isCompleted) retry.complete();
          },
          cancel: state?.pending == null || storage?.ownsControlLease != true
              ? null
              : () async {
                  await storage!.cancel();
                  if (!retry.isCompleted) retry.complete();
                },
        ),
      );
      await retry.future;
    }
  }
}

class _DataDirectoryStartupApp extends StatelessWidget {
  const _DataDirectoryStartupApp({
    this.error,
    this.path,
    this.retry,
    this.cancel,
  });

  final Object? error;
  final String? path;
  final VoidCallback? retry;
  final Future<void> Function()? cancel;

  @override
  Widget build(BuildContext context) {
    final palette = ThemePalettes.defaultPalette;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kelivo',
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: buildLightThemeForScheme(palette.light),
      darkTheme: buildDarkThemeForScheme(palette.dark),
      home: _StartupScreen(
        key: ObjectKey(error),
        error: error,
        path: path,
        retry: retry,
        cancel: cancel,
      ),
    );
  }
}

class _StartupScreen extends StatefulWidget {
  const _StartupScreen({
    super.key,
    this.error,
    this.path,
    this.retry,
    this.cancel,
  });
  final Object? error;
  final String? path;
  final VoidCallback? retry;
  final Future<void> Function()? cancel;

  @override
  State<_StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<_StartupScreen> {
  Object? _cancelError;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.error == null
                      ? l10n.dataDirectoryMoving
                      : l10n.dataDirectoryStartupFailed,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                if (widget.error == null)
                  const LinearProgressIndicator()
                else ...[
                  Text(
                    dataDirectoryErrorMessage(
                      l10n,
                      _cancelError ?? widget.error!,
                    ),
                  ),
                  if (widget.path case final path?) ...[
                    const SizedBox(height: 12),
                    SelectableText(path),
                  ],
                  const SizedBox(height: 12),
                  SelectableText(
                    (_cancelError ?? widget.error).toString(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  IosTileButton(
                    icon: Lucide.RotateCw,
                    label: l10n.dataDirectoryRetry,
                    enabled: !_busy,
                    onTap: () => widget.retry?.call(),
                  ),
                  if (widget.cancel != null) ...[
                    const SizedBox(height: 8),
                    Text(l10n.dataDirectoryCancelHint),
                    const SizedBox(height: 8),
                    IosTileButton(
                      icon: Lucide.X,
                      label: l10n.dataDirectoryCancelMove,
                      enabled: !_busy,
                      onTap: () async {
                        setState(() => _busy = true);
                        try {
                          await widget.cancel!();
                        } catch (error) {
                          if (mounted) setState(() => _cancelError = error);
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
