import 'creation_reference_actions.dart';
import 'creation_menu.dart';
import 'creation_controls.dart';
import 'creation_picker.dart';
import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart' as drag;

import '../../../core/database/app_database.dart';
import '../../../core/models/media_creation.dart';
import '../../../core/services/media/media_models.dart';
import '../../../core/services/media/media_request.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../desktop/desktop_context_menu.dart';
import '../../../desktop/hotkeys/chat_action_bus.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/action_sheet.dart';
import '../../../shared/widgets/plain_text_input.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/sliding_segmented_tabs.dart';
import 'creation_toast.dart';
import '../../../theme/app_font_weights.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../providers/media_creation_controller.dart';
import '../../provider/widgets/provider_avatar.dart';
import 'creation_video_player.dart';

typedef OpenCreationTopic = void Function(String topicId, String batchId);
typedef _LightboxDestination = ({String topicId, String batchId});

Future<void> showCreationLightbox(
  BuildContext context,
  GenerationItemRow item, {
  required bool desktop,
  List<GenerationItemRow>? gallery,
  String? draftTopicId,
  OpenCreationTopic? onOpenTopic,
  bool startEditing = false,
  bool fromChat = false,
}) async {
  final media = context.read<MediaCreationController>();
  if (SandboxPathResolver.resolveForIo(item.path) == null) {
    showCreationToast(
      context,
      message: AppLocalizations.of(context)!.creationActionFailed,
    );
    return;
  }
  final topicId = media.batch(item.batchId)?.topicId;
  final deck =
      gallery ??
      (topicId == null ? media.itemsFor(item.batchId) : media.worksFor(topicId))
          .where((candidate) => candidate.status == GenerationItemStatus.ready)
          .toList();
  final destination = await Navigator.of(context, rootNavigator: true)
      .push<_LightboxDestination>(
        PageRouteBuilder<_LightboxDestination>(
          opaque: false,
          barrierColor: desktop ? Colors.black.withValues(alpha: .9) : null,
          transitionDuration: handoffDuration(context, 200),
          reverseTransitionDuration: handoffDuration(context, 160),
          pageBuilder: (_, _, _) => _CreationLightbox(
            item: item,
            deck: deck,
            controller: media,
            desktop: desktop,
            draftTopicId: draftTopicId,
            canOpenTopic: gallery != null && onOpenTopic != null,
            startEditing: startEditing,
            fromChat: fromChat,
          ),
          transitionsBuilder: (_, animation, _, child) => desktop
              ? AnimatedBuilder(
                  animation: animation,
                  child: child,
                  builder: (_, content) => CreationGlassReveal(
                    progress: animation.value,
                    sigma: 18,
                    child: content!,
                  ),
                )
              : FadeTransition(opacity: animation, child: child),
        ),
      );
  if (destination != null && context.mounted) {
    onOpenTopic?.call(destination.topicId, destination.batchId);
  }
}

class _CreationLightbox extends StatefulWidget {
  const _CreationLightbox({
    required this.item,
    required this.deck,
    required this.controller,
    required this.desktop,
    required this.canOpenTopic,
    required this.startEditing,
    required this.fromChat,
    this.draftTopicId,
  });

  final GenerationItemRow item;
  final List<GenerationItemRow> deck;
  final MediaCreationController controller;
  final bool desktop, canOpenTopic, startEditing, fromChat;
  final String? draftTopicId;

  @override
  State<_CreationLightbox> createState() => _CreationLightboxState();
}

class _CreationLightboxState extends State<_CreationLightbox> {
  final _transform = TransformationController();
  final _editFocus = FocusNode();
  final _thumbs = ScrollController();
  late final _deck = widget.deck.any((item) => item.id == widget.item.id)
      ? widget.deck.toList()
      : [widget.item];
  late int _index = _deck.indexWhere((item) => item.id == widget.item.id);
  bool _editing = false;
  bool _zoomed = false;
  Offset _dragStart = Offset.zero;
  Offset _dragOffset = Offset.zero;
  bool _trackingPage = false;

