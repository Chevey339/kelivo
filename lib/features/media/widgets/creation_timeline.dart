import 'creation_menu.dart';
import 'creation_picker.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/media_creation.dart';
import '../../../core/models/provider_oauth.dart';
import '../../../core/services/media/media_request.dart';
import '../../../core/services/model_spec/model_spec_resolver.dart';
import '../../../desktop/desktop_context_menu.dart';
import '../../../desktop/desktop_settings_navigation_bus.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/action_sheet.dart';
import '../../../shared/widgets/sliding_segmented_tabs.dart';
import '../../../shared/widgets/ios_tactile.dart';
import 'creation_toast.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';
import 'creation_controls.dart';
import '../../provider/pages/provider_detail_page.dart';
import '../../provider/pages/providers_page.dart';
import '../../provider/widgets/oauth_login_panel.dart';
import '../../provider/widgets/provider_avatar.dart';
import '../providers/media_creation_controller.dart';
import 'creation_lightbox.dart';
import 'creation_gallery.dart';
import 'creation_waiting_card.dart';

class CreationTimeline extends StatefulWidget {
  const CreationTimeline({
    super.key,
    required this.topicId,
    required this.desktop,
    this.highlightBatchId,
  });

  final String? topicId;
  final String? highlightBatchId;
  final bool desktop;

  @override
  State<CreationTimeline> createState() => _CreationTimelineState();
}

class _CreationTimelineState extends State<CreationTimeline> {
  final _scroll = ItemScrollController();
  String? _lastSeenRequest;
  String? _pendingScroll;
  bool _observed = false;
  String? get topicId => widget.topicId;
  bool get desktop => widget.desktop;

  void _jump(String batchId, List<GenerationBatchRow> batches) {
    final index = batches.reversed.toList().indexWhere(
      (batch) => batch.id == batchId,
    );
    if (index < 0 || !_scroll.isAttached) return;
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      _scroll.jumpTo(index: index, alignment: .20);
    } else {
      unawaited(
        _scroll.scrollTo(
          index: index,
          alignment: .20,
          duration: const Duration(milliseconds: 260),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = context.watch<MediaCreationController>();
    final batches = topicId == null
        ? const <GenerationBatchRow>[]
        : media.batchesFor(topicId!);
    final requested = media.lastSubmission(topicId);
    if (_observed && requested != _lastSeenRequest) _pendingScroll = requested;
    _lastSeenRequest = requested;
    _observed = true;
    final pending = _pendingScroll;
    if (pending != null && batches.any((batch) => batch.id == pending)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _pendingScroll != pending || !_scroll.isAttached) {
          return;
        }
        _pendingScroll = null;
        final id = topicId;
        if (id != null) _jump(pending, media.batchesFor(id));
      });
    }
    if (batches.isEmpty) {
      return CreationEmptyState(desktop: desktop, topicId: topicId);
    }
    final highlight = widget.highlightBatchId;
    final target = highlight == null
        ? -1
        : batches.reversed.toList().indexWhere(
            (batch) => batch.id == highlight,
          );
    final reduced = MediaQuery.disableAnimationsOf(context);
    return ScrollablePositionedList.builder(
      key: ValueKey(topicId),
      itemScrollController: _scroll,
      initialScrollIndex: target < 0 ? 0 : target,
      initialAlignment: target < 0 ? 0 : .28,
      reverse: true,
      padding: EdgeInsets.fromLTRB(
        desktop ? 32 : 14,
        14,
        desktop ? 32 : 14,
        196,
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
        final group = Align(
          key: ValueKey(batch.id),
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
                    _BatchFailure(batch: batch, desktop: widget.desktop),
                ],
              ),
            ),
          ),
        );
        if (highlight == batch.id && !reduced) {
          return group
              .animate(key: ValueKey(highlight))
              .custom(
                duration: const Duration(milliseconds: 1600),
                begin: .08,
                end: 0,
                builder: (context, value, child) => ColoredBox(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: value),
                  child: child,
                ),
              );
        }
        return _BatchEntrance(
          key: ValueKey(batch.id),
          createdAt: batch.createdAt,
          child: group,
        );
      },
    );
  }
}

