import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/services/memory/memory_pipeline.dart';
import '../../../core/services/memory/memory_trace.dart';
import '../../../desktop/setting/memory_dialogs.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/custom_bottom_sheet.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/ios_tile_button.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../utils/platform_utils.dart';
import '../widgets/memory_ui.dart';

/// Debug viewer for the background memory pipeline (Gatekeeper → Extract →
/// Smart Add → Distiller, plus summaries, recall and memory tool calls).
class MemoryTracePage extends StatelessWidget {
  const MemoryTracePage({super.key});

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
        title: Text(l10n.memoryTracePageTitle),
      ),
      body: const MemoryTraceContent(),
    );
  }
}

/// Body of [MemoryTracePage], reused by the desktop pane.
class MemoryTraceContent extends StatelessWidget {
  const MemoryTraceContent({super.key, this.padding});

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final recorder = MemoryTraceRecorder.instance;

    return ListenableBuilder(
      listenable: recorder,
      builder: (context, _) {
        final traces = recorder.traces;
        return ListView(
          padding: padding ?? const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _SectionHeader(title: l10n.memoryTraceRecordingSection),
            _GroupedCard(
              children: [
                _ToggleRow(
                  title: l10n.memoryTraceToggleTitle,
                  subtitle: l10n.memoryTraceToggleSubtitle,
                  value: settings.memoryTraceEnabled,
                  onChanged: (v) =>
                      context.read<SettingsProvider>().setMemoryTraceEnabled(v),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _SectionHeader(title: l10n.memoryTraceRunsSection),
                ),
                if (traces.isNotEmpty)
                  IosTileButton(
                    label: l10n.memoryTraceClearAction,
                    icon: Lucide.Trash2,
                    fontSize: 13,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    onTap: () => _confirmClear(context, recorder),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (!settings.memoryTraceEnabled)
              _EmptyState(
                icon: Lucide.EyeOff,
                title: l10n.memoryTraceDisabledTitle,
                subtitle: l10n.memoryTraceDisabledSubtitle,
              )
            else if (traces.isEmpty)
              _EmptyState(
                icon: Lucide.Brain,
                title: l10n.memoryTraceEmptyTitle,
                subtitle: l10n.memoryTraceEmptySubtitle,
              )
            else
              for (final trace in traces)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TraceCard(
                    trace: trace,
                    onTap: () => _openTraceDetail(context, trace),
                  ),
                ),
          ],
        );
      },
    );
  }

  Future<void> _openTraceDetail(BuildContext context, MemoryTrace trace) async {
    if (PlatformUtils.isDesktopTarget) {
      await showDesktopMemoryTraceDetailDialog(context, trace: trace);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MemoryTraceDetailPage(trace: trace)),
    );
  }

  Future<void> _confirmClear(
    BuildContext context,
    MemoryTraceRecorder recorder,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final bool cleared;
    if (PlatformUtils.isDesktopTarget) {
      cleared = await showDesktopMemoryConfirmDialog(
        context,
        title: l10n.memoryTraceClearSheetTitle,
        message: l10n.memoryTraceClearSheetMessage,
        confirmLabel: l10n.memoryTraceClearConfirm,
      );
    } else {
      cleared =
          await showCustomBottomSheet<bool>(
            context: context,
            title: l10n.memoryTraceClearSheetTitle,
            partialHeightFactor: 0.36,
            builder: (sheetContext, controller) {
              final cs = Theme.of(sheetContext).colorScheme;
              return SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.memoryTraceClearSheetMessage,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: cs.onSurface.withValues(alpha: 0.66),
                      ),
                    ),
                    const SizedBox(height: 18),
                    IosTileButton(
                      label: l10n.memoryTraceClearConfirm,
                      icon: Lucide.Trash2,
                      backgroundColor: cs.error,
                      onTap: () => Navigator.of(sheetContext).pop(true),
                    ),
                    const SizedBox(height: 10),
                    IosTileButton(
                      label: l10n.memoryTraceCancel,
                      icon: Lucide.X,
                      onTap: () => Navigator.of(sheetContext).pop(false),
                    ),
                  ],
                ),
              );
            },
          ) ==
          true;
    }
    if (!cleared) return;
    recorder.clear();
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      message: l10n.memoryTraceClearedToast,
      type: NotificationType.success,
    );
  }
}

