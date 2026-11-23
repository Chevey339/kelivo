import 'creation_menu.dart';
import 'creation_controls.dart';
import 'creation_picker.dart';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../../core/models/media_creation.dart';
import '../../../core/services/media/media_request.dart';
import '../../../core/services/tool_image.dart';
import '../../../core/services/workspace/workspace_image_download.dart';
import '../../../core/utils/multimodal_input_utils.dart';
import '../../../desktop/desktop_context_menu.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/action_sheet.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/sliding_segmented_tabs.dart';
import 'creation_toast.dart';
import '../../../theme/app_font_weights.dart';
import '../../../utils/app_directories.dart';
import '../../home/services/composer_clipboard.dart';
import '../providers/media_creation_controller.dart';
import 'creation_lightbox.dart';

typedef ReferencePathsCallback = void Function(List<String> paths);

Future<void> showCreationReferenceSources(
  BuildContext context, {
  required bool desktop,
  required int limit,
  required ReferencePathsCallback onSelected,
  MediaReferenceRole? frameRole,
}) async {
  final l10n = AppLocalizations.of(context)!;
  Future<void> chooseFiles() async {
    final files = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: limit > 1,
    );
    if (!context.mounted || files == null) return;
    onSelected([
      for (final file in files.files)
        if (file.path case final path?) path,
    ]);
  }

  Future<void> choosePhotos() async {
    final files = limit == 1
        ? [
            if (await ImagePicker().pickImage(source: ImageSource.gallery)
                case final photo?)
              photo,
          ]
        : await ImagePicker().pickMultiImage();
    if (context.mounted && files.isNotEmpty) {
      onSelected(files.map((file) => file.path).toList());
    }
  }

  Future<void> camera() async {
    final file = await ImagePicker().pickImage(source: ImageSource.camera);
    if (context.mounted && file != null) onSelected([file.path]);
  }

  Future<void> recent() async {
    final selected = await _showRecentImages(
      context,
      desktop: desktop,
      limit: limit,
      frameRole: frameRole,
    );
    if (context.mounted && selected != null && selected.isNotEmpty) {
      onSelected(selected);
    }
  }

  Future<void> paste() async {
    final data = await readCreationClipboard();
    if (!context.mounted) return;
    if (data.paths.isEmpty) {
      showCreationToast(context, message: l10n.creationNoClipboardImage);
    } else {
      onSelected(data.paths);
    }
  }

  void run(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (context.mounted) {
        showCreationToast(context, message: l10n.creationActionFailed);
      }
    }
  }

  final items = [
    ActionSheetItem(
      icon: desktop ? Lucide.FolderOpen : Lucide.Image,
      label: desktop
          ? l10n.creationChooseReferenceFile
          : l10n.creationChooseFromLibrary,
      onTap: () => run(desktop ? chooseFiles : choosePhotos),
    ),
    if (!desktop)
      ActionSheetItem(
        icon: Lucide.Camera,
        label: l10n.creationTakeReferencePhoto,
        onTap: () => run(camera),
      ),
    ActionSheetItem(
      icon: LucideIcons.images,
      label: l10n.creationRecentImages,
      onTap: () => run(recent),
    ),
    ActionSheetItem(
      icon: Lucide.Clipboard,
      label: l10n.creationPasteReference,
      onTap: () => run(paste),
    ),
  ];
  if (!desktop) {
    await showCreationActions(
      context,
      title: l10n.creationAddReference,
      items: items,
    );
    return;
  }
  await showCreationMenu(
    context,
    preferAbove: true,
    items: [
      for (final item in items)
        DesktopContextMenuItem(
          icon: item.icon,
          label: item.label,
          onTap: item.onTap,
        ),
      DesktopContextMenuItem(
        label: l10n.creationReferenceDropHint,
        startsGroup: true,
      ),
    ],
  );
}

Future<({List<String> paths, String? text})> readCreationClipboard() async {
  final data = await ComposerClipboard.read();
  final bytes = data.bytes;
  if (bytes == null) return (paths: data.paths, text: data.text);
  if (bytes.length > 20 * 1024 * 1024) {
    throw const MediaFailure(
      MediaFailureKind.referenceTooLarge,
      'Reference image too large',
    );
  }
  final cache = await AppDirectories.getCacheDirectory();
  final file = await ComposerClipboard.reserve(
    Directory(p.join(cache.path, 'creation-references')),
    'reference',
    data.format ?? 'png',
  );
  try {
    await file.writeAsBytes(bytes, flush: true);
    return (paths: [file.path], text: null);
  } catch (_) {
    await ComposerClipboard.discard(file);
    rethrow;
  }
}