  @override
  void initState() {
    super.initState();
    if (desktop) _transform.addListener(_scaleChanged);
    _editFocus.addListener(_editFocusChanged);
    if (widget.startEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _toggleEdit();
      });
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollThumb(animated: false),
    );
  }

  @override
  void dispose() {
    _transform.removeListener(_scaleChanged);
    _transform.dispose();
    _editFocus.removeListener(_editFocusChanged);
    _editFocus.dispose();
    _thumbs.dispose();
    super.dispose();
  }

  MediaCreationController get _media => widget.controller;
  bool get desktop => widget.desktop;
  GenerationItemRow get _item => _media.item(_deck[_index].id) ?? _deck[_index];

  void _scaleChanged() {
    final zoomed = !_atFitScale;
    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  void _editFocusChanged() => setState(() {});

  void _scrollThumb({bool animated = true}) {
    if (!_thumbs.hasClients) return;
    final side = desktop ? 48.0 : 44.0;
    var center = (desktop ? 14 : 16) + side / 2;
    for (var i = 0; i < _index; i++) {
      center +=
          side +
          (_deck[i].batchId == _deck[i + 1].batchId ? (desktop ? 8 : 6) : 13);
    }
    final target = (center - _thumbs.position.viewportDimension / 2).clamp(
      0.0,
      _thumbs.position.maxScrollExtent,
    );
    if (!animated || MediaQuery.disableAnimationsOf(context)) {
      _thumbs.jumpTo(target);
    } else {
      _thumbs.animateTo(
        target,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _switch(int index) {
    if (index < 0 || index >= _deck.length || index == _index) return;
    _transform.value = Matrix4.identity();
    setState(() {
      _index = index;
      _editing = false;
    });
    _scrollThumb();
  }

  void _dismissPreview() {
    if (ModalRoute.of(context)?.isCurrent == true) {
      Navigator.of(context).pop();
    }
  }

  bool get _atFitScale => _transform.value.getMaxScaleOnAxis() <= 1.000001;

  void _escape() {
    if (_editFocus.hasFocus) {
      _editFocus.unfocus();
    } else if (_editing) {
      setState(() => _editing = false);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _jump(String topicId, String batchId) {
    Navigator.of(
      context,
    ).pop<_LightboxDestination>((topicId: topicId, batchId: batchId));
  }

  Future<void> _toggleEdit() async {
    final source = _item;
    final model = _media.editingModel(source);
    if (model == null) return;
    if (desktop) {
      setState(() => _editing = !_editing);
      return;
    }
    final batchId = await showCreationPicker<String>(
      context,
      desktop: false,
      darkSheet: true,
      title: AppLocalizations.of(context)!.creationEditImage,
      builder: (sheet) => _CreationEditForm(
        media: _media,
        item: source,
        model: model,
        focus: _editFocus,
        desktop: false,
        onSubmitted: (id) => Navigator.of(sheet).pop(id),
      ),
    );
    if (batchId != null) _finishEdit(source, batchId);
  }

  void _finishEdit(GenerationItemRow source, String id) {
    if (!mounted) return;
    final topicId = _media.batch(source.batchId)?.topicId;
    final l10n = AppLocalizations.of(context)!;
    showCreationToast(context, message: l10n.creationEditStarted);
    if (widget.canOpenTopic && topicId != null) {
      _jump(topicId, id);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete(GenerationItemRow item) async {
    if (!await _deleteArtwork(context, _media, item) || !mounted) return;
    _deck.removeWhere((candidate) => candidate.id == item.id);
    if (_deck.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    _transform.value = Matrix4.identity();
    setState(() {
      _index = _index.clamp(0, _deck.length - 1);
      _editing = false;
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _media,
    builder: (context, _) {
      final item = _item;
      final batch = _media.batch(item.batchId);
      final l10n = AppLocalizations.of(context)!;
      final editModel = _media.editingModel(item);
      void favorite() => toggleCreationArtworkFavorite(context, _media, item);
      Widget chrome(Widget child) => desktop
          ? child
          : IgnorePointer(
              ignoring: _dragOffset != Offset.zero,
              child: AnimatedOpacity(
                opacity: _dragOffset == Offset.zero ? 1 : 0,
                duration: handoffDuration(context, 160),
                child: child,
              ),
            );
      final contents = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          chrome(
            LayoutBuilder(
              builder: (context, constraints) => _header(
                context,
                item,
                batch,
                editModel,
                favorite,
                constraints.maxWidth,
              ),
            ),
          ),
          Expanded(child: _canvas(context, item)),
          chrome(
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: desktop
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.stretch,
              children: [
                if (!desktop && batch != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                    child: Text(
                      batch.prompt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.55,
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: desktop ? 4 : 8),
                  child: _thumbnailStrip(),
                ),
                if (desktop)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 18),
                    child: _counter(),
                  ),
                if (!desktop)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _mobileAction(
                          item.favorite
                              ? LucideIcons.starOff
                              : LucideIcons.star,
                          item.favorite
                              ? l10n.creationUnfavorite
                              : l10n.creationFavorite,
                          favorite,
                        ),
                        _mobileAction(
                          Lucide.Download,
                          item.mode == MediaMode.image
                              ? l10n.creationSaveImage
                              : l10n.creationSaveVideo,
                          () => saveCreationArtwork(
                            context,
                            item,
                            desktop: false,
                          ),
                        ),
                        _mobileAction(
                          Lucide.Share,
                          l10n.creationShare,
                          () => shareCreationArtwork(context, item),
                        ),
                        if (editModel != null)
                          _mobileAction(
                            Lucide.Pencil,
                            l10n.creationEditImage,
                            _toggleEdit,
                          ),
                        if (item.mode == MediaMode.image)
                          _mobileAction(
                            LucideIcons.send,
                            l10n.creationSendToChat,
                            () {
                              Navigator.of(context).pop();
                              _sendArtworkToChat(context, item);
                            },
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
      final stage = Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: _dismissPreview,
          ),
          contents,
        ],
      );
      final narrow = MediaQuery.sizeOf(context).width < 960;
      final panel = desktop && _editing && editModel != null
          ? _EditPanelIn(
              child: SizedBox(
                width:
                    (narrow
                            ? MediaQuery.sizeOf(context).width
                            : MediaQuery.sizeOf(context).width * .40)
                        .clamp(220.0, 360.0),
                child: ColoredBox(
                  color: const Color(0xff1c1c1e),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _CreationEditForm(
                      key: ValueKey(item.id),
                      media: _media,
                      item: item,
                      model: editModel,
                      focus: _editFocus,
                      desktop: true,
                      onClose: () => setState(() => _editing = false),
                      onSubmitted: (id) => _finishEdit(item, id),
                    ),
                  ),
                ),
              ),
            )
          : null;
      final body = SafeArea(
        child: panel == null
            ? stage
            : narrow
            ? Stack(
                children: [
                  Positioned.fill(child: stage),
                  Positioned.fill(
                    child: ModalBarrier(
                      color: Colors.black38,
                      onDismiss: () => setState(() => _editing = false),
                    ),
                  ),
                  PositionedDirectional(
                    end: 0,
                    top: 0,
                    bottom: 0,
                    child: panel,
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: stage),
                  panel,
                ],
              ),
      );
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): _escape,
          if (!_editFocus.hasFocus) ...{
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                _switch(_index - 1),
            const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                _switch(_index + 1),
          },
          const SingleActivator(LogicalKeyboardKey.keyD, meta: true): favorite,
          const SingleActivator(LogicalKeyboardKey.keyD, control: true):
              favorite,
        },
        child: Focus(
          autofocus: true,
          child: Material(
            color: desktop
                ? Colors.transparent
                : Colors.black.withValues(
                    alpha: 1 - (_dragOffset.dy / 320).clamp(0.0, .55),
                  ),
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle.light,
              child: body,
            ),
          ),
        ),
      );
    },
  );

  Widget _icon(
    IconData icon,
    String label,
    VoidCallback? onTap, {
    Color color = Colors.white,
  }) => IosIconButton(
    icon: icon,
    tooltip: label,
    color: color,
    size: 17,
    minSize: 34,
    onTap: onTap,
  );

  Widget _counter() => Text(
    '${_index + 1} / ${_deck.length}',
    style: TextStyle(
      color: desktop ? Colors.white54 : Colors.white70,
      fontSize: desktop ? 12 : 14,
    ),
  );

  Widget _header(
    BuildContext context,
    GenerationItemRow item,
    GenerationBatchRow? batch,
    MediaModelChoice? editModel,
    VoidCallback favorite,
    double availableWidth,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final topicId = batch?.topicId;
    final jump = widget.canOpenTopic && topicId != null;
    final conversationId = batch?.conversationId;
    final messageId = batch?.messageId;
    final conversation = conversationId == null
        ? null
        : context.read<ChatService?>()?.getConversation(conversationId);
    final jumpToChat =
        widget.canOpenTopic && conversation != null && messageId != null;
    void openChat() {
      Navigator.of(context).pop();
      ChatActionBus.instance.fireCreation(
        OpenCreationConversation(conversationId!, messageId!),
      );
    }

    final toolbarScale = MediaQuery.textScalerOf(context).scale(13) / 13;
    final compactTools =
        desktop &&
        (availableWidth < 680 || availableWidth / toolbarScale < 680);
    final close = _icon(
      Lucide.X,
      MaterialLocalizations.of(context).closeButtonTooltip,
      () => Navigator.of(context).pop(),
    );
    final menu = Builder(
      builder: (anchor) => _icon(
        Lucide.Ellipsis,
        l10n.chatMessageWidgetMoreTooltip,
        () => _showArtworkMenu(
          anchor,
          [
            if ((!desktop || compactTools) && jump)
              ActionSheetItem(
                icon: LucideIcons.externalLink,
                label: l10n.creationShowInTopic,
                onTap: () => _jump(topicId, item.batchId),
              ),
            if ((!desktop || compactTools) && jumpToChat)
              ActionSheetItem(
                icon: LucideIcons.externalLink,
                label: l10n.creationShowInConversation,
                onTap: openChat,
              ),
            ..._artworkActions(
              context,
              _media,
              item,
              desktop: desktop,
              draftTopicId: widget.draftTopicId,
              includePrimary: compactTools,
              onEdit: _toggleEdit,
              onUseAsReference: () {
                if (widget.fromChat) {
                  Navigator.of(context).pop();
                  _sendArtworkToChat(context, item);
                  return;
                }
                final result = addCreationReferences(
                  context,
                  _media,
                  widget.draftTopicId,
                  [item.path],
                );
                if (result == CreationReferenceResult.added ||
                    result == CreationReferenceResult.alreadyAdded) {
                  Navigator.of(context).pop();
                }
              },
              onDelete: () => _delete(item),
              onSendToChat: () {
                Navigator.of(context).pop();
                _sendArtworkToChat(context, item);
              },
            ),
          ],
          desktop: desktop,
          title: batch?.prompt,
        ),
      ),
    );
    if (!desktop) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            close,
            Expanded(child: Center(child: _counter())),
            menu,
          ],
        ),
      );
    }
    final topic = topicId == null ? null : _media.topic(topicId);
    final ratio = _readRatio(batch);
    if (compactTools) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            Platform.isMacOS ? 75 : 8,
            8,
            8,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  batch?.prompt ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13.5),
                ),
              ),
              _toolCapsule([
                if (editModel != null)
                  _icon(Lucide.Pencil, l10n.creationEditImage, _toggleEdit),
                menu,
              ]),
              const SizedBox(width: 8),
              _toolCapsule([close]),
            ],
          ),
        ),
      );
    }
    final material = MaterialLocalizations.of(context);
    final captions = [
      if (topic != null) topic.title,
      if (conversation != null) l10n.creationChatSource(conversation.title),
      if (batch != null) batch.modelId,
      ratio != 'auto' ? ratio : _artworkRatio(item, l10n),
      if (batch != null) material.formatCompactDate(batch.createdAt),
      if (batch != null)
        material.formatTimeOfDay(TimeOfDay.fromDateTime(batch.createdAt)),
      if (batch?.source == GenerationSource.edit) l10n.creationEditedResult,
    ];
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: EdgeInsets.fromLTRB(Platform.isMacOS ? 90 : 20, 10, 14, 0),
        child: Row(
          spacing: 12,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    batch?.prompt ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: AppFontWeights.semibold,
                    ),
                  ),
                  Row(
                    children: [
                      if (batch != null) ...[
                        ProviderAvatar(
                          providerKey: batch.providerId,
                          displayName: batch.providerId,
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                      ],
                      Expanded(
                        child: Text(
                          captions.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (jump || jumpToChat)
              _toolCapsule([
                if (jump)
                  Tooltip(
                    message: l10n.creationShowInTopic,
                    child: CreationAction(
                      small: true,
                      foreground: Colors.white,
                      icon: const Icon(LucideIcons.externalLink, size: 15),
                      onPressed: () => _jump(topicId, item.batchId),
                      child: Text(l10n.creationShowInTopic),
                    ),
                  ),
                if (jumpToChat)
                  _icon(
                    LucideIcons.externalLink,
                    l10n.creationShowInConversation,
                    openChat,
                  ),
              ]),
            _toolCapsule([
              if (editModel != null)
                CreationAction(
                  small: true,
                  pill: true,
                  fill: _editing ? Colors.white : Colors.transparent,
                  foreground: _editing ? Colors.black : Colors.white,
                  icon: const Icon(Lucide.Pencil, size: 14),
                  onPressed: _toggleEdit,
                  child: Text(l10n.creationEditImage),
                ),
              _icon(
                LucideIcons.star,
                item.favorite ? l10n.creationUnfavorite : l10n.creationFavorite,
                favorite,
                color: item.favorite ? const Color(0xffffd86b) : Colors.white,
              ),
              _icon(
                Lucide.Download,
                item.mode == MediaMode.image
                    ? l10n.creationSaveImage
                    : l10n.creationSaveVideo,
                () => saveCreationArtwork(context, item, desktop: true),
              ),
              _icon(
                Lucide.Share,
                l10n.creationShare,
                () => shareCreationArtwork(context, item),
              ),
              menu,
            ]),
            _toolCapsule([close]),
          ],
        ),
      ),
    );
  }

  Widget _toolCapsule(List<Widget> children) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xf2303032),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: Colors.white12),
      boxShadow: const [
        BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 6)),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 2,
        children: children,
      ),
    ),
  );

  void _updatePageDrag(Offset position) {
    final delta = position - _dragStart;
    final horizontal = delta.dx.abs() > delta.dy.abs();
    final offset = horizontal
        ? Offset(
            (delta.dx < 0 && _index == _deck.length - 1 ||
                    delta.dx > 0 && _index == 0)
                ? delta.dx * .2
                : delta.dx,
            0,
          )
        : Offset(0, delta.dy.clamp(0.0, double.infinity));
    if (_dragOffset != offset) setState(() => _dragOffset = offset);
  }

  void _endPageDrag() {
    final offset = _dragOffset;
    _trackingPage = false;
    if (offset.dy > 100) {
      Navigator.of(context).pop();
      return;
    }
    if (offset == Offset.zero) return;
    setState(() => _dragOffset = Offset.zero);
    if (offset.dx.abs() > 55) _switch(_index + (offset.dx < 0 ? 1 : -1));
  }

  Widget _canvas(BuildContext context, GenerationItemRow item) {
    final l10n = AppLocalizations.of(context)!;
    final width = item.width, height = item.height;
    final knownSize =
        width != null && width > 0 && height != null && height > 0;
    final radius = BorderRadius.circular(desktop ? 6 : 4);
    final image = IgnorePointer(
      // The native source also registers a long-press recognizer. Keep its
      // snapshot and image mounted, but let the viewer own every zoomed drag.
      ignoring: desktop && _zoomed,
      child: CreationDragOut(
        item: item,
        enabled: desktop,
        canDrag: () => _atFitScale,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: desktop
                ? const [
                    BoxShadow(
                      color: Colors.black54,
                      offset: Offset(0, 20),
                      blurRadius: 60,
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: CreationFileImage(
              item.path,
              key: ValueKey(item.id),
              fit: BoxFit.contain,
              fill: knownSize,
              fadeOnCacheHit: true,
            ),
          ),
        ),
      ),
    );
    Widget view;
    if (item.mode == MediaMode.video) {
      view = CreationVideoPlayer(
        key: ValueKey(item.id),
        item: item,
        cover: CreationMediaCover(item, playOverlay: false),
      );
      if (!desktop) {
        view = GestureDetector(
          onPanStart: (d) => _dragStart = d.globalPosition,
          onPanUpdate: (d) => _updatePageDrag(d.globalPosition),
          onPanEnd: (_) => _endPageDrag(),
          onPanCancel: _endPageDrag,
          child: view,
        );
      }
    } else {
      view = InteractiveViewer(
        transformationController: _transform,
        minScale: 1,
        maxScale: 4,
        onInteractionStart: (d) {
          _dragStart = d.focalPoint;
          _trackingPage =
              !desktop && _transform.value.getMaxScaleOnAxis() <= 1.02;
        },
        onInteractionUpdate: (d) {
          if (!_trackingPage) return;
          if (d.pointerCount > 1 ||
              _transform.value.getMaxScaleOnAxis() > 1.02) {
            _trackingPage = false;
            if (_dragOffset != Offset.zero) {
              setState(() => _dragOffset = Offset.zero);
            }
            return;
          }
          _updatePageDrag(d.focalPoint);
        },
        onInteractionEnd: (_) {
          if (_trackingPage) _endPageDrag();
        },
        child: SizedBox.expand(
          child: knownSize
              ? Center(
                  child: AspectRatio(aspectRatio: width / height, child: image),
                )
              : FittedBox(fit: BoxFit.contain, child: image),
        ),
      );
    }
    Widget arrow(IconData icon, String label, VoidCallback? tap) => SizedBox(
      width: MediaQuery.sizeOf(context).width < 650 ? 44 : 72,
      child: Center(
        child: Opacity(
          opacity: tap == null ? .25 : 1,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0x14ffffff),
              shape: BoxShape.circle,
            ),
            child: IosIconButton(
              icon: icon,
              color: Colors.white,
              tooltip: label,
              minSize: 40,
              size: 20,
              enabled: tap != null,
              onTap: tap,
            ),
          ),
        ),
      ),
    );
    return Row(
      children: [
        if (desktop)
          arrow(
            Lucide.ChevronLeft,
            l10n.creationPrevious,
            _index > 0 ? () => _switch(_index - 1) : null,
          ),
        Expanded(
          child: Padding(
            padding: desktop
                ? const EdgeInsets.only(top: 8, bottom: 12)
                : EdgeInsets.zero,
            child: ClipRect(
              child: TweenAnimationBuilder<Offset>(
                tween: Tween(end: _dragOffset),
                duration: _dragOffset == Offset.zero
                    ? handoffDuration(context, 300)
                    : Duration.zero,
                curve: handoffCurve,
                builder: (context, offset, child) => Transform.translate(
                  offset: offset,
                  child: Transform.scale(
                    scale: 1 - (offset.dy / 1200).clamp(0.0, .24),
                    child: child,
                  ),
                ),
                child: item.mode == MediaMode.image
                    ? GestureDetector(
                        excludeFromSemantics: true,
                        behavior: HitTestBehavior.opaque,
                        onTap: _dismissPreview,
                        child: view,
                      )
                    : view,
              ),
            ),
          ),
        ),
        if (desktop)
          arrow(
            Lucide.ChevronRight,
            l10n.creationNext,
            _index + 1 < _deck.length ? () => _switch(_index + 1) : null,
          ),
      ],
    );
  }

  Widget _thumbnailStrip() {
    final size = desktop ? 48.0 : 44.0;
    return SizedBox(
      height: size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: _dismissPreview,
        child: ListView.separated(
          shrinkWrap: desktop,
          separatorBuilder: (_, i) => _deck[i].batchId == _deck[i + 1].batchId
              ? SizedBox(width: desktop ? 8 : 6)
              : Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 9,
                  ),
                  child: Container(width: 1, color: Colors.white24),
                ),
          controller: _thumbs,
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: desktop ? 14 : 16),
          itemCount: _deck.length,
          itemBuilder: (context, index) => Semantics(
            button: true,
            selected: index == _index,
            label: MaterialLocalizations.of(
              context,
            ).tabLabel(tabIndex: index + 1, tabCount: _deck.length),
            child: IosCardPress(
              focusable: true,
              baseColor: Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              onTap: () => _switch(index),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: index == _index ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Opacity(
                    opacity: index == _index ? 1 : .55,
                    child: CreationMediaCover(_deck[index], thumbnail: true),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _mobileAction(IconData icon, String label, VoidCallback onTap) =>
      Flexible(
        child: IosCardPress(
          onTap: onTap,
          focusable: true,
          baseColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 21),
              const SizedBox(height: 3),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ],
          ),
        ),
      );
}

