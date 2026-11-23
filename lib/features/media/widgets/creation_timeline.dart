import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/media_creation.dart';
import '../../../desktop/desktop_settings_navigation_bus.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';
import '../../provider/pages/providers_page.dart';
import '../../provider/widgets/provider_avatar.dart';
import '../providers/media_creation_controller.dart';
import 'creation_lightbox.dart';
import 'creation_waiting_card.dart';

class CreationTimeline extends StatelessWidget {
  const CreationTimeline({
    super.key,
    required this.topicId,
    required this.desktop,
  });

  final String? topicId;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final media = context.watch<MediaCreationController>();
    final batches = topicId == null
        ? const <GenerationBatchRow>[]
        : media.batchesFor(topicId!);
    if (batches.isEmpty) return CreationEmptyState(desktop: desktop);
    return ListView.builder(
      key: ValueKey(topicId),
      reverse: true,
      padding: EdgeInsets.fromLTRB(
        desktop ? 32 : 14,
        14,
        desktop ? 32 : 14,
        160,
      ),
      itemCount: batches.length,
      itemBuilder: (context, index) {
        final sourceIndex = batches.length - 1 - index;
        final batch = batches[sourceIndex];
        final showDate =
            sourceIndex == 0 ||
            !DateUtils.isSameDay(
              batch.createdAt,
              batches[sourceIndex - 1].createdAt,
            );
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showDate) _DateDivider(date: batch.createdAt),
                  _BatchHeader(batch: batch, desktop: desktop),
                  const SizedBox(height: 12),
                  _BatchResults(
                    batch: batch,
                    items: media.itemsFor(batch.id),
                    desktop: desktop,
                  ),
                  if (!batch.status.isActive &&
                      batch.status != GenerationStatus.succeeded)
                    _BatchFailure(batch: batch),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class CreationEmptyState extends StatelessWidget {
  const CreationEmptyState({super.key, this.desktop = false});

  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final missing = context.watch<MediaCreationController>().model == null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 12, 28, 124),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              missing ? Lucide.KeyRound : Lucide.Palette,
              size: 36,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              missing ? l10n.creationNoModelTitle : l10n.creationEmptyTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: AppFontWeights.semibold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              missing ? l10n.creationNoModelBody : l10n.creationEmptyBody,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            if (missing) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  if (desktop) {
                    DesktopSettingsNavigationBus.instance.openProviders();
                  } else {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute(builder: (_) => const ProvidersPage()),
                    );
                  }
                },
                child: Text(l10n.settingsPageProviders),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final label = DateUtils.isSameDay(date, now)
        ? l10n.sideDrawerDateToday
        : DateUtils.isSameDay(date, DateTime(now.year, now.month, now.day - 1))
        ? l10n.sideDrawerDateYesterday
        : MaterialLocalizations.of(context).formatShortMonthDay(date);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Expanded(child: Divider(color: cs.outlineVariant)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 12,
                fontWeight: AppFontWeights.semibold,
              ),
            ),
          ),
          Expanded(child: Divider(color: cs.outlineVariant)),
        ],
      ),
    );
  }
}

class _BatchHeader extends StatefulWidget {
  const _BatchHeader({required this.batch, required this.desktop});
  final GenerationBatchRow batch;
  final bool desktop;

  @override
  State<_BatchHeader> createState() => _BatchHeaderState();
}

