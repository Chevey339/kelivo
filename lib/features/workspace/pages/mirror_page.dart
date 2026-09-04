import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/services/haptics.dart';
import 'package:Kelivo/core/services/sandbox/mirror_service.dart';
import 'package:Kelivo/features/workspace/widgets/environment/environment_chrome.dart';
import 'package:Kelivo/features/workspace/widgets/environment/environment_keys.dart';
import 'package:Kelivo/features/workspace/widgets/environment/environment_labels.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/ios_tile_button.dart';
import 'package:Kelivo/shared/widgets/section_card.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:Kelivo/theme/app_font_weights.dart';

class MirrorPage extends StatelessWidget {
  const MirrorPage({super.key, required this.category});

  final MirrorCategory category;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
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
        title: Text(workspaceEnvCategoryLabel(l10n, category)),
      ),
      body: MirrorPageBody(category: category),
    );
  }
}

class MirrorPageBody extends StatefulWidget {
  const MirrorPageBody({super.key, required this.category});

  final MirrorCategory category;

  static Key rowKey(String id) => ValueKey<String>('workspace-env-mirror-$id');

  static const speedTestKey = ValueKey<String>('workspace-env-mirror-speed');

  @override
  State<MirrorPageBody> createState() => _MirrorPageBodyState();
}

class _MirrorPageBodyState extends State<MirrorPageBody> {
  Map<String, MirrorProbeResult> _results = <String, MirrorProbeResult>{};
  bool _probing = false;
  String? _applyingId;

  Future<void> _setUseMirror(bool enabled) async {
    final mirrors = context.read<MirrorService?>();
    if (mirrors == null || _applyingId != null) return;
    final env = context.read<EnvironmentProvider>();
    setState(() => _applyingId = 'toggle');
    try {
      if (!enabled) {
        await mirrors.restoreOfficial(widget.category);
        if (!mounted) return;
        showAppSnackBar(
          context,
          message: AppLocalizations.of(context)!.workspaceEnvRestoreSuccess,
          type: NotificationType.success,
        );
        return;
      }
      final selection = env.mirrors[widget.category];
      final entry =
          MirrorService.findEntry(
            widget.category,
            id: selection?.mirrorId,
            url: selection?.selectedBaseUrl,
          ) ??
          MirrorService.officialEntry(widget.category);
      await mirrors.applyEntry(widget.category, entry);
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: AppLocalizations.of(context)!.workspaceEnvApplySuccess,
        type: NotificationType.success,
      );
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: AppLocalizations.of(context)!.workspaceEnvApplyFailed,
        type: NotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _applyingId = null);
    }
  }

  Future<void> _select(MirrorEntry entry) async {
    final mirrors = context.read<MirrorService?>();
    if (mirrors == null || _applyingId != null) return;
    setState(() => _applyingId = entry.id);
    try {
      await mirrors.applyEntry(widget.category, entry);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      showAppSnackBar(
        context,
        message: entry.official
            ? l10n.workspaceEnvRestoreSuccess
            : l10n.workspaceEnvApplySuccess,
        type: NotificationType.success,
      );
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: AppLocalizations.of(context)!.workspaceEnvApplyFailed,
        type: NotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _applyingId = null);
    }
  }

  Future<void> _speedTest() async {
    final mirrors = context.read<MirrorService?>();
    if (mirrors == null || _probing) return;
    setState(() {
      _probing = true;
      _results = <String, MirrorProbeResult>{};
    });
    try {
      await for (final result in mirrors.probeCategory(widget.category)) {
        if (!mounted) return;
        setState(() {
          _results = Map<String, MirrorProbeResult>.of(_results)
            ..[result.entry.id] = result;
        });
      }
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: AppLocalizations.of(context)!.workspaceEnvMirrorsFailed,
        type: NotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _probing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final env = context.watch<EnvironmentProvider>();
    final selection = env.mirrors[widget.category];
    final entries = MirrorService.entriesFor(widget.category);
    final selectedId =
        selection?.mirrorId ??
        MirrorService.findEntry(
          widget.category,
          url: selection?.selectedBaseUrl,
        )?.id;
    final useMirror = selection?.useMirror ?? false;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        SectionCard(
          children: [
            EnvironmentSwitchRow(
              switchKey: EnvironmentPaneKeys.useMirror(widget.category),
              label: l10n.workspaceEnvUseMirror,
              subtitle: l10n.workspaceEnvUseMirrorSubtitle,
              value: useMirror,
              onChanged: _applyingId == null ? _setUseMirror : null,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SectionCard(
          children: [
            for (var i = 0; i < entries.length; i++) ...[
              if (i > 0) const EnvironmentRowDivider(indent: 12),
              _MirrorEntryRow(
                key: MirrorPageBody.rowKey(entries[i].id),
                entry: entries[i],
                selected: selectedId == entries[i].id && useMirror
                    ? true
                    : selectedId == entries[i].id && entries[i].official,
                applying: _applyingId == entries[i].id,
                result: _results[entries[i].id],
                onTap: () => unawaited(_select(entries[i])),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        KeyedSubtree(
          key: MirrorPageBody.speedTestKey,
          child: IosTileButton(
            icon: Lucide.Gauge,
            label: l10n.workspaceEnvSpeedTest,
            enabled: !_probing && _applyingId == null,
            onTap: () => unawaited(_speedTest()),
          ),
        ),
        if (_probing) ...[
          const SizedBox(height: 12),
          Text(
            l10n.workspaceEnvDetectingMirrors,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ],
    );
  }
}

class _MirrorEntryRow extends StatelessWidget {
  const _MirrorEntryRow({
    super.key,
    required this.entry,
    required this.selected,
    required this.applying,
    required this.onTap,
    this.result,
  });

  final MirrorEntry entry;
  final bool selected;
  final bool applying;
  final VoidCallback onTap;
  final MirrorProbeResult? result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final name = workspaceEnvMirrorDisplayName(l10n, entry);
    final trailingChildren = <Widget>[];
    if (applying) {
      trailingChildren.add(const EnvironmentInlineSpinner(radius: 8));
    } else {
      if (result != null) {
        trailingChildren.add(
          EnvironmentLatencyCapsule(
            ms: result!.latencyMs,
            timedOut: result!.timedOut,
          ),
        );
      }
      if (selected) {
        if (trailingChildren.isNotEmpty) {
          trailingChildren.add(const SizedBox(width: 8));
        }
        trailingChildren.add(Icon(Lucide.Check, size: 18, color: cs.primary));
      }
    }
    final trailing = trailingChildren.isEmpty
        ? const SizedBox.shrink()
        : Row(mainAxisSize: MainAxisSize.min, children: trailingChildren);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: IosCardPress(
        haptics: false,
        onTap: applying
            ? null
            : () {
                Haptics.light();
                onTap();
              },
        borderRadius: BorderRadius.circular(12),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: AppFontWeights.medium,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      EnvironmentTextCapsule(
                        label: workspaceEnvRegionLabel(l10n, entry.region),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    entry.baseUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            trailing,
          ],
        ),
      ),
    );
  }
}