/// Full step-by-step view of a single trace.
class MemoryTraceDetailPage extends StatelessWidget {
  const MemoryTraceDetailPage({super.key, required this.trace});

  final MemoryTrace trace;

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
        title: Text(l10n.memoryTraceDetailTitle),
      ),
      body: MemoryTraceDetailContent(trace: trace),
    );
  }
}

/// Body of [MemoryTraceDetailPage], reused by the desktop dialog.
class MemoryTraceDetailContent extends StatelessWidget {
  const MemoryTraceDetailContent({
    super.key,
    required this.trace,
    this.padding,
  });

  final MemoryTrace trace;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding ?? const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _OverviewCard(trace: trace),
        for (final step in trace.steps) ...[
          const SizedBox(height: 12),
          _StepCard(step: step),
        ],
      ],
    );
  }
}

// ── Cards ───────────────────────────────────────────────────────────────────

class _TraceCard extends StatelessWidget {
  const _TraceCard({required this.trace, required this.onTap});

  final MemoryTrace trace;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    final title = (trace.conversationTitle ?? '').trim().isNotEmpty
        ? trace.conversationTitle!.trim()
        : (trace.conversationId ?? '—');
    final assistant = (trace.assistantName ?? '').trim().isNotEmpty
        ? trace.assistantName!.trim()
        : l10n.memoryTraceScopeGlobal;

    final subtitleParts = <String>[
      _fmtTime(trace.startedAt),
      assistant,
      if (trace.duration != null) _fmtDuration(trace.duration!),
      if (trace.repeatCount > 1) l10n.memoryTraceRepeatCount(trace.repeatCount),
    ];