String _artworkRatio(GenerationItemRow item, AppLocalizations l10n) {
  final w = item.width, h = item.height;
  if (w == null || h == null || w <= 0 || h <= 0) return l10n.creationAuto;
  final divisor = w.gcd(h);
  return '${w ~/ divisor}:${h ~/ divisor}';
}

String _readRatio(GenerationBatchRow? batch) {
  if (batch == null) return 'auto';
  try {
    return MediaRequest.fromBatch(batch).aspectRatio;
  } on FormatException {
    return 'auto';
  } on TypeError {
    return 'auto';
  }
}

class _EditPanelIn extends StatelessWidget {
  const _EditPanelIn({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final duration = handoffDuration(context, 320);
    if (duration == Duration.zero) return child;
    return child
        .animate()
        .fadeIn(duration: duration, curve: handoffCurve)
        .moveX(begin: 40, end: 0, duration: duration, curve: handoffCurve);
  }
}

class CreationDragOut extends StatelessWidget {
  const CreationDragOut({
    super.key,
    required this.item,
    required this.enabled,
    required this.canDrag,
    required this.child,
  });

  final GenerationItemRow item;
  final bool enabled;
  final ValueGetter<bool> canDrag;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return drag.DragItemWidget(
      allowedOperations: () => [drag.DropOperation.copy],
      dragItemProvider: (_) async {
        final path = SandboxPathResolver.resolveForIo(item.path);
        if (path == null || !await File(path).exists()) return null;
        return drag.DragItem(suggestedName: p.basename(path))
          ..add(drag.Formats.fileUri(Uri.file(path)));
      },
      child: drag.DraggableWidget(
        isLocationDraggable: (_) => canDrag(),
        child: child,
      ),
    );
  }
}

