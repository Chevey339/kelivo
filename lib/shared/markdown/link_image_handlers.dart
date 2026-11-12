import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'markdown_image_sources.dart';

import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:markstream/markstream.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/workspace/file_link_resolver.dart';
import 'package:Kelivo/features/workspace/workspace_file_navigation.dart';
import 'package:Kelivo/features/chat/pages/image_viewer_page.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:Kelivo/shared/widgets/scroll_layout_anchor.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';
import 'package:Kelivo/utils/svg_image_provider.dart';
import 'package:open_filex/open_filex.dart';

/// Source is read lazily when opening the gallery, avoiding another parse on
/// every streaming frame. Existing image widgets only rebuild for a new scope.
class MarkdownLinkScope extends InheritedWidget {
  const MarkdownLinkScope({
    super.key,
    required super.child,
    required this.source,
    this.conversationId,
    this.imageStorage,
  });
  final String source;
  final String? conversationId;
  final PageStorageBucket? imageStorage;
  static MarkdownLinkScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MarkdownLinkScope>();
  static MarkdownLinkScope? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<MarkdownLinkScope>();
  @override
  bool updateShouldNotify(MarkdownLinkScope oldWidget) =>
      conversationId != oldWidget.conversationId ||
      !identical(imageStorage, oldWidget.imageStorage);
}

class KelivoLinkHandler implements LinkHandler {
  const KelivoLinkHandler();
  @override
  Future<void> open(BuildContext context, LinkNode link) async {
    final url = link.destination
        .replaceAll(RegExp(r'[\u200B\u200C\u200D\uFEFF]'), '')
        .trim();
    if (KelivoLink.tryParse(url) != null) {
      await openWorkspaceLinkedFile(
        context,
        url,
        conversationId: MarkdownLinkScope.read(context)?.conversationId,
      );
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    try {
      final uri = Uri.parse(
        RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(url)
            ? url
            : 'https://$url',
      );
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        showAppSnackBar(
          context,
          message: l10n.chatMessageWidgetOpenLinkError,
          type: NotificationType.error,
        );
      }
    } catch (_) {
      if (context.mounted) {
        showAppSnackBar(
          context,
          message: l10n.chatMessageWidgetCannotOpenUrl(url),
          type: NotificationType.error,
        );
      }
    }
  }
}

class KelivoImageBuilder implements ImageBuilder {
  const KelivoImageBuilder();
  static final _dimensions = RegExp(r'^(?:(\d+)(?:x(\d+))?|x(\d+))$');
  @override
  Widget build(BuildContext context, ImageNode image, MarkstreamTheme theme) {
    final dimensions = _dimensions.firstMatch(toPlainText(image).trim());
    double? size(String? value) {
      final number = double.tryParse(value ?? '');
      return number != null && number.isFinite && number > 0 ? number : null;
    }

    return _MarkdownImage(
      theme: theme,
      url: image.destination,
      width: size(dimensions?[1]),
      height: size(dimensions?[2] ?? dimensions?[3]),
    );
  }
}

ImageProvider? markdownImageProvider(
  String source, {
  Color currentColor = const Color(0xff000000),
}) {
  if (isSvgImageSource(source)) {
    return SvgImageProvider(source, currentColor: currentColor);
  }
  if (source.startsWith('http://') || source.startsWith('https://')) {
    return NetworkImage(source);
  }
  if (source.startsWith('data:')) {
    try {
      return MemoryImage(UriData.parse(source).contentAsBytes());
    } catch (_) {
      return null;
    }
  }
  try {
    final file = File(SandboxPathResolver.fix(source));
    return file.existsSync() ? FileImage(file) : null;
  } catch (_) {
    return null;
  }
}

class _MarkdownImage extends StatefulWidget {
  const _MarkdownImage({
    required this.url,
    required this.theme,
    this.width,
    this.height,
  });
  final MarkstreamTheme theme;
  final String url;
  final double? width, height;
  @override
  State<_MarkdownImage> createState() => _MarkdownImageState();
}

class _MarkdownImageState extends State<_MarkdownImage> {
  Future<File?>? _file;
  File? _cachedFile;
  Object? _fileCacheId;
  String? _conversationId;
  late String _sourceId = sha256.convert(utf8.encode(widget.url)).toString();
  PageStorageBucket? _storage;
  double? _aspect;
  (String, Color?)? _providerSource;
  ImageProvider? _provider;
  ImageProvider? _listenedProvider;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  Object get _aspectId => ('markdown-image-aspect', _conversationId, _sourceId);

