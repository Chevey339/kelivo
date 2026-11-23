import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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
import '../../../shared/widgets/form_sheet.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/segmented_tabs.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../theme/app_font_weights.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../settings/widgets/custom_theme_widgets.dart';
import '../providers/media_creation_controller.dart';
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
}) async {
  final media = context.read<MediaCreationController>();
  if (SandboxPathResolver.resolveForIo(item.path) == null) {
    showAppSnackBar(
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
          barrierLabel: MaterialLocalizations.of(
            context,
          ).modalBarrierDismissLabel,
          barrierDismissible: desktop,
          transitionDuration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          pageBuilder: (_, _, _) => _CreationLightbox(
            item: item,
            deck: deck,
            controller: media,
            desktop: desktop,
            draftTopicId: draftTopicId,
            canOpenTopic: gallery != null && onOpenTopic != null,
            startEditing: startEditing,
          ),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
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
    this.draftTopicId,
  });

  final GenerationItemRow item;
  final List<GenerationItemRow> deck;
  final MediaCreationController controller;
  final bool desktop, canOpenTopic, startEditing;
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
  Offset _dragStart = Offset.zero;
  Offset _dragOffset = Offset.zero;
  double _swipeX = 0;

  @override
  void initState() {
    super.initState();
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
    _transform.dispose();
    _editFocus.removeListener(_editFocusChanged);
    _editFocus.dispose();
    _thumbs.dispose();
    super.dispose();
  }

  MediaCreationController get _media => widget.controller;
  bool get desktop => widget.desktop;
  GenerationItemRow get _item => _media.item(_deck[_index].id) ?? _deck[_index];

  void _editFocusChanged() => setState(() {});

  void _scrollThumb({bool animated = true}) {
    if (!_thumbs.hasClients) return;
    final target = (_index * 58.0 - _thumbs.position.viewportDimension / 2 + 24)
        .clamp(0.0, _thumbs.position.maxScrollExtent);
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

  void _zoom(TapUpDetails details) {
    if (!desktop) return;
    final point = details.localPosition;
    if (_transform.value.getMaxScaleOnAxis() > 1.1) {
      _transform.value = Matrix4.identity();
      return;
    }
    _transform.value = Matrix4.identity()
      ..setEntry(0, 0, 1.8)
      ..setEntry(1, 1, 1.8)
      ..setEntry(0, 3, -point.dx * .8)
      ..setEntry(1, 3, -point.dy * .8);
  }

  Future<void> _toggleEdit() async {
    final source = _item;
    final model = _media.editingModel(source);
    if (model == null) return;
    if (desktop) {
      setState(() => _editing = !_editing);
      return;
    }
    final batchId = await showFormSheet<String>(
      context,
      backgroundColor: const Color(0xff1c1c1e),
      builder: (sheet) => Theme(
        data: ThemeData.from(
          colorScheme: const ColorScheme.dark(surface: Color(0xff1c1c1e)),
        ),
        child: FormSheet(
          title: AppLocalizations.of(context)!.creationEditImage,
          children: [
            _CreationEditForm(
              media: _media,
              item: source,
              model: model,
              focus: _editFocus,
              desktop: false,
              onSubmitted: (id) => Navigator.of(sheet).pop(id),
            ),
          ],
        ),
      ),
    );
    if (batchId != null) _finishEdit(source, batchId);
  }

  void _finishEdit(GenerationItemRow source, String id) {
    if (!mounted) return;
    final topicId = _media.batch(source.batchId)?.topicId;
    final l10n = AppLocalizations.of(context)!;
    showAppSnackBar(context, message: l10n.creationEditStarted);
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
      final body = SafeArea(
        child: Column(
          children: [
            _header(context, item, batch, editModel, favorite),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _canvas(context, item)),
                  if (_editing && editModel != null)
                    SizedBox(
                      width: (MediaQuery.sizeOf(context).width * .44).clamp(
                        230.0,
                        360.0,
                      ),
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
                ],
              ),
            ),
            if (!desktop && batch != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 3, 15, 8),
                child: Text(
                  batch.prompt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            if (_deck.length > 1) _thumbnailStrip(),
            if (desktop && _deck.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: _counter(),
              ),
            if (!desktop)
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 7),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _mobileAction(
                      item.favorite ? LucideIcons.starOff : LucideIcons.star,
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
                      () => saveCreationArtwork(context, item, desktop: false),
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
                  ],
                ),
              ),
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
            child: desktop
                ? BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: body,
                  )
                : body,
          ),
        ),
      );
    },
  );

  Widget _icon(IconData icon, String label, VoidCallback? onTap) =>
      IosIconButton(
        icon: icon,
        tooltip: label,
        color: Colors.white,
        size: 17,
        minSize: 34,
        onTap: onTap,
      );

  Widget _counter() => Text(
    '${_index + 1} / ${_deck.length}',
    style: const TextStyle(color: Colors.white70, fontSize: 12),
  );

  Widget _header(
    BuildContext context,
    GenerationItemRow item,
    GenerationBatchRow? batch,
    MediaModelChoice? editModel,
    VoidCallback favorite,
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
            if (!desktop && jump)
              ActionSheetItem(
                icon: LucideIcons.externalLink,
                label: l10n.creationShowInTopic,
                onTap: () => _jump(topicId, item.batchId),
              ),
            if (!desktop && jumpToChat)
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
              includePrimary: false,
              onEdit: _toggleEdit,
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
    final captions = [
      if (topic != null) topic.title,
      if (conversation != null) l10n.creationChatSource(conversation.title),
      if (batch != null) batch.modelId,
      if (ratio != 'auto') ratio,
      if (batch != null)
        MaterialLocalizations.of(context).formatCompactDate(batch.createdAt),
      if (batch?.source == GenerationSource.edit) l10n.creationEditImage,
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(Platform.isMacOS ? 90 : 12, 8, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
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
                Text(
                  captions.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xf2303032),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                if (jump)
                  _icon(
                    LucideIcons.externalLink,
                    l10n.creationShowInTopic,
                    () => _jump(topicId, item.batchId),
                  ),
                if (jumpToChat)
                  _icon(
                    LucideIcons.externalLink,
                    l10n.creationShowInConversation,
                    openChat,
                  ),
                if (editModel != null)
                  _icon(Lucide.Pencil, l10n.creationEditImage, _toggleEdit),
                _icon(
                  item.favorite ? LucideIcons.starOff : LucideIcons.star,
                  item.favorite
                      ? l10n.creationUnfavorite
                      : l10n.creationFavorite,
                  favorite,
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
              ],
            ),
          ),
          close,
        ],
      ),
    );
  }

  Widget _canvas(BuildContext context, GenerationItemRow item) {
    final l10n = AppLocalizations.of(context)!;
    final nav = desktop && _deck.length > 1;
    final view = item.mode == MediaMode.video
        ? CreationVideoPlayer(
            key: ValueKey(item.id),
            item: item,
            cover: CreationMediaCover(item, playOverlay: false),
          )
        : InteractiveViewer(
            key: ValueKey(item.id),
            transformationController: _transform,
            minScale: 1,
            maxScale: 4,
            onInteractionStart: (details) {
              _dragStart = details.focalPoint;
              _swipeX = 0;
            },
            onInteractionUpdate: (details) {
              if (desktop) return;
              if (details.pointerCount > 1 ||
                  _transform.value.getMaxScaleOnAxis() > 1.02) {
                _swipeX = 0;
                if (_dragOffset != Offset.zero) {
                  setState(() => _dragOffset = Offset.zero);
                }
                return;
              }
              final offset = details.focalPoint - _dragStart;
              _swipeX = offset.dx.abs() > offset.dy.abs() ? offset.dx : 0;
              if (offset.dy > 0 && offset.dy > offset.dx.abs()) {
                setState(() => _dragOffset = Offset(0, offset.dy));
              } else if (_dragOffset != Offset.zero) {
                setState(() => _dragOffset = Offset.zero);
              }
            },
            onInteractionEnd: (_) {
              if (desktop) return;
              final down = _dragOffset.dy;
              final horizontal = _swipeX;
              _swipeX = 0;
              if (down > 110) {
                Navigator.of(context).pop();
              } else {
                if (_dragOffset != Offset.zero) {
                  setState(() => _dragOffset = Offset.zero);
                }
                if (horizontal.abs() > 60) {
                  _switch(_index + (horizontal < 0 ? 1 : -1));
                }
              }
            },
            child: GestureDetector(
              onTapUp: _zoom,
              child: CreationDragOut(
                item: item,
                enabled: desktop,
                child: Hero(
                  tag: 'creation:${item.id}',
                  child: CreationFileImage(item.path, fit: BoxFit.contain),
                ),
              ),
            ),
          );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: desktop ? 10 : 0, vertical: 10),
      child: Row(
        children: [
          if (nav)
            _icon(
              Lucide.ChevronLeft,
              l10n.creationPrevious,
              _index > 0 ? () => _switch(_index - 1) : null,
            ),
          Expanded(
            child: Transform.translate(
              offset: _dragOffset * .6,
              child: Transform.scale(
                scale: 1 - (_dragOffset.dy / 600).clamp(0.0, .25),
                child: view,
              ),
            ),
          ),
          if (nav)
            _icon(
              Lucide.ChevronRight,
              l10n.creationNext,
              _index + 1 < _deck.length ? () => _switch(_index + 1) : null,
            ),
        ],
      ),
    );
  }

  Widget _thumbnailStrip() {
    final size = desktop ? 48.0 : 44.0;
    return SizedBox(
      height: size + 4,
      child: ListView.builder(
        controller: _thumbs,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: _deck.length,
        itemBuilder: (context, index) => GestureDetector(
          onTap: () => _switch(index),
          child: Container(
            width: size,
            height: size,
            margin: EdgeInsets.only(
              right:
                  index + 1 < _deck.length &&
                      _deck[index + 1].batchId != _deck[index].batchId
                  ? 12
                  : 5,
            ),
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
                child: CreationMediaCover(_deck[index]),
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

class CreationDragOut extends StatelessWidget {
  const CreationDragOut({
    super.key,
    required this.item,
    required this.enabled,
    required this.child,
  });

  final GenerationItemRow item;
  final bool enabled;
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
      child: drag.DraggableWidget(child: child),
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
        showAppSnackBar(
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
    final colors = Theme.of(context).colorScheme;
    return Theme(
      data: widget.desktop
          ? ThemeData.from(
              colorScheme: const ColorScheme.dark(
                surface: Color(0xff1c1c1e),
                primary: Colors.white,
              ),
            )
          : Theme.of(context),
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
          TextField(
            controller: _prompt,
            focusNode: widget.focus,
            onChanged: (_) => setState(() {}),
            minLines: 4,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: l10n.creationEditPrompt,
              hintText: l10n.creationEditPromptExample,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedTabs(
            expand: options.length <= 3,
            radioGroup: true,
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
          FilledButton.icon(
            style: widget.desktop
                ? FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  )
                : null,
            onPressed: _busy || _prompt.text.trim().isEmpty
                ? null
                : () => _send(selected),
            icon: const Icon(LucideIcons.sparkles, size: 16),
            label: Text(l10n.creationEditNewGroup),
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
  Offset? anchor,
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
  Offset? anchor,
}) {
  if (!desktop) {
    return showMobileActionSheet(context, title: title, items: items);
  }
  final render = context.findRenderObject() as RenderBox?;
  final position =
      anchor ??
      render?.localToGlobal(render.size.bottomCenter(Offset.zero)) ??
      Offset.zero;
  return showDesktopContextMenuAt(
    context,
    globalPosition: position,
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
            showAppSnackBar(context, message: l10n.creationOptionCopied);
          }
        },
      ),
    if (image)
      ActionSheetItem(
        icon: LucideIcons.imagePlus,
        label: l10n.creationUseReference,
        onTap: () =>
            addCreationArtworkReference(context, media, item, draftTopicId),
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
      showAppSnackBar(
        context,
        message: AppLocalizations.of(context)!.creationActionFailed,
      );
    }
  }
}

void addCreationArtworkReference(
  BuildContext context,
  MediaCreationController media,
  GenerationItemRow item,
  String? topicId,
) {
  final changed = media.addReferencePaths(topicId, [item.path]) > 0;
  final l10n = AppLocalizations.of(context)!;
  showAppSnackBar(
    context,
    message: changed
        ? l10n.creationReferenceAdded
        : l10n.creationReferenceLimitReached(
            media.model?.capabilities.maxReferences ?? 0,
          ),
  );
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
    showAppSnackBar(
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
    showAppSnackBar(
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
        showAppSnackBar(
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
  final yes = await showAppDialog<bool>(
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
                TextButton(
                  onPressed: () => Navigator.of(dialog).pop(false),
                  child: Text(
                    MaterialLocalizations.of(dialog).cancelButtonLabel,
                  ),
                ),
                TextButton(
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
    showAppSnackBar(
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
  });

  final String path;
  final BoxFit fit;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    final file = SandboxPathResolver.resolveForIo(path);
    const placeholder = Center(child: Icon(Lucide.Image, size: 22));
    return file == null
        ? placeholder
        : Image.file(
            File(file),
            cacheWidth: cacheWidth,
            fit: fit,
            width: double.infinity,
            height: double.infinity,
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