class _CreationEditForm extends StatefulWidget {
  const _CreationEditForm({
    super.key,
    required this.media,
    required this.item,
    required this.model,
    required this.desktop,
    required this.focus,
    required this.onSubmitted,
    this.onClose,
  });

  final MediaCreationController media;
  final GenerationItemRow item;
  final MediaModelChoice model;
  final bool desktop;
  final FocusNode focus;
  final ValueChanged<String> onSubmitted;
  final VoidCallback? onClose;

  @override
  State<_CreationEditForm> createState() => _CreationEditFormState();
}

class _CreationEditFormState extends State<_CreationEditForm> {
  final _prompt = TextEditingController();
  String? _ratio;
  bool _busy = false;

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  Future<void> _send(String ratio) async {
    setState(() => _busy = true);
    try {
      final ticket = await widget.media.editItem(
        widget.item,
        widget.model,
        prompt: _prompt.text,
        ratio: ratio,
      );
      if (mounted && ticket != null) widget.onSubmitted(ticket.batchId);
    } catch (_) {
      if (mounted) {
        showCreationToast(
          context,
          message: AppLocalizations.of(context)!.creationActionFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final item = widget.item;
    final batch = widget.media.batch(item.batchId);
    final supported = widget.model.capabilities.aspectRatios;
    final width = item.width;
    final height = item.height;
    final sourceRatio =
        width != null && height != null && width > 0 && height > 0
        ? supported.where((ratio) {
            final parts = ratio.split(':');
            if (parts.length != 2) return false;
            final w = double.tryParse(parts.first);
            final h = double.tryParse(parts.last);
            return w != null &&
                h != null &&
                h > 0 &&
                (width / height - w / h).abs() < .01;
          }).firstOrNull
        : _readRatio(batch);
    final same = sourceRatio != 'auto' && supported.contains(sourceRatio)
        ? sourceRatio
        : null;
    final initial =
        same ?? (supported.contains('auto') ? 'auto' : supported.first);
    final options = [
      initial,
      ...supported
          .where((value) => value != initial && value != 'auto')
          .take(4),
    ];
    final selected = options.contains(_ratio) ? _ratio! : initial;
    const colors = ColorScheme.dark(
      surface: Color(0xff1c1c1e),
      primary: Colors.white,
      onSurface: Colors.white,
      onSurfaceVariant: Colors.white70,
    );
    return Theme(
      data: Theme.of(context).copyWith(colorScheme: colors),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.desktop)
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.creationEditImage,
                    style: const TextStyle(color: Colors.white, fontSize: 17),
                  ),
                ),
                IosIconButton(
                  icon: Lucide.X,
                  onTap: widget.onClose,
                  color: Colors.white,
                ),
              ],
            ),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: SizedBox.square(
                  dimension: 52,
                  child: CreationMediaCover(item),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.creationEditReference,
                      style: TextStyle(
                        color: widget.desktop ? Colors.white : colors.onSurface,
                      ),
                    ),
                    Text(
                      widget.model.spec.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: widget.desktop
                            ? Colors.white54
                            : colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            l10n.creationEditPrompt,
            style: const TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 6),
          PlainTextInput(
            controller: _prompt,
            focusNode: widget.focus,
            minLines: 4,
            maxLines: 5,
            onChanged: (_) => setState(() {}),
            placeholder: l10n.creationEditPromptExample,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            placeholderStyle: const TextStyle(color: Colors.white38),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 12),
          SlidingSegmentedTabs(
            backgroundColor: Colors.white.withValues(alpha: .08),
            selectedColor: const Color(0xfff5f5f5),
            selectedForegroundColor: const Color(0xff111111),
            foregroundColor: Colors.white70,
            expand: true,

            index: options.indexOf(selected),
            tabs: [
              for (final value in options)
                SegmentedTab(
                  label: value == same
                      ? l10n.creationEditOriginalRatio
                      : value == 'auto'
                      ? l10n.creationAuto
                      : value,
                ),
            ],
            onChanged: (index) => setState(() => _ratio = options[index]),
          ),
          const SizedBox(height: 9),
          Text(
            l10n.creationEditHelp,
            style: TextStyle(
              color: widget.desktop ? Colors.white54 : colors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          CreationAction(
            tone: CreationActionTone.primary,
            fill: Colors.white,
            foreground: Colors.black,
            minHeight: 44,
            onPressed: _busy || _prompt.text.trim().isEmpty
                ? null
                : () => _send(selected),
            icon: const Icon(LucideIcons.sparkles, size: 16),
            child: Text(l10n.creationEditNewGroup),
          ),
        ],
      ),
    );
  }
}