class _BatchEntrance extends StatefulWidget {
  const _BatchEntrance({
    super.key,
    required this.createdAt,
    required this.child,
  });
  final DateTime createdAt;
  final Widget child;
  @override
  State<_BatchEntrance> createState() => _BatchEntranceState();
}

class _BatchEntranceState extends State<_BatchEntrance> {
  late final bool _newBatch =
      DateTime.now().difference(widget.createdAt) < const Duration(seconds: 2);
  @override
  Widget build(BuildContext context) {
    final duration = handoffDuration(context, 360);
    if (!_newBatch || duration == Duration.zero) return widget.child;
    return widget.child
        .animate()
        .fadeIn(duration: duration, curve: handoffCurve)
        .moveY(begin: 10, end: 0, duration: duration, curve: handoffCurve);
  }
}

class CreationEmptyState extends StatelessWidget {
  const CreationEmptyState({super.key, this.desktop = false, this.topicId});

  final bool desktop;
  final String? topicId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final media = context.watch<MediaCreationController>();
    final missing = media.model == null;
    final video = media.mode == MediaMode.video;
    final suggestions = video
        ? [
            l10n.creationSuggestionMotion,
            l10n.creationSuggestionOcean,
            l10n.creationSuggestionLandscape,
            l10n.creationSuggestionProduct,
          ]
        : [
            l10n.creationSuggestionPoster,
            l10n.creationSuggestionLandscape,
            l10n.creationSuggestionProduct,
            l10n.creationSuggestionIllustration,
            l10n.creationSuggestionRoom,
            l10n.creationSuggestionSticker,
          ];
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        desktop ? 32 : 16,
        desktop ? 96 : 48,
        desktop ? 32 : 16,
        155,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                missing
                    ? LucideIcons.keyRound300
                    : video
                    ? LucideIcons.video300
                    : LucideIcons.palette300,
                size: desktop ? 56 : 48,
                color: cs.onSurface.withValues(alpha: .42),
              ),
              const SizedBox(height: 16),
              Text(
                !missing
                    ? l10n.creationEmptyTitle
                    : media
                          .modelsFor(video ? MediaMode.image : MediaMode.video)
                          .isEmpty
                    ? l10n.creationNoModelTitle
                    : video
                    ? l10n.creationNoVideoModels
                    : l10n.creationNoImageModels,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: AppFontWeights.semibold,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Text(
                  missing ? l10n.creationNoModelBody : l10n.creationEmptyBody,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ),
              SizedBox(height: desktop ? 22 : 20),
              if (missing)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (!video)
                      CreationAction(
                        tone: CreationActionTone.tonal,
                        pill: true,
                        icon: const ProviderAvatar(
                          providerKey: 'chatgpt',
                          displayName: 'ChatGPT',
                          size: 16,
                        ),
                        child: Text(l10n.creationConnectChatGPT),
                        onPressed: () => _login(
                          context,
                          OAuthProvider.chatgpt,
                          l10n.creationConnectChatGPT,
                        ),
                      ),
                    CreationAction(
                      tone: CreationActionTone.tonal,
                      pill: true,
                      icon: const ProviderAvatar(
                        providerKey: 'grok',
                        displayName: 'Grok',
                        size: 16,
                      ),
                      child: Text(l10n.creationConnectGrok),
                      onPressed: () => _login(
                        context,
                        OAuthProvider.grok,
                        l10n.creationConnectGrok,
                      ),
                    ),
                    CreationAction(
                      tone: CreationActionTone.tonal,
                      pill: true,
                      icon: ProviderAvatar(
                        providerKey: 'fal',
                        displayName: 'fal',
                        size: 16,
                      ),
                      child: Text(l10n.creationConfigureFal),
                      onPressed: () => _provider(context, fal: true),
                    ),
                    CreationAction(
                      pill: true,
                      icon: const Icon(Lucide.Settings, size: 15),
                      child: Text(l10n.creationOtherProviders),
                      onPressed: () => _provider(context),
                    ),
                  ],
                )
              else
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final value in suggestions.take(desktop ? 6 : 4))
                      CreationAction(
                        tone: CreationActionTone.tonal,
                        pill: true,
                        onPressed: () => media.suggestPrompt(topicId, value),
                        child: Text(value),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _login(
    BuildContext context,
    OAuthProvider provider,
    String label,
  ) async {
    final panel = OAuthLoginPanel(provider: provider, autoStart: true);
    if (desktop) {
      await showCreationDialog<void>(
        context,
        maxWidth: 560,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: panel,
        ),
      );
    } else {
      await showCreationPicker<void>(
        context,
        desktop: false,
        title: label,
        builder: (_) => panel,
      );
    }
  }

  void _provider(BuildContext context, {bool fal = false}) {
    if (desktop) {
      final navigation = DesktopSettingsNavigationBus.instance;
      if (fal) {
        navigation.openFal();
      } else {
        navigation.openProviders();
      }
      return;
    }
    final page = fal
        ? const ProviderDetailPage(keyName: 'fal', displayName: 'fal')
        : const ProvidersPage();
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => page));
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
  bool _hover = false, _focus = false;

  @override
  Widget build(BuildContext context) {
    final batch = widget.batch;
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final media = context.read<MediaCreationController>();
    final p = _parameters(batch);
    final visible = !widget.desktop || _hover || _focus;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Focus(
        onFocusChange: (f) => setState(() => _focus = f),
        child: Column(
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
                  CreationAction(
                    small: true,
                    onPressed: () => media.runner.cancel(batch.id),
                    icon: const Icon(Lucide.Square, size: 13),
                    child: Text(
                      MaterialLocalizations.of(context).cancelButtonLabel,
                    ),
                  )
                else if (visible) ...[
                  if (widget.desktop) ...[
                    IosIconButton(
                      icon: Lucide.RotateCcw,
                      size: 16,
                      tooltip: l10n.creationRepeat,
                      onTap: _repeat,
                    ),
                    IosIconButton(
                      icon: Lucide.Copy,
                      size: 16,
                      tooltip: l10n.creationCopyPrompt,
                      onTap: _copy,
                    ),
                  ],
                  Builder(
                    builder: (anchor) => IosIconButton(
                      icon: Lucide.Ellipsis,
                      size: 16,
                      tooltip: l10n.chatMessageWidgetMoreTooltip,
                      onTap: () => _menu(anchor),
                    ),
                  ),
                ],
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
                if (batch.parentItemId case final parent?)
                  _EditedFromTag(
                    item: media.item(parent),
                    desktop: widget.desktop,
                    draftTopicId: batch.topicId,
                  ),
                if (_referenceCount(batch) case final count when count > 0)
                  _Tag(
                    l10n.creationImagesCount(count),
                    leading: const Icon(Lucide.Image, size: 13),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.batch.prompt));
    if (mounted) {
      showCreationToast(
        context,
        message: AppLocalizations.of(context)!.creationOptionCopied,
      );
    }
  }

  Future<void> _repeat() async {
    final media = context.read<MediaCreationController>();
    try {
      await media.repeat(widget.batch);
    } catch (_) {
      if (mounted) {
        showCreationToast(
          context,
          message: AppLocalizations.of(context)!.creationActionFailed,
        );
      }
    }
  }

  Future<void> _menu(BuildContext anchor) async {
    final l10n = AppLocalizations.of(context)!;
    final batch = widget.batch;
    final media = context.read<MediaCreationController>();
    final images = media
        .itemsFor(batch.id)
        .where(
          (item) =>
              item.mode == MediaMode.image &&
              item.status == GenerationItemStatus.ready,
        )
        .toList();
    final choices = [
      ActionSheetItem(
        icon: Lucide.RotateCcw,
        label: l10n.creationRepeat,
        onTap: _repeat,
      ),
      ActionSheetItem(
        icon: Lucide.Copy,
        label: l10n.creationCopyPrompt,
        onTap: _copy,
      ),
      if (images.isNotEmpty)
        ActionSheetItem(
          icon: LucideIcons.imagePlus,
          label: l10n.creationUseGroupReferences(images.length),
          onTap: () {
            if (!mounted) return;
            final count = media.addReferencePaths(batch.topicId, [
              for (final item in images) item.path,
            ]);
            showCreationToast(
              context,
              message: count > 0
                  ? l10n.creationReferenceAdded
                  : l10n.creationReferenceLimitReached(
                      media.model?.capabilities.maxReferences ?? 0,
                    ),
            );
          },
        ),
      if (batch.status == GenerationStatus.failed ||
          batch.status == GenerationStatus.partial)
        ActionSheetItem(
          icon: Lucide.FileText,
          label: l10n.creationRequestDetails,
          onTap: () => showCreationRequestDetails(
            context,
            batch,
            desktop: widget.desktop,
          ),
        ),
      ActionSheetItem(
        icon: Lucide.Trash2,
        label: l10n.creationDeleteBatch,
        destructive: true,
        onTap: _delete,
      ),
    ];
    if (!widget.desktop) {
      await showCreationActions(context, items: choices);
      return;
    }
    final box = anchor.findRenderObject() as RenderBox;
    await showCreationMenu(
      context,
      globalPosition: box.localToGlobal(box.size.bottomCenter(Offset.zero)),
      items: [
        for (final item in choices)
          DesktopContextMenuItem(
            icon: item.icon,
            label: item.label,
            onTap: item.onTap,
            danger: item.destructive,
          ),
      ],
    );
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;
    final media = context.read<MediaCreationController>();
    final count = media.itemsFor(widget.batch.id).length;
    final confirmed = await showCreationDialog<bool>(
      context,
      maxWidth: 380,
      child: Builder(
        builder: (dialog) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.creationDeleteBatch,
                style: Theme.of(dialog).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(l10n.creationDeleteBatchBody(count)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CreationAction(
                    onPressed: () => Navigator.of(dialog).pop(false),
                    child: Text(
                      MaterialLocalizations.of(dialog).cancelButtonLabel,
                    ),
                  ),
                  CreationAction(
                    onPressed: () => Navigator.of(dialog).pop(true),
                    child: Text(l10n.chatHistoryPageDelete),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await media.deleteBatch(widget.batch);
    } catch (_) {
      if (mounted) {
        showCreationToast(context, message: l10n.creationActionFailed);
      }
    }
  }
}

class _EditedFromTag extends StatelessWidget {
  const _EditedFromTag({
    required this.item,
    required this.desktop,
    required this.draftTopicId,
  });

  final GenerationItemRow? item;
  final bool desktop;
  final String? draftTopicId;

  @override
  Widget build(BuildContext context) {
    final source = item;
    final l10n = AppLocalizations.of(context)!;
    final time = source == null
        ? null
        : MaterialLocalizations.of(
            context,
          ).formatTimeOfDay(TimeOfDay.fromDateTime(source.createdAt));
    final tag = _Tag(
      time == null
          ? l10n.creationEditedFrom
          : '${l10n.creationEditedFrom} $time',
      leading: source == null
          ? null
          : ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox.square(
                dimension: 16,
                child: CreationMediaCover(source),
              ),
            ),
    );
    return source == null
        ? tag
        : IosCardPress(
            focusable: true,
            onTap: () => showCreationLightbox(
              context,
              source,
              desktop: desktop,
              draftTopicId: draftTopicId,
            ),
            borderRadius: BorderRadius.circular(7),
            child: tag,
          );
  }
}

int _referenceCount(GenerationBatchRow batch) {
  try {
    return MediaRequest.fromBatch(batch).references.length;
  } catch (_) {
    return 0;
  }
}

Future<void> showCreationRequestDetails(
  BuildContext context,
  GenerationBatchRow batch, {
  required bool desktop,
  Future<void> Function()? retry,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final media = context.read<MediaCreationController>();
  final details = _requestDetails(batch);
  const json = JsonEncoder.withIndent('  ');
  final copyText = details.isEmpty
      ? l10n.creationNoRequestDetails
      : json.convert(details);
  final cs = Theme.of(context).colorScheme;
  final provider = media.settings.getProviderConfig(batch.providerId);
  final model = ModelSpecResolver.instance.spec(provider, batch.modelId);
  final kind = details['kind'];
  final retryable = MediaFailureKind.values
      .where((value) => value.name == kind)
      .any((value) => MediaFailure(value, '').retryable);
  Widget code(String title, Object data) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      DecoratedBox(
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: .05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: SelectableText(
            json.convert(data),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ),
    ],
  );
  final content = Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 10,
    children: [
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          if (kind is String)
            _Tag(
              l10n.creationFailureCategory(kind),
              leading: const Icon(Lucide.CircleAlert, size: 12),
            ),
          _Tag(
            retryable
                ? l10n.creationAutomaticRetry
                : l10n.creationNoAutomaticRetry,
          ),
          _Tag(model.displayName),
          _Tag(provider.name),
        ],
      ),
      Text(details['message']?.toString() ?? l10n.creationNoRequestDetails),
      if (details['retries'] case final List retries)
        code(l10n.creationRetryHistory, retries),
      if (details['request'] case final Map request)
        code(l10n.creationLoggedRequest, request),
      if (details['response'] case final Map response)
        code(l10n.creationLoggedResponse, response),
    ],
  );
  Widget actions(BuildContext dialog) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      CreationAction(
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: copyText));
          if (dialog.mounted) {
            showCreationToast(dialog, message: l10n.creationOptionCopied);
          }
        },
        child: Text(MaterialLocalizations.of(dialog).copyButtonLabel),
      ),
      CreationAction(
        onPressed: () async {
          Navigator.of(dialog).pop();
          try {
            if (retry == null) {
              await media.retry(batch);
            } else {
              await retry();
            }
          } catch (_) {
            if (context.mounted) {
              showCreationToast(context, message: l10n.creationActionFailed);
            }
          }
        },
        child: Text(l10n.creationRetry),
      ),
    ],
  );
  if (!desktop) {
    await showCreationPicker<void>(
      context,
      desktop: false,
      title: l10n.creationRequestDetails,
      builder: (dialog) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [content, const SizedBox(height: 12), actions(dialog)],
      ),
    );
    return;
  }
  await showCreationDialog<void>(
    context,
    maxWidth: 560,
    child: Builder(
      builder: (dialog) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.creationRequestDetails,
              style: Theme.of(dialog).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Flexible(child: SingleChildScrollView(child: content)),
            const SizedBox(height: 8),
            actions(dialog),
          ],
        ),
      ),
    ),
  );
}

