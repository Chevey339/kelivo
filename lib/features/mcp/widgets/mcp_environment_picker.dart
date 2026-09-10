import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/environment_variable.dart';
import '../../../core/providers/environment_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/option_sheet.dart';

Future<EnvironmentVariable?> pickMcpEnvironmentVariable(
  BuildContext context,
) async {
  final environment = context.read<EnvironmentProvider?>();
  if (environment == null) return null;
  await environment.loaded;
  if (!context.mounted) return null;
  final l10n = AppLocalizations.of(context)!;
  return showOptionSheet<EnvironmentVariable>(
    context,
    title: l10n.mcpImportEnvironment,
    items: [
      for (final variable in environment.variables)
        OptionSheetItem(
          value: variable,
          label: variable.name,
          subtitle: variable.note.isEmpty ? null : variable.note,
        ),
    ],
    footer: environment.variables.isEmpty
        ? Text(l10n.mcpEnvironmentEmpty)
        : null,
  );
}