Future<void> showCreationArtworkMenu(
  BuildContext context,
  GenerationItemRow item, {
  required bool desktop,
  String? draftTopicId,
  List<GenerationItemRow>? gallery,
  OpenCreationTopic? onOpenTopic,
  Rect? anchor,
}) {
  final media = context.read<MediaCreationController>();
  return _showArtworkMenu(
    context,
    _artworkActions(
      context,
      media,
      item,
      desktop: desktop,
      draftTopicId: draftTopicId,
      includePrimary: true,
      onEdit: () => showCreationLightbox(
        context,
        item,
        desktop: desktop,
        gallery: gallery,
        draftTopicId: draftTopicId,
        onOpenTopic: onOpenTopic,
        startEditing: true,
      ),
      onDelete: () => _deleteArtwork(context, media, item),
    ),
    desktop: desktop,
    title: media.batch(item.batchId)?.prompt,
    anchor: anchor,
  );
}

Future<void> _showArtworkMenu(
  BuildContext context,
  List<ActionSheetItem> items, {
  required bool desktop,
  String? title,
  Rect? anchor,
}) {
  if (!desktop) {
    return showCreationActions(
      context,
      title: title,
      items: items,
      darkSheet: ModalRoute.of(context)?.opaque == false,
    );
  }
  return showCreationMenu(
    context,
    globalAnchor: anchor,
    items: [
      for (final item in items)
        DesktopContextMenuItem(
          icon: item.icon,
          label: item.label,
          onTap: item.onTap,
          danger: item.destructive,
        ),
    ],
  );
}