Map<String, Object?> _requestDetails(GenerationBatchRow batch) {
  try {
    if (jsonDecode(batch.errorJson ?? '{}')
        case final Map<String, dynamic> value) {
      return value;
    }
  } on FormatException {
    // The failure may have no structured details.
  }
  return const {};
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

class _BatchResults extends StatefulWidget {
  const _BatchResults({
    required this.batch,
    required this.items,
    required this.desktop,
  });
  final GenerationBatchRow batch;
  final List<GenerationItemRow> items;
  final bool desktop;

  @override
  State<_BatchResults> createState() => _BatchResultsState();
}

class _BatchResultsState extends State<_BatchResults> {
  final _published = <int>{};
  bool _observed = false;

  @override
  void didUpdateWidget(covariant _BatchResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.batch.id != widget.batch.id ||
        !oldWidget.batch.status.isActive && widget.batch.status.isActive) {
      _published.clear();
      _observed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = context.read<MediaCreationController>();
    final batch = widget.batch;
    final desktop = widget.desktop;
    final params = _parameters(batch);
    final visible = widget.items
        .where((row) => row.status == GenerationItemStatus.ready)
        .toList();
    final remaining = (params.count - visible.length).clamp(0, 16);
    final slots = media.runner.resultSlotsFor(batch.id);
    final first = slots?.first ?? (visible.lastOrNull?.ordinal ?? -1) + 1;
    final end = slots?.end ?? first + remaining;
    if (!_observed && slots != null) {
      for (var ordinal = first; ordinal < slots.next; ordinal++) {
        _published.add(ordinal);
      }
    }
    _observed = true;
    _published.addAll(visible.map((item) => item.ordinal));
    final waiting = [
      if (batch.status.isActive)
        for (var ordinal = first; ordinal < end; ordinal++)
          if (!_published.contains(ordinal)) ordinal,
    ];
    final missing = batch.status == GenerationStatus.partial ? remaining : 0;
    final total = waiting.length + visible.length + missing;
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
        Widget slot(
          int ordinal,
          double aspectRatio, {
          GenerationItemRow? item,
        }) {
          final result = item == null ? null : _artwork(context, item);
          return SizedBox(
            key: ValueKey((batch.id, ordinal)),
            width: width,
            child: AspectRatio(
              aspectRatio: aspectRatio.clamp(.3, 4),
              child: AnimatedBuilder(
                animation: item == null ? media.runner : _idle,
                child: result,
                builder: (context, result) {
                  final progress = item == null
                      ? media.runner.progressFor(batch.id)
                      : null;
                  return CreationWaitingCard(
                    batch: batch,
                    ordinal: ordinal,
                    progress: progress?.fraction,
                    preview: ordinal == waiting.firstOrNull
                        ? progress?.preview
                        : null,
                    queueAhead: item == null
                        ? media.runner.queueAhead(batch.id)
                        : 0,
                    result: result,
                  );
                },
              ),
            ),
          );
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in visible)
              slot(item.ordinal, _itemRatio(item, requestedRatio), item: item),
            for (var index = 0; index < missing; index++)
              SizedBox(
                width: width,
                child: AspectRatio(
                  aspectRatio: ratio.clamp(.3, 4),
                  child: _DownloadFailure(batch: batch),
                ),
              ),
            for (final ordinal in waiting) slot(ordinal, ratio),
          ],
        );
      },
    );
  }

  static const _idle = AlwaysStoppedAnimation<double>(0);

  Widget _artwork(BuildContext context, GenerationItemRow item) {
    final batch = widget.batch;
    final desktop = widget.desktop;
    final tile = CreationArtworkTile(
      key: ValueKey(item.id),
      item: item,
      desktop: desktop,
      draftTopicId: batch.topicId,
      onOpen: () => showCreationLightbox(
        context,
        item,
        desktop: desktop,
        draftTopicId: batch.topicId,
      ),
    );
    return animateCreationResult(context, item, tile);
  }
}