    return IosCardPress(
      baseColor: context.appColors.surfaceCard,
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.26 : 0.38),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Pill(
                  label: _triggerLabel(l10n, trace.trigger),
                  tone: _PillTone.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: AppFontWeights.emphasis,
                      color: cs.onSurface.withValues(alpha: 0.92),
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _OutcomePill(trace: trace),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitleParts.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.60),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Pill(
                  label: _scopeLabel(l10n, trace.scope),
                  tone: _PillTone.neutral,
                ),
                if (trace.steps.isNotEmpty)
                  _Pill(
                    label: l10n.memoryTraceStepsCount(trace.steps.length),
                    tone: _PillTone.neutral,
                  ),
                if (trace.mutationCount > 0)
                  _Pill(
                    label: l10n.memoryTraceMutationsCount(trace.mutationCount),
                    tone: _PillTone.success,
                  ),
                for (final step in trace.steps)
                  if (step.status == MemoryTraceStepStatus.failed)
                    _Pill(label: _stepLabel(l10n, step), tone: _PillTone.error),
              ],
            ),
            if (trace.hasError) ...[
              const SizedBox(height: 10),
              _ErrorLine(
                text: memoryOutcomeLabel(l10n, trace.error!),
                tone: _isSkipOutcome(trace.error!)
                    ? _ErrorLineTone.info
                    : _ErrorLineTone.error,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.trace});

  final MemoryTrace trace;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final items = <_Kv>[
      _Kv(l10n.memoryTraceFieldTime, _fmtTimestamp(trace.startedAt)),
      _Kv(
        l10n.memoryTraceFieldDuration,
        trace.duration == null ? '—' : _fmtDuration(trace.duration!),
      ),
      _Kv(l10n.memoryTraceFieldTrigger, _triggerLabel(l10n, trace.trigger)),
      _Kv(l10n.memoryTraceFieldScope, _scopeLabel(l10n, trace.scope)),
      _Kv(
        l10n.memoryTraceFieldConversation,
        _joinIdentity(trace.conversationTitle, trace.conversationId),
      ),
      _Kv(
        l10n.memoryTraceFieldAssistant,
        trace.assistantId == null
            ? l10n.memoryTraceScopeGlobal
            : _joinIdentity(trace.assistantName, trace.assistantId),
      ),
      _Kv(
        l10n.memoryTraceFieldWindow,
        trace.windowStartOrder == null || trace.windowEndOrder == null
            ? '—'
            : l10n.memoryTraceWindowValue(
                trace.windowSize,
                trace.windowStartOrder!,
                trace.windowEndOrder!,
              ),
      ),
      _Kv(
        l10n.memoryTraceFieldWatermark,
        trace.watermark == null ? '—' : '#${trace.watermark}',
      ),
      _Kv(l10n.memoryTraceFieldOutcome, _outcomeLabel(l10n, trace)),
      if (trace.hasError)
        _Kv(
          l10n.memoryTraceFieldError,
          memoryOutcomeLabel(l10n, trace.error!),
          secondary: trace.error,
        ),
    ];

    return _SectionCard(
      icon: Lucide.BadgeInfo,
      title: l10n.memoryTraceSectionOverview,
      child: _KvGrid(items: items),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.step});

  final MemoryTraceStep step;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final prompt = step.prompt;
    final response = step.rawResponse;
    final parsed = step.parsedResult ?? '';

    return _SectionCard(
      icon: _stepIcon(step.kind),
      title: _stepLabel(l10n, step),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (step.duration != null) ...[
            Text(
              _fmtDuration(step.duration!),
              style: TextStyle(
                fontSize: 12,
                fontWeight: AppFontWeights.emphasis,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(width: 8),
          ],
          _StatusPill(status: step.status),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((step.error ?? '').isNotEmpty) ...[
            _ErrorLine(
              text: memoryOutcomeLabel(l10n, step.error!),
              tone: _isSkipOutcome(step.error!)
                  ? _ErrorLineTone.info
                  : _ErrorLineTone.error,
            ),
            const SizedBox(height: 12),
          ],
          if (prompt.isNotEmpty) ...[
            _CollapsibleCode(
              label: l10n.memoryTraceSectionPrompt,
              text: prompt,
            ),
            const SizedBox(height: 12),
          ],
          if (response.isNotEmpty) ...[
            _CollapsibleCode(
              label: l10n.memoryTraceSectionResponse,
              text: response,
            ),
            const SizedBox(height: 12),
          ],
          if (parsed.isNotEmpty) ...[
            _CollapsibleCode(
              label: l10n.memoryTraceSectionParsed,
              text: parsed,
            ),
            const SizedBox(height: 12),
          ],
          if (step.mutations.isNotEmpty) ...[
            _FieldLabel(text: l10n.memoryTraceSectionMutations),
            const SizedBox(height: 8),
            for (final mutation in step.mutations) ...[
              _MutationTile(mutation: mutation),
              if (mutation != step.mutations.last) const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class _MutationTile extends StatelessWidget {
  const _MutationTile({required this.mutation});

  final MemoryTraceMutation mutation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    final header = <String>[
      if (mutation.targetId != null) mutation.targetId!,
      if (mutation.label != null) mutation.label!,
    ].join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: context.appColors.surfaceFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.22 : 0.34),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Pill(
                label: _mutationLabel(l10n, mutation.kind),
                tone: _mutationTone(mutation.kind),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  header,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    color: cs.onSurface.withValues(alpha: 0.62),
                  ),
                ),
              ),
            ],
          ),
          if (mutation.before != null) ...[
            const SizedBox(height: 8),
            _BeforeAfterLine(
              label: l10n.memoryTraceBefore,
              value: mutation.before!,
              strike: true,
            ),
          ],
          if (mutation.after != null) ...[
            const SizedBox(height: 6),
            _BeforeAfterLine(
              label: l10n.memoryTraceAfter,
              value: mutation.after!,
              strike: false,
            ),
          ],
        ],
      ),
    );
  }
}

class _BeforeAfterLine extends StatelessWidget {
  const _BeforeAfterLine({
    required this.label,
    required this.value,
    required this.strike,
  });

