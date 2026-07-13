import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';

String restoreFailureDiagnosticCode(Object error) {
  if (error is FileSystemException) {
    final osCode = error.osError?.errorCode;
    return osCode == null ? 'filesystem' : 'filesystem_$osCode';
  }
  final Object? message = switch (error) {
    StateError() => error.message,
    FormatException() => error.message,
    _ => null,
  };
  final raw = message?.toString();
  if (raw != null && RegExp(r'^[a-zA-Z0-9_.:-]{1,160}$').hasMatch(raw)) {
    return raw;
  }
  return error.runtimeType.toString();
}

/// A persistence-free shell used when the startup restore gate fails closed.
class RestoreFailureScreen extends StatefulWidget {
  const RestoreFailureScreen({
    super.key,
    required this.diagnosticCode,
    required this.restart,
  });

  final String diagnosticCode;
  final Future<void> Function() restart;

  @override
  State<RestoreFailureScreen> createState() => _RestoreFailureScreenState();
}

class _RestoreFailureScreenState extends State<RestoreFailureScreen> {
  bool _restarting = false;
  bool _restartFailed = false;
  bool _copied = false;

  Future<void> _restart() async {
    if (_restarting) return;
    setState(() {
      _restarting = true;
      _restartFailed = false;
    });
    try {
      await widget.restart();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Kelivo restore',
          context: ErrorDescription('while restarting after restore failure'),
        ),
      );
      if (!mounted) return;
      setState(() {
        _restarting = false;
        _restartFailed = true;
      });
    }
  }

  Future<void> _copyDiagnostic() async {
    await Clipboard.setData(ClipboardData(text: widget.diagnosticCode));
    if (!mounted) return;
    setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isLeaseUnavailable =
        widget.diagnosticCode == 'RestoreBusinessLeaseUnavailable';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Material(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.shield_outlined,
                          size: 30,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        isLeaseUnavailable
                            ? l10n.backupRestoreBusinessLeaseUnavailableTitle
                            : l10n.backupRestoreFailureTitle,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isLeaseUnavailable
                            ? l10n.backupRestoreBusinessLeaseUnavailableContent
                            : l10n.backupRestoreFailureContent,
                        style: textTheme.bodyLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SelectableText(
                          l10n.backupRestoreFailureDiagnostic(
                            widget.diagnosticCode,
                          ),
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      if (_copied) ...[
                        const SizedBox(height: 8),
                        Text(
                          l10n.backupRestoreFailureCopied,
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.primary,
                          ),
                        ),
                      ],
                      if (_restartFailed) ...[
                        const SizedBox(height: 12),
                        Text(
                          l10n.restartAppFailedMessage,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colors.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _restarting ? null : _restart,
                          icon: _restarting
                              ? SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.onPrimary,
                                  ),
                                )
                              : const Icon(Icons.restart_alt_rounded),
                          label: Text(l10n.backupRestoreFailureRestartButton),
                        ),
                      ),
                      Align(
                        alignment: Alignment.center,
                        child: TextButton.icon(
                          onPressed: _copyDiagnostic,
                          icon: Icon(
                            _copied ? Icons.check_rounded : Icons.copy_rounded,
                            size: 18,
                          ),
                          label: Text(l10n.backupRestoreFailureCopyButton),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