List<String> creationImagePaths(Iterable<String> files) => [
  for (final path in files)
    if (inferMediaMimeFromSource(path).startsWith('image/')) path,
];

Future<List<String>?> _showRecentImages(
  BuildContext context, {
  required bool desktop,
  required int limit,
  MediaReferenceRole? frameRole,
}) {
  final l10n = AppLocalizations.of(context)!;
  final media = context.read<MediaCreationController>();
  final screen = MediaQuery.sizeOf(context);
  final content = SizedBox(
    height: math.min(screen.height * (desktop ? .69 : .62), 550),
    child: _RecentImages(
      media: media,
      desktop: desktop,
      limit: limit,
      frameRole: frameRole,
    ),
  );
  if (!desktop) {
    return showCreationPicker<List<String>>(
      context,
      desktop: false,
      title: l10n.creationRecentImages,
      scroll: false,
      builder: (_) => content,
    );
  }
  return showCreationDialog<List<String>>(
    context,
    maxWidth: 560,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.creationRecentImages,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Flexible(child: content),
        ],
      ),
    ),
  );
}

class _RecentImages extends StatefulWidget {
  const _RecentImages({
    required this.media,
    required this.desktop,
    required this.limit,
    required this.frameRole,
  });

  final MediaCreationController media;
  final bool desktop;
  final int limit;
  final MediaReferenceRole? frameRole;

  @override
  State<_RecentImages> createState() => _RecentImagesState();
}

