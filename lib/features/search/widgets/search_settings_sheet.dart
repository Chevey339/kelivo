import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/search/search_service.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/services/api/builtin_tools.dart';
import '../../../icons/lucide_adapter.dart';
import '../pages/search_services_page.dart';
import 'search_service_avatar.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../core/services/haptics.dart';
import '../../../theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';
import '../../../shared/widgets/section_card.dart';

/// [chatModelProviderKey]/[chatModelId] carry the model the chat actually
/// sends with, resolved by the caller (conversation override -> assistant ->
/// global default), so built-in-search support is judged against it.
Future<void> showSearchSettingsSheet(
  BuildContext context, {
  String? chatModelProviderKey,
  String? chatModelId,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.overlaySurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _SearchSettingsSheet(
      chatModelProviderKey: chatModelProviderKey,
      chatModelId: chatModelId,
    ),
  );
}

class _SearchSettingsSheet extends StatelessWidget {
  const _SearchSettingsSheet({this.chatModelProviderKey, this.chatModelId});

  final String? chatModelProviderKey;
  final String? chatModelId;

  String _nameOf(BuildContext context, SearchServiceOptions s) {
    final svc = SearchService.getService(s);
    return svc.name;
  }

  Future<void> _setBuiltInSearchEnabled({
    required SettingsProvider settings,
    required ProviderConfig providerCfg,
    required String providerKey,
    required String modelId,
    required bool enabled,
  }) async {
    final overrides = Map<String, dynamic>.from(providerCfg.modelOverrides);
    final rawMo = overrides[modelId];
    final baseMo = rawMo is Map ? rawMo : null;
    final mo = Map<String, dynamic>.from(
      baseMo?.map((k, val) => MapEntry(k.toString(), val)) ??
          const <String, dynamic>{},
    );
    final builtIns = BuiltInToolNames.parseAndNormalize(mo['builtInTools']);
    if (enabled) {
      builtIns.add(BuiltInToolNames.search);
    } else {
      builtIns.remove(BuiltInToolNames.search);
    }
    if (builtIns.isEmpty) {
      mo.remove('builtInTools');
    } else {
      mo['builtInTools'] = BuiltInToolNames.orderedForStorage(builtIns);
    }
    overrides[modelId] = mo;
    await settings.setProviderConfig(
      providerKey,
      providerCfg.copyWith(modelOverrides: overrides),
    );
  }

