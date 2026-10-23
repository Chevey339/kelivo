import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:markstream/markstream.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:Kelivo/core/services/workspace/file_link_resolver.dart';
import 'package:Kelivo/features/workspace/workspace_file_navigation.dart';
import 'package:Kelivo/features/chat/pages/image_viewer_page.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';

/// Source is read lazily when opening the gallery, avoiding another parse on
/// every streaming frame. Existing image widgets only rebuild for a new scope.
class MarkdownLinkScope extends InheritedWidget {
  const MarkdownLinkScope({
    super.key,
    required super.child,
    required this.source,
    this.conversationId,
  });
  final String source;
  final String? conversationId;
  static MarkdownLinkScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MarkdownLinkScope>();
  static MarkdownLinkScope? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<MarkdownLinkScope>();
  @override
  bool updateShouldNotify(MarkdownLinkScope oldWidget) =>
      conversationId != oldWidget.conversationId;
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

/// Local paths with spaces are parsed directly, without changing source spans.
/// Standard links, escaped labels and URL/title parsing remain in the core.
class LocalImagePathSyntax extends InlineSyntax {
  const LocalImagePathSyntax();
  static final _local = RegExp(r'^(?:/|file://|[A-Za-z]:[\\/])');
  @override
  Set<int> get startCharacters => const {33};
  @override
  InlineSyntaxMatch? match(InlineSyntaxContext context, int offset) {
    final text = context.text;
    if (!text.startsWith('![', offset)) return null;
    var closeLabel = offset + 2;
    while (closeLabel < text.length && text[closeLabel] != ']') {
      if (text[closeLabel] == '\n' || text[closeLabel] == '\r') return null;
      if (text[closeLabel] == '\\') closeLabel++;
      closeLabel++;
    }
    if (closeLabel >= text.length || !text.startsWith('](', closeLabel)) {
      return null;
    }
    final start = closeLabel + 2;
    var end = start, depth = 0;
    String? quote;
    while (end < text.length) {
      final c = text[end];
      if (c == '\n' || c == '\r') return null;
      if (quote != null) {
        if (c == '\\') {
          end += 2;
          continue;
        }
        if (c == quote) quote = null;
        end++;
        continue;
      }
      if ((c == '"' || c == "'") && end > start && text[end - 1] == ' ') {
        quote = c;
        end++;
        continue;
      }
      if (c == '(') depth++;
      if (c == ')') {
        if (depth == 0) break;
        depth--;
      }
      end++;
    }
    if (end >= text.length) return null;
    var destination = text.substring(start, end).trim();
    if (!_local.hasMatch(destination) || !destination.contains(' ')) {
      return null;
    }
    String? title;
    final titleMatch = RegExp(r'''\s+["'](.*)["']$''').firstMatch(destination);
    if (titleMatch != null) {
      title = titleMatch[1];
      destination = destination.substring(0, titleMatch.start).trimRight();
    }
    return InlineSyntaxMatch(
      end: end + 1,
      node: ImageNode(
        span: context.span(offset, end + 1),
        children: InlineParser(
          options: context.options,
        ).parseFragments(context.textNodes(offset + 2, closeLabel)),
        destination: destination,
        title: title,
      ),
    );
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

ImageProvider? markdownImageProvider(String source) {
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
  String? _conversationId;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final conversationId = MarkdownLinkScope.of(context)?.conversationId;
    if (_file == null || conversationId != _conversationId) {
      _conversationId = conversationId;
      _resolve();
    }
  }

  @override
  void didUpdateWidget(_MarkdownImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _resolve();
  }

  void _resolve() {
    _file = KelivoLink.tryParse(widget.url) == null
        ? null
        : resolveWorkspaceLinkedFile(
            context,
            widget.url,
            conversationId: _conversationId,
          );
  }

  Widget _broken() => ColoredBox(
    color: widget.theme.colors.fillBlock,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Icon(Lucide.ImageOff, size: 22, color: widget.theme.colors.ink3),
    ),
  );
  @override
  Widget build(BuildContext context) {
    if (_file == null) {
      return _image(widget.url, markdownImageProvider(widget.url));
    }
    return FutureBuilder<File?>(
      future: _file,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final file = snapshot.data;
        return file == null ? _broken() : _image(file.path, FileImage(file));
      },
    );
  }

  Widget _image(String url, ImageProvider? provider) {
    if (provider == null) return _broken();
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _open(url),
        child: LayoutBuilder(
          builder: (context, constraints) {
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
                : widget.height;
            final cacheWidth = width == null
                ? null
                : math.max(
                    1,
                    (width * MediaQuery.devicePixelRatioOf(context)).ceil(),
                  );
            return Container(
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.theme.imageRadius),
                border: Border.all(
                  color: widget.theme.colors.divider,
                  width: MarkstreamTheme.stroke,
                ),
              ),
              child: Image(
                image: ResizeImage.resizeIfNeeded(cacheWidth, null, provider),
                width: width,
                height: height,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) => _broken(),
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
      final pending = <MarkdownNode>[
        MarkdownParser(
          inlineSyntaxes: const [LocalImagePathSyntax()],
        ).parse(source),
      ];
      while (pending.isNotEmpty) {
        final node = pending.removeLast();
        final destination = node is ImageNode
            ? node.destination
            : node is HtmlElementNode && node.tag == 'img'
            ? node.attributes['src']
            : null;
        if (destination != null &&
            (node is ImageNode || isSafeHtmlUrl(destination, image: true)) &&
            KelivoLink.tryParse(destination) == null) {
          urls.add(destination);
        }
        pending.addAll(node.children.reversed);
      }
    }
    if (!urls.contains(url)) urls.insert(0, url);
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) =>
            ImageViewerPage(images: urls, initialIndex: urls.indexOf(url)),
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