class _RecentImagesState extends State<_RecentImages> {
  static const _pageSize = 48;
  final _images = <RecentMediaImage>[];
  final _selected = <String>{};
  final _scroll = ScrollController();
  RecentImageSource _source = RecentImageSource.all;
  int _page = 0;
  int _revision = 0;
  bool _more = true;
  bool _loading = false;
  bool _error = false;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoad);
    _load();
  }

  void _maybeLoad() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 300) _load();
  }

  Future<void> _load() async {
    if (_loading || !_more) return;
    final revision = _revision;
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final next = await widget.media.runner.repository.recentImages(
        _source,
        offset: _page * _pageSize,
        limit: _pageSize,
      );
      if (!mounted || revision != _revision) return;
      final paths = _images.map((image) => image.path).toSet();
      setState(() {
        _images.addAll(next.where((image) => paths.add(image.path)));
        _page++;
        _more = next.length == _pageSize;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && revision == _revision) _maybeLoad();
      });
    } catch (_) {
      if (!mounted || revision != _revision) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  void _filter(RecentImageSource value) {
    if (value == _source) return;
    setState(() {
      _source = value;
      _revision++;
      _page = 0;
      _more = true;
      _loading = false;
      _error = false;
      _images.clear();
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _load();
  }

  void _toggle(String path) {
    if (_adding) return;
    setState(() {
      if (_selected.remove(path)) return;
      if (widget.limit == 1) _selected.clear();
      if (_selected.length < widget.limit) _selected.add(path);
    });
  }

  Uri? _remoteUri(String path) {
    final uri = Uri.tryParse(path);
    return uri != null &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty &&
            (uri.isScheme('https') || uri.isScheme('http'))
        ? uri
        : null;
  }

  Future<void> _confirm() async {
    final selected = _selected.toList();
    if (selected.every((path) => _remoteUri(path) == null)) {
      Navigator.of(context).pop(selected);
      return;
    }
    setState(() => _adding = true);
    final temporaryFiles = <File>[];
    try {
      final cache = await AppDirectories.getCacheDirectory();
      final directory = Directory(p.join(cache.path, 'creation-references'));
      void checkOpen() {
        if (!mounted || ModalRoute.of(context)?.isCurrent != true) {
          throw StateError('Recent image picker closed');
        }
      }

      final paths = <String>[];
      for (final path in selected) {
        final uri = _remoteUri(path);
        if (uri == null) {
          paths.add(path);
          continue;
        }
        final bytes = await downloadWorkspaceImage(uri, checkAccess: checkOpen);
        final image = await ToolImage.fromNetworkBytes(bytes);
        checkOpen();
        final file = await ComposerClipboard.reserve(
          directory,
          'reference',
          AppDirectories.extFromMime(image.mime),
        );
        temporaryFiles.add(file);
        await file.writeAsBytes(image.bytes, flush: true);
        paths.add(file.path);
      }
      checkOpen();
      if (!mounted) return;
      Navigator.of(context).pop(paths);
    } catch (_) {
      for (final file in temporaryFiles) {
        await ComposerClipboard.discard(file);
      }
      if (!mounted) return;
      setState(() => _adding = false);
      showCreationToast(
        context,
        message: AppLocalizations.of(context)!.creationDownloadFailed,
      );
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final frame = switch (widget.frameRole) {
      MediaReferenceRole.firstFrame => l10n.creationFirstFrame,
      MediaReferenceRole.lastFrame => l10n.creationLastFrame,
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SlidingSegmentedTabs(
          index: _source.index,
          height: 34,

          tabs: [
            SegmentedTab(label: l10n.creationFilterAll),
            SegmentedTab(label: l10n.creationRecentCreation),
            SegmentedTab(label: l10n.creationRecentChat),
          ],
          onChanged: (index) => _filter(RecentImageSource.values[index]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Text(
            frame ?? l10n.creationReferenceSlotsAvailable(widget.limit),
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: _images.isEmpty && _error
              ? Center(
                  child: CreationAction(
                    onPressed: _load,
                    child: Text(l10n.creationRetry),
                  ),
                )
              : _images.isEmpty && _loading
              ? const Center(child: CreationSpinner())
              : _images.isEmpty
              ? Center(child: Text(l10n.creationRecentEmpty))
              : GridView.builder(
                  padding: EdgeInsets.zero,
                  controller: _scroll,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: widget.desktop ? 5 : 3,
                    crossAxisSpacing: 7,
                    mainAxisSpacing: 7,
                  ),
                  itemCount: _images.length + (_loading || _error ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _images.length) {
                      return Center(
                        child: _error
                            ? CreationAction(
                                onPressed: _load,
                                child: Text(l10n.creationRetry),
                              )
                            : const CreationSpinner(),
                      );
                    }
                    final item = _images[index];
                    final selected = _selected.contains(item.path);
                    final remote = item.thumbnailPath == null
                        ? _remoteUri(item.path)
                        : null;
                    final title = item.title.trim().isNotEmpty
                        ? item.title
                        : item.source == RecentImageSource.chat
                        ? l10n.creationRecentChat
                        : l10n.creationRecentCreation;
                    return Semantics(
                      selected: selected,
                      label: title,
                      child: IosCardPress(
                        focusable: true,
                        onTap: () => _toggle(item.path),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: EdgeInsets.all(selected ? 2.5 : 0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: selected ? colors.primary : null,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (remote case final uri?)
                                  ColoredBox(
                                    color: colors.surfaceContainerHighest,
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Lucide.Image, size: 20),
                                            Text(
                                              uri.host,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  CreationFileImage(
                                    item.thumbnailPath ?? item.path,
                                    cacheWidth: 240,
                                  ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(
                                      5,
                                      12,
                                      5,
                                      4,
                                    ),
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black54,
                                        ],
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          item.source == RecentImageSource.chat
                                              ? Lucide.MessageCircle
                                              : Lucide.Palette,
                                          size: 11,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 3),
                                        Expanded(
                                          child: Text(
                                            title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10.5,
                                              fontWeight:
                                                  AppFontWeights.semibold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 5,
                                  top: 5,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: selected
                                          ? colors.primary
                                          : Colors.black26,
                                      border: Border.all(color: Colors.white54),
                                    ),
                                    child: SizedBox.square(
                                      dimension: 19,
                                      child: selected
                                          ? const Icon(
                                              Lucide.Check,
                                              color: Colors.white,
                                              size: 12,
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                _selected.isEmpty
                    ? l10n.creationTapToSelect
                    : l10n.creationSelectedImages(_selected.length),
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
            ),
            CreationAction(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            CreationAction(
              tone: CreationActionTone.primary,
              onPressed: _selected.isEmpty || _adding ? null : _confirm,
              child: _adding
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CreationSpinner(radius: 7),
                    )
                  : Text(l10n.creationAddSelected(_selected.length)),
            ),
          ],
        ),
      ],
    );
  }
}
