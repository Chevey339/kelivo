import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/model_provider.dart';
import '../../../core/models/api_keys.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../model/widgets/model_select_sheet.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_tile_button.dart';
import '../../../core/services/haptics.dart';

class MultiKeyManagerPage extends StatefulWidget {
  const MultiKeyManagerPage({super.key, required this.providerKey, required this.providerDisplayName});
  final String providerKey;
  final String providerDisplayName;

  @override
  State<MultiKeyManagerPage> createState() => _MultiKeyManagerPageState();
}

class _MultiKeyManagerPageState extends State<MultiKeyManagerPage> {
  String? _detectModelId;
  bool _detecting = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final cfg = settings.getProviderConfig(widget.providerKey, defaultName: widget.providerDisplayName);
    final apiKeys = List<ApiKeyConfig>.from(cfg.apiKeys ?? const <ApiKeyConfig>[]);
    final total = apiKeys.length;
    final normal = apiKeys.where((k) => k.status == ApiKeyStatus.active).length;
    final errors = apiKeys.where((k) => k.status == ApiKeyStatus.error).length;
    // accuracy metric removed from UI; no longer needed

    return Scaffold(
      appBar: AppBar(
        leading: Tooltip(
          message: l10n.settingsPageBackButton,
          child: _TactileIconButton(
            icon: Lucide.ArrowLeft,
            color: cs.onSurface,
            semanticLabel: l10n.settingsPageBackButton,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(l10n.multiKeyPageTitle),
        actions: [
          Tooltip(
            message: l10n.multiKeyPageDeleteErrorsTooltip,
            child: _TactileIconButton(
              icon: Lucide.Trash2,
              color: cs.onSurface,
              semanticLabel: l10n.multiKeyPageDeleteErrorsTooltip,
              onTap: _onDeleteAllErrorKeys,
            ),
          ),
          if (_detecting)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
              ),
            )
          else
            Tooltip(
              message: l10n.multiKeyPageDetect,
              child: _TactileIconButton(
                icon: Lucide.HeartPulse,
                color: cs.onSurface,
                semanticLabel: l10n.multiKeyPageDetect,
                onTap: _onDetect,
                onLongPress: _onPickDetectModel,
              ),
            ),
          Tooltip(
            message: l10n.multiKeyPageAdd,
            child: _TactileIconButton(
              icon: Lucide.Plus,
              color: cs.onSurface,
              semanticLabel: l10n.multiKeyPageAdd,
              onTap: _onAddKeys,
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          _iosSectionCard(children: [
            _iosRow(
              context,
              label: l10n.multiKeyPageTotal,
              trailing: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text('$total', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ),
            ),
            _iosRow(
              context,
              label: l10n.multiKeyPageNormal,
              trailing: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text('$normal', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ),
            ),
            _iosRow(
              context,
              label: l10n.multiKeyPageError,
              trailing: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text('$errors', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ),
            ),
            _strategyRow(context, cfg),
          ]),
          const SizedBox(height: 12),
          _keysList(context, apiKeys),
        ],
      ),
    );
  }

  String _strategyLabel(BuildContext context, LoadBalanceStrategy s) {
    final l10n = AppLocalizations.of(context)!;
    switch (s) {
      case LoadBalanceStrategy.priority:
        return l10n.multiKeyPageStrategyPriority;
      case LoadBalanceStrategy.leastUsed:
        return l10n.multiKeyPageStrategyLeastUsed;
      case LoadBalanceStrategy.random:
        return l10n.multiKeyPageStrategyRandom;
      case LoadBalanceStrategy.roundRobin:
      default:
        return l10n.multiKeyPageStrategyRoundRobin;
    }
  }

  Widget _strategyRow(BuildContext context, ProviderConfig cfg) {
    final cs = Theme.of(context).colorScheme;
    final strategy = cfg.keyManagement?.strategy ?? LoadBalanceStrategy.roundRobin;
    return _TactileRow(
      pressedScale: 1.00,
      onTap: _showStrategySheet,
      builder: (pressed) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final base = cs.onSurface;
        final target = pressed
            ? (Color.lerp(base, isDark ? Colors.black : Colors.white, 0.55) ?? base)
            : base;
        return TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: target),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          builder: (context, color, _) {
            final c = color ?? base;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                children: [
                  Expanded(child: Text(AppLocalizations.of(context)!.multiKeyPageStrategyTitle, style: TextStyle(fontSize: 15, color: c))),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _strategyLabel(context, strategy),
                        style: TextStyle(fontSize: 15, color: c),
                      ),
                      const SizedBox(width: 6),
                      Icon(Lucide.ChevronRight, size: 16, color: c),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _keysList(BuildContext context, List<ApiKeyConfig> keys) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    if (keys.isEmpty) {
      return _iosSectionCard(children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(child: Text(l10n.multiKeyPageNoKeys)),
        )
      ]);
    }

    String mask(String key) {
      if (key.length <= 8) return key;
      return '${key.substring(0, 4)}••••${key.substring(key.length - 4)}';
    }

    Color statusColor(ApiKeyStatus st) {
      switch (st) {
        case ApiKeyStatus.active:
          return Colors.green;
        case ApiKeyStatus.disabled:
          return cs.onSurface.withOpacity(0.6);
        case ApiKeyStatus.error:
          return cs.error;
        case ApiKeyStatus.rateLimited:
          return cs.tertiary;
      }
    }

    String statusText(ApiKeyStatus st) {
      switch (st) {
        case ApiKeyStatus.active:
          return l10n.multiKeyPageStatusActive;
        case ApiKeyStatus.disabled:
          return l10n.multiKeyPageStatusDisabled;
        case ApiKeyStatus.error:
          return l10n.multiKeyPageStatusError;
        case ApiKeyStatus.rateLimited:
          return l10n.multiKeyPageStatusRateLimited;
      }
    }

    return _iosSectionCard(
      children: [
        for (int i = 0; i < keys.length; i++)
          _keyRow(context, keys[i], statusColor, statusText, mask),
      ],
    );
  }

