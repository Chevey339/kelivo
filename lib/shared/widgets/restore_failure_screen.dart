import 'dart:io';

import 'package:flutter/material.dart';

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
class RestoreFailureScreen extends StatelessWidget {
  const RestoreFailureScreen({super.key, required this.diagnosticCode});

  final String diagnosticCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 36,
                        color: colors.primary,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        l10n.backupRestoreFailureTitle,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.backupRestoreFailureContent,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 20),
                      SelectableText(
                        l10n.backupRestoreFailureDiagnostic(diagnosticCode),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
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