class _BatchHeaderState extends State<_BatchHeader> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final batch = widget.batch;
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final media = context.read<MediaCreationController>();
    final p = _parameters(batch);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Text(
                  batch.prompt,
                  maxLines: _expanded ? null : 2,
                  overflow: _expanded ? null : TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14.5, height: 1.55),
                ),
              ),
            ),
            if (batch.status.isActive)
              TextButton.icon(
                onPressed: () => media.runner.cancel(batch.id),
                icon: const Icon(Lucide.Square, size: 13),
                label: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              )
            else
              IosIconButton(
                icon: Lucide.Copy,
                size: 16,
                tooltip: l10n.creationCopyPrompt,
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: batch.prompt));
                  if (context.mounted) {
                    showAppSnackBar(
                      context,
                      message: l10n.creationOptionCopied,
                    );
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 5,
          runSpacing: 5,
          children: [
            Text(
              MaterialLocalizations.of(
                context,
              ).formatTimeOfDay(TimeOfDay.fromDateTime(batch.createdAt)),
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
            _Tag(
              batch.modelId,
              leading: ProviderAvatar(
                providerKey: batch.providerId,
                displayName: batch.providerId,
                size: 15,
              ),
            ),
            if (p.ratio != 'auto') _Tag(p.ratio),
            if (batch.mode == MediaMode.image)
              _Tag(l10n.creationImagesCount(p.count)),
            if (p.duration case final duration?)
              _Tag(l10n.creationDurationSeconds(duration)),
            if (p.resolution case final resolution?) _Tag(resolution),
          ],
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, {this.leading});
  final String label;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.appColors.surfaceFill,
      borderRadius: BorderRadius.circular(7),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 4)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: AppFontWeights.medium,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _BatchResults extends StatelessWidget {
  const _BatchResults({
    required this.batch,
    required this.items,
    required this.desktop,
  });
  final GenerationBatchRow batch;
  final List<GenerationItemRow> items;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final media = context.read<MediaCreationController>();
    final params = _parameters(batch);
    final visible = items
        .where((row) => row.status == GenerationItemStatus.ready)
        .toList();
    final pending = batch.status.isActive
        ? (params.count - visible.length).clamp(0, 16)
        : 0;
    final total = pending + visible.length;
    if (total == 0) return const SizedBox.shrink();
    final requestedRatio =
        params.ratio == 'auto' && batch.mode == MediaMode.video
        ? 16 / 9
        : _ratio(params.ratio);
    final ratio = visible.isEmpty
        ? requestedRatio
        : _itemRatio(visible.first, requestedRatio);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = !desktop || constraints.maxWidth < 400;
        final columns = total < 3
            ? total
            : compact
            ? 2
            : math.min(total, 4);
        final limit = total == 1
            ? ratio < 1
                  ? math.min(400.0, 520 * ratio)
                  : ratio == 1
                  ? 400.0
                  : ratio < 2
                  ? 480.0
                  : constraints.maxWidth
            : total == 2 && ratio <= 1
            ? 560.0
            : constraints.maxWidth;
        final width =
            (math.min(limit, constraints.maxWidth) - (columns - 1) * 8) /
            columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in visible)
              SizedBox(
                width: width,
                child: AspectRatio(
                  aspectRatio: _itemRatio(item, requestedRatio).clamp(.3, 4),
                  child: GestureDetector(
                    onTap: () =>
                        showCreationLightbox(context, item, desktop: desktop),
                    child: Hero(
                      tag: 'creation:${item.id}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CreationMediaCover(item),
                      ),
                    ),
                  ),
                ),
              ),
            for (var index = 0; index < pending; index++)
              SizedBox(
                key: ValueKey((batch.id, index)),
                width: width,
                child: AspectRatio(
                  aspectRatio: ratio.clamp(.3, 4),
                  child: ListenableBuilder(
                    listenable: media.runner,
                    builder: (context, _) => CreationWaitingCard(
                      batch: batch,
                      progress: media.runner.progressFor(batch.id)?.fraction,
                      queueAhead: media.runner.queueAhead(batch.id),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BatchFailure extends StatelessWidget {
  const _BatchFailure({required this.batch});
  final GenerationBatchRow batch;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final media = context.read<MediaCreationController>();
    final title = switch (batch.status) {
      GenerationStatus.interrupted => l10n.creationInterrupted,
      GenerationStatus.cancelled => l10n.creationCancelled,
      GenerationStatus.partial => l10n.creationPartial,
      _ => l10n.creationFailed,
    };
    final danger =
        batch.status == GenerationStatus.failed ||
        batch.status == GenerationStatus.partial;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: danger
              ? cs.error.withValues(alpha: .08)
              : context.appColors.surfaceFill,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Icon(
                danger ? Lucide.CircleAlert : Lucide.Square,
                size: 20,
                color: danger ? cs.error : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: AppFontWeights.semibold,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  try {
                    await media.retry(batch);
                  } catch (_) {
                    if (context.mounted) {
                      showAppSnackBar(
                        context,
                        message: l10n.creationActionFailed,
                      );
                    }
                  }
                },
                icon: const Icon(Lucide.RotateCcw, size: 15),
                label: Text(l10n.creationRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

({int count, String ratio, int? duration, String? resolution}) _parameters(
  GenerationBatchRow row,
) {
  try {
    final params = jsonDecode(row.paramsJson);
    if (params is Map) {
      return (
        count: params['count'] is int
            ? (params['count'] as int).clamp(1, 16)
            : 1,
        ratio: params['aspectRatio'] is String
            ? params['aspectRatio'] as String
            : 'auto',
        duration: params['durationSec'] is int
            ? params['durationSec'] as int
            : null,
        resolution: params['resolution'] is String
            ? params['resolution'] as String
            : null,
      );
    }
  } on FormatException {
    // Render an older or damaged row with ordinary tile dimensions.
  }
  return (count: 1, ratio: 'auto', duration: null, resolution: null);
}

double _ratio(String value) {
  final parts = value.split(':').map(double.tryParse).toList();
  if (parts.length != 2 ||
      parts[0] == null ||
      parts[1] == null ||
      parts[0]! <= 0 ||
      parts[1]! <= 0) {
    return 1;
  }
  return parts[0]! / parts[1]!;
}

double _itemRatio(GenerationItemRow item, double fallback) =>
    (item.width ?? 0) > 0 && (item.height ?? 0) > 0
    ? item.width! / item.height!
    : fallback;