  final String label;
  final String value;
  final bool strike;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: AppFontWeights.emphasis,
              color: cs.onSurface.withValues(alpha: 0.50),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SelectableText(
            value,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.3,
              color: cs.onSurface.withValues(alpha: strike ? 0.55 : 0.88),
              decoration: strike ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// Long prompt / response text: monospace, copyable, collapsed by default.
class _CollapsibleCode extends StatefulWidget {
  const _CollapsibleCode({required this.label, required this.text});

  final String label;
  final String text;

  @override
  State<_CollapsibleCode> createState() => _CollapsibleCodeState();
}

class _CollapsibleCodeState extends State<_CollapsibleCode> {
  static const int _previewChars = 420;

  bool _expanded = false;

  Future<void> _copy() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await Clipboard.setData(ClipboardData(text: widget.text));
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: l10n.memoryTraceCopiedToast,
        type: NotificationType.success,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    final long = widget.text.length > _previewChars;
    final shown = (!long || _expanded)
        ? widget.text
        : '${widget.text.substring(0, _previewChars)}…';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _FieldLabel(text: widget.label)),
            IosIconButton(
              icon: Lucide.Copy,
              size: 16,
              padding: const EdgeInsets.all(6),
              semanticLabel: l10n.memoryTraceCopyAction,
              onTap: _copy,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.appColors.surfaceFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: isDark ? 0.22 : 0.34),
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: SelectableText(
            shown,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11.5,
              height: 1.4,
              color: cs.onSurface.withValues(alpha: 0.86),
            ),
          ),
        ),
        if (long) ...[
          const SizedBox(height: 6),
          IosCardPress(
            baseColor: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            padding: EdgeInsets.zero,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _expanded ? Lucide.ChevronUp : Lucide.ChevronDown,
                    size: 15,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _expanded
                        ? l10n.memoryTraceShowLess
                        : l10n.memoryTraceShowMore,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: AppFontWeights.semibold,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Small shared pieces ─────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: AppFontWeights.semibold,
          color: cs.onSurface.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}

class _GroupedCard extends StatelessWidget {
  const _GroupedCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.appColors.hairline,
          width: 0.6,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: AppFontWeights.semibold,
                    color: cs.onSurface.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.25,
                    color: cs.onSurface.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IosSwitch(value: value, semanticLabel: title, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SectionCard(
      variant: SectionCardVariant.emphasized,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: cs.onSurface.withValues(alpha: 0.78)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: AppFontWeights.heavy,
                    color: cs.onSurface.withValues(alpha: 0.90),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: AppFontWeights.emphasis,
        color: cs.onSurface.withValues(alpha: 0.55),
      ),
    );
  }
}

enum _ErrorLineTone { error, info }

class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.text, this.tone = _ErrorLineTone.error});

  final String text;
  final _ErrorLineTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isInfo = tone == _ErrorLineTone.info;
    final accent = isInfo
        ? cs.onSurface.withValues(alpha: isDark ? 0.78 : 0.70)
        : cs.error.withValues(alpha: isDark ? 0.92 : 0.86);
    final fill = isInfo
        ? cs.onSurface.withValues(alpha: isDark ? 0.10 : 0.05)
        : Color.alphaBlend(
            cs.error.withValues(alpha: isDark ? 0.12 : 0.07),
            context.appColors.surfaceFill,
          );
    final border = isInfo
        ? cs.onSurface.withValues(alpha: isDark ? 0.16 : 0.10)
        : cs.error.withValues(alpha: isDark ? 0.32 : 0.22);

    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isInfo ? Lucide.BadgeInfo : Lucide.XCircle,
            size: 16,
            color: accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              text,
              style: TextStyle(
                fontFamily: isInfo ? null : 'monospace',
                fontSize: isInfo ? 12.5 : 11.5,
                height: 1.3,
                color: cs.onSurface.withValues(alpha: 0.86),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 42, color: cs.onSurface.withValues(alpha: 0.26)),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: AppFontWeights.semibold,
              color: cs.onSurface.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: cs.onSurface.withValues(alpha: 0.52),
            ),
          ),
        ],
      ),
    );
  }
}