  bool _syncAspect({bool sourceChanged = false}) {
    final storage =
        MarkdownLinkScope.read(context)?.imageStorage ??
        PageStorage.maybeOf(context);
    if (!sourceChanged && identical(storage, _storage)) return false;
    _stopListening();
    _listenedProvider = null;
    _storage = storage;
    _aspect = storage?.readState(context, identifier: _aspectId) as double?;
    return true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final conversationId = MarkdownLinkScope.of(context)?.conversationId;
    final changed = conversationId != _conversationId;
    _conversationId = conversationId;
    final storageChanged = _syncAspect(sourceChanged: changed);
    if (_file == null || changed || storageChanged) {
      _resolve();
    }
  }

  @override
  void didUpdateWidget(_MarkdownImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = oldWidget.url != widget.url;
    if (changed) {
      _sourceId = sha256.convert(utf8.encode(widget.url)).toString();
    }
    final storageChanged = _syncAspect(sourceChanged: changed);
    if (changed || storageChanged) _resolve();
  }

  void _stopListening() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  void _listenForAspect(ImageProvider provider) {
    if (_listenedProvider == provider) return;
    _stopListening();
    _listenedProvider = provider;
    _stream = provider.resolve(createLocalImageConfiguration(context));
    _listener = ImageStreamListener(
      (info, synchronous) {
        final aspect = info.image.width / info.image.height;
        info.dispose();
        // Geometry needs only the first frame. Leave animated-image playback
        // and TickerMode handling to Image's own listener.
        _stopListening();
        if (!mounted || !aspect.isFinite || aspect <= 0) return;
        _storage?.writeState(context, aspect, identifier: _aspectId);
        if (_aspect == aspect) return;
        if (synchronous) {
          _aspect = aspect;
        } else {
          preserveScrollLayoutAnchor(context);
          setState(() => _aspect = aspect);
        }
      },
      // Image's errorBuilder owns the visible failure state.
      onError: (Object error, StackTrace? stack) => _stopListening(),
    );
    _stream!.addListener(_listener!);
  }

  ({double? width, double? height}) _displaySize(BoxConstraints constraints) {
    final available = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : null;
    final requestedWidth = widget.width ?? available;
    final width = requestedWidth == null || available == null
        ? requestedWidth
        : math.min(requestedWidth, available);
    final height =
        widget.height != null && widget.width != null && width != null
        ? widget.height! * width / widget.width!
        : widget.height ??
              (width != null && _aspect != null ? width / _aspect! : null);
    return (width: width, height: height);
  }

  void _resolve() {
    final link = KelivoLink.tryParse(widget.url);
    _cachedFile = null;
    _fileCacheId = null;
    if (link == null) {
      _file = null;
      return;
    }
    if (link.kind == KelivoLinkKind.workspaceFile) {
      final chat = context.read<ChatService?>();
      final id = _conversationId ?? chat?.currentConversationId;
      final conversation = id == null ? null : chat?.getConversation(id);
      final workspaceId = conversation?.extras[WorkspaceBinding.keyId];
      final resolver = context.read<FileLinkResolver?>();
      final workspaces =
          resolver?.workspaces ?? context.read<WorkspaceProvider?>();
      final workspace = workspaceId is String
          ? workspaces?.byId(workspaceId)
          : null;
      // Retain only the resolved source, never image pixels. A different
      // conversation, binding, workspace root or resolver starts a fresh view.
      _fileCacheId = (
        'markdown-workspace-image',
        id,
        _sourceId,
        workspaceId,
        workspace?.kind,
        workspace?.hostPath,
        resolver,
      );
      _cachedFile =
          _storage?.readState(context, identifier: _fileCacheId) as File?;
    }
    final storage = _storage;
    final cacheId = _fileCacheId;
    final request = resolveWorkspaceLinkedFile(
      context,
      widget.url,
      conversationId: _conversationId,
    );
    _file = request;
    request.then((file) {
      if (!mounted || !identical(_file, request)) return;
      if (cacheId != null && identical(storage, _storage)) {
        storage?.writeState(context, file, identifier: cacheId);
      }
      preserveScrollLayoutAnchor(context);
    });
  }

  ImageProvider? _imageProvider(String source) {
    final color = isSvgImageSource(source) ? widget.theme.proseInk : null;
    final input = (source, color);
    if (_providerSource != input || _provider == null) {
      _providerSource = input;
      _provider = markdownImageProvider(
        source,
        currentColor: color ?? widget.theme.proseInk,
      );
    }
    return _provider;
  }

