import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

import '../../../core/models/assistant_memory.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/memory_provider.dart';
import '../../../core/providers/memory_provider_v2.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/memory/legacy_memory_migration.dart';
import '../../../core/services/memory/memory_prompts.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_tile_button.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../utils/platform_utils.dart';
import '../../model/widgets/model_select_sheet.dart';
import '../widgets/memory_ui.dart';

/// Read-only legacy memories from [MemoryProvider] (§14.5 / D-29).
class LegacyMemoryPage extends StatelessWidget {
  const LegacyMemoryPage({super.key, this.assistantId});

  /// When set, only legacy memories of that assistant are listed and exported.
  final String? assistantId;

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
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(l10n.legacyMemoryPageTitle),
        actions: [
          Tooltip(
            message: l10n.legacyMemoryExport,
            child: IosIconButton(
              icon: Lucide.Share2,
              color: cs.onSurface,
              size: 20,
              minSize: 44,
              onTap: () => LegacyMemoryContent.exportAll(
                context,
                assistantId: assistantId,
              ),
            ),
          ),
          Tooltip(
            message: l10n.legacyMemoryMigrate,
            child: IosIconButton(
              icon: Lucide.Import,
              color: cs.primary,
              size: 20,
              minSize: 44,
              semanticLabel: l10n.legacyMemoryMigrate,
              onTap: () => LegacyMemoryContent.showMigration(
                context,
                assistantId: assistantId,
              ),
            ),
          ),
        ],
      ),
      body: LegacyMemoryContent(assistantId: assistantId),
    );
  }
}

class LegacyMemoryContent extends StatefulWidget {
  const LegacyMemoryContent({super.key, this.padding, this.assistantId});

  final EdgeInsetsGeometry? padding;

  /// When set, only legacy memories of that assistant are listed.
  final String? assistantId;

  static String buildExportText({
    required AppLocalizations l10n,
    required List<AssistantMemory> memories,
    required String Function(String assistantId) assistantName,
    DateTime? now,
  }) {
    final stamp = DateFormat('yyyy-MM-dd HH:mm').format(now ?? DateTime.now());
    final buf = StringBuffer()
      ..writeln('# ${l10n.legacyMemoryExportTitle}')
      ..writeln('# $stamp')
      ..writeln();
    final byAssistant = <String, List<AssistantMemory>>{};
    for (final m in memories) {
      byAssistant.putIfAbsent(m.assistantId, () => []).add(m);
    }
    for (final entry in byAssistant.entries) {
      buf.writeln(
        '## ${l10n.legacyMemoryAssistantHeader(assistantName(entry.key))}',
      );
      for (final m in entry.value) {
        buf.writeln('- ${m.content}');
      }
      buf.writeln();
    }
    return buf.toString().trimRight();
  }

