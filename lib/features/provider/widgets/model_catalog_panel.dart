import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/model_catalog/model_catalog_service.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_settings_rows.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/snackbar.dart';

class ModelCatalogPanel extends StatefulWidget {
  const ModelCatalogPanel({
    super.key,
    required this.catalog,
    this.compact = false,
  });

  final ModelCatalogService catalog;
  final bool compact;

  @override
  State<ModelCatalogPanel> createState() => _ModelCatalogPanelState();
}

class _ModelCatalogPanelState extends State<ModelCatalogPanel> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.catalog.ensureLoaded());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.catalog,
      builder: (context, _) {
        final statusRows = _statusRows(context);
        final actionRows = [_refreshRow(context), _autoUpdateRow(context)];
        if (widget.compact) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [...statusRows, ...actionRows],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionCard(dividers: true, children: statusRows),
            const SizedBox(height: 12),
            SectionCard(dividers: true, children: actionRows),
          ],
        );
      },
    );
  }

  List<Widget> _statusRows(BuildContext context) {
    final catalog = widget.catalog;
    final l10n = AppLocalizations.of(context)!;
    final date = formatModelCatalogDate(catalog.generatedAt);
    final source = catalog.generatedAt == null
        ? null
        : catalog.isBundled
        ? l10n.modelCatalogSourceBundled(date)
        : l10n.modelCatalogSourceRemote(date);
    return [
      IosNavRow(
        key: const ValueKey('model-catalog-source'),
        label: 'models.dev',
        subtitle: source,
      ),
      if (catalog.isLoaded) ...[
        IosNavRow(
          key: const ValueKey('model-catalog-provider-count'),
          label: l10n.modelCatalogProviderCount(catalog.providerCount),
        ),
        IosNavRow(
          key: const ValueKey('model-catalog-model-count'),
          label: l10n.modelCatalogModelCount(catalog.modelCount),
        ),
      ],
    ];
  }

  Widget _refreshRow(BuildContext context) {
    final catalog = widget.catalog;
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return IosNavRow(
      key: const ValueKey('model-catalog-refresh'),
      label: l10n.modelCatalogRefresh,
      onTap: catalog.refreshing ? null : () => _refresh(context),
      trailing: catalog.refreshing
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.primary,
              ),
            )
          : Icon(
              Lucide.RefreshCw,
              size: 16,
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
    );
  }

  Widget _autoUpdateRow(BuildContext context) {
    final catalog = widget.catalog;
    final l10n = AppLocalizations.of(context)!;
    return IosSwitchRow(
      key: const ValueKey('model-catalog-auto-update'),
      label: l10n.modelCatalogAutoUpdate,
      value: catalog.autoUpdate,
      onChanged: (value) {
        unawaited(catalog.setAutoUpdate(value));
      },
    );
  }

  Future<void> _refresh(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await widget.catalog.refresh(force: true);
    if (!context.mounted) return;
    if (ok) {
      showAppSnackBar(
        context,
        message: l10n.modelCatalogUpdated,
        type: NotificationType.success,
      );
      return;
    }
    showAppSnackBar(
      context,
      message: l10n.modelCatalogRefreshFailed(widget.catalog.lastError ?? ''),
      type: NotificationType.error,
    );
  }
}

String formatModelCatalogDate(DateTime? value) {
  if (value == null) return '—';
  final date = value.toUtc();
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