List<ActionSheetItem> _artworkActions(
  BuildContext context,
  MediaCreationController media,
  GenerationItemRow item, {
  required bool desktop,
  required bool includePrimary,
  required String? draftTopicId,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
  VoidCallback? onSendToChat,
  VoidCallback? onUseAsReference,
}) {
  final l10n = AppLocalizations.of(context)!;
  final image = item.mode == MediaMode.image;
  return [
    if (includePrimary) ...[
      if (media.editingModel(item) != null)
        ActionSheetItem(
          icon: Lucide.Pencil,
          label: l10n.creationEditImage,
          onTap: onEdit,
        ),
      ActionSheetItem(
        icon: item.favorite ? LucideIcons.starOff : LucideIcons.star,
        label: item.favorite ? l10n.creationUnfavorite : l10n.creationFavorite,
        onTap: () => toggleCreationArtworkFavorite(context, media, item),
      ),
      ActionSheetItem(
        icon: Lucide.Download,
        label: image ? l10n.creationSaveImage : l10n.creationSaveVideo,
        onTap: () => saveCreationArtwork(context, item, desktop: desktop),
      ),
      ActionSheetItem(
        icon: Lucide.Share,
        label: l10n.creationShare,
        onTap: () => shareCreationArtwork(context, item),
      ),
    ],
    if (image)
      ActionSheetItem(
        icon: Lucide.Copy,
        label: l10n.creationCopyImage,
        onTap: () => _copyArtwork(context, item),
      ),
    if (media.batch(item.batchId) case final batch?)
      ActionSheetItem(
        icon: Lucide.Copy,
        label: l10n.creationCopyPrompt,
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: batch.prompt));
          if (context.mounted) {
            showCreationToast(context, message: l10n.creationOptionCopied);
          }
        },
      ),
    if (image)
      ActionSheetItem(
        icon: LucideIcons.imagePlus,
        label: l10n.creationUseReference,
        onTap:
            onUseAsReference ??
            () => addCreationReferences(context, media, draftTopicId, [
              item.path,
            ]),
      ),
    if (image)
      ActionSheetItem(
        icon: Lucide.MessageCircle,
        label: l10n.creationSendToChat,
        onTap: onSendToChat ?? () => _sendArtworkToChat(context, item),
      ),
    ActionSheetItem(
      icon: Lucide.Trash2,
      label: l10n.creationDeleteItem,
      destructive: true,
      onTap: onDelete,
    ),
  ];
}

