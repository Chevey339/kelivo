import 'dart:async';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/services/media/fal_model_catalog.dart';
import '../../../core/services/media/fal_model_discovery.dart';
import '../../../core/services/network/provider_http_client.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/configurable_avatar.dart';
import '../../../shared/widgets/form_sheet.dart';
import '../../../shared/widgets/model_tag_wrap.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../theme/app_semantic_colors.dart';
import '../../../utils/brand_assets.dart';
import '../../media/widgets/creation_controls.dart';

Future<void> showFalModelPicker(
  BuildContext context,
  ProviderConfig config, {
  required bool desktop,
}) async {
  final lifetime = CancelToken();
  final client = providerHttpClient(
    config,
    cancelToken: lifetime,
    timeout: const Duration(seconds: 15),
  );
  final picker = FalModelPicker(
    config: config,
    desktop: desktop,
    catalog: FalModelDiscovery.forProvider(client, config),
  );
  try {
    if (desktop) {
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: context.overlaySurface,
          child: SizedBox(width: 590, height: 580, child: picker),
        ),
      );
    } else {
      await showFormSheet<void>(
        context,
        builder: (context) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .72,
              child: picker,
            ),
          ),
        ),
      );
    }
  } finally {
    lifetime.cancel();
    client.close();
  }
}

class FalModelPicker extends StatefulWidget {
  const FalModelPicker({
    super.key,
    required this.config,
    required this.desktop,
    required this.catalog,
  });
  final ProviderConfig config;
  final bool desktop;
  final FalModelDiscovery catalog;
  @override
  State<FalModelPicker> createState() => _FalModelPickerState();
}

class _FalModelPickerState extends State<FalModelPicker> {
  final _models = <FalCatalogEntry>[];
  final _seen = <String>{};
  final _pending = <String>{};
  Timer? _debounce;
  int _revision = 0;
  int? _fetching;
  String _query = '';
  String? _cursor;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  void _search(String text) {
    final query = text.trim();
    if (query == _query) return;
    _debounce?.cancel();
    setState(() {
      _query = query;
      _revision++;
      _models.clear();
      _seen.clear();
      _cursor = null;
      _error = null;
      _loading = true;
    });
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _load() async {
    final revision = _revision;
    if (_fetching == revision) return;
    _fetching = revision;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.catalog.search(_query, cursor: _cursor);
      if (!mounted || revision != _revision) return;
      setState(() {
        for (final model in page.models) {
          if (_seen.add(model.id)) _models.add(model);
        }
        _cursor = page.nextCursor;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || revision != _revision) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    } finally {
      if (_fetching == revision) _fetching = null;
    }
  }

  Future<void> _toggle(FalCatalogEntry entry) async {
    if (!_pending.add(entry.id)) return;
    setState(() {});
    final settings = context.read<SettingsProvider>();
    final key = widget.config.id;
    try {
      final current = settings.getProviderConfig(key);
      if (current.models.contains(entry.id)) {
        await settings.setProviderConfig(
          key,
          current.copyWith(
            models: current.models.where((id) => id != entry.id).toList(),
          ),
        );
      } else {
        final details = falModels.containsKey(entry.id)
            ? null
            : await widget.catalog.describe(entry);
        if (!mounted || ModalRoute.of(context)?.isCurrent == false) return;
        final latest = settings.getProviderConfig(key);
        if (latest.models.contains(entry.id) ||
            latest.baseUrl != widget.config.baseUrl) {
          return;
        }
        final previous = latest.modelOverrides[entry.id];
        await settings.setProviderConfig(
          key,
          latest.copyWith(
            models: [...latest.models, entry.id],
            modelOverrides: {
              ...latest.modelOverrides,
              if (details != null)
                entry.id: {
                  if (previous is Map) ...Map<String, dynamic>.from(previous),
                  'falEndpoint': details,
                },
            },
          ),
        );
      }
    } catch (error) {
      if (mounted && ModalRoute.of(context)?.isCurrent != false) {
        showAppSnackBar(
          context,
          type: NotificationType.error,
          message: AppLocalizations.of(
            context,
          )!.falCatalogLoadFailed(error.toString()),
        );
      }
    } finally {
      if (mounted) setState(() => _pending.remove(entry.id));
    }
  }

  Widget _footer(AppLocalizations l10n) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }
    if (_error != null) {
      return Column(
        children: [
          Text(
            l10n.falCatalogLoadFailed(_error.toString()),
            textAlign: TextAlign.center,
          ),
          TextButton(onPressed: _load, child: Text(l10n.creationRetry)),
        ],
      );
    }
    if (_cursor != null) {
      return TextButton(onPressed: _load, child: Text(l10n.falCatalogMore));
    }
    return _models.isEmpty
        ? Center(child: Text(l10n.falCatalogNoMatch))
        : const SizedBox.shrink();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final selected = context.select<SettingsProvider, List<String>>(
      (s) => s.getProviderConfig(widget.config.id).models,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.providerDetailPageModelsTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IosIconButton(
                icon: LucideIcons.x,
                tooltip: l10n.commonClose,
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
          CreationSearchBox(
            hint: l10n.providerDetailPageFilterHint,
            mobile: !widget.desktop,
            onChanged: _search,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _models.length + 1,
              itemBuilder: (context, index) {
                if (index == _models.length) return _footer(l10n);
                final model = _models[index];
                final added = selected.contains(model.id);
                return Semantics(
                  button: true,
                  selected: added,
                  child: IosCardPress(
                    key: ValueKey(model.id),
                    baseColor: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    onTap: _pending.contains(model.id)
                        ? null
                        : () => _toggle(model),
                    child: Row(
                      children: [
                        ConfigurableAvatar(
                          avatar: widget.config.modelAvatar(model.id),
                          name: model.name,
                          fallbackAsset: BrandAssets.assetForModel(
                            model.id,
                            displayName: model.name,
                          ),
                          matchBrandByName: false,
                          withBackground: false,
                          size: 22,
                          iconScale: 1,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                model.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                model.id,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ModelCapsulesRow(model: model.spec),
                        const SizedBox(width: 8),
                        if (_pending.contains(model.id))
                          const CupertinoActivityIndicator()
                        else
                          Icon(
                            added ? LucideIcons.check : LucideIcons.plus,
                            size: 18,
                            color: added ? cs.primary : cs.onSurfaceVariant,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