  static Future<void> exportAll(
    BuildContext context, {
    String? assistantId,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final mp = context.read<MemoryProvider>();
    final ap = context.read<AssistantProvider>();
    await mp.initialize();
    if (!context.mounted) return;
    final memories = assistantId == null
        ? mp.memories
        : mp.memories.where((m) => m.assistantId == assistantId).toList();
    final text = buildExportText(
      l10n: l10n,
      memories: memories,
      assistantName: (id) => ap.getById(id)?.name ?? id,
    );
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/kelivo-legacy-memory-${DateTime.now().millisecondsSinceEpoch}.txt',
    );
    await file.writeAsString(text);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  static Future<void> showMigration(
    BuildContext context, {
    String? assistantId,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<MemoryProvider>();
    await provider.initialize();
    if (!context.mounted) return;
    final memories = assistantId == null
        ? provider.memories
        : provider.memories
              .where((memory) => memory.assistantId == assistantId)
              .toList(growable: false);
    if (memories.isEmpty) {
      showAppSnackBar(
        context,
        message: l10n.legacyMemoryEmpty,
        type: NotificationType.info,
      );
      return;
    }
    await _showLegacyMemoryMigration(
      context,
      memories: memories,
      assistantId: assistantId,
    );
  }

  @override
  State<LegacyMemoryContent> createState() => _LegacyMemoryContentState();
}

class _LegacyMemoryContentState extends State<LegacyMemoryContent> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MemoryProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mp = context.watch<MemoryProvider>();
    final ap = context.watch<AssistantProvider>();
    final q = _search.text.trim().toLowerCase();
    final assistantFilter = widget.assistantId;
    final memories = mp.memories.where((m) {
      if (assistantFilter != null && m.assistantId != assistantFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return m.content.toLowerCase().contains(q);
    }).toList();
    final byAssistant = <String, List<AssistantMemory>>{};
    for (final m in memories) {
      byAssistant.putIfAbsent(m.assistantId, () => []).add(m);
    }

    return ListView(
      padding: widget.padding ?? const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Container(
          decoration: BoxDecoration(
            color: cs.secondaryContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Lucide.BadgeInfo, size: 18, color: cs.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.legacyMemoryBanner,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: cs.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MemorySearchField(
          controller: _search,
          hintText: l10n.legacyMemorySearchHint,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        if (byAssistant.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                l10n.legacyMemoryEmpty,
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.55)),
              ),
            ),
          )
        else
          for (final entry in byAssistant.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
              child: Text(
                l10n.legacyMemoryAssistantHeader(
                  ap.getById(entry.key)?.name ?? entry.key,
                ),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: AppFontWeights.semibold,
                ),
              ),
            ),
            for (final m in entry.value)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: context.appColors.surfaceCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(
                        alpha: isDark ? 0.08 : 0.06,
                      ),
                      width: 0.6,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            m.content,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Tooltip(
                          message: l10n.legacyMemoryCopy,
                          child: IosIconButton(
                            icon: Lucide.Copy,
                            size: 18,
                            color: cs.primary,
                            minSize: 32,
                            onTap: () async {
                              await Clipboard.setData(
                                ClipboardData(text: m.content),
                              );
                              if (!context.mounted) return;
                              showAppSnackBar(
                                context,
                                message: l10n.legacyMemoryCopied,
                                type: NotificationType.success,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
      ],
    );
  }
}

Future<void> _showLegacyMemoryMigration(
  BuildContext context, {
  required List<AssistantMemory> memories,
  required String? assistantId,
}) {
  final panel = _LegacyMemoryMigrationPanel(
    memories: memories,
    assistantId: assistantId,
  );
  if (PlatformUtils.isDesktopTarget) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: dialogContext.overlaySurface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
          child: panel,
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.9,
            ),
            child: Material(
              color: sheetContext.appColors.surfaceCard,
              elevation: 0,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: panel,
            ),
          ),
        ),
      );
    },
  );
}

class _LegacyMemoryMigrationPanel extends StatefulWidget {
  const _LegacyMemoryMigrationPanel({
    required this.memories,
    required this.assistantId,
  });

  final List<AssistantMemory> memories;
  final String? assistantId;

  @override
  State<_LegacyMemoryMigrationPanel> createState() =>
      _LegacyMemoryMigrationPanelState();
}