Future<void> _runArtworkAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (_) {
    if (context.mounted) {
      showCreationToast(
        context,
        message: AppLocalizations.of(context)!.creationActionFailed,
      );
    }
  }
}

Future<void> toggleCreationArtworkFavorite(
  BuildContext context,
  MediaCreationController media,
  GenerationItemRow item,
) => _runArtworkAction(context, () async {
  final value = !(media.item(item.id)?.favorite ?? item.favorite);
  await media.setFavorite(item.id, value);
  if (context.mounted) {
    final l10n = AppLocalizations.of(context)!;
    showCreationToast(
      context,
      message: value ? l10n.creationFavorited : l10n.creationUnfavorited,
    );
  }
});

String _filePath(GenerationItemRow item) =>
    SandboxPathResolver.resolveForIo(item.path) ??
    (throw StateError('Creation file unavailable'));

Future<void> saveCreationArtwork(
  BuildContext context,
  GenerationItemRow item, {
  required bool desktop,
}) => _runArtworkAction(context, () async {
  final path = _filePath(item);
  if (desktop) {
    final target = await FilePicker.platform.saveFile(
      fileName: p.basename(path),
    );
    if (target == null) return;
    if (!p.equals(path, target)) await File(path).copy(target);
  } else {
    final result = await ImageGallerySaverPlus.saveFile(path);
    if (result is! Map || result['isSuccess'] != true) {
      throw StateError('Could not save creation');
    }
  }
  if (context.mounted) {
    showCreationToast(
      context,
      message: AppLocalizations.of(context)!.creationOptionSaved,
    );
  }
});