enum _PillTone { neutral, accent, success, warning, error }

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.tone});

  final String label;
  final _PillTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final Color fg = switch (tone) {
      _PillTone.neutral => cs.onSurface.withValues(alpha: isDark ? 0.78 : 0.70),
      _PillTone.accent => cs.primary,
      _PillTone.success => context.appColors.success,
      _PillTone.warning => context.appColors.warning,
      _PillTone.error => cs.error.withValues(alpha: isDark ? 0.92 : 0.88),
    };
    final Color bg = tone == _PillTone.neutral
        ? cs.onSurface.withValues(alpha: isDark ? 0.10 : 0.05)
        : fg.withValues(alpha: isDark ? 0.20 : 0.13);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: AppFontWeights.emphasis,
          letterSpacing: -0.1,
          color: fg,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final MemoryTraceStepStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (String label, _PillTone tone) = switch (status) {
      MemoryTraceStepStatus.success => (
        l10n.memoryTraceStatusSuccess,
        _PillTone.success,
      ),
      MemoryTraceStepStatus.failed => (
        l10n.memoryTraceStatusFailed,
        _PillTone.error,
      ),
      MemoryTraceStepStatus.skipped => (
        l10n.memoryTraceStatusSkipped,
        _PillTone.neutral,
      ),
      MemoryTraceStepStatus.running => (
        l10n.memoryTraceStatusRunning,
        _PillTone.warning,
      ),
    };
    return _Pill(label: label, tone: tone);
  }
}

class _OutcomePill extends StatelessWidget {
  const _OutcomePill({required this.trace});

  final MemoryTrace trace;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (trace.forcedAdvance) {
      return _Pill(
        label: l10n.memoryTraceOutcomeForced,
        tone: _PillTone.warning,
      );
    }
    if (trace.advanced) {
      return _Pill(
        label: l10n.memoryTraceOutcomeAdvanced,
        tone: _PillTone.success,
      );
    }
    final error = trace.error;
    final skip = error != null && error.isNotEmpty && _isSkipOutcome(error);
    return _Pill(
      label: l10n.memoryTraceOutcomeHeld,
      tone: trace.hasError && !skip ? _PillTone.error : _PillTone.neutral,
    );
  }
}

class _Kv {
  const _Kv(this.k, this.v, {this.secondary});

  final String k;
  final String v;
  final String? secondary;
}

class _KvGrid extends StatelessWidget {
  const _KvGrid({required this.items});