class _LegacyMemoryMigrationPanelState
    extends State<_LegacyMemoryMigrationPanel> {
  static const List<int> _batchSizeOptions = <int>[6, 8, 12, 16, 24];

  ModelSelection? _model;
  LegacyMemoryMigrationTarget _target = LegacyMemoryMigrationTarget.assistant;
  bool _preserveOriginal = true;
  LegacyMemoryMigrationProgress? _progress;
  LegacyMemoryMigrationResult? _result;
  bool _loadedInitialModel = false;
  bool _running = false;
  bool _failed = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedInitialModel) return;
    _loadedInitialModel = true;
    final settings = context.read<SettingsProvider>();
    final provider = settings.memoryModelProvider;
    final model = settings.memoryModelId;
    if (provider != null && model != null) {
      _model = ModelSelection(provider, model);
    }
  }

  String _modelLabel(AppLocalizations l10n) {
    final selection = _model;
    if (selection == null) return l10n.legacyMemoryMigrationChooseModel;
    final config = context.read<SettingsProvider>().getProviderConfig(
      selection.providerKey,
    );
    final providerName = config.name.trim().isEmpty
        ? selection.providerKey
        : config.name.trim();
    return '$providerName / ${selection.modelId}';
  }

  Future<void> _pickModel() async {
    if (_running) return;
    final selection = await showModelSelector(
      context,
      initialProviderKey: _model?.providerKey,
      initialModelId: _model?.modelId,
    );
    if (!mounted || selection == null) return;
    setState(() => _model = selection);
  }

  Future<void> _runMigration() async {
    final selection = _model;
    if (selection == null || _running) return;
    final settings = context.read<SettingsProvider>();
    final memory = context.read<MemoryProviderV2>();
    final lang = settings.resolvedMemoryPromptLang;
    final service = LegacyMemoryMigrationService(
      repository: memory.repository,
      batchSize: settings.memoryMigrationBatchSize,
    );
    setState(() {
      _running = true;
      _failed = false;
      _error = null;
      _result = null;
      _progress = LegacyMemoryMigrationProgress(
        phase: LegacyMemoryMigrationPhase.analyzing,
        processed: 0,
        total: widget.memories.length,
      );
    });

    try {
      final result = await service.migrate(
        inputs: [
          for (final memory in widget.memories)
            LegacyMemoryMigrationInput(
              legacyId: memory.id,
              assistantId: memory.assistantId,
              content: memory.content,
            ),
        ],
        target: _target,
        config: settings.getProviderConfig(selection.providerKey),
        modelId: selection.modelId,
        preserveOriginal: _preserveOriginal,
        promptTemplate: _preserveOriginal
            ? MemoryPrompts.migratePreserveFor(lang)
            : (lang == MemoryPromptLang.zh
                  ? settings.memoryMigratePromptZh
                  : settings.memoryMigratePromptEn),
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _progress = progress);
        },
      );
      await memory.reloadCurrentScope();
      if (!mounted) return;
      setState(() {
        _running = false;
        _result = result;
        _error = result.errorMessage;
      });
    } catch (error, stackTrace) {
      debugPrint('Legacy memory migration failed: $error\n$stackTrace');
      await memory.reloadCurrentScope();
      if (!mounted) return;
      setState(() {
        _running = false;
        _failed = true;
        _error = error.toString();
      });
    }
  }

  void _close() {
    if (_running) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<SettingsProvider>();
    final batchSize = settings.memoryMigrationBatchSize;
    final batchSizes = <int>{..._batchSizeOptions, batchSize}.toList()..sort();
    final complete = _result != null && _result!.failed == 0;
    final partial = _result != null && _result!.failed > 0;
    final targetAssistantLabel = widget.assistantId == null
        ? l10n.legacyMemoryMigrationTargetOriginalAssistants
        : l10n.legacyMemoryMigrationTargetAssistant;
    final targetAssistantDescription = widget.assistantId == null
        ? l10n.legacyMemoryMigrationTargetOriginalDescription
        : l10n.legacyMemoryMigrationTargetAssistantDescription;
    final progress = _progress;

    return PopScope(
      canPop: !_running,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: isDark ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(Lucide.Import, size: 20, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      l10n.legacyMemoryMigrationTitle,
                      style: TextStyle(
                        fontSize: 18,
                        height: 1.25,
                        fontWeight: AppFontWeights.semibold,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ),
                IosIconButton(
                  icon: Lucide.X,
                  size: 18,
                  minSize: 36,
                  color: cs.onSurface,
                  enabled: !_running,
                  semanticLabel: MaterialLocalizations.of(
                    context,
                  ).closeButtonTooltip,
                  onTap: _close,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.legacyMemoryMigrationSubtitle(widget.memories.length),
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: cs.onSurface.withValues(alpha: 0.68),
              ),
            ),
            if (complete) ...[
              const SizedBox(height: 28),
              _MigrationResultView(result: _result!),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: IosTileButton(
                  label: l10n.legacyMemoryMigrationClose,
                  icon: Lucide.Check,
                  backgroundColor: cs.primary,
                  onTap: _close,
                ),
              ),
            ] else ...[
              const SizedBox(height: 20),
              _MigrationFieldLabel(text: l10n.legacyMemoryMigrationModel),
              MemorySectionCard(
                children: [
                  MemoryNavRow(
                    title: l10n.legacyMemoryMigrationModel,
                    subtitle: _modelLabel(l10n),
                    onTap: _pickModel,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _MigrationFieldLabel(text: l10n.legacyMemoryMigrationTarget),
              MemorySectionCard(
                padding: const EdgeInsets.all(12),
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        MemorySelectChip(
                          label: l10n.legacyMemoryMigrationTargetGlobal,
                          icon: Lucide.Globe,
                          selected:
                              _target == LegacyMemoryMigrationTarget.global,
                          onTap: _running
                              ? null
                              : () => setState(
                                  () => _target =
                                      LegacyMemoryMigrationTarget.global,
                                ),
                        ),
                        MemorySelectChip(
                          label: targetAssistantLabel,
                          icon: Lucide.Bot,
                          selected:
                              _target == LegacyMemoryMigrationTarget.assistant,
                          onTap: _running
                              ? null
                              : () => setState(
                                  () => _target =
                                      LegacyMemoryMigrationTarget.assistant,
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      _target == LegacyMemoryMigrationTarget.global
                          ? l10n.legacyMemoryMigrationTargetGlobalDescription
                          : targetAssistantDescription,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: cs.onSurface.withValues(alpha: 0.58),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _MigrationFieldLabel(text: l10n.legacyMemoryMigrationContentMode),
              MemorySectionCard(
                padding: const EdgeInsets.all(12),
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        MemorySelectChip(
                          label: l10n.legacyMemoryMigrationContentPreserve,
                          selected: _preserveOriginal,
                          onTap: _running
                              ? null
                              : () => setState(() => _preserveOriginal = true),
                        ),
                        MemorySelectChip(
                          label: l10n.legacyMemoryMigrationContentOrganize,
                          selected: !_preserveOriginal,
                          onTap: _running
                              ? null
                              : () => setState(() => _preserveOriginal = false),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      _preserveOriginal
                          ? l10n.legacyMemoryMigrationContentPreserveDescription
                          : l10n.legacyMemoryMigrationContentOrganizeDescription,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: cs.onSurface.withValues(alpha: 0.58),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _MigrationFieldLabel(text: l10n.legacyMemoryMigrationBatchSize),
              MemorySectionCard(
                padding: const EdgeInsets.all(12),
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final size in batchSizes)
                          MemorySelectChip(
                            label: '$size',
                            selected: batchSize == size,
                            onTap: _running
                                ? null
                                : () => unawaited(
                                    settings.setMemoryMigrationBatchSize(size),
                                  ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_running && progress != null) ...[
                const SizedBox(height: 20),
                _MigrationProgressView(progress: progress),
              ],
              if (_failed) ...[
                const SizedBox(height: 16),
                _MigrationMessageCard(
                  icon: Lucide.TriangleAlert,
                  color: cs.error,
                  text: [
                    l10n.legacyMemoryMigrationFailed,
                    if (_error != null) _legacyMigrationErrorText(_error, l10n),
                  ].join('\n'),
                ),
              ],
              if (partial) ...[
                const SizedBox(height: 16),
                _MigrationMessageCard(
                  icon: Lucide.TriangleAlert,
                  color: cs.error,
                  text: [
                    l10n.legacyMemoryMigrationPartial(
                      _result!.created,
                      _result!.skipped,
                      _result!.failed,
                    ),
                    if (_error != null) _legacyMigrationErrorText(_error, l10n),
                  ].join('\n'),
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: IosTileButton(
                  label: partial
                      ? l10n.legacyMemoryMigrationContinue
                      : (_failed
                            ? l10n.legacyMemoryMigrationRetry
                            : l10n.legacyMemoryMigrationStart),
                  icon: partial || _failed ? Lucide.RefreshCw : Lucide.Import,
                  backgroundColor: cs.primary,
                  enabled: _model != null && !_running,
                  onTap: () => unawaited(_runMigration()),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MigrationMessageCard extends StatelessWidget {
  const _MigrationMessageCard({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: cs.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _legacyMigrationErrorText(Object? error, AppLocalizations l10n) {
  final raw = error?.toString() ?? '';
  final lower = raw.toLowerCase();
  if (_isLegacyMigrationNetworkError(error, lower)) {
    return l10n.legacyMemoryMigrationErrorNetwork;
  }
  if (_isLegacyMigrationAuthError(lower)) {
    return l10n.legacyMemoryMigrationErrorAuth;
  }
  if (_isLegacyMigrationFormatError(error, lower)) {
    return l10n.legacyMemoryMigrationErrorFormat;
  }
  final trimmed = raw.trim();
  final truncated = trimmed.length > 180
      ? '${trimmed.substring(0, 180)}…'
      : trimmed;
  return l10n.legacyMemoryMigrationErrorOther(
    truncated.isEmpty ? error.runtimeType.toString() : truncated,
  );
}

bool _isLegacyMigrationNetworkError(Object? error, String lower) {
  if (error is SocketException || error is HandshakeException) return true;
  if (error is TimeoutException) return true;
  return lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('connection refused') ||
      lower.contains('network is unreachable') ||
      lower.contains('timed out') ||
      lower.contains('timeout') ||
      lower.contains('connection reset') ||
      lower.contains('clientexception');
}

bool _isLegacyMigrationAuthError(String lower) {
  return lower.contains('401') ||
      lower.contains('403') ||
      lower.contains('unauthorized') ||
      lower.contains('forbidden') ||
      lower.contains('invalid api key') ||
      lower.contains('invalid_api_key') ||
      lower.contains('authentication');
}

bool _isLegacyMigrationFormatError(Object? error, String lower) {
  if (error is FormatException) return true;
  return lower.contains('formatexception') ||
      lower.contains('legacy_memory_response');
}

class _MigrationFieldLabel extends StatelessWidget {
  const _MigrationFieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 7),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: AppFontWeights.semibold,
          color: cs.onSurface.withValues(alpha: 0.72),
        ),
      ),
    );
  }
}

class _MigrationProgressView extends StatelessWidget {
  const _MigrationProgressView({required this.progress});

  final LegacyMemoryMigrationProgress progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = progress.phase == LegacyMemoryMigrationPhase.analyzing
        ? l10n.legacyMemoryMigrationAnalyzing
        : l10n.legacyMemoryMigrationWriting;
    return Semantics(
      liveRegion: true,
      label: label,
      value: l10n.legacyMemoryMigrationProgress(
        progress.processed,
        progress.total,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: AppFontWeights.semibold,
                    color: cs.onSurface.withValues(alpha: 0.78),
                  ),
                ),
              ),
              Text(
                l10n.legacyMemoryMigrationProgress(
                  progress.processed,
                  progress.total,
                ),
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.56),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                height: 6,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: isDark ? 0.13 : 0.09),
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: AlignmentDirectional.centerStart,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  width: constraints.maxWidth * progress.fraction,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MigrationResultView extends StatelessWidget {
  const _MigrationResultView({required this.result});

  final LegacyMemoryMigrationResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      liveRegion: true,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primary.withValues(alpha: isDark ? 0.18 : 0.10),
            ),
            child: Icon(Lucide.Check, size: 26, color: cs.primary),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.legacyMemoryMigrationComplete,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: AppFontWeights.semibold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.legacyMemoryMigrationResult(result.created, result.skipped),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: cs.onSurface.withValues(alpha: 0.62),
            ),
          ),
        ],
      ),
    );
  }
}
