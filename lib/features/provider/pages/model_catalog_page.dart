import 'package:flutter/material.dart';

import '../../../core/services/model_catalog/model_catalog_service.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../widgets/model_catalog_panel.dart';

class ModelCatalogPage extends StatelessWidget {
  ModelCatalogPage({super.key, ModelCatalogService? catalog})
    : catalog = catalog ?? ModelCatalogService.instance;

  final ModelCatalogService catalog;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 52,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IosIconButton(
            icon: Lucide.ArrowLeft,
            size: 22,
            semanticLabel: l10n.settingsPageBackButton,
            minSize: 44,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(
          l10n.modelCatalogTitle,
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: ListView(
        key: const ValueKey('model-catalog-page'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [ModelCatalogPanel(catalog: catalog)],
      ),
    );
  }
}