class _DownloadFailure extends StatelessWidget {
  const _DownloadFailure({required this.batch});

  final GenerationBatchRow batch;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final media = context.read<MediaCreationController>();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.cloudOff, color: colors.error, size: 22),
                const SizedBox(height: 4),
                Text(
                  _requestDetails(batch)['kind'] ==
                          MediaFailureKind.download.name
                      ? l10n.creationDownloadFailed
                      : l10n.creationPartial,
                  style: const TextStyle(fontSize: 12),
                ),
                CreationAction(
                  onPressed: () async {
                    try {
                      await media.retry(batch);
                    } catch (_) {
                      if (context.mounted) {
                        showCreationToast(
                          context,
                          message: l10n.creationActionFailed,
                        );
                      }
                    }
                  },
                  child: Text(l10n.creationRetry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BatchFailure extends StatelessWidget {
  const _BatchFailure({required this.batch, required this.desktop});
  final GenerationBatchRow batch;
  final bool desktop;

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
    final details = _requestDetails(batch);
    final kind = details['kind']?.toString();
    final reason = danger
        ? details['message']?.toString() ?? l10n.creationNoRequestDetails
        : batch.status == GenerationStatus.cancelled
        ? l10n.creationCancelledHelp
        : l10n.creationInterruptedHelp;
    final ink = danger ? cs.error : cs.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: danger
              ? cs.error.withValues(alpha: .08)
              : context.appColors.surfaceFill,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: ink.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                danger
                    ? Lucide.CircleAlert
                    : batch.status == GenerationStatus.interrupted
                    ? LucideIcons.circleX
                    : Lucide.Square,
                size: 18,
                color: ink,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    danger && kind != null
                        ? '$title · ${l10n.creationFailureCategory(kind)}'
                        : title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    reason,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 5,
                    children: [
                      CreationAction(
                        tone: CreationActionTone.tonal,
                        small: true,
                        icon: const Icon(Lucide.RotateCcw, size: 14),
                        child: Text(l10n.creationRetry),
                        onPressed: () async {
                          try {
                            await media.retry(batch);
                          } catch (_) {
                            if (context.mounted) {
                              showCreationToast(
                                context,
                                message: l10n.creationActionFailed,
                              );
                            }
                          }
                        },
                      ),
                      if (danger)
                        CreationAction(
                          small: true,
                          icon: const Icon(Lucide.FileText, size: 14),
                          child: Text(l10n.creationRequestDetails),
                          onPressed: () => showCreationRequestDetails(
                            context,
                            batch,
                            desktop: desktop,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
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