  Widget _broken() => ColoredBox(
    color: widget.theme.colors.fillBlock,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Icon(Lucide.ImageOff, size: 22, color: widget.theme.colors.ink3),
    ),
  );

  Widget _loading(BoxConstraints constraints) {
    final size = _displaySize(constraints);
    return SizedBox(
      width: size.width ?? 36,
      height: size.height ?? 36,
      child: const Center(
        child: SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  bool _hasCachedPixels(ImageProvider provider) {
    // FileImage/SvgImageProvider and their ResizeImage wrapper have synchronous
    // keys. Check only the existing cache: an unvalidated path must not start
    // a new file read or decode while workspace resolution is still pending.
    var cached = false;
    provider.obtainKey(createLocalImageConfiguration(context)).then((key) {
      cached = PaintingBinding.instance.imageCache.statusForKey(key).keepAlive;
    });
    return cached;
  }

  @override
  Widget build(BuildContext context) {
    if (_file == null) {
      return _image(widget.url, _imageProvider(widget.url));
    }
    return FutureBuilder<File?>(
      key: ValueKey((_conversationId, _sourceId, _fileCacheId)),
      future: _file,
      initialData: _cachedFile,
      builder: (context, snapshot) {
        final resolving = snapshot.connectionState != ConnectionState.done;
        if (resolving && snapshot.data == null) {
          // File resolution runs again after recycling. Preserve the decoded
          // aspect (or explicit dimensions) while the file is being located.
          return LayoutBuilder(
            builder: (context, constraints) => _loading(constraints),
          );
        }
        final file = snapshot.data;
        return file == null
            ? _broken()
            : _image(
                file.path,
                _imageProvider(file.path),
                cacheOnly: resolving,
              );
      },
    );
  }

  Widget _image(String url, ImageProvider? provider, {bool cacheOnly = false}) {
    if (provider == null) {
      return cacheOnly
          ? LayoutBuilder(
              builder: (context, constraints) => _loading(constraints),
            )
          : _broken();
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          if (!cacheOnly) {
            _open(url);
            return;
          }
          final request = _file;
          final file = await request;
          if (!mounted ||
              !identical(_file, request) ||
              file == null ||
              ModalRoute.of(context)?.isCurrent == false) {
            return;
          }
          _open(file.path);
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = _displaySize(constraints).width;
            final cacheWidth = width == null
                ? null
                : math.max(
                    1,
                    (width * MediaQuery.devicePixelRatioOf(context)).ceil(),
                  );
            final resized = ResizeImage.resizeIfNeeded(
              cacheWidth,
              null,
              provider,
            );
            if (cacheOnly && !_hasCachedPixels(resized)) {
              return _loading(constraints);
            }
            // Observe the same decoded stream as Image, without decoding a
            // second full-resolution copy or retaining image pixels in storage.
            _listenForAspect(resized);
            final height = _displaySize(constraints).height;
            return Container(
              width: width,
              // File resolution and pixel decoding are separate async stages.
              // Keep the loading extent until the first decoded aspect arrives.
              height: height ?? (_aspect == null ? 36 : null),
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.theme.imageRadius),
                border: Border.all(
                  color: widget.theme.colors.divider,
                  width: MarkstreamTheme.stroke,
                ),
              ),
              child: Image(
                key: ValueKey(url),
                image: resized,
                width: width,
                height: height,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (context, error, stack) => isSvgImageSource(url)
                    ? GestureDetector(
                        onTap: () async {
                          if (url.startsWith('http://') ||
                              url.startsWith('https://')) {
                            await const KelivoLinkHandler().open(
                              context,
                              LinkNode(
                                span: const SourceSpan(0, 0),
                                children: const [],
                                destination: url,
                              ),
                            );
                          } else if (!url.startsWith('data:')) {
                            await OpenFilex.open(SandboxPathResolver.fix(url));
                          }
                        },
                        child: _broken(),
                      )
                    : _broken(),
              ),
            );
          },
        ),
      ),
    );
  }

  void _open(String url) {
    final source = MarkdownLinkScope.read(context)?.source;
    final urls = <String>[];
    if (source != null) {
      urls.addAll(
        markdownImageSources(
          source,
        ).where((url) => KelivoLink.tryParse(url) == null),
      );
    }
    if (!urls.contains(url)) urls.insert(0, url);
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => ImageViewerPage(
          images: urls,
          initialIndex: urls.indexOf(url),
          imageProviders: {
            for (final source in urls)
              if (isSvgImageSource(source))
                source: SvgImageProvider(
                  source,
                  currentColor: widget.theme.proseInk,
                ),
          },
        ),
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
          child: child,
        ),
      ),
    );
  }
}