  final List<_Kv> items;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final it in items) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 92,
                child: Text(
                  it.k,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: AppFontWeights.emphasis,
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      it.v,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: AppFontWeights.emphasis,
                        color: cs.onSurface.withValues(alpha: 0.86),
                        height: 1.2,
                      ),
                    ),
                    if (it.secondary != null &&
                        it.secondary!.isNotEmpty &&
                        it.secondary != it.v)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: SelectableText(
                          it.secondary!,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.48),
                            height: 1.2,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (it != items.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

// ── Formatting ──────────────────────────────────────────────────────────────

String _joinIdentity(String? name, String? id) {
  final n = (name ?? '').trim();
  final i = (id ?? '').trim();
  if (n.isEmpty && i.isEmpty) return '—';
  if (n.isEmpty) return i;
  if (i.isEmpty) return n;
  return '$n ($i)';
}

String _triggerLabel(AppLocalizations l10n, MemoryTraceTrigger trigger) {
  return switch (trigger) {
    MemoryTraceTrigger.autoTurns => l10n.memoryTraceTriggerAuto,
    MemoryTraceTrigger.manual => l10n.memoryTraceTriggerManual,
    MemoryTraceTrigger.toolCall => l10n.memoryTraceTriggerTool,
    MemoryTraceTrigger.conversationSummary => l10n.memoryTraceTriggerSummary,
  };
}

String _scopeLabel(AppLocalizations l10n, MemoryTraceScope scope) {
  return switch (scope) {
    MemoryTraceScope.assistant => l10n.memoryTraceScopeAssistant,
    MemoryTraceScope.global => l10n.memoryTraceScopeGlobal,
  };
}

String _outcomeLabel(AppLocalizations l10n, MemoryTrace trace) {
  if (trace.forcedAdvance) return l10n.memoryTraceOutcomeForced;
  return trace.advanced
      ? l10n.memoryTraceOutcomeAdvanced
      : l10n.memoryTraceOutcomeHeld;
}

bool _isSkipOutcome(String code) {
  if (MemoryPipelineService.skipReasonCodes.contains(code)) return true;
  final colon = code.indexOf(':');
  if (colon <= 0) return false;
  return MemoryPipelineService.skipReasonCodes.contains(
    code.substring(0, colon),
  );
}

String _stepLabel(AppLocalizations l10n, MemoryTraceStep step) {
  final base = switch (step.kind) {
    MemoryTraceStepKind.gatekeeper => l10n.memoryTraceStepGatekeeper,
    MemoryTraceStepKind.extract => l10n.memoryTraceStepExtract,
    MemoryTraceStepKind.smartAdd => l10n.memoryTraceStepSmartAdd,
    MemoryTraceStepKind.profileDistiller => l10n.memoryTraceStepDistiller,
    MemoryTraceStepKind.conversationSummary => l10n.memoryTraceStepSummary,
    MemoryTraceStepKind.chatSearch => l10n.memoryTraceStepChatSearch,
    MemoryTraceStepKind.memoryTool => l10n.memoryTraceStepTool,
  };
  final label = (step.label ?? '').trim();
  return label.isEmpty ? base : '$base · $label';
}

IconData _stepIcon(MemoryTraceStepKind kind) {
  return switch (kind) {
    MemoryTraceStepKind.gatekeeper => Lucide.Shield,
    MemoryTraceStepKind.extract => Lucide.ListTree,
    MemoryTraceStepKind.smartAdd => Lucide.Sparkles,
    MemoryTraceStepKind.profileDistiller => Lucide.User,
    MemoryTraceStepKind.conversationSummary => Lucide.FileText,
    MemoryTraceStepKind.chatSearch => Lucide.Search,
    MemoryTraceStepKind.memoryTool => Lucide.Wrench,
  };
}

String _mutationLabel(AppLocalizations l10n, MemoryTraceMutationKind kind) {
  return switch (kind) {
    MemoryTraceMutationKind.memoryCreated => l10n.memoryTraceMutationCreated,
    MemoryTraceMutationKind.memoryMerged => l10n.memoryTraceMutationMerged,
    MemoryTraceMutationKind.memoryEdited => l10n.memoryTraceMutationEdited,
    MemoryTraceMutationKind.memoryArchived => l10n.memoryTraceMutationArchived,
    MemoryTraceMutationKind.memoryLinked => l10n.memoryTraceMutationLinked,
    MemoryTraceMutationKind.profileFieldWritten =>
      l10n.memoryTraceMutationProfileWritten,
    MemoryTraceMutationKind.profileFieldCleared =>
      l10n.memoryTraceMutationProfileCleared,
    MemoryTraceMutationKind.conversationSummaryWritten =>
      l10n.memoryTraceMutationSummary,
  };
}

_PillTone _mutationTone(MemoryTraceMutationKind kind) {
  return switch (kind) {
    MemoryTraceMutationKind.memoryCreated ||
    MemoryTraceMutationKind.profileFieldWritten ||
    MemoryTraceMutationKind.conversationSummaryWritten => _PillTone.success,
    MemoryTraceMutationKind.memoryMerged ||
    MemoryTraceMutationKind.memoryEdited => _PillTone.accent,
    MemoryTraceMutationKind.memoryArchived ||
    MemoryTraceMutationKind.profileFieldCleared => _PillTone.warning,
    MemoryTraceMutationKind.memoryLinked => _PillTone.neutral,
  };
}

String _two(int v) => v.toString().padLeft(2, '0');

String _fmtTime(DateTime dt) =>
    '${_two(dt.hour)}:${_two(dt.minute)}:${_two(dt.second)}';

String _fmtTimestamp(DateTime dt) =>
    '${dt.year}-${_two(dt.month)}-${_two(dt.day)} ${_fmtTime(dt)}';

String _fmtDuration(Duration d) {
  if (d.inMilliseconds < 1000) return '${d.inMilliseconds}ms';
  if (d.inSeconds < 60) {
    return '${(d.inMilliseconds / 1000).toStringAsFixed(1)}s';
  }
  final m = d.inMinutes;
  return '${m}m ${d.inSeconds - m * 60}s';
}