  Widget _keyRow(
    BuildContext context,
    ApiKeyConfig k,
    Color Function(ApiKeyStatus) statusColor,
    String Function(ApiKeyStatus) statusText,
    String Function(String) mask,
  ) {
    final cs = Theme.of(context).colorScheme;
    final name = k.name?.isNotEmpty == true ? k.name! : mask(k.key);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor(k.status).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusText(k.status),
                    style: TextStyle(color: statusColor(k.status), fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IosSwitch(
            value: k.isEnabled,
            onChanged: (v) async {
              // Haptics.soft();
              await _updateKey(k.copyWith(isEnabled: v));
            },
            width: 46,
            height: 28,
          ),
          const SizedBox(width: 6),
          _TactileIconButton(
            icon: Lucide.Pencil,
            color: cs.primary,
            semanticLabel: AppLocalizations.of(context)!.multiKeyPageEdit,
            onTap: () async {
              await _editKey(k);
            },
          ),
          const SizedBox(width: 4),
          _TactileIconButton(
            icon: Lucide.Trash2,
            color: cs.error,
            semanticLabel: AppLocalizations.of(context)!.multiKeyPageDelete,
            onTap: () async {
              await _deleteKey(k);
            },
          ),
        ],
      ),
    );
  }

  // iOS-style section container
  Widget _iosSectionCard({required List<Widget> children}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    // Blend with surface to better match page background while retaining a card feel
    final Color base = cs.surface;
    final Color bg = isDark
        ? Color.lerp(base, Colors.white, 0.06)!
        : Color.lerp(base, Colors.white, 0.92)!;
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outlineVariant.withOpacity(isDark ? 0.08 : 0.06),
          width: 0.6,
        ),
        // boxShadow: [
        //   if (!isDark)
        //     BoxShadow(
        //       color: Colors.black.withOpacity(0.02),
        //       blurRadius: 6,
        //       offset: const Offset(0, 1),
        //     ),
        // ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  // Single row with label-left and custom trailing
  Widget _iosRow(
    BuildContext context, {
    required String label,
    Widget? trailing,
    GestureTapCallback? onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
          if (trailing != null) DefaultTextStyle.merge(
            style: TextStyle(color: cs.onSurface.withOpacity(0.8)),
            child: trailing,
          ),
        ],
      ),
    );
    if (onTap != null) {
      return _TactileScale(child: row, onTap: onTap);
    }
    return row;
  }

  Widget _divider(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(height: 0.6, color: cs.outlineVariant.withOpacity(0.25));
  }

  Future<void> _updateKey(ApiKeyConfig updated) async {
    final settings = context.read<SettingsProvider>();
    final old = settings.getProviderConfig(widget.providerKey, defaultName: widget.providerDisplayName);
    final list = List<ApiKeyConfig>.from(old.apiKeys ?? const <ApiKeyConfig>[]);
    final idx = list.indexWhere((e) => e.id == updated.id);
    if (idx >= 0) {
      list[idx] = updated;
      await settings.setProviderConfig(widget.providerKey, old.copyWith(apiKeys: list));
    }
  }

  Future<void> _deleteKey(ApiKeyConfig k) async {
    final settings = context.read<SettingsProvider>();
    final old = settings.getProviderConfig(widget.providerKey, defaultName: widget.providerDisplayName);
    final list = List<ApiKeyConfig>.from(old.apiKeys ?? const <ApiKeyConfig>[]);
    final idx = list.indexWhere((e) => e.id == k.id);
    if (idx < 0) return;
    final removed = list.removeAt(idx);
    await settings.setProviderConfig(widget.providerKey, old.copyWith(apiKeys: list));
    if (!mounted) return;
    showAppSnackBar(
      context,
      message: AppLocalizations.of(context)!.multiKeyPageDeleteSnackbarDeletedOne,
      type: NotificationType.info,
      actionLabel: AppLocalizations.of(context)!.multiKeyPageUndo,
      onAction: () async {
        // Re-insert if user taps undo
        final latest = settings.getProviderConfig(widget.providerKey, defaultName: widget.providerDisplayName);
        final cur = List<ApiKeyConfig>.from(latest.apiKeys ?? const <ApiKeyConfig>[]);
        final insertIndex = idx <= cur.length ? idx : cur.length;
        cur.insert(insertIndex, removed);
        await settings.setProviderConfig(widget.providerKey, latest.copyWith(apiKeys: cur));
        if (!mounted) return;
        showAppSnackBar(
          context,
          message: AppLocalizations.of(context)!.multiKeyPageUndoRestored,
          type: NotificationType.success,
          duration: const Duration(seconds: 2),
        );
      },
    );
  }

  Future<void> _editKey(ApiKeyConfig k) async {
    final updated = await _showEditKeySheet(k);
    if (updated == null) return;
    // Optional: prevent duplicate keys if key changed
    final settings = context.read<SettingsProvider>();
    final cfg = settings.getProviderConfig(widget.providerKey, defaultName: widget.providerDisplayName);
    final list = List<ApiKeyConfig>.from(cfg.apiKeys ?? const <ApiKeyConfig>[]);
    final duplicate = list.any((e) => e.id != k.id && e.key.trim() == updated.key.trim());
    if (duplicate) {
      showAppSnackBar(context, message: AppLocalizations.of(context)!.multiKeyPageDuplicateKeyWarning, type: NotificationType.warning);
      return;
    }
    await _updateKey(updated);
  }

  Future<void> _onAddKeys() async {
    final l10n = AppLocalizations.of(context)!;
    final added = await _showAddKeysSheet();
    if (added == null) return;
    final settings = context.read<SettingsProvider>();
    final cfg = settings.getProviderConfig(widget.providerKey, defaultName: widget.providerDisplayName);
    final existing = (cfg.apiKeys ?? const <ApiKeyConfig>[]);
    final existingSet = existing.map((e) => e.key.trim()).toSet();
    final unique = <String>[];
    for (final k in added) {
      if (k.isEmpty) continue;
      if (!existingSet.contains(k)) unique.add(k);
    }
    if (unique.isEmpty) {
      showAppSnackBar(context, message: l10n.multiKeyPageImportedSnackbar(0));
      return;
    }
    final newKeys = [
      ...existing,
      for (final s in unique) ApiKeyConfig.create(s),
    ];
    await settings.setProviderConfig(widget.providerKey, cfg.copyWith(apiKeys: newKeys, multiKeyEnabled: true));
    if (!mounted) return;
    showAppSnackBar(context, message: l10n.multiKeyPageImportedSnackbar(unique.length), type: NotificationType.success);

    // Auto-detect imported keys
    await _detectOnly(keys: unique);
  }

  List<String> _splitKeys(String raw) {
    final s = raw.replaceAll(',', ' ').trim();
    return s.split(RegExp(r'\s+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  Future<void> _onDetect() async {
    if (_detecting) return;
    final settings = context.read<SettingsProvider>();
    final cfg = settings.getProviderConfig(widget.providerKey, defaultName: widget.providerDisplayName);
    final models = cfg.models;
    if (_detectModelId == null) {
      if (models.isEmpty) {
        if (!mounted) return;
        showAppSnackBar(context, message: AppLocalizations.of(context)!.multiKeyPagePleaseAddModel, type: NotificationType.warning);
        return;
      }
      _detectModelId = models.first;
    }
    setState(() => _detecting = true);
    try {
      await _detectAllForModel(_detectModelId!);
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
  }

  Future<void> _onPickDetectModel() async {
    final sel = await showModelSelector(context, limitProviderKey: widget.providerKey);
    if (sel != null) {
      setState(() => _detectModelId = sel.modelId);
    }
  }

  Future<void> _onDeleteAllErrorKeys() async {
    final settings = context.read<SettingsProvider>();
    final cfg = settings.getProviderConfig(widget.providerKey, defaultName: widget.providerDisplayName);
    final keys = List<ApiKeyConfig>.from(cfg.apiKeys ?? const <ApiKeyConfig>[]);
    final errorKeys = keys.where((e) => e.status == ApiKeyStatus.error).toList();
    if (errorKeys.isEmpty) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.multiKeyPageDeleteErrorsConfirmTitle),
          content: Text(l10n.multiKeyPageDeleteErrorsConfirmContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.multiKeyPageCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(foregroundColor: cs.error),
              child: Text(l10n.multiKeyPageDelete),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    final remain = keys.where((e) => e.status != ApiKeyStatus.error).toList();
    await settings.setProviderConfig(widget.providerKey, cfg.copyWith(apiKeys: remain));
    if (!mounted) return;
    showAppSnackBar(
      context,
      message: AppLocalizations.of(context)!.multiKeyPageDeletedErrorsSnackbar(errorKeys.length),
      type: NotificationType.success,
    );
  }

  Future<void> _chooseDetectModel() async {
    final sel = await showModelSelector(context, limitProviderKey: widget.providerKey);
    if (sel != null) setState(() => _detectModelId = sel.modelId);
  }

  Future<void> _showStrategySheet() async {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final settings = context.read<SettingsProvider>();
    final old = settings.getProviderConfig(widget.providerKey, defaultName: widget.providerDisplayName);
    final current = old.keyManagement?.strategy ?? LoadBalanceStrategy.roundRobin;
    String labelFor(LoadBalanceStrategy s) {
      switch (s) {
        case LoadBalanceStrategy.priority:
          return l10n.multiKeyPageStrategyPriority;
        case LoadBalanceStrategy.leastUsed:
          return l10n.multiKeyPageStrategyLeastUsed;
        case LoadBalanceStrategy.random:
          return l10n.multiKeyPageStrategyRandom;
        case LoadBalanceStrategy.roundRobin:
        default:
          return l10n.multiKeyPageStrategyRoundRobin;
      }
    }

    final selected = await showModalBottomSheet<LoadBalanceStrategy>(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                // Only show Round Robin and Random for now
                for (final s in <LoadBalanceStrategy>[LoadBalanceStrategy.roundRobin, LoadBalanceStrategy.random])
                  _TactileRow(
                    pressedScale: 1.00,
                    onTap: () => Navigator.of(ctx).pop(s),
                    builder: (pressed) {
                      final base = cs.onSurface;
                      final isDark = Theme.of(ctx).brightness == Brightness.dark;
                      final target = pressed ? (Color.lerp(base, isDark ? Colors.black : Colors.white, 0.55) ?? base) : base;
                      return TweenAnimationBuilder<Color?>(
                        tween: ColorTween(end: target),
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        builder: (context, color, _) {
                          final c = color ?? base;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(child: Text(labelFor(s), style: TextStyle(fontSize: 15, color: c))),
                                if (s == current) Icon(Icons.check, color: cs.primary),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null && selected != current) {
      final km = (old.keyManagement ?? const KeyManagementConfig()).copyWith(strategy: selected);
      await settings.setProviderConfig(widget.providerKey, old.copyWith(keyManagement: km));
    }
  }

  Future<List<String>?> _showAddKeysSheet() async {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputCtrl = TextEditingController();
    final result = await showModalBottomSheet<List<String>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(999)))),
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Text(l10n.multiKeyPageAdd, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _TactileIconButton(
                          icon: Lucide.X,
                          color: cs.onSurface,
                          onTap: () => Navigator.of(ctx).maybePop(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: inputCtrl,
                  minLines: 3,
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText: l10n.multiKeyPageAddHint,
                    filled: true,
                    fillColor: isDark ? Colors.white10 : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.4))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.4))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cs.primary.withOpacity(0.5))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: IosTileButton(
                    label: l10n.multiKeyPageAdd,
                    icon: Lucide.Plus,
                    backgroundColor: cs.primary,
                    onTap: () => Navigator.of(ctx).pop(_splitKeys(inputCtrl.text)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    return result;
  }

  Future<ApiKeyConfig?> _showEditKeySheet(ApiKeyConfig k) async {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final aliasCtrl = TextEditingController(text: k.name ?? '');
    final keyCtrl = TextEditingController(text: k.key);
    final priCtrl = TextEditingController(text: k.priority.toString());
    final updated = await showModalBottomSheet<ApiKeyConfig?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(999)))),
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Text(l10n.multiKeyPageEdit, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _TactileIconButton(
                          icon: Lucide.X,
                          color: cs.onSurface,
                          onTap: () => Navigator.of(ctx).maybePop(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: aliasCtrl,
                  decoration: InputDecoration(
                    hintText: l10n.multiKeyPageAlias,
                    filled: true,
                    fillColor: isDark ? Colors.white10 : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.4))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.4))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cs.primary.withOpacity(0.5))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: keyCtrl,
                  decoration: InputDecoration(
                    hintText: l10n.multiKeyPageKey,
                    filled: true,
                    fillColor: isDark ? Colors.white10 : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.4))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.4))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cs.primary.withOpacity(0.5))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: l10n.multiKeyPagePriority,
                    filled: true,
                    fillColor: isDark ? Colors.white10 : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.4))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.4))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cs.primary.withOpacity(0.5))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: IosTileButton(
                    label: l10n.multiKeyPageSave,
                    icon: Lucide.Check,
                    backgroundColor: cs.primary,
                    onTap: () {
                      final p = int.tryParse(priCtrl.text.trim()) ?? k.priority;
                      final clamped = p.clamp(1, 10) as int;
                      Navigator.of(ctx).pop(
                        k.copyWith(
                          name: aliasCtrl.text.trim().isEmpty ? null : aliasCtrl.text.trim(),
                          key: keyCtrl.text.trim(),
                          priority: clamped,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    return updated;
  }

  Future<void> _detectOnly({required List<String> keys}) async {
    final cfg = context.read<SettingsProvider>().getProviderConfig(widget.providerKey, defaultName: widget.providerDisplayName);
    final models = cfg.models;
    if (_detectModelId == null) {
      if (models.isEmpty) {
        showAppSnackBar(context, message: AppLocalizations.of(context)!.multiKeyPagePleaseAddModel, type: NotificationType.warning);
        return;
      }
      _detectModelId = models.first;
    }
    final list = List<ApiKeyConfig>.from(cfg.apiKeys ?? const <ApiKeyConfig>[]);
    final toTest = list.where((e) => keys.contains(e.key)).toList();
    await _testKeysAndSave(list, toTest, _detectModelId!);
  }

  Future<void> _detectAllForModel(String modelId) async {
    final settings = context.read<SettingsProvider>();
    final cfg = settings.getProviderConfig(widget.providerKey, defaultName: widget.providerDisplayName);
    final list = List<ApiKeyConfig>.from(cfg.apiKeys ?? const <ApiKeyConfig>[]);
    await _testKeysAndSave(list, list, modelId);
  }

  Future<void> _testKeysAndSave(List<ApiKeyConfig> fullList, List<ApiKeyConfig> toTest, String modelId) async {
    final settings = context.read<SettingsProvider>();
    final base = settings.getProviderConfig(widget.providerKey, defaultName: widget.providerDisplayName);
    final out = List<ApiKeyConfig>.from(fullList);
    for (int i = 0; i < toTest.length; i++) {
      final k = toTest[i];
      final ok = await _testSingleKey(base, modelId, k);
      final idx = out.indexWhere((e) => e.id == k.id);
      if (idx >= 0) out[idx] = k.copyWith(
        status: ok ? ApiKeyStatus.active : ApiKeyStatus.error,
        usage: k.usage.copyWith(
          totalRequests: k.usage.totalRequests + 1,
          successfulRequests: k.usage.successfulRequests + (ok ? 1 : 0),
          failedRequests: k.usage.failedRequests + (ok ? 0 : 1),
          consecutiveFailures: ok ? 0 : (k.usage.consecutiveFailures + 1),
          lastUsed: DateTime.now().millisecondsSinceEpoch,
        ),
        lastError: ok ? null : 'Test failed',
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      // Small delay between tests for UX
      await Future.delayed(const Duration(milliseconds: 120));
    }
    await settings.setProviderConfig(widget.providerKey, base.copyWith(apiKeys: out));
  }

  Future<bool> _testSingleKey(ProviderConfig baseCfg, String modelId, ApiKeyConfig key) async {
    try {
      final cfg2 = baseCfg.copyWith(apiKey: key.key);
      await ProviderManager.testConnection(cfg2, modelId);
      return true;
    } catch (_) {
      return false;
    }
  }
}

// A scale-on-tap wrapper for iOS-like lightweight feedback (no ripple)
class _TactileScale extends StatefulWidget {
  const _TactileScale({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_TactileScale> createState() => _TactileScaleState();
}

class _TactileScaleState extends State<_TactileScale> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
      onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
      onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (context.read<SettingsProvider>().hapticsOnListItemTap) Haptics.soft();
              widget.onTap!.call();
            },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

// Icon-only, no-border, iOS-like tactile icon button
class _TactileIconButton extends StatefulWidget {
  const _TactileIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.size = 22,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;
  final double size;

  @override
  State<_TactileIconButton> createState() => _TactileIconButtonState();
}

class _TactileIconButtonState extends State<_TactileIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final base = widget.color;
    final pressColor = base.withOpacity(0.7);
    final icon = Icon(widget.icon, size: widget.size, color: _pressed ? pressColor : base, semanticLabel: widget.semanticLabel);

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          // Haptics.light();
          widget.onTap();
        },
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                 Haptics.light();
                widget.onLongPress!.call();
              },
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: icon,
          ),
        ),
      ),
    );
  }
}

// Builder-based tactile wrapper to expose pressed state and optional scale
class _TactileRow extends StatefulWidget {
  const _TactileRow({required this.builder, this.onTap, this.pressedScale = 0.97});
  final Widget Function(bool pressed) builder;
  final VoidCallback? onTap;
  final double pressedScale;

  @override
  State<_TactileRow> createState() => _TactileRowState();
}

class _TactileRowState extends State<_TactileRow> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
      onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
      onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
      onTap: widget.onTap == null
          ? null
          : () {
              Haptics.soft();
              widget.onTap!.call();
            },
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: widget.builder(_pressed),
      ),
    );
  }
}