  Future<void> _setClaudeDynamicWebSearchEnabled({
    required SettingsProvider settings,
    required ProviderConfig providerCfg,
    required String providerKey,
    required String modelId,
    required bool enabled,
  }) async {
    final overrides = Map<String, dynamic>.from(providerCfg.modelOverrides);
    overrides[modelId] = BuiltInToolsHelper.withClaudeDynamicWebSearch(
      overrides[modelId],
      enabled,
    );
    await settings.setProviderConfig(
      providerKey,
      providerCfg.copyWith(modelOverrides: overrides),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final settingsNotifier = context.read<SettingsProvider>();
    final ap = context.watch<AssistantProvider>();
    final assistantNotifier = context.read<AssistantProvider>();
    final a = ap.currentAssistant;
    final services = settings.searchServices;
    final selected = settings.searchServiceSelected.clamp(
      0,
      services.isNotEmpty ? services.length - 1 : 0,
    );
    final enabled = ap.currentSearchEnabled;

    // Determine if current selected model supports built-in search
    final providerKey =
        chatModelProviderKey ??
        a?.chatModelProvider ??
        settings.currentModelProvider;
    final modelId = chatModelId ?? a?.chatModelId ?? settings.currentModelId;
    final cfg = (providerKey != null)
        ? settings.getProviderConfig(providerKey)
        : null;
    final supportsBuiltInSearch =
        BuiltInToolsHelper.supportsBuiltInSearchForModel(
          cfg: cfg,
          modelId: modelId,
        );
    final supportsClaudeDynamicWebSearch =
        BuiltInToolsHelper.supportsClaudeDynamicWebSearchForModel(
          cfg: cfg,
          modelId: modelId,
        );

    // Read current built-in search toggle from modelOverrides
    final hasBuiltInSearch = BuiltInToolsHelper.isBuiltInSearchEnabled(
      cfg: cfg,
      modelId: modelId,
    );
    final hasClaudeDynamicWebSearch =
        BuiltInToolsHelper.isClaudeDynamicWebSearchEnabled(
          cfg: cfg,
          modelId: modelId,
        );
    Future<void> setExternalSearchEnabled(bool value) async {
      if (value &&
          cfg != null &&
          providerKey != null &&
          (modelId ?? '').isNotEmpty) {
        await _setBuiltInSearchEnabled(
          settings: settingsNotifier,
          providerCfg: cfg,
          providerKey: providerKey,
          modelId: modelId!,
          enabled: false,
        );
      }
      await assistantNotifier.setSearchEnabledForCurrentAssistant(value);
    }

    final maxHeight = MediaQuery.of(context).size.height * 0.8;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    l10n.searchSettingsSheetTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: AppFontWeights.emphasis,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Built-in search toggle
                if (cfg != null &&
                    supportsBuiltInSearch &&
                    (providerKey != null) &&
                    (modelId ?? '').isNotEmpty) ...[
                  Builder(
                    builder: (context) {
                      final providerCfg = cfg;
                      final mid = modelId!;
                      return IosCardPress(
                        borderRadius: BorderRadius.circular(14),
                        baseColor: sheetTileColor(context),
                        duration: const Duration(milliseconds: 260),
                        onTap: () async {
                          Haptics.light();
                          final bool v = !hasBuiltInSearch;
                          await _setBuiltInSearchEnabled(
                            settings: settingsNotifier,
                            providerCfg: providerCfg,
                            providerKey: providerKey,
                            modelId: mid,
                            enabled: v,
                          );
                          if (v) {
                            await assistantNotifier
                                .setSearchEnabledForCurrentAssistant(false);
                          }
                        },
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            Icon(Lucide.Search, size: 20, color: cs.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    l10n.searchSettingsSheetBuiltinSearchTitle,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: AppFontWeights.emphasis,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            IosSwitch(
                              value: hasBuiltInSearch,
                              onChanged: (v) async {
                                Haptics.light();
                                await _setBuiltInSearchEnabled(
                                  settings: settingsNotifier,
                                  providerCfg: providerCfg,
                                  providerKey: providerKey,
                                  modelId: mid,
                                  enabled: v,
                                );
                                if (v) {
                                  await assistantNotifier
                                      .setSearchEnabledForCurrentAssistant(
                                        false,
                                      );
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  // Only meaningful under built-in search: the tool version is
                  // picked when that tool is added, so on its own it is inert.
                  if (supportsClaudeDynamicWebSearch && hasBuiltInSearch)
                    Builder(
                      builder: (context) {
                        final providerCfg = cfg;
                        final mid = modelId!;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: IosCardPress(
                            borderRadius: BorderRadius.circular(14),
                            baseColor: sheetTileColor(context),
                            duration: const Duration(milliseconds: 260),
                            onTap: () async {
                              Haptics.light();
                              await _setClaudeDynamicWebSearchEnabled(
                                settings: settingsNotifier,
                                providerCfg: providerCfg,
                                providerKey: providerKey,
                                modelId: mid,
                                enabled: !hasClaudeDynamicWebSearch,
                              );
                            },
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Lucide.Search,
                                  size: 20,
                                  color: cs.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        l10n.searchSettingsSheetClaudeDynamicSearchTitle,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: AppFontWeights.emphasis,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        l10n.searchSettingsSheetClaudeDynamicSearchDescription,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: cs.onSurface.withValues(
                                            alpha: 0.7,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IosSwitch(
                                  value: hasClaudeDynamicWebSearch,
                                  onChanged: (v) async {
                                    Haptics.light();
                                    await _setClaudeDynamicWebSearchEnabled(
                                      settings: settingsNotifier,
                                      providerCfg: providerCfg,
                                      providerKey: providerKey,
                                      modelId: mid,
                                      enabled: v,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],

                // External search remains available while built-in search is
                // active so users can switch modes in one step.
                IosCardPress(
                  borderRadius: BorderRadius.circular(14),
                  baseColor: sheetTileColor(context),
                  duration: const Duration(milliseconds: 260),
                  onTap: () async {
                    Haptics.light();
                    await setExternalSearchEnabled(!enabled);
                  },
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Icon(Lucide.Globe, size: 20, color: cs.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.searchSettingsSheetWebSearchTitle,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: AppFontWeights.emphasis,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip:
                            l10n.searchSettingsSheetOpenSearchServicesTooltip,
                        icon: Icon(Lucide.Settings, size: 20),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SearchServicesPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 4),
                      IosSwitch(
                        value: enabled,
                        onChanged: setExternalSearchEnabled,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Services list (iOS-style rows like learning mode)
                if (services.isNotEmpty) ...[
                  ...List.generate(services.length, (i) {
                    final s = services[i];
                    final bool isSelected = i == selected;
                    final Color onColor = isSelected
                        ? cs.primary
                        : cs.onSurface;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: SizedBox(
                        height: 48,
                        child: IosCardPress(
                          borderRadius: BorderRadius.circular(14),
                          baseColor: sheetTileColor(context),
                          duration: const Duration(milliseconds: 260),
                          onTap: () async {
                            Haptics.light();
                            await settingsNotifier.setSearchServiceSelected(i);
                            await setExternalSearchEnabled(true);
                            if (!context.mounted) return;
                            Navigator.of(context).maybePop();
                          },
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              // Brand icon
                              SearchServiceAvatar.forService(
                                s,
                                avatar: settings.searchServiceAvatar(s.id),
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _nameOf(context, s),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: AppFontWeights.medium,
                                    color: onColor,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(Lucide.Check, size: 18, color: cs.primary)
                              else
                                const SizedBox(width: 18),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                ] else ...[
                  Text(
                    l10n.searchSettingsSheetNoServicesMessage,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