Future<void> _copyArtwork(BuildContext context, GenerationItemRow item) =>
    _runArtworkAction(context, () async {
      final clipboard = SystemClipboard.instance;
      if (clipboard == null) throw StateError('Image clipboard unavailable');
      final bytes = await File(_filePath(item)).readAsBytes();
      final format = switch (item.mime) {
        'image/jpeg' => Formats.jpeg,
        'image/webp' => Formats.webp,
        'image/gif' => Formats.gif,
        _ => Formats.png,
      };
      await clipboard.write([DataWriterItem()..add(format(bytes))]);
      if (context.mounted) {
        showCreationToast(
          context,
          message: AppLocalizations.of(context)!.creationOptionCopied,
        );
      }
    });

Future<void> shareCreationArtwork(
  BuildContext context,
  GenerationItemRow item,
) => _runArtworkAction(context, () async {
  final box = context.findRenderObject() as RenderBox?;
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(_filePath(item), mimeType: item.mime)],
      sharePositionOrigin: box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size,
    ),
  );
});

Future<bool> _deleteArtwork(
  BuildContext context,
  MediaCreationController media,
  GenerationItemRow item,
) async {
  final l10n = AppLocalizations.of(context)!;
  final yes = await showCreationDialog<bool>(
    context,
    maxWidth: 380,
    child: Builder(
      builder: (dialog) => Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.creationDeleteItem,
              style: Theme.of(dialog).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(l10n.creationDeleteItemBody),
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
  if (yes != true || !context.mounted) return false;
  var success = false;
  await _runArtworkAction(context, () async {
    await media.deleteItem(item);
    success = true;
  });
  return success;
}

void _sendArtworkToChat(BuildContext context, GenerationItemRow item) {
  final file = SandboxPathResolver.resolveForIo(item.path);
  if (file != null) {
    ChatActionBus.instance.fireCreation(PrefillChatImage(file));
  } else {
    showCreationToast(
      context,
      message: AppLocalizations.of(context)!.creationActionFailed,
    );
  }
}

class CreationFileImage extends StatelessWidget {
  const CreationFileImage(
    this.path, {
    super.key,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.fill = true,
    this.fadeOnCacheHit = false,
  });

  final String path;
  final BoxFit fit;
  final bool fill;
  final bool fadeOnCacheHit;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    final file = SandboxPathResolver.resolveForIo(path);
    const placeholder = Center(child: Icon(Lucide.Image, size: 22));
    return file == null
        ? placeholder
        : Image.file(
            File(file),
            key: ValueKey((file, cacheWidth)),
            frameBuilder: MediaQuery.disableAnimationsOf(context)
                ? null
                : (context, child, frame, synchronous) {
                    if (frame == null || (synchronous && !fadeOnCacheHit)) {
                      return child;
                    }
                    return child.animate().fadeIn(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    );
                  },
            cacheWidth: cacheWidth,
            fit: fit,
            width: fill ? double.infinity : null,
            height: fill ? double.infinity : null,
            errorBuilder: (_, _, _) => placeholder,
          );
  }
}

class CreationMediaCover extends StatelessWidget {
  const CreationMediaCover(
    this.item, {
    super.key,
    this.playOverlay = true,
    this.thumbnail = false,
  });

  final GenerationItemRow item;
  final bool playOverlay;
  final bool thumbnail;

  @override
  Widget build(BuildContext context) {
    if (item.mode == MediaMode.image) {
      return CreationFileImage(
        thumbnail ? item.thumbnailPath ?? item.path : item.path,
      );
    }
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      label: l10n.creationVideo,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (item.thumbnailPath case final path?)
            CreationFileImage(path)
          else
            ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: playOverlay
                  ? null
                  : const Center(child: Icon(LucideIcons.video, size: 22)),
            ),
          if (playOverlay) ...[
            Center(
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: SizedBox.square(
                    dimension: 48,
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: .36),
                      child: const Icon(
                        Lucide.Play,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (item.durationMs case final duration?)
              PositionedDirectional(
                start: 8,
                top: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Text(
                      creationVideoTime(duration),
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
