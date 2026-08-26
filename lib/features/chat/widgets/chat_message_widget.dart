import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, visibleForTesting;
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/services.dart';
import '../../../core/services/haptics.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:open_filex/open_filex.dart';
// import 'package:easy_image_viewer/easy_image_viewer.dart';
import 'dart:convert';
import '../../home/widgets/file_processing_indicator.dart';
import '../pages/image_viewer_page.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/message_part.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../icons/reasoning_icons.dart';
// import '../../../theme/design_tokens.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/providers/assistant_provider.dart';
import 'package:intl/intl.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../../utils/safe_resize_image.dart';
import '../../../utils/avatar_cache.dart';
import '../../../utils/assistant_regex.dart';
import '../../../core/models/assistant.dart';
import '../../../core/providers/tts_provider.dart';
import '../../../shared/widgets/markdown_with_highlight.dart';
import '../../../shared/widgets/snackbar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../theme/chat_bubble_style.dart';
import 'frosted/frosted_surface.dart';
import '../../../core/providers/model_provider.dart';
import '../../../core/models/assistant_regex.dart';
import '../../../shared/widgets/custom_bottom_sheet.dart';
import '../../../shared/widgets/ios_checkbox.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/thinking_sheen.dart';
import '../../../desktop/desktop_context_menu.dart';
import '../../../desktop/menu_anchor.dart';
import '../../../shared/widgets/emoji_text.dart';
import '../../../utils/platform_utils.dart';
import '../../home/services/ask_user_interaction_service.dart';
import '../../home/services/local_tools_service.dart';
import '../../home/services/tool_approval_service.dart';
import '../utils/thinking_tag_parser.dart';
import 'timeline_projection.dart';
import 'timeline_visibility.dart';
import 'citation_sources_sheet.dart';
import 'chat_suggestion_bubbles.dart';
import 'token_display_widget.dart';
import 'screen_time_tool_ui.dart';
import 'tool_detail_text_section.dart';
import '../../../theme/app_font_weights.dart';

final RegExp _urlSchemeRe = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:');

@visibleForTesting
bool shouldInlineImagePart(ImagePart part) =>
    !part.unavailable && part.uri.trim().isNotEmpty;

Uri? _tryNormalizeExternalUri(String raw) {
  var u = raw.trim();
  if (u.isEmpty) return null;

  // Handle JSON-ish values like `"example.com"` defensively.
  if ((u.startsWith('"') && u.endsWith('"')) ||
      (u.startsWith("'") && u.endsWith("'"))) {
    u = u.substring(1, u.length - 1).trim();
    if (u.isEmpty) return null;
  }

  if (u.startsWith('//')) {
    u = 'https:$u';
  } else if (!_urlSchemeRe.hasMatch(u)) {
    u = 'https://$u';
  }

  final uri = Uri.tryParse(u);
  if (uri == null) return null;
  if ((uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isEmpty) {
    return null;
  }
  return uri;
}

@visibleForTesting
(String, List<String>) parseMcpImagePathsForTesting(
  String? content, {
  Map<String, dynamic>? metadata,
}) => parseToolResultImages(content, metadata: metadata);

@visibleForTesting
const double kToolImageTimelineHeight = 120;
@visibleForTesting
const double kToolImageTimelineMaxWidth = 240;
@visibleForTesting
const double kToolImageCardHeight = 180;
@visibleForTesting
const double kToolImageCardMaxWidth = 320;
@visibleForTesting
const double kToolImageDetailHeight = 220;
@visibleForTesting
const double kToolImageDetailMaxWidth = 420;

@visibleForTesting
const int kToolImageMaxDecodePixels = 2097152; // 8 MiB of RGBA
@visibleForTesting
const int kToolImageMaxDecodeEdge = 2048;

@visibleForTesting
({int width, int height}) toolImageDecodePixels({
  required double logicalWidth,
  required double logicalHeight,
  required double devicePixelRatio,
}) {
  final dpr = devicePixelRatio <= 0 ? 1.0 : devicePixelRatio;
  return clampDecodedPixelSize(
    width: math.max(1.0, logicalWidth * dpr),
    height: math.max(1.0, logicalHeight * dpr),
    maxEdge: kToolImageMaxDecodeEdge,
    maxPixels: kToolImageMaxDecodePixels,
  );
}

/// Incremented when a memoized tool-step builder actually runs.
@visibleForTesting
int debugTimelineToolStepBuilds = 0;

String _resolveAttachmentImageUri(String uri) {
  final path = uri.trim();
  if (path.isEmpty) return path;
  if (path.startsWith('http://') ||
      path.startsWith('https://') ||
      path.startsWith('data:')) {
    return path;
  }
  return SandboxPathResolver.fix(path);
}

/// Decoded `data:` image bytes, keyed by the full data URI.
///
/// Reusing the same [Uint8List] keeps [MemoryImage] cache keys stable across
/// rebuilds, so the image is decoded once instead of on every frame. Entries
/// are evicted least-recently-used first, bounded by both entry count and
/// total decoded bytes so a few large images cannot pin unbounded memory.
final Map<String, Uint8List?> _dataUriBytesCache = <String, Uint8List?>{};
const int _dataUriBytesCacheLimit = 24;
const int _dataUriBytesCacheMaxBytes = 16 << 20;
int _dataUriBytesCacheBytes = 0;

Uint8List? _decodeDataUriBytes(String path) {
  if (_dataUriBytesCache.containsKey(path)) {
    // Re-insert to mark as most recently used (LinkedHashMap keeps order).
    final cached = _dataUriBytesCache.remove(path);
    _dataUriBytesCache[path] = cached;
    return cached;
  }

  Uint8List? bytes;
  try {
    const marker = 'base64,';
    final idx = path.indexOf(marker);
    if (idx != -1) bytes = base64Decode(path.substring(idx + marker.length));
  } catch (_) {
    bytes = null;
  }

  _dataUriBytesCache[path] = bytes;
  _dataUriBytesCacheBytes += bytes?.length ?? 0;
  // Evict oldest entries first. The entry just added is always kept (even if
  // it alone exceeds the byte budget) so its MemoryImage key stays stable.
  while (_dataUriBytesCache.length > 1 &&
      (_dataUriBytesCache.length > _dataUriBytesCacheLimit ||
          _dataUriBytesCacheBytes > _dataUriBytesCacheMaxBytes)) {
    final evicted = _dataUriBytesCache.remove(_dataUriBytesCache.keys.first);
    _dataUriBytesCacheBytes -= evicted?.length ?? 0;
  }
  return bytes;
}

/// Shared image widget for tool thumbnails and message attachment previews.
///
/// Decodes through [SafeResizeImage] at the display area × device pixel ratio so
/// 17K tool outputs are not materialized at full resolution.
Widget _buildResolvedImage(
  BuildContext context,
  String rawPath, {
  double? width,
  double? height,
  double? maxLogicalWidth,
  BoxFit fit = BoxFit.contain,
  Widget Function()? placeholder,
}) {
  final cs = Theme.of(context).colorScheme;
  Widget errorWidget() =>
      placeholder?.call() ??
      Container(
        width: width ?? (height != null ? height * 0.67 : 120),
        height: height ?? 180,
        color: cs.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(
          Lucide.ImageOff,
          size: 24,
          color: cs.onSurface.withValues(alpha: 0.5),
        ),
      );

  final path = rawPath.trim();
  if (path.isEmpty) return errorWidget();

  final provider = _toolImageProvider(path);
  if (provider == null) return errorWidget();

  final logicalHeight = height ?? width ?? kToolImageCardHeight;
  final logicalWidth =
      maxLogicalWidth ??
      width ??
      (height != null ? height * 2 : kToolImageTimelineMaxWidth);
  final decode = toolImageDecodePixels(
    logicalWidth: logicalWidth,
    logicalHeight: logicalHeight,
    devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
  );
  Widget image = Image(
    image: SafeResizeImage.display(
      provider,
      width: decode.width,
      height: decode.height,
      fit: fit == BoxFit.cover ? SafeResizeFit.cover : SafeResizeFit.contain,
      allowUpscaling: false,
      maxEdge: kToolImageMaxDecodeEdge,
      maxPixels: kToolImageMaxDecodePixels,
    ),
    width: width,
    height: height,
    fit: fit,
    gaplessPlayback: true,
    errorBuilder: (_, __, ___) => errorWidget(),
  );
  if (maxLogicalWidth != null) {
    image = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxLogicalWidth),
      child: image,
    );
  }
  return image;
}

ImageProvider<Object>? _toolImageProvider(String path) {
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return NetworkImage(path);
  }
  if (path.startsWith('data:')) {
    final bytes = _decodeDataUriBytes(path);
    if (bytes == null) return null;
    return MemoryImage(bytes);
  }
  return FileImage(File(SandboxPathResolver.fix(path)));
}

ImageProvider? _assistantInlineImageProvider(String src) {
  if (src.startsWith('http://') || src.startsWith('https://')) {
    return NetworkImage(src);
  }
  if (src.startsWith('data:')) {
    final bytes = _decodeDataUriBytes(src);
    if (bytes == null) return null;
    return MemoryImage(bytes);
  }
  final fixed = SandboxPathResolver.fix(src);
  if (File(fixed).existsSync()) return FileImage(File(fixed));
  return null;
}

class _AssistantInlineImage extends StatefulWidget {
  const _AssistantInlineImage({
    required this.uri,
    required this.imageKey,
    required this.group,
    required this.initialIndex,
    this.onAspectResolved,
  });

  final String uri;
  final String imageKey;
  final List<String> group;
  final int initialIndex;
  final void Function(String imageKey, double aspectRatio)? onAspectResolved;

  @override
  State<_AssistantInlineImage> createState() => _AssistantInlineImageState();
}

class _AssistantInlineImageState extends State<_AssistantInlineImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  String? _listenedIdentity;

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  void _stopListening() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
    _listenedIdentity = null;
  }

  void _listenForAspect(ImageProvider provider) {
    final identity = '${widget.imageKey}:${widget.uri.length}';
    if (_listenedIdentity == identity) return;
    _stopListening();
    _listenedIdentity = identity;
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      final width = info.image.width;
      final height = info.image.height;
      if (width > 0 && height > 0) {
        widget.onAspectResolved?.call(widget.imageKey, width / height);
      }
    });
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    final provider = _assistantInlineImageProvider(widget.uri);
    return GestureDetector(
      key: ValueKey('assistant-inline-image:${widget.imageKey}'),
      onTap: widget.group.isEmpty
          ? null
          : () => _openAssistantImageViewer(
              context,
              images: widget.group,
              initialIndex: widget.initialIndex.clamp(
                0,
                widget.group.length - 1,
              ),
            ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final displayWidth = constraints.maxWidth;
          final dpr = MediaQuery.devicePixelRatioOf(context);
          final cacheWidth = displayWidth.isFinite
              ? math.max(1, (displayWidth * dpr).ceil())
              : null;
          final image = provider == null
              ? const Icon(Icons.broken_image)
              : Image(
                  image: ResizeImage.resizeIfNeeded(cacheWidth, null, provider),
                  width: displayWidth.isFinite ? displayWidth : null,
                  fit: BoxFit.contain,
                  frameBuilder: (context, child, frame, _) {
                    if (frame != null) {
                      _listenForAspect(provider);
                    }
                    return child;
                  },
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                );
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: image,
          );
        },
      ),
    );
  }
}

void _openAssistantImageViewer(
  BuildContext context, {
  required List<String> images,
  required int initialIndex,
}) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      pageBuilder: (_, __, ___) =>
          ImageViewerPage(images: images, initialIndex: initialIndex),
      transitionDuration: const Duration(milliseconds: 360),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      transitionsBuilder: (context, anim, sec, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

IconData _toolIconFor(String name, [Map<String, dynamic> args = const {}]) {
  final localIcon = _localToolIconFor(name, args);
  if (localIcon != null) return localIcon;
  switch (name) {
    case 'memory_read':
    case 'memory_update':
    case 'memory_search_profile':
    case 'memory_edit':
    case 'update_user_profile':
    case 'create_memory':
    case 'edit_memory':
      return Lucide.bookHeart;
    case 'memory_delete':
    case 'delete_memory':
      return Lucide.bookDashed;
    case 'chat_search':
      return Lucide.Search;
    case 'search_web':
      return Lucide.Earth;
    case 'builtin_search':
      return Lucide.Search;
    default:
      return Lucide.Wrench;
  }
}

IconData? _localToolIconFor(String name, Map<String, dynamic> args) {
  if (name == LocalToolNames.askUser) {
    return Lucide.MessageCircleQuestionMark;
  }
  return switch (name) {
    LocalToolNames.timeInfo => Lucide.clock,
    LocalToolNames.clipboard => switch ((args['action'] ?? '').toString()) {
      'read' => Lucide.ClipboardCheck,
      'write' => Lucide.ClipboardPen,
      _ => Lucide.Clipboard,
    },
    LocalToolNames.textToSpeech => Lucide.Volume2,
    LocalToolNames.calculate => Lucide.Calculator,
    LocalToolNames.screenTime => Lucide.Smartphone,
    LocalToolNames.calendarQuery => Lucide.Calendar,
    LocalToolNames.calendarCreate => Lucide.CalendarPlus,
    _ => null,
  };
}

String? _localToolTitleFor(
  AppLocalizations l10n,
  String name,
  Map<String, dynamic> args,
) {
  if (name == LocalToolNames.askUser) {
    return _askUserToolTitleFor(l10n, args);
  }
  return switch (name) {
    LocalToolNames.timeInfo => l10n.assistantEditLocalToolTimeInfoTitle,
    LocalToolNames.clipboard => switch ((args['action'] ?? '').toString()) {
      'read' => l10n.chatMessageWidgetReadClipboard,
      'write' => l10n.chatMessageWidgetWriteClipboard,
      _ => l10n.assistantEditLocalToolClipboardTitle,
    },
    LocalToolNames.textToSpeech => l10n.chatMessageWidgetSpeakingTitle,
    LocalToolNames.calculate => l10n.assistantEditLocalToolCalculateTitle,
    LocalToolNames.screenTime => l10n.assistantEditLocalToolScreenTimeTitle,
    LocalToolNames.calendarQuery =>
      l10n.assistantEditLocalToolCalendarQueryTitle,
    LocalToolNames.calendarCreate =>
      l10n.assistantEditLocalToolCalendarCreateTitle,
    _ => null,
  };
}

String _textToSpeechToolText(Map<String, dynamic> args) {
  return (args['text'] ?? '').toString().trim();
}

void _replayTextToSpeech(BuildContext context, String text) {
  final content = text.trim();
  if (content.isEmpty) return;

  final tts = context.read<TtsProvider>();
  if (!tts.isAvailable) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: StateError('Text-to-speech is unavailable.'),
        library: 'Kelivo chat message tools',
        context: ErrorDescription('while replaying text-to-speech'),
      ),
    );
    return;
  }

  unawaited(
    tts.speak(content).catchError((Object error, StackTrace stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'Kelivo chat message tools',
          context: ErrorDescription('while replaying text-to-speech'),
        ),
      );
    }),
  );
}

Widget _buildTextToSpeechReplayRow(
  BuildContext context, {
  required String text,
  required Color textColor,
  required Color buttonColor,
  double fontSize = 12,
  int maxLines = 2,
}) {
  final l10n = AppLocalizations.of(context)!;
  return Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: Text(
          text,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: fontSize, height: 1.4, color: textColor),
        ),
      ),
      const SizedBox(width: 8),
      Tooltip(
        message: l10n.ttsFloatingReplayTooltip,
        child: IosIconButton(
          size: 14,
          minSize: 30,
          padding: const EdgeInsets.all(6),
          color: buttonColor,
          semanticLabel: l10n.ttsFloatingReplayTooltip,
          builder: (color) => Icon(Lucide.RefreshCw, size: 14, color: color),
          onTap: () => _replayTextToSpeech(context, text),
        ),
      ),
    ],
  );
}

String _askUserToolTitleFor(AppLocalizations l10n, Map<String, dynamic> args) {
  final questions = AskUserInteractionService.normalizeQuestions(args);
  if (questions.isNotEmpty) {
    return l10n.askUserCardQuestionCount(questions.length);
  }
  return l10n.assistantEditLocalToolAskUserTitle;
}

String _toolTitleFor(
  BuildContext context,
  String name,
  Map<String, dynamic> args, {
  required bool isResult,
}) {
  final l10n = AppLocalizations.of(context)!;
  if (name == LocalToolNames.askUser) {
    return _askUserToolTitleFor(l10n, args);
  }
  final localToolTitle = _localToolTitleFor(l10n, name, args);
  if (localToolTitle != null) return localToolTitle;
  switch (name) {
    case 'memory_read':
      return l10n.chatMessageWidgetMemoryRead;
    case 'memory_update':
      return l10n.chatMessageWidgetMemoryUpdate;
    case 'memory_search_profile':
      return l10n.chatMessageWidgetMemorySearchProfile;
    case 'memory_edit':
    case 'edit_memory':
      return l10n.chatMessageWidgetMemoryEdit;
    case 'memory_delete':
    case 'delete_memory':
      return l10n.chatMessageWidgetMemoryDelete;
    case 'update_user_profile':
      return l10n.chatMessageWidgetUpdateUserProfile;
    case 'chat_search':
      return l10n.chatMessageWidgetChatSearch;
    case 'create_memory':
      return l10n.chatMessageWidgetCreateMemory;
    case 'search_web':
      final q = (args['query'] ?? '').toString();
      return l10n.chatMessageWidgetWebSearch(q);
    case 'builtin_search':
      return l10n.chatMessageWidgetBuiltinSearch;
    default:
      return isResult
          ? l10n.chatMessageWidgetToolResult(name)
          : l10n.chatMessageWidgetToolCall(name);
  }
}

String _prettyToolJson(String raw) {
  try {
    final obj = jsonDecode(raw);
    return const JsonEncoder.withIndent('  ').convert(obj);
  } catch (_) {
    return raw;
  }
}

Widget _buildToolImageFromPath(
  BuildContext context,
  String path, {
  double? height,
  double? maxLogicalWidth,
  BoxFit fit = BoxFit.contain,
}) {
  return _buildResolvedImage(
    context,
    path,
    height: height,
    maxLogicalWidth: maxLogicalWidth,
    fit: fit,
  );
}

void _showToolFullImage(BuildContext context, String path) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      pageBuilder: (_, __, ___) => ImageViewerPage(images: [path]),
      transitionDuration: const Duration(milliseconds: 360),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      transitionsBuilder: (context, anim, sec, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

void _showToolDetail(BuildContext context, ToolUIPart part) {
  final l10n = AppLocalizations.of(context)!;
  final argsPretty = const JsonEncoder.withIndent('  ').convert(part.arguments);
  final (cleanText, images) = parseToolResultImages(
    part.content,
    metadata: part.metadata,
  );
  final resultText = cleanText.isNotEmpty
      ? _prettyToolJson(cleanText)
      : l10n.chatMessageWidgetNoResultYet;
  final title = _toolTitleFor(
    context,
    part.toolName,
    part.arguments,
    isResult: !part.loading,
  );
  final closeSemanticLabel = l10n.mcpPageClose;
  final screenTime = part.toolName == LocalToolNames.screenTime
      ? ScreenTimeResult.tryParse(cleanText)
      : null;
  final useScreenTimeDetail = screenTime != null && screenTime.hasApps;

  if (PlatformUtils.isDesktopTarget) {
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => _ToolDetailDesktopDialog(
          title: title,
          closeSemanticLabel: closeSemanticLabel,
          argsPretty: argsPretty,
          resultText: resultText,
          images: images,
          argumentsLabel: l10n.chatMessageWidgetArguments,
          resultLabel: l10n.chatMessageWidgetResult,
          imagesLabel: l10n.chatMessageWidgetImages,
          screenTimeResult: useScreenTimeDetail ? screenTime : null,
        ),
      ),
    );
    return;
  }

  unawaited(
    showCustomBottomSheet<void>(
      context: context,
      title: title,
      closeSemanticLabel: closeSemanticLabel,
      builder: (sheetContext, scrollController) {
        if (useScreenTimeDetail) {
          return ScreenTimeToolDetailBody(
            result: screenTime,
            scrollController: scrollController,
          );
        }
        return _ToolDetailBody(
          scrollController: scrollController,
          argsPretty: argsPretty,
          resultText: resultText,
          images: images,
          argumentsLabel: l10n.chatMessageWidgetArguments,
          resultLabel: l10n.chatMessageWidgetResult,
          imagesLabel: l10n.chatMessageWidgetImages,
        );
      },
    ),
  );
}

class _ToolDetailDesktopDialog extends StatefulWidget {
  const _ToolDetailDesktopDialog({
    required this.title,
    required this.closeSemanticLabel,
    required this.argsPretty,
    required this.resultText,
    required this.images,
    required this.argumentsLabel,
    required this.resultLabel,
    required this.imagesLabel,
    this.screenTimeResult,
  });

  static const dialogKey = ValueKey('tool_detail_desktop_dialog');
  static const closeButtonKey = ValueKey('tool_detail_desktop_dialog_close');

  final String title;
  final String closeSemanticLabel;
  final String argsPretty;
  final String resultText;
  final List<String> images;
  final String argumentsLabel;
  final String resultLabel;
  final String imagesLabel;
  final ScreenTimeResult? screenTimeResult;

  @override
  State<_ToolDetailDesktopDialog> createState() =>
      _ToolDetailDesktopDialogState();
}

class _ToolDetailDesktopDialogState extends State<_ToolDetailDesktopDialog> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      key: _ToolDetailDesktopDialog.dialogKey,
      elevation: 12,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 420,
          maxWidth: 640,
          maxHeight: 680,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Material(
            color: cs.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 16,
                            fontWeight: AppFontWeights.emphasis,
                            height: 1.2,
                          ),
                        ),
                      ),
                      SizedBox(
                        key: _ToolDetailDesktopDialog.closeButtonKey,
                        width: 28,
                        height: 28,
                        child: IosIconButton(
                          icon: Lucide.X,
                          size: 20,
                          padding: EdgeInsets.zero,
                          color: cs.onSurface.withValues(alpha: 0.62),
                          semanticLabel: widget.closeSemanticLabel,
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Scrollbar(
                    controller: _scrollController,
                    child: widget.screenTimeResult != null
                        ? ScreenTimeToolDetailBody(
                            result: widget.screenTimeResult!,
                            scrollController: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          )
                        : _ToolDetailBody(
                            scrollController: _scrollController,
                            argsPretty: widget.argsPretty,
                            resultText: widget.resultText,
                            images: widget.images,
                            argumentsLabel: widget.argumentsLabel,
                            resultLabel: widget.resultLabel,
                            imagesLabel: widget.imagesLabel,
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolDetailBody extends StatelessWidget {
  const _ToolDetailBody({
    required this.scrollController,
    required this.argsPretty,
    required this.resultText,
    required this.images,
    required this.argumentsLabel,
    required this.resultLabel,
    required this.imagesLabel,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 24),
  });

  final ScrollController scrollController;
  final String argsPretty;
  final String resultText;
  final List<String> images;
  final String argumentsLabel;
  final String resultLabel;
  final String imagesLabel;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SelectionArea(
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverPadding(
            padding: padding,
            sliver: SliverMainAxisGroup(
              slivers: [
                ToolDetailTextSection(label: argumentsLabel, text: argsPretty),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                ToolDetailTextSection(label: resultLabel, text: resultText),
                if (images.isNotEmpty) ...[
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverToBoxAdapter(
                    child: Text(
                      imagesLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 6)),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: kToolImageDetailHeight,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: images.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final path = images[index];
                          return GestureDetector(
                            onTap: () => _showToolFullImage(context, path),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _buildToolImageFromPath(
                                context,
                                path,
                                height: kToolImageDetailHeight,
                                maxLogicalWidth: kToolImageDetailMaxWidth,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessageWidget extends StatefulWidget {
  final ChatMessage message;
  final Widget? modelIcon;
  final bool showModelIcon;
  // Assistant identity override
  final bool useAssistantAvatar;
  final bool useAssistantName;
  final String? assistantName;
  final String? assistantAvatar; // path/url/emoji; null => use initial
  final bool showUserAvatar;
  final bool showTokenStats;
  final VoidCallback? onRegenerate;
  final VoidCallback? onResend;
  final VoidCallback? onCopy;
  final VoidCallback? onTranslate;
  final VoidCallback? onSpeak;
  final VoidCallback? onMore;
  final VoidCallback? onEdit; // user: edit
  final VoidCallback? onDelete; // user: delete
  // Optional version switcher (branch) UI controls
  final int? versionIndex; // zero-based display ordinal, not a version number
  final int? versionCount;
  final VoidCallback? onPrevVersion;
  final VoidCallback? onNextVersion;
  // Optional reasoning UI props (for reasoning-capable models)
  final String? reasoningText;
  final bool reasoningExpanded;
  final bool reasoningLoading;
  final DateTime? reasoningStartAt;
  final DateTime? reasoningFinishedAt;
  final VoidCallback? onToggleReasoning;
  // For multiple reasoning segments
  final List<ReasoningSegment>? reasoningSegments;
  // Optional translation UI props
  final bool translationExpanded;
  final VoidCallback? onToggleTranslation;
  // MCP tool calls/results mixed-in cards
  final List<ToolUIPart>? toolParts;
  final List<int>? contentSplitOffsets;
  final List<int>? reasoningCountAtSplit;
  final List<int>? toolCountAtSplit;
  // Hide streaming dots when pinned globally
  final bool hideStreamingIndicator;
  // Whether files are currently being processed
  final bool isProcessingFiles;
  final bool enableStreamingTextMotion;
  final List<String> suggestions;
  final ValueChanged<String>? onSuggestionTap;
  final Future<void> Function(ToolUIPart part, AskUserResult result)?
  onRecoveredAskUserAnswer;

  /// When null, follows [SettingsProvider.showThinkingCards].
  final bool? showThinkingCards;

  /// When null, follows [SettingsProvider.showToolCards].
  final bool? showToolCards;
  final void Function(String imageKey, double aspectRatio)? onInlineImageAspect;

  const ChatMessageWidget({
    super.key,
    required this.message,
    this.modelIcon,
    this.showModelIcon = true,
    this.useAssistantAvatar = false,
    this.useAssistantName = false,
    this.assistantName,
    this.assistantAvatar,
    this.showUserAvatar = true,
    this.showTokenStats = true,
    this.onRegenerate,
    this.onResend,
    this.onCopy,
    this.onTranslate,
    this.onSpeak,
    this.onMore,
    this.onEdit,
    this.onDelete,
    this.versionIndex,
    this.versionCount,
    this.onPrevVersion,
    this.onNextVersion,
    this.reasoningText,
    this.reasoningExpanded = false,
    this.reasoningLoading = false,
    this.reasoningStartAt,
    this.reasoningFinishedAt,
    this.onToggleReasoning,
    this.reasoningSegments,
    this.translationExpanded = true,
    this.onToggleTranslation,
    this.toolParts,
    this.contentSplitOffsets,
    this.reasoningCountAtSplit,
    this.toolCountAtSplit,
    this.hideStreamingIndicator = false,
    this.isProcessingFiles = false,
    this.enableStreamingTextMotion = true,
    this.suggestions = const <String>[],
    this.onSuggestionTap,
    this.onRecoveredAskUserAnswer,
    this.showThinkingCards,
    this.showToolCards,
    this.onInlineImageAspect,
  });

  @override
  State<ChatMessageWidget> createState() => _ChatMessageWidgetState();
}

class _ChatMessageWidgetState extends State<ChatMessageWidget> {
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  final ScrollController _reasoningScroll = ScrollController();
  bool _tickActive = false;
  // Local expand state for inline <think> card (defaults to expanded)
  bool? _inlineThinkExpanded;
  bool _inlineThinkManuallyToggled = false;
  // User message context menu state
  final GlobalKey _userBubbleKey = GlobalKey();
  OverlayEntry? _userMenuOverlay;
  // Desktop anchored menus for bottom action buttons
  final GlobalKey _moreBtnKey1 = GlobalKey();
  final GlobalKey _moreBtnKey2 = GlobalKey();
  final GlobalKey _translateBtnKey2 = GlobalKey();
  // ValueNotifier for reasoning animation tick - avoids full widget rebuild
  final ValueNotifier<int> _reasoningTick = ValueNotifier<int>(0);
  Timer? _reasoningTimer;
  // Memoized think-tag parse, keyed by source string equality. The parser is
  // a pure function of message content, so a single slot is enough.
  String? _inlineThinkMemoSource;
  ThinkingTagParseResult? _inlineThinkMemoResult;
  // Memoized assistant visual-regex results, keyed by scope + input string.
  // Cleared when the rule signature changes; skipped while streaming because
  // the content changes every frame anyway.
  final Map<String, String> _visualRegexMemo = <String, String>{};
  String _visualRegexMemoSignature = '';
  // Search-result extraction is keyed by tool-part list identity.
  List<ToolUIPart>? _searchItemsParts;
  List<Map<String, dynamic>>? _searchItemsCache;

  @override
  void initState() {
    super.initState();
    _syncTicker();

    // Determine initial state for inline <think> card BEFORE first paint to avoid
    // post-frame size changes that can cause list scroll jitter/snapping.
    try {
      final parsed = _legacyInlineThinkingFor(widget);
      final extracted = parsed.thinkingTexts.join('\n\n');
      final usingInlineThink =
          (widget.reasoningText == null || widget.reasoningText!.isEmpty) &&
          extracted.isNotEmpty;
      if (usingInlineThink && _inlineThinkExpanded == null) {
        final autoCollapse = context
            .read<SettingsProvider>()
            .autoCollapseThinking;
        _inlineThinkExpanded = !autoCollapse ? true : false;
      }
    } catch (_) {
      // If anything fails here, fall back to later update logic.
    }
  }

  @override
  void didUpdateWidget(covariant ChatMessageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
    // Auto-collapse when inline <think> transitions from loading -> finished
    _applyAutoCollapseInlineThinkIfFinished(oldWidget: oldWidget);
  }

  void _applyAutoCollapseInlineThinkIfFinished({ChatMessageWidget? oldWidget}) {
    if (!mounted) return;
    final newExtracted = _legacyInlineThinkingFor(
      widget,
    ).thinkingTexts.join('\n\n');
    final usingInlineThinkNew =
        (widget.reasoningText == null || widget.reasoningText!.isEmpty) &&
        newExtracted.isNotEmpty;

    bool usingInlineThinkOld = false;
    if (oldWidget != null) {
      final oldExtracted = _legacyInlineThinkingFor(
        oldWidget,
      ).thinkingTexts.join('\n\n');
      usingInlineThinkOld =
          (oldWidget.reasoningText == null ||
              oldWidget.reasoningText!.isEmpty) &&
          oldExtracted.isNotEmpty;
    }

    final autoCollapse = context.read<SettingsProvider>().autoCollapseThinking;

    // If finished now (not loading), inline think is used, and auto-collapse is on
    // Only collapse when user hasn't manually toggled; also if we don't yet have a chosen state.
    final finishedNow = usingInlineThinkNew;
    final justFinished = oldWidget != null
        ? (!usingInlineThinkOld && finishedNow)
        : finishedNow;

    if (autoCollapse && finishedNow && justFinished) {
      if (!_inlineThinkManuallyToggled || _inlineThinkExpanded == null) {
        if (mounted) setState(() => _inlineThinkExpanded = false);
        return;
      }
    }

    // On first mount where already finished and no user choice yet, honor autoCollapse
    if (oldWidget == null &&
        usingInlineThinkNew &&
        _inlineThinkExpanded == null) {
      if (autoCollapse) {
        if (mounted) setState(() => _inlineThinkExpanded = false);
      } else {
        if (mounted) setState(() => _inlineThinkExpanded = true);
      }
    }
  }

  void _syncTicker() {
    final loading =
        widget.reasoningLoading &&
        widget.reasoningStartAt != null &&
        widget.reasoningFinishedAt == null;
    _tickActive = loading;
    if (loading) {
      _reasoningTimer ??= Timer.periodic(const Duration(milliseconds: 100), (
        _,
      ) {
        if (mounted && _tickActive) _reasoningTick.value++;
      });
    } else {
      _reasoningTimer?.cancel();
      _reasoningTimer = null;
    }
  }

  ThinkingTagParseResult _legacyInlineThinkingFor(ChatMessageWidget widget) {
    if ((widget.reasoningText?.isNotEmpty ?? false) ||
        widget.reasoningLoading ||
        (widget.reasoningSegments?.isNotEmpty ?? false)) {
      return ThinkingTagParseResult(
        visibleContent: widget.message.content,
        thinkingTexts: const <String>[],
      );
    }
    final source = widget.message.content;
    final memo = _inlineThinkMemoResult;
    if (memo != null && _inlineThinkMemoSource == source) return memo;
    final parsed = ThinkingTagParser.parseLegacyInlineBlocks(source);
    _inlineThinkMemoSource = source;
    _inlineThinkMemoResult = parsed;
    return parsed;
  }

  String _visualRegexSignature(Assistant assistant) {
    // String signature (not a hash) so rule edits can never collide into a
    // stale memo hit.
    return assistant.regexRules
        .map(
          (rule) =>
              '${rule.enabled}|${rule.pattern}|${rule.replacement}|'
              '${rule.visualOnly}|${rule.replaceOnly}|'
              '${rule.scopes.map((scope) => scope.index).join(',')}',
        )
        .join(';');
  }

  String _applyVisualAssistantRegexes(
    String input, {
    required Assistant? assistant,
    required AssistantRegexScope scope,
  }) {
    if (input.isEmpty ||
        assistant == null ||
        assistant.regexRules.isEmpty ||
        widget.message.isStreaming) {
      return applyAssistantRegexes(
        input,
        assistant: assistant,
        scope: scope,
        target: AssistantRegexTransformTarget.visual,
      );
    }
    final signature = _visualRegexSignature(assistant);
    if (signature != _visualRegexMemoSignature) {
      _visualRegexMemo.clear();
      _visualRegexMemoSignature = signature;
    }
    if (_visualRegexMemo.length >= 8) _visualRegexMemo.clear();
    return _visualRegexMemo.putIfAbsent(
      '${scope.index}\u0000$input',
      () => applyAssistantRegexes(
        input,
        assistant: assistant,
        scope: scope,
        target: AssistantRegexTransformTarget.visual,
      ),
    );
  }

  String _assistantNameFallback() {
    try {
      final chat = context.read<ChatService>();
      final convo = chat.getConversation(widget.message.conversationId);
      final aId = convo?.assistantId;
      if (aId != null && aId.isNotEmpty) {
        final ap = context.read<AssistantProvider>();
        final a = ap.getById(aId);
        final name = a?.name.trim();
        if (name != null && name.isNotEmpty) return name;
      }
    } catch (_) {}
    return 'AI Assistant';
  }

  Assistant? _assistantForMessage() {
    try {
      final chat = context.read<ChatService>();
      final convo = chat.getConversation(widget.message.conversationId);
      final aId = convo?.assistantId;
      if (aId == null || aId.isEmpty) return null;
      final ap = context.watch<AssistantProvider>();
      return ap.getById(aId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _confirmRegeneration(VoidCallback action) async {
    final settings = context.read<SettingsProvider>();
    if (!settings.showRegenerateConfirmDialog) {
      action();
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final content = settings.regenerateDeleteTrailingMessages
        ? l10n.chatMessageWidgetRegenerateConfirmDeleteTrailingContent
        : l10n.chatMessageWidgetRegenerateConfirmContent;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: Theme.of(dctx).colorScheme.surface,
        title: Text(l10n.chatMessageWidgetRegenerateConfirmTitle),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: Text(l10n.chatMessageWidgetRegenerateConfirmCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(true),
            child: Text(l10n.chatMessageWidgetRegenerateConfirmOk),
          ),
        ],
      ),
    );
    if (ok == true && mounted) action();
  }

  String _resolveModelDisplayName(SettingsProvider settings) {
    final modelId = widget.message.modelId;
    if (modelId == null || modelId.trim().isEmpty) {
      // Model metadata can be missing for legacy/preset messages.
      return AppLocalizations.of(context)?.messageExportSheetAssistant ??
          'Assistant';
    }

    final providerId = widget.message.providerId;
    String baseId = modelId;
    String? providerName;
    if (providerId != null && providerId.isNotEmpty) {
      try {
        final cfg = settings.getProviderConfig(providerId);
        providerName = cfg.name.trim();
        final ov = cfg.modelOverrides[modelId] as Map?;
        if (ov != null) {
          final name = (ov['name'] as String?)?.trim();
          if (name != null && name.isNotEmpty) {
            if (settings.showProviderInChatMessage && providerName.isNotEmpty) {
              return '$name | $providerName';
            }
            return name;
          }
          final apiId = (ov['apiModelId'] ?? ov['api_model_id'])
              ?.toString()
              .trim();
          if (apiId != null && apiId.isNotEmpty) {
            baseId = apiId;
          }
        }
      } catch (_) {
        // ignore lookup failures; fall through to inferred name.
      }
    }

    final inferred = ModelRegistry.infer(
      ModelInfo(id: baseId, displayName: baseId),
    );
    final fallback = inferred.displayName.trim();
    final displayName = fallback.isNotEmpty ? fallback : baseId;
    if (settings.showProviderInChatMessage &&
        providerName != null &&
        providerName.isNotEmpty) {
      return '$displayName | $providerName';
    }
    return displayName;
  }

  @override
  void dispose() {
    try {
      _userMenuOverlay?.remove();
    } catch (_) {}
    _userMenuOverlay = null;
    _reasoningTimer?.cancel();
    _reasoningTimer = null;
    _reasoningTick.dispose();
    _reasoningScroll.dispose();
    super.dispose();
  }

  void _showUserContextMenu() {
    // Haptic feedback (optional)
    try {
      Haptics.light();
    } catch (_) {}

    final box = _userBubbleKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    if (box == null || overlayBox == null) return;

    final bubbleTopLeft = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    final bubbleSize = box.size;
    final screenSize = overlayBox.size;
    final insets = MediaQuery.paddingOf(context); // status bar / gesture insets
    final safeLeft = insets.left + 12;
    final safeRight = insets.right + 12;
    final safeTop = insets.top + 12;
    final safeBottom = insets.bottom + 12;

    const double menuWidth = 220; // compact width
    const double estMenuHeight = 140; // ~ 3 rows
    const double gap = 10; // space between bubble and menu

    // Horizontal placement: align menu's right edge to bubble's right edge,
    // and clamp into safe area for better reachability on long messages.
    final double bubbleRight = bubbleTopLeft.dx + bubbleSize.width;
    double x = bubbleRight - menuWidth;
    final double minX = safeLeft;
    final double maxX = screenSize.width - safeRight - menuWidth;
    if (x < minX) x = minX;
    if (x > maxX) x = maxX;

    // Decide above vs below using safe area
    final availableAbove = bubbleTopLeft.dy - gap - safeTop;
    final availableBelow =
        (screenSize.height - safeBottom) -
        (bubbleTopLeft.dy + bubbleSize.height + gap);
    final bool canPlaceAbove = availableAbove >= estMenuHeight;
    final bool canPlaceBelow = availableBelow >= estMenuHeight;

    bool placeAbove;
    if (canPlaceAbove) {
      placeAbove = true;
    } else if (canPlaceBelow) {
      placeAbove = false;
    } else {
      // Fallback: choose the side with more space
      placeAbove = availableAbove > availableBelow;
    }

    double y = placeAbove
        ? (bubbleTopLeft.dy - estMenuHeight - gap)
        : (bubbleTopLeft.dy + bubbleSize.height + gap);

    // Clamp vertically to remain fully visible within safe area
    final double minY = safeTop;
    final double maxY = screenSize.height - safeBottom - estMenuHeight;
    if (y < minY) y = minY;
    if (y > maxY) y = maxY;

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'context-menu',
      barrierColor: cs.scrim.withValues(alpha: 0.08),
      pageBuilder: (ctx, _, __) {
        return Stack(
          children: [
            // Positioned popup
            Positioned(
              left: x,
              top: y,
              width: menuWidth,
              child: _AnimatedPopup(
                child: DecoratedBox(
                  // Draw border outside the clipped/blurred content to avoid corner clipping
                  decoration: ShapeDecoration(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isDark
                            ? cs.onSurface.withValues(alpha: 0.08)
                            : cs.outlineVariant.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHigh.withValues(
                            alpha: 0.66,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _MenuItem(
                                icon: Lucide.Copy,
                                label: l10n.shareProviderSheetCopyButton,
                                onTap: () async {
                                  Navigator.of(ctx).pop();
                                  if (widget.onCopy != null) {
                                    widget.onCopy!.call();
                                  } else {
                                    await Clipboard.setData(
                                      ClipboardData(
                                        text: widget.message.content,
                                      ),
                                    );
                                    if (mounted) {
                                      showAppSnackBar(
                                        context,
                                        message: l10n
                                            .chatMessageWidgetCopiedToClipboard,
                                        type: NotificationType.success,
                                      );
                                    }
                                  }
                                },
                              ),
                              if (widget.onEdit != null)
                                _MenuItem(
                                  icon: Lucide.Pencil,
                                  label: l10n.messageMoreSheetEdit,
                                  onTap: () {
                                    Navigator.of(ctx).pop();
                                    widget.onEdit?.call();
                                  },
                                ),
                              _MenuItem(
                                icon: Lucide.Trash2,
                                danger: true,
                                label: l10n.messageMoreSheetDelete,
                                onTap: () {
                                  Navigator.of(ctx).pop();
                                  (widget.onDelete ?? widget.onMore)?.call();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ).whenComplete(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Widget _buildUserAvatar(
    String? avatarType,
    String? avatarValue,
    ColorScheme cs,
  ) {
    Widget avatarContent;

    if (avatarType == 'emoji' && avatarValue != null) {
      final bool isIOS = defaultTargetPlatform == TargetPlatform.iOS;
      final double fs = 18;
      final Offset? nudge = isIOS ? Offset(fs * 0.065, fs * -0.05) : null;
      avatarContent = Center(
        child: EmojiText(
          avatarValue,
          fontSize: fs,
          optimizeEmojiAlign: true,
          nudge: nudge,
        ),
      );
    } else if (avatarType == 'url' && avatarValue != null) {
      final url = avatarValue;
      avatarContent = FutureBuilder<String?>(
        future: AvatarCache.getPath(url),
        builder: (ctx, snap) {
          final p = snap.data;
          if (p != null && File(p).existsSync()) {
            return ClipOval(
              child: Image.file(
                File(p),
                width: 32,
                height: 32,
                fit: BoxFit.cover,
              ),
            );
          }
          return ClipOval(
            child: Image.network(
              url,
              width: 32,
              height: 32,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(Lucide.User, size: 18, color: cs.primary),
            ),
          );
        },
      );
    } else if (avatarType == 'file' && avatarValue != null) {
      final fixed = SandboxPathResolver.fix(avatarValue);
      final f = File(fixed);
      if (f.existsSync()) {
        avatarContent = ClipOval(
          child: Image.file(f, width: 32, height: 32, fit: BoxFit.cover),
        );
      } else {
        avatarContent = Icon(Lucide.User, size: 18, color: cs.primary);
      }
    } else {
      avatarContent = Icon(Lucide.User, size: 18, color: cs.primary);
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: avatarContent,
    );
  }

  Widget _buildToolMessage() {
    // Parse JSON payload embedded in tool message content
    String toolName = 'tool';
    Map<String, dynamic> args = const {};
    String result = '';
    Map<String, dynamic>? metadata;
    try {
      final obj = jsonDecode(widget.message.content) as Map<String, dynamic>;
      toolName = (obj['tool'] ?? 'tool').toString();
      final a = obj['arguments'];
      if (a is Map<String, dynamic>) args = a;
      result = (obj['result'] ?? '').toString();
      if (obj['metadata'] is Map) {
        metadata = Map<String, dynamic>.from(obj['metadata'] as Map);
      }
    } catch (_) {}

    final part = ToolUIPart(
      id: widget.message.id,
      toolName: toolName,
      arguments: args,
      content: result,
      metadata: metadata,
      loading: false,
    );
    if (!_shouldShowToolCard(
      context,
      part,
      showToolCards: widget.showToolCards,
      conversationId: widget.message.conversationId,
    )) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: _RecoveredAskUserAction(
        conversationId: widget.message.conversationId,
        onSubmit: widget.onRecoveredAskUserAnswer,
        child: _ToolCallItem(
          part: part,
          conversationId: widget.message.conversationId,
        ),
      ),
    );
  }

  Widget _buildUserMessage() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userName = context.select<UserProvider, String>((u) => u.name);
    final userAvatarType = context.select<UserProvider, String?>(
      (u) => u.avatarType,
    );
    final userAvatarValue = context.select<UserProvider, String?>(
      (u) => u.avatarValue,
    );
    final l10n = AppLocalizations.of(context)!;
    final userMessageSettings = context
        .select<
          SettingsProvider,
          ({
            bool showActions,
            bool showName,
            bool showTimestamp,
            bool enableMarkdown,
          })
        >(
          (s) => (
            showActions: s.showUserMessageActions,
            showName: s.showUserName,
            showTimestamp: s.showUserTimestamp,
            enableMarkdown: s.enableUserMarkdown,
          ),
        );
    // Attachments come from structured parts only. Literal marker-like text
    // inside TextPart stays plain text and is never re-parsed.
    final assistant = _assistantForMessage();
    final visualText = _applyVisualAssistantRegexes(
      widget.message.content,
      assistant: assistant,
      scope: AssistantRegexScope.user,
    );
    final showUserActions = userMessageSettings.showActions;
    final showVersionSwitcher = (widget.versionCount ?? 1) > 1;
    final mediaPreview = _buildAttachmentPreview(
      context,
      parts: widget.message.parts,
      isDark: isDark,
      alignEnd: true,
    );
    final textBubble = visualText.isNotEmpty
        ? Container(
            key: ValueKey('user-message-text-bubble:${widget.message.id}'),
            child: _buildBubbleContainer(
              context: context,
              isUser: true,
              child: _buildUserTextContent(
                context,
                visualText,
                userMessageSettings.enableMarkdown,
              ),
            ),
          )
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Header: User info and avatar
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (userMessageSettings.showName ||
                  userMessageSettings.showTimestamp)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (userMessageSettings.showName)
                      Text(
                        userName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: AppFontWeights.medium,
                          color: cs.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    if (userMessageSettings.showName &&
                        userMessageSettings.showTimestamp)
                      const SizedBox(height: 2),
                    if (userMessageSettings.showTimestamp)
                      Text(
                        _dateFormat.format(widget.message.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                ),
              if (widget.showUserAvatar) ...[
                const SizedBox(width: 8),
                // User avatar
                _buildUserAvatar(userAvatarType, userAvatarValue, cs),
              ],
            ],
          ),
          const SizedBox(height: 8),
          // Message content (context menu: long-press on mobile, right-click on desktop)
          GestureDetector(
            onLongPressStart: (_) {
              final isDesktop =
                  defaultTargetPlatform == TargetPlatform.macOS ||
                  defaultTargetPlatform == TargetPlatform.windows ||
                  defaultTargetPlatform == TargetPlatform.linux;
              if (isDesktop) return; // Desktop uses right-click menu
              _showUserContextMenu();
            },
            onSecondaryTapDown: (details) {
              final isDesktop =
                  defaultTargetPlatform == TargetPlatform.macOS ||
                  defaultTargetPlatform == TargetPlatform.windows ||
                  defaultTargetPlatform == TargetPlatform.linux;
              if (!isDesktop) return; // Mobile keeps long-press
              _showUserContextMenuAt(details.globalPosition);
            },
            behavior: HitTestBehavior.translucent,
            child: Container(
              key: _userBubbleKey,
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.75,
              ),
              child: Column(
                key: ValueKey('user-message-content:${widget.message.id}'),
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (mediaPreview != null) mediaPreview,
                  if (mediaPreview != null && textBubble != null)
                    const SizedBox(height: 8),
                  if (textBubble != null) textBubble,
                ],
              ),
            ),
          ),
          if (showUserActions || showVersionSwitcher) ...[
            SizedBox(height: showUserActions ? 8 : 6),
            Align(
              alignment: Alignment.centerRight,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.75,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (showUserActions) ...[
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: Center(
                          child: IosIconButton(
                            size: 16,
                            padding: EdgeInsets.all(4),
                            icon: Lucide.Copy,
                            color: cs.onSurface.withValues(alpha: 0.9),
                            onTap:
                                widget.onCopy ??
                                () {
                                  Clipboard.setData(
                                    ClipboardData(text: widget.message.content),
                                  );
                                  showAppSnackBar(
                                    context,
                                    message:
                                        l10n.chatMessageWidgetCopiedToClipboard,
                                    type: NotificationType.success,
                                  );
                                },
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: Center(
                          child: IosIconButton(
                            size: 16,
                            padding: EdgeInsets.all(4),
                            icon: Lucide.RefreshCw,
                            color: cs.onSurface.withValues(alpha: 0.9),
                            onTap: widget.onResend == null
                                ? null
                                : () => _confirmRegeneration(widget.onResend!),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (widget.onEdit != null) ...[
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: Center(
                            child: IosIconButton(
                              size: 16,
                              padding: EdgeInsets.all(4),
                              icon: Lucide.Pencil,
                              color: cs.onSurface.withValues(alpha: 0.9),
                              onTap: widget.onEdit,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: Center(
                          child: GestureDetector(
                            key: _moreBtnKey1,
                            onTapDown: (d) {
                              final isDesktop =
                                  defaultTargetPlatform ==
                                      TargetPlatform.macOS ||
                                  defaultTargetPlatform ==
                                      TargetPlatform.windows ||
                                  defaultTargetPlatform == TargetPlatform.linux;
                              if (isDesktop) {
                                try {
                                  DesktopMenuAnchor.setPosition(
                                    d.globalPosition,
                                  );
                                } catch (_) {}
                              }
                            },
                            onTap: () {
                              final isDesktop =
                                  defaultTargetPlatform ==
                                      TargetPlatform.macOS ||
                                  defaultTargetPlatform ==
                                      TargetPlatform.windows ||
                                  defaultTargetPlatform == TargetPlatform.linux;
                              if (isDesktop) {
                                _setAnchorFromKey(_moreBtnKey1);
                              }
                              widget.onMore?.call();
                            },
                            child: IosIconButton(
                              size: 16,
                              padding: EdgeInsets.all(4),
                              icon: Lucide.Ellipsis,
                              color: cs.onSurface.withValues(alpha: 0.9),
                              onTap: null,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (showVersionSwitcher) ...[
                      if (showUserActions) const SizedBox(width: 6),
                      _BranchSelector(
                        index: widget.versionIndex ?? 0,
                        total: widget.versionCount ?? 1,
                        onPrev: widget.onPrevVersion,
                        onNext: widget.onNextVersion,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showUserContextMenuAt(Offset globalPosition) async {
    final l10n = AppLocalizations.of(context)!;
    // Haptic feedback
    try {
      Haptics.light();
    } catch (_) {}
    await showDesktopContextMenuAt(
      context,
      globalPosition: globalPosition,
      items: [
        DesktopContextMenuItem(
          icon: Lucide.Copy,
          label: l10n.shareProviderSheetCopyButton,
          onTap: () async {
            if (widget.onCopy != null) {
              widget.onCopy!.call();
            } else {
              await Clipboard.setData(
                ClipboardData(text: widget.message.content),
              );
              if (mounted) {
                showAppSnackBar(
                  context,
                  message: l10n.chatMessageWidgetCopiedToClipboard,
                  type: NotificationType.success,
                );
              }
            }
          },
        ),
        if (widget.onEdit != null)
          DesktopContextMenuItem(
            icon: Lucide.Pencil,
            label: l10n.messageMoreSheetEdit,
            onTap: () => widget.onEdit?.call(),
          ),
        DesktopContextMenuItem(
          icon: Lucide.Trash2,
          label: l10n.messageMoreSheetDelete,
          danger: true,
          onTap: () => (widget.onDelete ?? widget.onMore)?.call(),
        ),
      ],
    );
  }

  void _setAnchorFromKey(GlobalKey key) {
    final rb = key.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return;
    try {
      final center = rb.localToGlobal(
        Offset(rb.size.width / 2, rb.size.height),
      );
      DesktopMenuAnchor.setPosition(center);
    } catch (_) {}
  }

  Widget _buildUserTextContent(
    BuildContext context,
    String visualText,
    bool enableUserMarkdown,
  ) {
    final bool isDesktop =
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
    final double baseUser = isDesktop ? 14.0 : 15.5;

    Widget content;
    if (enableUserMarkdown) {
      content = DefaultTextStyle.merge(
        style: TextStyle(fontSize: baseUser, height: 1.45),
        child: MarkdownWithCodeHighlight(
          text: visualText,
          baseStyle: TextStyle(fontSize: baseUser, height: 1.45),
        ),
      );
    } else {
      content = Text(
        visualText,
        style: TextStyle(
          fontSize: baseUser,
          height: 1.4,
          color: _chatSurfacePlainTextColor(context, isUser: true),
        ),
      );
    }

    return isDesktop
        ? SelectionArea(
            key: ValueKey('user_${widget.message.id}'),
            child: content,
          )
        : content;
  }

  /// Attachment previews in [parts] ordinal order (not images-then-files).
  ///
  /// [alignEnd] true for user bubbles (trailing), false for assistant (start).
  Widget? _buildAttachmentPreview(
    BuildContext context, {
    required List<MessagePart> parts,
    required bool isDark,
    required bool alignEnd,
  }) {
    final attachmentEntries = <({int index, MessagePart part})>[
      for (var i = 0; i < parts.length; i++)
        if (parts[i] is ImagePart ||
            parts[i] is FilePart ||
            (parts[i] is MalformedPart &&
                (parts[i] as MalformedPart).isAttachmentKind))
          (index: i, part: parts[i]),
    ];
    if (attachmentEntries.isEmpty) return null;

    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final roleKey = alignEnd ? 'user' : 'assistant';

    Widget unavailableImagePlaceholder() => Container(
      width: 112,
      height: 112,
      color: cs.onSurface.withValues(alpha: isDark ? 0.08 : 0.06),
      alignment: Alignment.center,
      child: Icon(Lucide.ImageOff, color: cs.onSurface.withValues(alpha: 0.45)),
    );

    final viewablePaths = <String>[
      for (final entry in attachmentEntries)
        if (entry.part is ImagePart)
          if (!(entry.part as ImagePart).unavailable &&
              (entry.part as ImagePart).uri.trim().isNotEmpty)
            _resolveAttachmentImageUri((entry.part as ImagePart).uri),
    ];

    final items = <Widget>[];
    for (final entry in attachmentEntries) {
      final part = entry.part;
      final partIndex = entry.index;
      if (part is MalformedPart) {
        if (part.rawKind == 'image') {
          items.add(
            IosCardPress(
              key: ValueKey(
                '$roleKey-message-attachment:${widget.message.id}:$partIndex',
              ),
              baseColor: Colors.transparent,
              pressedScale: 0.985,
              borderRadius: BorderRadius.circular(10),
              padding: EdgeInsets.zero,
              onTap: null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: unavailableImagePlaceholder(),
              ),
            ),
          );
        } else {
          items.add(
            IosCardPress(
              key: ValueKey(
                '$roleKey-message-attachment:${widget.message.id}:$partIndex',
              ),
              baseColor: isDark
                  ? cs.onSurface.withValues(alpha: 0.08)
                  : cs.surface.withValues(alpha: 0.92),
              pressedScale: 0.99,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.18),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              onTap: null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.insert_drive_file,
                    size: 16,
                    color: cs.onSurface.withValues(alpha: 0.45),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.chatMessageWidgetAttachmentUnavailable,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        continue;
      }
      if (part is ImagePart) {
        final path = part.uri.trim();
        final fixed = path.isEmpty ? '' : _resolveAttachmentImageUri(path);
        final viewIndex = viewablePaths.indexOf(fixed);
        items.add(
          IosCardPress(
            key: ValueKey(
              '$roleKey-message-attachment:${widget.message.id}:$partIndex',
            ),
            baseColor: Colors.transparent,
            pressedScale: 0.985,
            borderRadius: BorderRadius.circular(10),
            padding: EdgeInsets.zero,
            onTap: part.unavailable || viewIndex < 0
                ? null
                : () {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => ImageViewerPage(
                          images: viewablePaths,
                          initialIndex: viewIndex,
                        ),
                        transitionDuration: const Duration(milliseconds: 360),
                        reverseTransitionDuration: const Duration(
                          milliseconds: 280,
                        ),
                        transitionsBuilder: (context, anim, sec, child) {
                          final curved = CurvedAnimation(
                            parent: anim,
                            curve: Curves.easeOutCubic,
                            reverseCurve: Curves.easeInCubic,
                          );
                          return FadeTransition(
                            opacity: curved,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.02),
                                end: Offset.zero,
                              ).animate(curved),
                              child: child,
                            ),
                          );
                        },
                      ),
                    );
                  },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Hero(
                tag:
                    'img:${fixed.isNotEmpty ? fixed : 'unavailable-$partIndex'}',
                child: part.unavailable || fixed.isEmpty
                    ? unavailableImagePlaceholder()
                    : _buildResolvedImage(
                        context,
                        fixed,
                        width: 112,
                        height: 112,
                        fit: BoxFit.cover,
                        placeholder: unavailableImagePlaceholder,
                      ),
              ),
            ),
          ),
        );
        continue;
      }

      if (part is FilePart) {
        final d = part;
        items.add(
          IosCardPress(
            key: ValueKey(
              '$roleKey-message-attachment:${widget.message.id}:$partIndex',
            ),
            baseColor: isDark
                ? cs.onSurface.withValues(alpha: 0.08)
                : cs.surface.withValues(alpha: 0.92),
            pressedScale: 0.99,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.18),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            onTap: d.unavailable
                ? null
                : () async {
                    try {
                      final uri = d.uri.trim();
                      if (uri.startsWith('http://') ||
                          uri.startsWith('https://')) {
                        final normalized = _tryNormalizeExternalUri(uri);
                        if (normalized == null) {
                          if (!context.mounted) return;
                          showAppSnackBar(
                            context,
                            message: l10n.chatMessageWidgetOpenLinkError,
                            type: NotificationType.error,
                          );
                          return;
                        }
                        final ok = await launchUrl(
                          normalized,
                          mode: LaunchMode.externalApplication,
                        );
                        if (!ok) {
                          if (!context.mounted) return;
                          showAppSnackBar(
                            context,
                            message: l10n.chatMessageWidgetCannotOpenUrl(
                              normalized.toString(),
                            ),
                            type: NotificationType.error,
                          );
                        }
                        return;
                      }
                      if (uri.startsWith('data:')) {
                        if (!context.mounted) return;
                        showAppSnackBar(
                          context,
                          message: l10n.chatMessageWidgetCannotOpenFile(
                            'unsupported data URI',
                          ),
                          type: NotificationType.warning,
                        );
                        return;
                      }
                      final fixed = SandboxPathResolver.fix(uri);
                      final f = File(fixed);
                      if (!(await f.exists())) {
                        if (!context.mounted) return;
                        showAppSnackBar(
                          context,
                          message: l10n.chatMessageWidgetFileNotFound(d.name),
                          type: NotificationType.error,
                        );
                        return;
                      }
                      final res = await OpenFilex.open(
                        fixed,
                        type: d.mime ?? 'application/octet-stream',
                      );
                      if (res.type != ResultType.done) {
                        if (!context.mounted) return;
                        final openMessage = res.message;
                        showAppSnackBar(
                          context,
                          message: l10n.chatMessageWidgetCannotOpenFile(
                            openMessage.isNotEmpty
                                ? openMessage
                                : res.type.toString(),
                          ),
                          type: NotificationType.error,
                        );
                      }
                    } catch (e) {
                      if (!context.mounted) return;
                      showAppSnackBar(
                        context,
                        message: l10n.chatMessageWidgetOpenFileError(
                          e.toString(),
                        ),
                        type: NotificationType.error,
                      );
                    }
                  },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.insert_drive_file,
                  size: 16,
                  color: cs.onSurface.withValues(alpha: 0.72),
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    d.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.86),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    return Align(
      key: ValueKey('$roleKey-message-attachments:${widget.message.id}'),
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: Wrap(
        alignment: alignEnd ? WrapAlignment.end : WrapAlignment.start,
        spacing: 8,
        runSpacing: 8,
        children: items,
      ),
    );
  }

  Widget _buildBubbleContainer({
    required BuildContext context,
    required bool isUser,
    required Widget child,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    BorderRadius radius = BorderRadius.circular(16);
    return _buildSharedChatSurface(
      context,
      borderRadius: radius,
      padding: const EdgeInsets.all(12),
      defaultColor: isUser
          ? (isDark
                ? cs.primary.withValues(alpha: 0.15)
                : cs.primary.withValues(alpha: 0.08))
          : null,
      bareOnDefault: !isUser,
      isUser: isUser,
      child: child,
    );
  }

  Widget _buildAssistantBubbleContainer({
    required BuildContext context,
    required Widget child,
  }) {
    // Reuse same styles, but flag as non-user for default fallthrough
    return _buildBubbleContainer(context: context, isUser: false, child: child);
  }

  Widget _buildAssistantTextContent(
    BuildContext context,
    String visualContent,
    bool enableAssistantMarkdown,
    Map<String, String> citationIndexLookup,
  ) {
    final bool isDesktop =
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
    final double baseAssistant = isDesktop ? 14.0 : 15.7;

    Widget assistantContent;
    if (enableAssistantMarkdown) {
      assistantContent = MarkdownWithCodeHighlight(
        text: visualContent,
        onCitationTap: (id) => _handleCitationTap(id),
        citationIndexResolver: (id) =>
            _resolveCitationIndex(id, citationIndexLookup),
        baseStyle: TextStyle(fontSize: baseAssistant, height: 1.5),
        streaming: widget.message.isStreaming,
      );
    } else {
      assistantContent = Text(
        visualContent,
        style: TextStyle(
          fontSize: baseAssistant,
          height: 1.5,
          color: _chatSurfacePlainTextColor(context),
        ),
      );
    }

    final media = MediaQuery.maybeOf(context);
    final bool reduceMotion =
        (media?.disableAnimations ?? false) ||
        (media?.accessibleNavigation ?? false);
    assistantContent = _StreamingAssistantMessageMotion(
      enabled:
          widget.message.isStreaming &&
          widget.enableStreamingTextMotion &&
          !reduceMotion &&
          visualContent.isNotEmpty,
      child: assistantContent,
    );

    return RepaintBoundary(
      child: SelectionArea(
        key: ValueKey('assistant_${widget.message.id}'),
        child: DefaultTextStyle.merge(
          style: TextStyle(fontSize: baseAssistant, height: 1.5),
          child: assistantContent,
        ),
      ),
    );
  }

  Widget _buildAssistantTextBlock(
    BuildContext context,
    String visualContent,
    bool enableAssistantMarkdown,
    Map<String, String> citationIndexLookup,
  ) {
    return SizedBox(
      width: double.infinity,
      child: _buildAssistantBubbleContainer(
        context: context,
        child: _buildAssistantTextContent(
          context,
          visualContent,
          enableAssistantMarkdown,
          citationIndexLookup,
        ),
      ),
    );
  }

  Widget _buildAssistantImageBlock(
    BuildContext context,
    String uri, {
    required String imageKey,
    required List<String> group,
  }) {
    final resolved = _resolveAttachmentImageUri(uri);
    final index = group.indexOf(resolved);
    return SizedBox(
      width: double.infinity,
      child: _buildAssistantBubbleContainer(
        context: context,
        child: _AssistantInlineImage(
          uri: resolved,
          imageKey: imageKey,
          group: group,
          initialIndex: index >= 0 ? index : 0,
          onAspectResolved: widget.onInlineImageAspect,
        ),
      ),
    );
  }

  TimelineProjection _projectAssistantTimeline(
    String visualContent, {
    List<ReasoningSegment>? reasoningSegments,
  }) {
    final assistant = _assistantForMessage();
    return projectAssistantTimeline(
      parts: widget.message.parts,
      liveTools: [
        for (var i = 0; i < (widget.toolParts?.length ?? 0); i++)
          TimelineToolRef(
            providerId: widget.toolParts![i].id,
            fallbackOrdinal: i,
            toolName: widget.toolParts![i].toolName,
            arguments: widget.toolParts![i].arguments,
            content: widget.toolParts![i].content,
            metadata: widget.toolParts![i].metadata,
            loading: widget.toolParts![i].loading,
            memoToken: identityHashCode(widget.toolParts![i]),
          ),
      ],
      reasoningSegments: [
        for (final segment in reasoningSegments ?? const <ReasoningSegment>[])
          TimelineReasoningRef(
            text: segment.text,
            expanded: segment.expanded,
            loading: segment.loading,
            startAt: segment.startAt,
            finishedAt: segment.finishedAt,
            toolStartIndex: segment.toolStartIndex,
          ),
      ],
      visualContent: visualContent,
      contentSplitOffsets: widget.contentSplitOffsets,
      reasoningCountAtSplit: widget.reasoningCountAtSplit,
      toolCountAtSplit: widget.toolCountAtSplit,
      transformText: (text) => _applyVisualAssistantRegexes(
        text,
        assistant: assistant,
        scope: AssistantRegexScope.assistant,
      ),
      partsArrivalOrdered: widget.message.isStreaming,
    );
  }

  VoidCallback? _projectedReasoningToggle(
    int? overlayIndex,
    List<ReasoningSegment>? reasoningSegments,
  ) {
    if (overlayIndex == null ||
        reasoningSegments == null ||
        overlayIndex < 0 ||
        overlayIndex >= reasoningSegments.length) {
      return null;
    }
    return reasoningSegments[overlayIndex].onToggle;
  }

  List<_TimelineStepData> _timelineStepsFromProjected(
    List<TimelineProjectedStep> steps,
    List<ReasoningSegment>? reasoningSegments,
  ) {
    return [
      for (final step in steps)
        if (step.isReasoning)
          _TimelineStepData.reasoning(
            reasoning: ReasoningSegment(
              text: step.reasoning!.text,
              expanded: step.reasoning!.expanded,
              loading: step.reasoning!.loading,
              startAt: step.reasoning!.startAt,
              finishedAt: step.reasoning!.finishedAt,
              onToggle: _projectedReasoningToggle(
                step.reasoningOverlayIndex,
                reasoningSegments,
              ),
              toolStartIndex: step.reasoning!.toolStartIndex,
            ),
            reasoningCountAfter: step.reasoningCountAfter,
            toolCountAfter: step.toolCountAfter,
            sourceOrdinal: step.sourceOrdinal,
          )
        else
          _TimelineStepData.tool(
            tool: ToolUIPart(
              id: step.tool!.providerId,
              toolName: step.tool!.toolName,
              arguments: step.tool!.arguments,
              content: step.tool!.content,
              metadata: step.tool!.metadata,
              loading: step.tool!.loading,
              memoToken: step.tool!.memoToken,
            ),
            reasoningCountAfter: step.reasoningCountAfter,
            toolCountAfter: step.toolCountAfter,
            sourceOrdinal: step.sourceOrdinal,
          ),
    ];
  }

  List<ReasoningSegment>? _effectiveReasoningSegments(
    String extractedThinking,
  ) {
    final hasProvidedReasoning =
        (widget.reasoningText != null && widget.reasoningText!.isNotEmpty) ||
        widget.reasoningLoading;
    final effectiveReasoningText =
        (widget.reasoningText != null && widget.reasoningText!.isNotEmpty)
        ? widget.reasoningText!
        : extractedThinking;
    final usingInlineThink =
        (widget.reasoningText == null || widget.reasoningText!.isEmpty) &&
        extractedThinking.isNotEmpty;
    final effectiveExpanded = usingInlineThink
        ? (_inlineThinkExpanded ?? true)
        : widget.reasoningExpanded;
    final effectiveLoading = timelineReasoningLoading(
      finishedAt: widget.reasoningFinishedAt,
      isStreaming: widget.message.isStreaming,
      usingInlineThink: usingInlineThink,
    );

    final provided = widget.reasoningSegments;
    if (provided != null && provided.isNotEmpty) return provided;
    if (!hasProvidedReasoning && effectiveReasoningText.isEmpty) {
      return provided;
    }
    return <ReasoningSegment>[
      ReasoningSegment(
        text: effectiveReasoningText,
        expanded: effectiveExpanded,
        loading: effectiveLoading,
        startAt: usingInlineThink ? null : widget.reasoningStartAt,
        finishedAt: usingInlineThink ? null : widget.reasoningFinishedAt,
        onToggle: usingInlineThink
            ? () => setState(() {
                _inlineThinkExpanded = !(_inlineThinkExpanded ?? true);
                _inlineThinkManuallyToggled = true;
              })
            : widget.onToggleReasoning,
      ),
    ];
  }

  Widget _buildAssistantMessage() {
    final cs = Theme.of(context).colorScheme;
    final fg = _computeChatSurfaceForegroundPalette(context);
    final l10n = AppLocalizations.of(context)!;
    final showModelName = context.select<SettingsProvider, bool>(
      (s) => s.showModelName,
    );
    final showModelTimestamp = context.select<SettingsProvider, bool>(
      (s) => s.showModelTimestamp,
    );
    final enableAssistantMarkdown = context.select<SettingsProvider, bool>(
      (s) => s.enableAssistantMarkdown,
    );
    final showThinkingCardsSetting = context.select<SettingsProvider, bool>(
      (s) => s.showThinkingCards,
    );
    final showToolCardsSetting = context.select<SettingsProvider, bool>(
      (s) => s.showToolCards,
    );
    final modelDisplayName = context.select<SettingsProvider, String>(
      _resolveModelDisplayName,
    );
    final assistant = _assistantForMessage();

    final parsedInlineThinking = _legacyInlineThinkingFor(widget);
    final extractedThinking = parsedInlineThinking.thinkingTexts.join('\n\n');
    final contentWithoutThink = parsedInlineThinking.visibleContent;
    final visualContent = _applyVisualAssistantRegexes(
      contentWithoutThink,
      assistant: assistant,
      scope: AssistantRegexScope.assistant,
    );
    final visualTranslation = widget.message.translation != null
        ? _applyVisualAssistantRegexes(
            widget.message.translation!,
            assistant: assistant,
            scope: AssistantRegexScope.assistant,
          )
        : null;
    final translationText = visualTranslation ?? widget.message.translation;
    final bool hasTranslation =
        (translationText != null && translationText.isNotEmpty);
    final bool isTranslating =
        translationText == l10n.chatMessageWidgetTranslating;
    final searchItems = _allSearchItems();
    final citationIndexLookup = _buildCitationIndexLookup(searchItems);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveReasoningSegments = _effectiveReasoningSegments(
      extractedThinking,
    );
    final timelineProjection = _projectAssistantTimeline(
      visualContent,
      reasoningSegments: effectiveReasoningSegments,
    );
    final mediaPreview = _buildAttachmentPreview(
      context,
      parts: timelineProjection.fromParts
          ? [
              for (final part in widget.message.parts)
                if (part is FilePart) part,
            ]
          : widget.message.parts,
      isDark: isDark,
      alignEnd: false,
    );

    return _ChatSurfaceTheme(
      palette: fg,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Model info and time
            Row(
              children: [
                if (widget.useAssistantAvatar) ...[
                  _buildAssistantAvatar(cs),
                  const SizedBox(width: 8),
                ] else if (widget.showModelIcon) ...[
                  widget.modelIcon ??
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: cs.secondary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Lucide.Bot, size: 18, color: cs.secondary),
                      ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showModelName)
                        Text(
                          widget.useAssistantName
                              ? (widget.assistantName?.trim().isNotEmpty == true
                                    ? widget.assistantName!.trim()
                                    : _assistantNameFallback())
                              : modelDisplayName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: AppFontWeights.medium,
                            color: cs.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      Builder(
                        builder: (context) {
                          final List<Widget> rowChildren = [];
                          if (showModelTimestamp) {
                            rowChildren.add(
                              Text(
                                _dateFormat.format(widget.message.timestamp),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            );
                          }
                          // Token stats moved to action toolbar
                          return rowChildren.isNotEmpty
                              ? Row(children: rowChildren)
                              : const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (mediaPreview != null) ...[
              mediaPreview,
              const SizedBox(height: 8),
            ],

            // File Processing Indicator (inserted before content)
            if (widget.isProcessingFiles) ...[
              const FileProcessingIndicator(),
              const SizedBox(height: 8),
            ],
            ...() {
              final showThinkingCards =
                  widget.showThinkingCards ?? showThinkingCardsSetting;
              final showToolCards =
                  widget.showToolCards ?? showToolCardsSetting;
              ToolApprovalService? approval;
              try {
                approval = context.read<ToolApprovalService>();
                context.select<ToolApprovalService, int>(
                  (service) => Object.hashAll([
                    for (final req in service.pendingRequests)
                      Object.hash(req.toolCallId, req.conversationId),
                  ]),
                );
              } catch (_) {}
              bool isPending(TimelineToolRef tool) =>
                  approval?.pendingFor(
                    toolCallId: tool.providerId,
                    conversationId: widget.message.conversationId,
                  ) !=
                  null;
              final visibleBlocks = visibleAssistantTimeline(
                timelineProjection,
                showThinkingCards: showThinkingCards,
                showToolCards: showToolCards,
                isPendingApproval: isPending,
              );
              if (visibleBlocks.isEmpty &&
                  widget.message.isStreaming &&
                  visualContent.isEmpty) {
                return <Widget>[
                  SizedBox(
                    width: double.infinity,
                    child: _buildAssistantBubbleContainer(
                      context: context,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Semantics(
                          label: l10n.chatMessageWidgetThinking,
                          child: widget.hideStreamingIndicator
                              ? const SizedBox(height: 16)
                              : const LoadingIndicator(),
                        ),
                      ),
                    ),
                  ),
                ];
              }
              // Projector omits trim-empty visualContent. Newline-only history
              // still has to occupy body height so a short scroll from the
              // bottom does not evict the last streaming bubble.
              if (visibleBlocks.isEmpty && visualContent.isNotEmpty) {
                return <Widget>[
                  _buildAssistantTextBlock(
                    context,
                    visualContent,
                    enableAssistantMarkdown,
                    citationIndexLookup,
                  ),
                  if (widget.message.isStreaming && visualContent.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 4),
                      child: widget.hideStreamingIndicator
                          ? const SizedBox(height: 16)
                          : const LoadingIndicator(),
                    ),
                ];
              }

              final widgets = <Widget>[];
              void addVisible(Widget child) {
                if (widgets.isNotEmpty) {
                  widgets.add(const SizedBox(height: 8));
                }
                widgets.add(child);
              }

              final imageGroup = <String>[
                for (final block in visibleBlocks)
                  if (block.isImage)
                    _resolveAttachmentImageUri(block.imageUri!),
              ];

              for (final block in visibleBlocks) {
                if (block.isImage) {
                  addVisible(
                    _buildAssistantImageBlock(
                      context,
                      block.imageUri!,
                      imageKey:
                          block.imageKey ??
                          timelineImageBlockKey(sourceOrdinal: 0),
                      group: imageGroup,
                    ),
                  );
                  continue;
                }
                if (block.isText) {
                  addVisible(
                    _buildAssistantTextBlock(
                      context,
                      block.text!,
                      enableAssistantMarkdown,
                      citationIndexLookup,
                    ),
                  );
                  continue;
                }
                if (!block.isThinking) continue;
                addVisible(
                  _ChainOfThoughtCard(
                    steps: _timelineStepsFromProjected(
                      block.thinkingSteps,
                      effectiveReasoningSegments,
                    ),
                    conversationId: widget.message.conversationId,
                    showThinkingCards: showThinkingCards,
                    showToolCards: showToolCards,
                    onRecoveredAnswer: widget.onRecoveredAskUserAnswer,
                  ),
                );
              }

              if (widget.message.isStreaming && visualContent.isNotEmpty) {
                widgets.add(
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 4),
                    child: widget.hideStreamingIndicator
                        ? const SizedBox(height: 16)
                        : const LoadingIndicator(),
                  ),
                );
              }
              return widgets;
            }(),
            if (hasTranslation) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: _buildSharedChatSurface(
                  context,
                  borderRadius: BorderRadius.circular(16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  defaultColor: cs.primaryContainer.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark
                        ? 0.25
                        : 0.30,
                  ),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: const Cubic(0.2, 0.8, 0.2, 1),
                    alignment: Alignment.topCenter,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IosCardPress(
                          onTap: widget.onToggleTranslation,
                          borderRadius: BorderRadius.circular(12),
                          baseColor: Colors.transparent,
                          pressedBlendStrength: 0.12,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Lucide.Languages,
                                size: 16,
                                color: fg.strong,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                l10n.chatMessageWidgetTranslation,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: AppFontWeights.emphasis,
                                  color: fg.strong,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                widget.translationExpanded
                                    ? Lucide.ChevronDown
                                    : Lucide.ChevronRight,
                                size: 18,
                                color: fg.strong,
                              ),
                            ],
                          ),
                        ),
                        if (widget.translationExpanded) ...[
                          const SizedBox(height: 8),
                          if (isTranslating)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
                              child: Row(
                                children: [
                                  const LoadingIndicator(),
                                  const SizedBox(width: 8),
                                  Builder(
                                    builder: (context) {
                                      final bool isDesktop =
                                          defaultTargetPlatform ==
                                              TargetPlatform.macOS ||
                                          defaultTargetPlatform ==
                                              TargetPlatform.windows ||
                                          defaultTargetPlatform ==
                                              TargetPlatform.linux;
                                      return Text(
                                        l10n.chatMessageWidgetTranslating,
                                        style: TextStyle(
                                          fontSize: isDesktop ? 14.0 : 15.5,
                                          color: fg.muted,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
                              child: RepaintBoundary(
                                child: SelectionArea(
                                  key: ValueKey(
                                    'translation_${widget.message.id}',
                                  ),
                                  child: Builder(
                                    builder: (context) {
                                      final bool isDesktop =
                                          defaultTargetPlatform ==
                                              TargetPlatform.macOS ||
                                          defaultTargetPlatform ==
                                              TargetPlatform.windows ||
                                          defaultTargetPlatform ==
                                              TargetPlatform.linux;
                                      final double baseTranslation = isDesktop
                                          ? 14.0
                                          : 15.5;
                                      Widget translationContent;
                                      if (enableAssistantMarkdown) {
                                        translationContent =
                                            MarkdownWithCodeHighlight(
                                              text: translationText,
                                              onCitationTap: (id) =>
                                                  _handleCitationTap(id),
                                              citationIndexResolver: (id) =>
                                                  _resolveCitationIndex(
                                                    id,
                                                    citationIndexLookup,
                                                  ),
                                              baseStyle: TextStyle(
                                                fontSize: baseTranslation,
                                                height: 1.4,
                                              ),
                                            );
                                      } else {
                                        translationContent = Text(
                                          translationText,
                                          style: TextStyle(
                                            fontSize: baseTranslation,
                                            height: 1.4,
                                            color: _chatSurfacePlainTextColor(
                                              context,
                                            ),
                                          ),
                                        );
                                      }
                                      return DefaultTextStyle.merge(
                                        style: TextStyle(
                                          fontSize: baseTranslation,
                                          height: 1.4,
                                        ),
                                        child: translationContent,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
            // Sources summary card (tap to open full citations)
            if (searchItems.isNotEmpty) ...[
              const SizedBox(height: 8),
              _SourcesSummaryCard(
                count: searchItems.length,
                items: searchItems,
                onTap: () => _showCitationsSheet(searchItems),
              ),
            ],
            // Action buttons (hidden while generating)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) => SizeTransition(
                sizeFactor: anim,
                alignment: const AlignmentDirectional(-1.0, -1.0),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: widget.message.isStreaming
                  ? const SizedBox.shrink()
                  : Padding(
                      key: const ValueKey('assistant-actions'),
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: Center(
                              child: IosIconButton(
                                size: 16,
                                padding: EdgeInsets.all(4),
                                icon: Lucide.Copy,
                                color: cs.onSurface.withValues(alpha: 0.9),
                                onTap:
                                    widget.onCopy ??
                                    () {
                                      Clipboard.setData(
                                        ClipboardData(
                                          text: widget.message.content,
                                        ),
                                      );
                                      showAppSnackBar(
                                        context,
                                        message: l10n
                                            .chatMessageWidgetCopiedToClipboard,
                                        type: NotificationType.success,
                                      );
                                    },
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: Center(
                              child: IosIconButton(
                                size: 16,
                                padding: EdgeInsets.all(4),
                                icon: Lucide.RefreshCw,
                                color: cs.onSurface.withValues(alpha: 0.9),
                                onTap: widget.onRegenerate == null
                                    ? null
                                    : () => _confirmRegeneration(
                                        widget.onRegenerate!,
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Consumer<TtsProvider>(
                            builder: (context, tts, _) {
                              final ttsActive = tts.playbackState.isActive;
                              return SizedBox(
                                width: 28,
                                height: 28,
                                child: Center(
                                  child: IosIconButton(
                                    size: 16,
                                    padding: EdgeInsets.all(4),
                                    onTap: widget.onSpeak,
                                    color: cs.onSurface.withValues(alpha: 0.9),
                                    builder: (color) => AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      transitionBuilder: (child, anim) =>
                                          ScaleTransition(
                                            scale: anim,
                                            child: FadeTransition(
                                              opacity: anim,
                                              child: child,
                                            ),
                                          ),
                                      child: Icon(
                                        ttsActive
                                            ? Lucide.CircleStop
                                            : Lucide.Volume2,
                                        key: ValueKey(
                                          ttsActive ? 'stop' : 'speak',
                                        ),
                                        size: 16,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: Center(
                              child: GestureDetector(
                                key: _translateBtnKey2,
                                behavior: HitTestBehavior.opaque,
                                onTapDown: (d) {
                                  final isDesktop =
                                      defaultTargetPlatform ==
                                          TargetPlatform.macOS ||
                                      defaultTargetPlatform ==
                                          TargetPlatform.windows ||
                                      defaultTargetPlatform ==
                                          TargetPlatform.linux;
                                  if (isDesktop) {
                                    try {
                                      DesktopMenuAnchor.setPosition(
                                        d.globalPosition,
                                      );
                                    } catch (_) {}
                                  }
                                },
                                onTap: () {
                                  final isDesktop =
                                      defaultTargetPlatform ==
                                          TargetPlatform.macOS ||
                                      defaultTargetPlatform ==
                                          TargetPlatform.windows ||
                                      defaultTargetPlatform ==
                                          TargetPlatform.linux;
                                  if (isDesktop) {
                                    _setAnchorFromKey(_translateBtnKey2);
                                  }
                                  widget.onTranslate?.call();
                                },
                                child: IosIconButton(
                                  size: 16,
                                  padding: EdgeInsets.all(4),
                                  icon: Lucide.Languages,
                                  color: cs.onSurface.withValues(alpha: 0.9),
                                  onTap: null,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: Center(
                              child: GestureDetector(
                                key: _moreBtnKey2,
                                onTapDown: (d) {
                                  final isDesktop =
                                      defaultTargetPlatform ==
                                          TargetPlatform.macOS ||
                                      defaultTargetPlatform ==
                                          TargetPlatform.windows ||
                                      defaultTargetPlatform ==
                                          TargetPlatform.linux;
                                  if (isDesktop) {
                                    try {
                                      DesktopMenuAnchor.setPosition(
                                        d.globalPosition,
                                      );
                                    } catch (_) {}
                                  }
                                },
                                onTap: () {
                                  final isDesktop =
                                      defaultTargetPlatform ==
                                          TargetPlatform.macOS ||
                                      defaultTargetPlatform ==
                                          TargetPlatform.windows ||
                                      defaultTargetPlatform ==
                                          TargetPlatform.linux;
                                  if (isDesktop) {
                                    _setAnchorFromKey(_moreBtnKey2);
                                  }
                                  widget.onMore?.call();
                                },
                                child: IosIconButton(
                                  size: 16,
                                  padding: EdgeInsets.all(4),
                                  icon: Lucide.Ellipsis,
                                  color: cs.onSurface.withValues(alpha: 0.9),
                                  onTap: null,
                                ),
                              ),
                            ),
                          ),
                          if ((widget.versionCount ?? 1) > 1) ...[
                            const SizedBox(width: 6),
                            _BranchSelector(
                              index: widget.versionIndex ?? 0,
                              total: widget.versionCount ?? 1,
                              onPrev: widget.onPrevVersion,
                              onNext: widget.onNextVersion,
                            ),
                          ],
                          if (widget.showTokenStats &&
                              widget.message.totalTokens != null) ...[
                            const Spacer(),
                            TokenDisplayWidget(
                              totalTokens: widget.message.totalTokens!,
                              promptTokens: widget.message.promptTokens,
                              completionTokens: widget.message.completionTokens,
                              cachedTokens: widget.message.cachedTokens,
                              durationMs: widget.message.durationMs,
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
            if (!widget.message.isStreaming &&
                widget.suggestions.isNotEmpty &&
                widget.onSuggestionTap != null) ...[
              const SizedBox(height: 8),
              ChatSuggestionBubbles(
                suggestions: widget.suggestions,
                onTap: widget.onSuggestionTap!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Build once per message so each citation marker only performs a map lookup.
  // Insert IDs first so an exact ID match wins over a legacy numeric index.
  Map<String, String> _buildCitationIndexLookup(
    List<Map<String, dynamic>> items,
  ) {
    final lookup = <String, String>{};
    for (final item in items) {
      final id = item['id']?.toString() ?? '';
      final index = item['index']?.toString() ?? '';
      if (id.isNotEmpty && index.isNotEmpty) lookup[id] ??= index;
    }
    for (final item in items) {
      final index = item['index']?.toString() ?? '';
      if (index.isNotEmpty) lookup[index] ??= index;
    }
    return lookup;
  }

  String? _resolveCitationIndex(
    String id,
    Map<String, String> citationIndexLookup,
  ) {
    final key = id.trim();
    if (key.isEmpty) return null;
    final direct = citationIndexLookup[key];
    if (direct != null) return direct;
    final asIndex = int.tryParse(key);
    return asIndex == null ? null : citationIndexLookup[asIndex.toString()];
  }

  // Try resolve citation id -> url from the latest search_web tool results of this assistant message
  void _handleCitationTap(String id) async {
    final l10n = AppLocalizations.of(context)!;
    final items = _allSearchItems();
    Map<String, dynamic>? match = items
        .cast<Map<String, dynamic>?>()
        .firstWhere(
          (e) => (e?['id']?.toString() ?? '') == id,
          orElse: () => null,
        );

    // Fallbacks for models that don't strictly follow "index:id":
    // 1) If id is actually an index number, match by item.index.
    // 2) If id itself looks like a URL, open it directly.
    String? url = match?['url']?.toString();
    if (url == null || url.isEmpty) {
      final idx = int.tryParse(id.trim());
      if (idx != null) {
        match = items.cast<Map<String, dynamic>?>().firstWhere(
          (e) => (e?['index']?.toString() ?? '') == idx.toString(),
          orElse: () => null,
        );
        url = match?['url']?.toString();
      }
    }
    if ((url == null || url.isEmpty) &&
        (id.contains('/') || id.contains('.'))) {
      url = id;
    }

    if (url == null || url.isEmpty) {
      if (context.mounted) {
        showAppSnackBar(
          context,
          message: l10n.chatMessageWidgetCitationNotFound,
          type: NotificationType.warning,
        );
      }
      return;
    }
    try {
      final uri = _tryNormalizeExternalUri(url);
      if (uri == null) {
        if (!mounted) return;
        showAppSnackBar(
          context,
          message: l10n.chatMessageWidgetOpenLinkError,
          type: NotificationType.error,
        );
        return;
      }
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        if (!mounted) return;
        showAppSnackBar(
          context,
          message: l10n.chatMessageWidgetCannotOpenUrl(uri.toString()),
          type: NotificationType.error,
        );
      }
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: l10n.chatMessageWidgetOpenLinkError,
        type: NotificationType.error,
      );
    }
  }

  // Extract items from all search_web or builtin_search tool results for this assistant message.
  // We scan from end to start so "latest" items win when there are duplicates.
  List<Map<String, dynamic>> _allSearchItems() {
    final parts = widget.toolParts ?? const <ToolUIPart>[];
    if (identical(parts, _searchItemsParts) && _searchItemsCache != null) {
      return _searchItemsCache!;
    }
    if (parts.isEmpty) {
      _searchItemsParts = parts;
      _searchItemsCache = const <Map<String, dynamic>>[];
      return _searchItemsCache!;
    }

    final out = <Map<String, dynamic>>[];
    final seen = <String>{};

    for (int i = parts.length - 1; i >= 0; i--) {
      final p = parts[i];
      if ((p.toolName != 'search_web' && p.toolName != 'builtin_search') ||
          (p.content?.isNotEmpty ?? false) == false) {
        continue;
      }
      try {
        final obj = jsonDecode(p.content!) as Map<String, dynamic>;
        final arr = obj['items'] as List? ?? const <dynamic>[];
        for (final it in arr) {
          if (it is! Map) continue;
          final m = it.cast<String, dynamic>();
          final key = (m['id'] ?? m['url'] ?? '')
              .toString(); // builtin_search no id
          if (key.isNotEmpty) {
            if (!seen.add(key)) continue;
          }
          out.add(m);
        }
      } catch (_) {
        // ignore broken tool payload
      }
    }
    _searchItemsParts = parts;
    _searchItemsCache = out;
    return out;
  }

  void _showCitationsSheet(List<Map<String, dynamic>> items) {
    final l10n = AppLocalizations.of(context)!;
    final sources = <CitationSourceItem>[
      for (int i = 0; i < items.length; i++)
        CitationSourceItem.fromMap(items[i], fallbackIndex: i + 1),
    ];

    showCitationSourcesBottomSheet(
      context: context,
      title: l10n.chatMessageWidgetSearchResultsTitle,
      closeSemanticLabel: l10n.mcpPageClose,
      items: sources,
      onOpen: _openCitationSource,
    );
  }

  Future<void> _openCitationSource(CitationSourceItem item) async {
    final l10n = AppLocalizations.of(context)!;
    final uri = _tryNormalizeExternalUri(item.url);
    if (uri == null) {
      showAppSnackBar(
        context,
        message: l10n.chatMessageWidgetOpenLinkError,
        type: NotificationType.error,
      );
      return;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      if (!ok) {
        showAppSnackBar(
          context,
          message: l10n.chatMessageWidgetCannotOpenUrl(uri.toString()),
          type: NotificationType.error,
        );
      }
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: l10n.chatMessageWidgetOpenLinkError,
        type: NotificationType.error,
      );
    }
  }

  Widget _buildAssistantAvatar(ColorScheme cs) {
    final av = (widget.assistantAvatar ?? '').trim();
    if (av.isNotEmpty) {
      if (av.startsWith('http')) {
        return FutureBuilder<String?>(
          future: AvatarCache.getPath(av),
          builder: (ctx, snap) {
            final p = snap.data;
            if (p != null && File(p).existsSync()) {
              return ClipOval(
                child: Image.file(
                  File(p),
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                ),
              );
            }
            return ClipOval(
              child: Image.network(
                av,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _assistantInitial(cs),
              ),
            );
          },
        );
      }
      if (av.startsWith('/') || av.contains(':')) {
        final fixed = SandboxPathResolver.fix(av);
        final f = File(fixed);
        if (f.existsSync()) {
          return ClipOval(
            child: Image.file(f, width: 32, height: 32, fit: BoxFit.cover),
          );
        }
        return _assistantInitial(cs);
      }
      // treat as emoji or single char label
      final bool isIOS = defaultTargetPlatform == TargetPlatform.iOS;
      final double fs = 18;
      final Offset? nudge = isIOS ? Offset(fs * 0.065, fs * -0.05) : null;
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: EmojiText(
          av.characters.take(1).toString(),
          fontSize: fs,
          optimizeEmojiAlign: true,
          nudge: nudge,
        ),
      );
    }
    return _assistantInitial(cs);
  }

  Widget _assistantInitial(ColorScheme cs) {
    final name = (widget.assistantName ?? '').trim();
    final ch = name.isNotEmpty ? name.characters.first.toUpperCase() : 'A';
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        ch,
        style: TextStyle(
          color: cs.primary,
          fontWeight: AppFontWeights.emphasis,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.role == 'user';
    final palette = _computeChatSurfaceForegroundPalette(
      context,
      isUser: isUser,
    );
    final child = isUser
        ? _buildUserMessage()
        : widget.message.role == 'tool'
        ? _buildToolMessage()
        : _buildAssistantMessage();
    return _ChatSurfaceTheme(palette: palette, child: child);
  }
}

class _AnimatedPopup extends StatefulWidget {
  const _AnimatedPopup({required this.child});
  final Widget child;

  @override
  State<_AnimatedPopup> createState() => _AnimatedPopupState();
}

class _AnimatedPopupState extends State<_AnimatedPopup> {
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _opacity = 1.0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      opacity: _opacity,
      child: widget.child,
    );
  }
}

({ChatMessageBackgroundStyle style, ChatBubbleStyleOverrides overrides})
_chatSurfaceStyleSelection(BuildContext context, {bool isUser = false}) {
  return context.select<
    SettingsProvider,
    ({ChatMessageBackgroundStyle style, ChatBubbleStyleOverrides overrides})
  >(
    (s) => (
      style: s.chatMessageBackgroundStyle,
      overrides: s.chatBubbleStyleOverridesFor(isUser: isUser),
    ),
  );
}

Color _chatSurfacePlainTextColor(BuildContext context, {bool isUser = false}) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final selection = _chatSurfaceStyleSelection(context, isUser: isUser);
  if (selection.style == ChatMessageBackgroundStyle.defaultStyle) {
    return cs.onSurface;
  }
  return resolveBubbleStyle(
    cs,
    theme.brightness,
    selection.style,
    selection.overrides,
  ).text;
}

Widget _buildSharedChatSurface(
  BuildContext context, {
  required Widget child,
  required BorderRadius borderRadius,
  required EdgeInsetsGeometry padding,
  Color? defaultColor,
  bool bareOnDefault = false,
  bool isUser = false,
}) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final selection = _chatSurfaceStyleSelection(context, isUser: isUser);
  final style = selection.style;
  final overrides = selection.overrides;
  final resolved = resolveBubbleStyle(cs, theme.brightness, style, overrides);
  Widget paddedChild = Padding(padding: padding, child: child);
  if (style != ChatMessageBackgroundStyle.defaultStyle &&
      overrides.hasTextOverride(theme.brightness)) {
    paddedChild = DefaultTextStyle.merge(
      style: TextStyle(color: resolved.text),
      child: paddedChild,
    );
  }

  switch (style) {
    case ChatMessageBackgroundStyle.frosted:
      final radius = BorderRadius.circular(resolved.radius);
      return FrostedSurface(
        style: resolved,
        borderRadius: radius,
        isUser: isUser,
        child: paddedChild,
      );
    case ChatMessageBackgroundStyle.solid:
      final radius = BorderRadius.circular(resolved.radius);
      return DecoratedBox(
        decoration: BoxDecoration(
          color: resolved.background,
          borderRadius: radius,
          border: Border.all(
            color: resolved.border,
            width: resolved.borderWidth,
          ),
        ),
        child: paddedChild,
      );
    case ChatMessageBackgroundStyle.defaultStyle:
      if (bareOnDefault) {
        return child;
      }
      if (defaultColor == null) {
        return paddedChild;
      }
      return DecoratedBox(
        decoration: BoxDecoration(
          color: defaultColor,
          borderRadius: borderRadius,
        ),
        child: paddedChild,
      );
  }
}

class _ChatSurfaceForegroundPalette {
  const _ChatSurfaceForegroundPalette({
    required this.strong,
    required this.medium,
    required this.muted,
    required this.body,
    required this.divider,
    required this.accent,
  });

  final Color strong;
  final Color medium;
  final Color muted;
  final Color body;
  final Color divider;
  final Color accent;

  @override
  bool operator ==(Object other) =>
      other is _ChatSurfaceForegroundPalette &&
      other.strong == strong &&
      other.medium == medium &&
      other.muted == muted &&
      other.body == body &&
      other.divider == divider &&
      other.accent == accent;

  @override
  int get hashCode => Object.hash(strong, medium, muted, body, divider, accent);
}

class _ChatSurfaceTheme extends InheritedWidget {
  const _ChatSurfaceTheme({required this.palette, required super.child});

  final _ChatSurfaceForegroundPalette palette;

  static _ChatSurfaceForegroundPalette? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_ChatSurfaceTheme>()
        ?.palette;
  }

  @override
  bool updateShouldNotify(_ChatSurfaceTheme oldWidget) =>
      palette != oldWidget.palette;
}

_ChatSurfaceForegroundPalette _chatSurfaceForegroundPalette(
  BuildContext context, {
  bool isUser = false,
}) {
  if (!isUser) {
    final inherited = _ChatSurfaceTheme.maybeOf(context);
    if (inherited != null) return inherited;
  }
  return _computeChatSurfaceForegroundPalette(context, isUser: isUser);
}

_ChatSurfaceForegroundPalette _computeChatSurfaceForegroundPalette(
  BuildContext context, {
  bool isUser = false,
}) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final selection = _chatSurfaceStyleSelection(context, isUser: isUser);
  if (selection.style == ChatMessageBackgroundStyle.defaultStyle) {
    return _ChatSurfaceForegroundPalette(
      strong: cs.secondary,
      medium: cs.secondary.withValues(alpha: 0.9),
      muted: cs.onSurface.withValues(alpha: 0.5),
      body: cs.onSurface.withValues(alpha: 0.7),
      divider: theme.brightness == Brightness.dark
          ? cs.onSurface.withValues(alpha: 0.24)
          : cs.outline.withValues(alpha: 0.15),
      accent: cs.primary,
    );
  }

  final base = resolveBubbleStyle(
    cs,
    theme.brightness,
    selection.style,
    selection.overrides,
  ).text;
  final bool isDark = theme.brightness == Brightness.dark;
  return _ChatSurfaceForegroundPalette(
    strong: base.withValues(alpha: isDark ? 0.88 : 0.78),
    medium: base.withValues(alpha: isDark ? 0.76 : 0.66),
    muted: base.withValues(alpha: isDark ? 0.56 : 0.46),
    body: base.withValues(alpha: isDark ? 0.72 : 0.6),
    divider: base.withValues(alpha: isDark ? 0.16 : 0.14),
    accent: base.withValues(alpha: isDark ? 0.84 : 0.74),
  );
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = danger ? Theme.of(context).colorScheme.error : cs.onSurface;
    final ic = danger
        ? Theme.of(context).colorScheme.error
        : cs.onSurface.withValues(alpha: 0.9);
    // iOS-style press effect: no ripple. Use transparent base and a subtle
    // pressed blend inside the blurred/glass menu container.
    return IosCardPress(
      borderRadius: BorderRadius.zero,
      baseColor: Colors.transparent,
      onTap: () {
        try {
          Haptics.light();
        } catch (_) {}
        onTap?.call();
      },
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            Icon(icon, size: 18, color: ic),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14.5,
                  color: fg,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BranchSelector extends StatelessWidget {
  const _BranchSelector({
    required this.index,
    required this.total,
    this.onPrev,
    this.onNext,
  });
  final int index; // zero-based
  final int total;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canPrev = index > 0;
    final canNext = index < total - 1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: Center(
            child: IosIconButton(
              size: 16,
              enabled: canPrev,
              color: cs.onSurface,
              icon: Lucide.ChevronLeft,
              onTap: canPrev ? onPrev : null,
            ),
          ),
        ),
        SizedBox(
          width: 28,
          height: 28,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${index + 1}/$total',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.8),
                  fontWeight: AppFontWeights.medium,
                ),
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ),
        ),
        SizedBox(
          width: 28,
          height: 28,
          child: Center(
            child: IosIconButton(
              size: 16,
              enabled: canNext,
              color: cs.onSurface,
              icon: Lucide.ChevronRight,
              onTap: canNext ? onNext : null,
            ),
          ),
        ),
      ],
    );
  }
}

// Pulsing 3-dot loading indicator for chat thinking states (shared)
class LoadingIndicator extends StatefulWidget {
  const LoadingIndicator({
    super.key,
    this.height = 16,
    this.dotSize = 9,
    this.spacing = 6,
    this.color,
  });

  final double height;
  final double dotSize;
  final double spacing;
  final Color? color;
  @override
  State<LoadingIndicator> createState() => _LoadingIndicatorState();
}

class _LoadingIndicatorState extends State<LoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = widget.color ?? cs.primary;

    return RepaintBoundary(
      child: CustomPaint(
        size: Size(widget.dotSize * 3 + widget.spacing * 2, widget.height),
        painter: _LoadingDotsPainter(
          animation: _controller,
          color: base,
          dotSize: widget.dotSize,
          spacing: widget.spacing,
        ),
      ),
    );
  }
}

class _LoadingDotsPainter extends CustomPainter {
  _LoadingDotsPainter({
    required this.animation,
    required this.color,
    required this.dotSize,
    required this.spacing,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color color;
  final double dotSize;
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 3; i++) {
      final phase = (animation.value - i * 0.22) * 2 * math.pi;
      final wave = (math.sin(phase) + 1) / 2;
      final scale = 0.85 + 0.15 * wave;
      final opacity = 0.45 + 0.45 * wave;
      final cx = i * (dotSize + spacing) + dotSize / 2;
      final cy = size.height / 2;
      canvas.save();
      canvas.translate(cx, cy);
      canvas.scale(scale);
      canvas.drawCircle(
        Offset.zero,
        dotSize / 2,
        Paint()..color = color.withValues(alpha: opacity),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Streaming visual wrapper for assistant message content.
///
/// Goals:
/// - Make streaming output feel less "chunky" by smoothing size growth.
/// - Respect reduce-motion settings.
class _StreamingAssistantMessageMotion extends StatelessWidget {
  const _StreamingAssistantMessageMotion({
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return AnimatedSize(
      key: const ValueKey('streaming-assistant-message-motion'),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topLeft,
      clipBehavior: Clip.hardEdge,
      child: child,
    );
  }
}

ToolUIPart? toolUiFromPayload(String payloadJson, {int fallbackOrdinal = 0}) {
  try {
    final decoded = jsonDecode(payloadJson);
    if (decoded is! Map) return null;
    var id = (decoded['id'] ?? '').toString();
    final name = (decoded['name'] ?? '').toString();
    if (id.isEmpty) {
      id = '${name.isEmpty ? 'tool' : name}-$fallbackOrdinal';
    }
    final args = decoded['arguments'];
    final content = decoded['content']?.toString();
    final rawMeta = decoded['metadata'];
    return ToolUIPart(
      id: id,
      toolName: name,
      arguments: args is Map
          ? args.cast<String, dynamic>()
          : const <String, dynamic>{},
      content: content,
      metadata: rawMeta is Map ? Map<String, dynamic>.from(rawMeta) : null,
      loading: content == null || content.isEmpty,
    );
  } catch (_) {
    return null;
  }
}

// UI data for MCP tool calls/results
class ToolUIPart {
  final String id;
  final String toolName;
  final Map<String, dynamic> arguments;
  final String? content; // null means still loading/result not yet available
  final Map<String, dynamic>? metadata;
  final bool loading;

  /// Stable memo identity from the original live tool, if any.
  final int? memoToken;

  const ToolUIPart({
    required this.id,
    required this.toolName,
    required this.arguments,
    this.content,
    this.metadata,
    this.loading = false,
    this.memoToken,
  });

  int get cacheToken => memoToken ?? identityHashCode(this);
}

// Data for a reasoning segment (for mixed display)
class ReasoningSegment {
  final String text;
  final bool expanded;
  final bool loading;
  final DateTime? startAt;
  final DateTime? finishedAt;
  final VoidCallback? onToggle;
  // Index of the first tool call that occurs after this segment starts.
  final int toolStartIndex;

  const ReasoningSegment({
    required this.text,
    required this.expanded,
    required this.loading,
    this.startAt,
    this.finishedAt,
    this.onToggle,
    this.toolStartIndex = 0,
  });

  /// Toggle is excluded: the step State looks it up on tap so a new
  /// closure every parent rebuild does not bust widget memoization.
  @override
  bool operator ==(Object other) =>
      other is ReasoningSegment &&
      other.text == text &&
      other.expanded == expanded &&
      other.loading == loading &&
      other.startAt == startAt &&
      other.finishedAt == finishedAt &&
      other.toolStartIndex == toolStartIndex;

  @override
  int get hashCode =>
      Object.hash(text, expanded, loading, startAt, finishedAt, toolStartIndex);
}

class _TimelineStepData {
  const _TimelineStepData.reasoning({
    required this.reasoning,
    required this.reasoningCountAfter,
    required this.toolCountAfter,
    this.sourceOrdinal = 0,
  }) : tool = null;

  const _TimelineStepData.tool({
    required this.tool,
    required this.reasoningCountAfter,
    required this.toolCountAfter,
    this.sourceOrdinal = 0,
  }) : reasoning = null;

  final ReasoningSegment? reasoning;
  final ToolUIPart? tool;
  final int reasoningCountAfter;
  final int toolCountAfter;
  final int sourceOrdinal;

  bool get isReasoning => reasoning != null;
  bool get isTool => tool != null;
  bool get loading => reasoning?.loading ?? tool?.loading ?? false;
}

/// Value-equal id set so [context.select] can ignore identical approval snapshots.
class _IdSet {
  const _IdSet(this.ids);
  final Set<String> ids;

  bool contains(String? id) => id != null && ids.contains(id);

  @override
  bool operator ==(Object other) =>
      other is _IdSet &&
      other.ids.length == ids.length &&
      other.ids.containsAll(ids);

  @override
  int get hashCode => Object.hashAllUnordered(ids);
}

ToolApprovalRequest? _matchingApprovalRequest({
  required ToolApprovalService approval,
  required String? conversationId,
  String? toolCallId,
}) {
  if (toolCallId == null || toolCallId.isEmpty) {
    return null;
  }
  return approval.pendingFor(
    toolCallId: toolCallId,
    conversationId: conversationId,
  );
}

bool _shouldShowToolCard(
  BuildContext context,
  ToolUIPart part, {
  bool? showToolCards,
  String? conversationId,
}) {
  final visible =
      showToolCards ??
      context.select<SettingsProvider, bool>((s) => s.showToolCards);
  var pendingApproval = false;
  if (!visible && part.loading) {
    try {
      pendingApproval = context.select<ToolApprovalService, bool>(
        (approval) =>
            _matchingApprovalRequest(
              approval: approval,
              conversationId: conversationId,
              toolCallId: part.id,
            ) !=
            null,
      );
    } catch (_) {}
  }
  return isTimelineToolVisible(
    toolName: part.toolName,
    loading: part.loading,
    showToolCards: visible,
    pendingApproval: pendingApproval,
    filterBuiltinSearch: false,
  );
}

List<_TimelineStepData> _visibleChatTimelineSteps(
  BuildContext context,
  List<_TimelineStepData> steps, {
  required bool showThinkingCards,
  required bool showToolCards,
  required String conversationId,
}) {
  if (showThinkingCards && showToolCards) return steps;
  ToolApprovalService? approval;
  if (!showToolCards) {
    try {
      approval = context.read<ToolApprovalService>();
      context.select<ToolApprovalService, int>(
        (service) => Object.hashAll([
          for (final req in service.pendingRequests)
            Object.hash(req.toolCallId, req.conversationId),
        ]),
      );
    } catch (_) {}
  }
  return [
    for (final step in steps)
      if (step.isReasoning
          ? showThinkingCards
          : isTimelineToolVisible(
              toolName: step.tool!.toolName,
              loading: step.tool!.loading,
              showToolCards: showToolCards,
              pendingApproval:
                  approval?.pendingFor(
                    toolCallId: step.tool?.id ?? '',
                    conversationId: conversationId,
                  ) !=
                  null,
            ))
        step,
  ];
}

enum _ReasoningStepState { collapsed, preview, expanded }

const double _timelineStepPaddingV = 8;
const double _timelineIconSize = 18;
const double _timelineIconColumnWidth = 24;
const double _timelineGap = 8;
const double _timelineLineGap = 3;
const double _timelineLineX = (_timelineIconColumnWidth - 1) / 2;

/// Holds the latest reasoning-toggle callbacks so memoized step widgets can
/// look them up on tap without baking a new closure into the cache key.
class _ChainOfThoughtActions extends InheritedWidget {
  const _ChainOfThoughtActions({required this.toggles, required super.child});

  final List<VoidCallback?> toggles;

  static VoidCallback? toggleOf(BuildContext context, int index) {
    final scope = context
        .getInheritedWidgetOfExactType<_ChainOfThoughtActions>();
    if (scope == null || index < 0 || index >= scope.toggles.length) {
      return null;
    }
    return scope.toggles[index];
  }

  @override
  bool updateShouldNotify(_ChainOfThoughtActions oldWidget) => false;
}

/// Holds the latest recovered-answer callback so memoized ask-user steps can
/// submit without baking a new closure into the cache key.
class _RecoveredAskUserAction extends InheritedWidget {
  const _RecoveredAskUserAction({
    required this.conversationId,
    required this.onSubmit,
    required super.child,
  });

  final String conversationId;
  final Future<void> Function(ToolUIPart part, AskUserResult result)? onSubmit;

  static _RecoveredAskUserAction? maybeOf(BuildContext context) {
    return context.getInheritedWidgetOfExactType<_RecoveredAskUserAction>();
  }

  @override
  bool updateShouldNotify(_RecoveredAskUserAction oldWidget) => false;
}

class _CachedTimelineStep extends StatefulWidget {
  const _CachedTimelineStep({
    super.key,
    required this.signature,
    required this.builder,
  });

  /// Must include every ambient input the [builder] reads. Returning the same
  /// widget instance lets [Element.updateChild] skip the subtree entirely.
  final Object signature;
  final Widget Function() builder;

  @override
  State<_CachedTimelineStep> createState() => _CachedTimelineStepState();
}

class _CachedTimelineStepState extends State<_CachedTimelineStep> {
  Widget? _rendered;

  @override
  void didUpdateWidget(covariant _CachedTimelineStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.signature != widget.signature) {
      _rendered = null;
    }
  }

  @override
  Widget build(BuildContext context) => _rendered ??= widget.builder();
}

class _ChainOfThoughtCard extends StatefulWidget {
  const _ChainOfThoughtCard({
    required this.steps,
    required this.conversationId,
    required this.showThinkingCards,
    required this.showToolCards,
    this.onRecoveredAnswer,
  });

  final List<_TimelineStepData> steps;
  final String conversationId;
  final bool showThinkingCards;
  final bool showToolCards;
  final Future<void> Function(ToolUIPart part, AskUserResult result)?
  onRecoveredAnswer;

  @override
  State<_ChainOfThoughtCard> createState() => _ChainOfThoughtCardState();
}

class _ChainOfThoughtCardState extends State<_ChainOfThoughtCard> {
  bool _showAllSteps = false;

  Object _reasoningStepSignature({
    required ReasoningSegment step,
    required bool isFirst,
    required bool isLast,
    required _ChatSurfaceForegroundPalette fg,
    required Brightness brightness,
    required bool enableReasoningMarkdown,
    required double textScale,
    required bool hasToggle,
  }) {
    return Object.hash(
      'reasoning',
      identityHashCode(step.text),
      step.expanded,
      step.loading,
      step.startAt,
      step.finishedAt,
      step.toolStartIndex,
      isFirst,
      isLast,
      fg,
      brightness,
      enableReasoningMarkdown,
      textScale,
      hasToggle,
    );
  }

  Object _toolStepSignature({
    required ToolUIPart part,
    required bool isFirst,
    required bool isLast,
    required _ChatSurfaceForegroundPalette fg,
    required Brightness brightness,
    required bool showToolResultSummary,
    required bool hideToolResultImages,
    required bool pendingApproval,
    required double textScale,
  }) {
    return Object.hash(
      'tool',
      widget.conversationId,
      part.cacheToken,
      isFirst,
      isLast,
      fg,
      brightness,
      showToolResultSummary,
      hideToolResultImages,
      pendingApproval,
      textScale,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fg = _chatSurfaceForegroundPalette(context);
    final collapseThinkingSteps = context.select<SettingsProvider, bool>(
      (s) => s.collapseThinkingSteps,
    );
    final showToolResultSummary = context.select<SettingsProvider, bool>(
      (s) => s.showToolResultSummary,
    );
    final hideToolResultImages = context.select<SettingsProvider, bool>(
      (s) => s.hideToolResultImages,
    );
    final enableReasoningMarkdown = context.select<SettingsProvider, bool>(
      (s) => s.enableReasoningMarkdown,
    );
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final filteredSteps = _visibleChatTimelineSteps(
      context,
      widget.steps,
      showThinkingCards: widget.showThinkingCards,
      showToolCards: widget.showToolCards,
      conversationId: widget.conversationId,
    );
    if (filteredSteps.isEmpty) {
      return const SizedBox.shrink();
    }
    final pendingApprovalIds = context.select<ToolApprovalService, _IdSet>((
      approval,
    ) {
      return _IdSet({
        for (final step in filteredSteps)
          if (step.tool != null &&
              _matchingApprovalRequest(
                    approval: approval,
                    conversationId: widget.conversationId,
                    toolCallId: step.tool!.id,
                  ) !=
                  null)
            step.tool!.id,
      });
    });
    final l10n = AppLocalizations.of(context)!;
    final enableAdaptiveWidth =
        filteredSteps.isNotEmpty &&
        filteredSteps.every((step) => step.isReasoning) &&
        !filteredSteps.any((step) => step.isReasoning && step.loading);
    final canCollapse = collapseThinkingSteps && filteredSteps.length > 2;
    final hiddenCount = canCollapse && !_showAllSteps
        ? filteredSteps.length - 2
        : 0;
    final visibleSteps = hiddenCount > 0
        ? filteredSteps.sublist(hiddenCount)
        : filteredSteps;
    final fillWidth =
        !enableAdaptiveWidth ||
        visibleSteps.any(
          (step) =>
              step.isReasoning &&
              ((step.reasoning?.expanded ?? false) || step.loading),
        );

    final card = _buildSharedChatSurface(
      context,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      defaultColor: cs.primaryContainer.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.25 : 0.30,
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubicEmphasized,
        alignment: Alignment.topLeft,
        child: _RecoveredAskUserAction(
          conversationId: widget.conversationId,
          onSubmit: widget.onRecoveredAnswer,
          child: _ChainOfThoughtActions(
            toggles: [
              for (final step in filteredSteps) step.reasoning?.onToggle,
            ],
            child: Column(
              mainAxisSize: fillWidth ? MainAxisSize.max : MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (canCollapse)
                  IosCardPress(
                    onTap: () => setState(() => _showAllSteps = !_showAllSteps),
                    borderRadius: BorderRadius.circular(12),
                    baseColor: Colors.transparent,
                    pressedScale: 1,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 0,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: _timelineIconColumnWidth,
                            child: Center(
                              child: Icon(
                                _showAllSteps
                                    ? Lucide.ChevronUp
                                    : Lucide.ChevronDown,
                                size: 16,
                                color: fg.strong,
                              ),
                            ),
                          ),
                          const SizedBox(width: _timelineGap),
                          Text(
                            _showAllSteps
                                ? l10n.chainOfThoughtCollapse
                                : l10n.chainOfThoughtExpandSteps(
                                    widget.steps.length - visibleSteps.length,
                                  ),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: AppFontWeights.semibold,
                              color: fg.strong,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                for (var i = 0; i < visibleSteps.length; i++)
                  () {
                    final step = visibleSteps[i];
                    final sourceIndex = hiddenCount + i;
                    final isFirst = i == 0;
                    final isLast = i == visibleSteps.length - 1;
                    if (step.isReasoning) {
                      final reasoning = step.reasoning!;
                      final hasToggle = reasoning.onToggle != null;
                      return _CachedTimelineStep(
                        key: ValueKey<String>('reasoning-$sourceIndex'),
                        signature: _reasoningStepSignature(
                          step: reasoning,
                          isFirst: isFirst,
                          isLast: isLast,
                          fg: fg,
                          brightness: theme.brightness,
                          enableReasoningMarkdown: enableReasoningMarkdown,
                          textScale: textScale,
                          hasToggle: hasToggle,
                        ),
                        builder: () => _ChainOfThoughtReasoningStep(
                          step: reasoning,
                          sourceIndex: sourceIndex,
                          isFirst: isFirst,
                          isLast: isLast,
                        ),
                      );
                    }
                    final part = step.tool!;
                    return _CachedTimelineStep(
                      key: ValueKey<String>(
                        timelineToolStepKey(
                          id: part.id,
                          sourceOrdinal: step.sourceOrdinal,
                          toolName: part.toolName,
                        ),
                      ),
                      signature: _toolStepSignature(
                        part: part,
                        isFirst: isFirst,
                        isLast: isLast,
                        fg: fg,
                        brightness: theme.brightness,
                        showToolResultSummary: showToolResultSummary,
                        hideToolResultImages: hideToolResultImages,
                        pendingApproval: pendingApprovalIds.contains(part.id),
                        textScale: textScale,
                      ),
                      builder: () {
                        debugTimelineToolStepBuilds++;
                        return _ChainOfThoughtToolStep(
                          part: part,
                          conversationId: widget.conversationId,
                          isFirst: isFirst,
                          isLast: isLast,
                        );
                      },
                    );
                  }(),
              ],
            ),
          ),
        ),
      ),
    );

    return Align(
      alignment: Alignment.centerLeft,
      widthFactor: fillWidth ? null : 1,
      child: card,
    );
  }
}

class _TimelineStepShell extends StatelessWidget {
  const _TimelineStepShell({
    required this.icon,
    required this.label,
    required this.isFirst,
    required this.isLast,
    this.onTap,
    this.extra,
    this.indicator,
    this.content,
    this.contentVisible = false,
    this.expectContent = false,
  });

  final Widget icon;
  final Widget label;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onTap;
  final Widget? extra;
  final Widget? indicator;
  final Widget? content;
  final bool contentVisible;

  /// Keep [AnimatedSize] mounted so a later result or expand can grow in.
  /// Finished steps with no body skip the slot entirely.
  final bool expectContent;

  @override
  Widget build(BuildContext context) {
    final fg = _chatSurfaceForegroundPalette(context);
    final headerContent = Padding(
      padding: const EdgeInsets.symmetric(vertical: _timelineStepPaddingV),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
            width: _timelineIconColumnWidth,
            height: _timelineIconSize,
          ),
          const SizedBox(width: _timelineGap),
          Expanded(child: label),
          if (extra != null) ...[const SizedBox(width: 8), extra!],
          if (indicator != null) ...[const SizedBox(width: 6), indicator!],
        ],
      ),
    );

    final header = Stack(
      children: [
        headerContent,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: _timelineIconColumnWidth,
          child: _TimelineIconColumn(
            icon: icon,
            isFirst: isFirst,
            isLast: isLast,
            lineColor: fg.divider,
          ),
        ),
      ],
    );

    final pressableHeader = IosCardPress(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      baseColor: Colors.transparent,
      pressedScale: 1,
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: header,
    );
    if (content == null && !expectContent) {
      return KeyedSubtree(
        key: ValueKey<String>('chatMessageTimelineStepShell:$isFirst:$isLast'),
        child: pressableHeader,
      );
    }

    return KeyedSubtree(
      key: ValueKey<String>('chatMessageTimelineStepShell:$isFirst:$isLast'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          pressableHeader,
          Stack(
            clipBehavior: Clip.none,
            children: [
              if (!isLast)
                Positioned(
                  left: _timelineLineX,
                  top: 0,
                  bottom: 0,
                  child: SizedBox(
                    key: const ValueKey('chatMessageTimelineContentLine'),
                    width: 1,
                    child: ColoredBox(color: fg.divider),
                  ),
                ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: const Cubic(0.2, 0.8, 0.2, 1),
                alignment: Alignment.topLeft,
                child: contentVisible
                    ? Padding(
                        padding: const EdgeInsets.only(
                          left: _timelineIconColumnWidth + _timelineGap,
                          top: 4,
                          bottom: 8,
                        ),
                        child: content,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimelineIconColumn extends StatelessWidget {
  const _TimelineIconColumn({
    required this.icon,
    required this.isFirst,
    required this.isLast,
    required this.lineColor,
  });

  final Widget icon;
  final bool isFirst;
  final bool isLast;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      key: ValueKey<String>('chatMessageTimelineIconColumn:$isFirst:$isLast'),
      painter: _TimelineLinePainter(
        isFirst: isFirst,
        isLast: isLast,
        lineColor: lineColor,
      ),
      child: SizedBox.expand(child: Center(child: icon)),
    );
  }
}

class _TimelineLinePainter extends CustomPainter {
  const _TimelineLinePainter({
    required this.isFirst,
    required this.isLast,
    required this.lineColor,
  });

  final bool isFirst;
  final bool isLast;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final x = size.width / 2;
    final iconTop = (size.height - _timelineIconSize) / 2;
    final iconBottom = iconTop + _timelineIconSize;
    if (!isFirst) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, math.max(0, iconTop - _timelineLineGap)),
        paint,
      );
    }
    if (!isLast) {
      canvas.drawLine(
        Offset(x, math.min(size.height, iconBottom + _timelineLineGap)),
        Offset(x, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TimelineLinePainter oldDelegate) {
    return oldDelegate.isFirst != isFirst ||
        oldDelegate.isLast != isLast ||
        oldDelegate.lineColor != lineColor;
  }
}

class _ChainOfThoughtReasoningStep extends StatefulWidget {
  const _ChainOfThoughtReasoningStep({
    required this.step,
    required this.sourceIndex,
    required this.isFirst,
    required this.isLast,
  });

  final ReasoningSegment step;
  final int sourceIndex;
  final bool isFirst;
  final bool isLast;

  @override
  State<_ChainOfThoughtReasoningStep> createState() =>
      _ChainOfThoughtReasoningStepState();
}

class _ChainOfThoughtReasoningStepState
    extends State<_ChainOfThoughtReasoningStep> {
  final ValueNotifier<int> _elapsedTick = ValueNotifier<int>(0);
  Timer? _elapsedTimer;
  final ScrollController _scroll = ScrollController();
  bool _hasOverflow = false;

  _ReasoningStepState get _stepState {
    if (widget.step.loading) {
      return widget.step.expanded
          ? _ReasoningStepState.expanded
          : _ReasoningStepState.preview;
    }
    return widget.step.expanded
        ? _ReasoningStepState.expanded
        : _ReasoningStepState.collapsed;
  }

  String _sanitize(String s) {
    return s.replaceAll('\r', '').trim();
  }

  String _elapsed() {
    final start = widget.step.startAt;
    if (start == null) return '';
    final end =
        widget.step.finishedAt ??
        (widget.step.loading ? DateTime.now() : start);
    final ms = end.difference(start).inMilliseconds;
    return '(${(ms / 1000).toStringAsFixed(1)}s)';
  }

  void _syncElapsedTimer() {
    if (widget.step.loading) {
      _elapsedTimer ??= Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (mounted) _elapsedTick.value++;
      });
    } else {
      _elapsedTimer?.cancel();
      _elapsedTimer = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _syncElapsedTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOverflow();
      if (widget.step.loading && _scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _ChainOfThoughtReasoningStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncElapsedTimer();
    if (widget.step.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _elapsedTick.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _checkOverflow() {
    if (!_scroll.hasClients) return;
    final over = _scroll.position.maxScrollExtent > 0.5;
    if (over != _hasOverflow && mounted) {
      setState(() => _hasOverflow = over);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = _chatSurfaceForegroundPalette(context);
    final l10n = AppLocalizations.of(context)!;
    final enableReasoningMarkdown = context.select<SettingsProvider, bool>(
      (s) => s.enableReasoningMarkdown,
    );
    final state = _stepState;
    final display = _sanitize(widget.step.text);
    final label = ThinkingSheen(
      enabled: widget.step.loading,
      color: fg.strong,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.chatMessageWidgetDeepThinking,
            style: TextStyle(
              fontSize: 13,
              fontWeight: AppFontWeights.semibold,
              color: fg.strong,
            ),
          ),
          if (widget.step.startAt != null) ...[
            const SizedBox(width: 6),
            ValueListenableBuilder<int>(
              valueListenable: _elapsedTick,
              builder: (context, _, __) => Text(
                _elapsed(),
                style: TextStyle(fontSize: 13, color: fg.medium),
              ),
            ),
          ],
        ],
      ),
    );

    final icon = SizedBox(
      width: 18,
      height: 18,
      child: Center(
        child: ReasoningIcons.thinkingCardIcon(size: 18, color: fg.strong),
      ),
    );

    Widget reasoningContent(String text) {
      if (enableReasoningMarkdown) {
        return RepaintBoundary(
          child: MarkdownWithCodeHighlight(
            text: text.isNotEmpty ? text : '…',
            baseStyle: TextStyle(fontSize: 12.5, height: 1.32),
            streaming: widget.step.loading,
          ),
        );
      }
      return Text(
        text.isNotEmpty ? text : '…',
        style: TextStyle(fontSize: 12.5, height: 1.32),
      );
    }

    Widget? content;
    if (state == _ReasoningStepState.preview) {
      content = ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 100),
        child: _hasOverflow
            ? ShaderMask(
                shaderCallback: (rect) {
                  final h = rect.height;
                  const double topFade = 12;
                  const double bottomFade = 28;
                  final double sTop = (topFade / h).clamp(0.0, 1.0);
                  final double sBot = (1.0 - bottomFade / h).clamp(0.0, 1.0);
                  return LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: const [
                      Color(
                        0x00FFFFFF,
                      ), // color-gate: ignore (dstIn alpha mask)
                      Color(
                        0xFFFFFFFF,
                      ), // color-gate: ignore (dstIn alpha mask)
                      Color(
                        0xFFFFFFFF,
                      ), // color-gate: ignore (dstIn alpha mask)
                      Color(
                        0x00FFFFFF,
                      ), // color-gate: ignore (dstIn alpha mask)
                    ],
                    stops: [0.0, sTop, sBot, 1.0],
                  ).createShader(rect);
                },
                blendMode: BlendMode.dstIn,
                child: SingleChildScrollView(
                  controller: _scroll,
                  physics: const BouncingScrollPhysics(),
                  child: SelectionArea(child: reasoningContent(display)),
                ),
              )
            : SingleChildScrollView(
                controller: _scroll,
                physics: const NeverScrollableScrollPhysics(),
                child: SelectionArea(child: reasoningContent(display)),
              ),
      );
    } else if (state == _ReasoningStepState.expanded) {
      content = SelectionArea(child: reasoningContent(display));
    }

    final hasToggle =
        _ChainOfThoughtActions.toggleOf(context, widget.sourceIndex) != null;
    return _TimelineStepShell(
      icon: icon,
      label: label,
      isFirst: widget.isFirst,
      isLast: widget.isLast,
      onTap: hasToggle
          ? () => _ChainOfThoughtActions.toggleOf(
              context,
              widget.sourceIndex,
            )?.call()
          : null,
      indicator: hasToggle
          ? Icon(
              state == _ReasoningStepState.expanded
                  ? Lucide.ChevronUp
                  : Lucide.ChevronDown,
              size: 16,
              color: fg.muted,
            )
          : null,
      content: content,
      contentVisible: state != _ReasoningStepState.collapsed,
      expectContent: true,
    );
  }
}

class _ChainOfThoughtToolStep extends StatefulWidget {
  const _ChainOfThoughtToolStep({
    required this.part,
    required this.conversationId,
    required this.isFirst,
    required this.isLast,
  });

  final ToolUIPart part;
  final String conversationId;
  final bool isFirst;
  final bool isLast;

  @override
  State<_ChainOfThoughtToolStep> createState() =>
      _ChainOfThoughtToolStepState();
}

class _ChainOfThoughtToolStepState extends State<_ChainOfThoughtToolStep> {
  bool get _isAskUser => widget.part.toolName == LocalToolNames.askUser;
  bool? _askUserExpanded;

  String? _cachedContent;
  Map<String, dynamic>? _cachedMetadata;
  String _cleanText = '';
  List<String> _imagePaths = const [];

  bool get _askUserAnswered =>
      widget.part.content?.trim().isNotEmpty == true && !widget.part.loading;

  @override
  void initState() {
    super.initState();
    _updateContentCache();
  }

  @override
  void didUpdateWidget(covariant _ChainOfThoughtToolStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasAnswered =
        oldWidget.part.content?.trim().isNotEmpty == true &&
        !oldWidget.part.loading;
    if (_isAskUser && !wasAnswered && _askUserAnswered) {
      _askUserExpanded = true;
    }
    if (oldWidget.part.content != widget.part.content ||
        oldWidget.part.metadata != widget.part.metadata) {
      _updateContentCache();
    }
  }

  void _updateContentCache() {
    final content = widget.part.content;
    final metadata = widget.part.metadata;
    if (content == _cachedContent && metadata == _cachedMetadata) return;
    _cachedContent = content;
    _cachedMetadata = metadata;
    final (cleanText, paths) = parseToolResultImages(
      content,
      metadata: metadata,
    );
    _cleanText = cleanText;
    _imagePaths = paths;
  }

  IconData _iconFor(String name, Map<String, dynamic> args) {
    return _toolIconFor(name, args);
  }

  String _titleFor(
    BuildContext context,
    String name,
    Map<String, dynamic> args, {
    required bool isResult,
  }) {
    return _toolTitleFor(context, name, args, isResult: isResult);
  }

  String _argsSummary(Map<String, dynamic> args) {
    if (args.isEmpty) return '';
    final entries = args.entries.take(2).map((entry) {
      final value = entry.value?.toString() ?? '';
      final truncated = value.length > 40
          ? '${value.substring(0, 40)}...'
          : value;
      return '${entry.key}: $truncated';
    });
    final suffix = args.length > 2 ? ' ...' : '';
    return entries.join(', ') + suffix;
  }

  void _showDenyDialog(
    BuildContext context,
    ToolApprovalService approvalService,
    String toolCallId, {
    String? conversationId,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final reasonCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.toolApprovalDenyTitle),
        content: TextField(
          controller: reasonCtrl,
          decoration: InputDecoration(hintText: l10n.toolApprovalDenyHint),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () {
              final reason = reasonCtrl.text.trim().isEmpty
                  ? null
                  : reasonCtrl.text.trim();
              approvalService.deny(
                toolCallId,
                reason: reason,
                conversationId: conversationId,
              );
              Navigator.of(ctx).pop();
            },
            child: Text(l10n.toolApprovalDeny),
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context) {
    _showToolDetail(context, widget.part);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = _chatSurfaceForegroundPalette(context);
    final showToolResultSummary = context.select<SettingsProvider, bool>(
      (s) => s.showToolResultSummary,
    );
    final hideToolResultImages = context.select<SettingsProvider, bool>(
      (s) => s.hideToolResultImages,
    );
    final approvalService = context.read<ToolApprovalService>();
    final pendingRequest = context
        .select<ToolApprovalService, ToolApprovalRequest?>(
          (approval) => _matchingApprovalRequest(
            approval: approval,
            conversationId: widget.conversationId,
            toolCallId: widget.part.id,
          ),
        );
    final isPendingApproval = pendingRequest != null;
    final approvalRequest = pendingRequest;

    final icon = _isAskUser
        ? Icon(
            _iconFor(widget.part.toolName, widget.part.arguments),
            size: 16,
            color: fg.strong,
          )
        : widget.part.loading && !isPendingApproval
        ? LoadingIndicator(height: 12, dotSize: 3, spacing: 2, color: fg.strong)
        : Icon(
            _iconFor(widget.part.toolName, widget.part.arguments),
            size: 16,
            color: fg.strong,
          );

    final title = _titleFor(
      context,
      widget.part.toolName,
      widget.part.arguments,
      isResult: !widget.part.loading && !isPendingApproval,
    );
    final label = ThinkingSheen(
      enabled: widget.part.loading && !_isAskUser,
      color: fg.strong,
      child: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: AppFontWeights.semibold,
          color: fg.strong,
        ),
      ),
    );

    final cleanText = _cleanText;
    final imagePaths = _imagePaths;
    final screenTimeResult = widget.part.toolName == LocalToolNames.screenTime
        ? ScreenTimeResult.tryParse(cleanText)
        : null;
    final String summaryText = approvalRequest != null
        ? _argsSummary(approvalRequest.arguments)
        : cleanText.isNotEmpty
        ? cleanText
        : ((widget.part.arguments['query'] ??
                      widget.part.arguments['url'] ??
                      widget.part.arguments['text']) ??
                  '')
              .toString();
    final bool shouldShowSummary = showToolResultSummary;
    final askUserExpanded = _askUserExpanded ?? true;
    final ttsText = widget.part.toolName == LocalToolNames.textToSpeech
        ? _textToSpeechToolText(widget.part.arguments)
        : '';
    final Widget? summaryContent = _isAskUser
        ? _AskUserInlineBody(part: widget.part, compact: true)
        : ttsText.isNotEmpty
        ? _buildTextToSpeechReplayRow(
            context,
            text: ttsText,
            textColor: fg.body,
            buttonColor: fg.accent,
          )
        : screenTimeResult != null &&
              (screenTimeResult.isNoPermission || screenTimeResult.hasApps)
        ? ScreenTimeToolSummary(
            result: screenTimeResult,
            textColor: fg.body,
            secondaryColor: fg.muted,
            errorColor: cs.error,
          )
        : !shouldShowSummary || summaryText.trim().isEmpty
        ? null
        : Text(
            summaryText.trim(),
            maxLines: isPendingApproval ? 2 : 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              fontFamily: isPendingApproval ? 'monospace' : null,
              color: fg.body,
            ),
          );
    final Widget? imageThumbnails =
        (!_isAskUser && !hideToolResultImages && imagePaths.isNotEmpty)
        ? SizedBox(
            key: ValueKey('tool-image-thumbnails:${widget.part.id}'),
            height: kToolImageTimelineHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: imagePaths.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final path = imagePaths[i];
                return GestureDetector(
                  onTap: () => _showToolFullImage(context, path),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildToolImageFromPath(
                      context,
                      path,
                      height: kToolImageTimelineHeight,
                      maxLogicalWidth: kToolImageTimelineMaxWidth,
                    ),
                  ),
                );
              },
            ),
          )
        : null;
    final Widget? content = (summaryContent == null && imageThumbnails == null)
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (summaryContent != null) summaryContent,
              if (summaryContent != null && imageThumbnails != null)
                const SizedBox(height: 8),
              if (imageThumbnails != null) imageThumbnails,
            ],
          );

    final extra = approvalRequest != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IosIconButton(
                size: 14,
                padding: const EdgeInsets.all(7),
                color: cs.error,
                semanticLabel: AppLocalizations.of(context)!.toolApprovalDeny,
                builder: (color) => Icon(Lucide.X, size: 14, color: color),
                onTap: () => _showDenyDialog(
                  context,
                  approvalService,
                  approvalRequest.toolCallId,
                  conversationId: approvalRequest.conversationId,
                ),
              ),
              const SizedBox(width: 6),
              IosIconButton(
                size: 14,
                padding: const EdgeInsets.all(7),
                color: fg.accent,
                semanticLabel: AppLocalizations.of(
                  context,
                )!.toolApprovalApprove,
                builder: (color) => Icon(Lucide.Check, size: 14, color: color),
                onTap: () => approvalService.approve(
                  approvalRequest.toolCallId,
                  conversationId: approvalRequest.conversationId,
                ),
              ),
            ],
          )
        : null;

    return _TimelineStepShell(
      icon: icon,
      label: label,
      isFirst: widget.isFirst,
      isLast: widget.isLast,
      onTap: _isAskUser
          ? () => setState(() => _askUserExpanded = !askUserExpanded)
          : () => _showDetail(context),
      extra: extra,
      indicator: _isAskUser
          ? Icon(
              askUserExpanded ? Lucide.ChevronUp : Lucide.ChevronDown,
              size: 16,
              color: fg.muted,
            )
          : Icon(Lucide.ChevronRight, size: 16, color: fg.muted),
      content: content,
      contentVisible: content != null && (!_isAskUser || askUserExpanded),
      expectContent:
          widget.part.loading ||
          isPendingApproval ||
          _isAskUser ||
          content != null,
    );
  }
}

class _ToolCallItem extends StatefulWidget {
  const _ToolCallItem({required this.part, required this.conversationId});
  final ToolUIPart part;
  final String conversationId;

  @override
  State<_ToolCallItem> createState() => _ToolCallItemState();
}

class _ToolCallItemState extends State<_ToolCallItem> {
  // Cache image paths (local file or URL)
  List<String> _imagePaths = const [];
  String? _lastContent;
  Map<String, dynamic>? _lastMetadata;

  void _updateImageCache() {
    final content = widget.part.content;
    final metadata = widget.part.metadata;
    if (content == _lastContent && metadata == _lastMetadata) return;
    _lastContent = content;
    _lastMetadata = metadata;

    final (_, paths) = parseToolResultImages(content, metadata: metadata);
    _imagePaths = paths;
  }

  /// Build image widget from path (http(s), data URI, or local file).
  Widget _buildImageFromPath(
    String path, {
    double? height,
    BoxFit fit = BoxFit.contain,
  }) {
    return _buildResolvedImage(
      context,
      path,
      height: height,
      maxLogicalWidth: kToolImageCardMaxWidth,
      fit: fit,
    );
  }

  @override
  void initState() {
    super.initState();
    _updateImageCache();
  }

  @override
  void didUpdateWidget(covariant _ToolCallItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.part.content != widget.part.content ||
        oldWidget.part.metadata != widget.part.metadata) {
      _updateImageCache();
    }
  }

  IconData _iconFor(String name, Map<String, dynamic> args) {
    return _toolIconFor(name, args);
  }

  String _titleFor(
    BuildContext context,
    String name,
    Map<String, dynamic> args, {
    required bool isResult,
  }) {
    return _toolTitleFor(context, name, args, isResult: isResult);
  }

  /// Build a short argument summary for display in the approval card.
  String _argsSummary(Map<String, dynamic> args) {
    if (args.isEmpty) return '';
    // Show first 1-2 key=value pairs, truncated
    final entries = args.entries.take(2).map((e) {
      final v = e.value?.toString() ?? '';
      final truncated = v.length > 40 ? '${v.substring(0, 40)}...' : v;
      return '${e.key}: $truncated';
    });
    final suffix = args.length > 2 ? ' ...' : '';
    return entries.join(', ') + suffix;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = _chatSurfaceForegroundPalette(context);
    final hideToolResultImages = context.select<SettingsProvider, bool>(
      (s) => s.hideToolResultImages,
    );
    final hasImages = !hideToolResultImages && _imagePaths.isNotEmpty;
    final l10n = AppLocalizations.of(context)!;
    final ttsText = widget.part.toolName == LocalToolNames.textToSpeech
        ? _textToSpeechToolText(widget.part.arguments)
        : '';

    if (widget.part.toolName == LocalToolNames.askUser) {
      return _AskUserToolCard(part: widget.part);
    }

    // Check if this tool call is pending approval
    final approvalService = context.watch<ToolApprovalService>();
    final pendingRequest = widget.part.loading
        ? _matchingApprovalRequest(
            approval: approvalService,
            conversationId: widget.conversationId,
            toolCallId: widget.part.id,
          )
        : null;
    final isPendingApproval = pendingRequest != null;
    final pendingToolCallId = pendingRequest?.toolCallId;

    return IosCardPress(
      borderRadius: BorderRadius.circular(16),
      baseColor: Colors.transparent,
      pressedScale: 1.0,
      duration: const Duration(milliseconds: 260),
      onTap: isPendingApproval ? null : () => _showDetail(context),
      padding: EdgeInsets.zero,
      child: _buildSharedChatSurface(
        context,
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        defaultColor: cs.primaryContainer.withValues(
          alpha: isDark ? 0.25 : 0.30,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon — approval pending / loading spinner / result icon
                if (isPendingApproval)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: Center(
                      child: Icon(Lucide.Shield, size: 18, color: fg.accent),
                    ),
                  )
                else if (widget.part.loading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(fg.accent),
                    ),
                  )
                else
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: Center(
                      child: Icon(
                        _iconFor(widget.part.toolName, widget.part.arguments),
                        size: 18,
                        color: fg.strong,
                      ),
                    ),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title: always show tool name; add "waiting" badge when pending
                      ThinkingSheen(
                        enabled: widget.part.loading && !isPendingApproval,
                        color: fg.strong,
                        child: Text(
                          _titleFor(
                            context,
                            widget.part.toolName,
                            widget.part.arguments,
                            isResult:
                                !widget.part.loading && !isPendingApproval,
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: AppFontWeights.emphasis,
                            color: isPendingApproval ? fg.accent : fg.strong,
                          ),
                        ),
                      ),
                      // "Waiting for approval" subtitle
                      if (isPendingApproval) ...[
                        const SizedBox(height: 2),
                        Text(
                          l10n.toolApprovalPending,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: AppFontWeights.medium,
                            color: fg.medium,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (ttsText.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildTextToSpeechReplayRow(
                context,
                text: ttsText,
                textColor: fg.body,
                buttonColor: fg.accent,
              ),
            ],
            if (!widget.part.loading &&
                !isPendingApproval &&
                widget.part.toolName == LocalToolNames.screenTime) ...[
              Builder(
                builder: (context) {
                  final screenTime = ScreenTimeResult.tryParse(
                    widget.part.content,
                  );
                  if (screenTime == null ||
                      (!screenTime.isNoPermission && !screenTime.hasApps)) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ScreenTimeToolSummary(
                      result: screenTime,
                      textColor: fg.body,
                      secondaryColor: fg.muted,
                      errorColor: cs.error,
                    ),
                  );
                },
              ),
            ],
            // Argument summary so users know what the tool is about to do
            if (isPendingApproval && widget.part.arguments.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: isDark ? 0.06 : 0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _argsSummary(widget.part.arguments),
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: fg.body,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            // Approval action buttons
            if (isPendingApproval && pendingToolCallId != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ApprovalButton(
                      label: l10n.toolApprovalDeny,
                      color: cs.error,
                      filled: false,
                      onTap: () => _showDenyDialog(
                        context,
                        approvalService,
                        pendingToolCallId,
                        conversationId: pendingRequest.conversationId,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ApprovalButton(
                      label: l10n.toolApprovalApprove,
                      color: fg.accent,
                      filled: true,
                      onTap: () => approvalService.approve(
                        pendingToolCallId,
                        conversationId: pendingRequest.conversationId,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            // Show image thumbnails if available
            if (hasImages) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: kToolImageCardHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _imagePaths.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final path = _imagePaths[i];
                    return GestureDetector(
                      onTap: () => _showFullImage(context, path),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildImageFromPath(
                          path,
                          height: kToolImageCardHeight,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDenyDialog(
    BuildContext context,
    ToolApprovalService approvalService,
    String toolCallId, {
    String? conversationId,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final reasonCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.toolApprovalDenyTitle),
        content: TextField(
          controller: reasonCtrl,
          decoration: InputDecoration(hintText: l10n.toolApprovalDenyHint),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () {
              final reason = reasonCtrl.text.trim().isEmpty
                  ? null
                  : reasonCtrl.text.trim();
              approvalService.deny(
                toolCallId,
                reason: reason,
                conversationId: conversationId,
              );
              Navigator.of(ctx).pop();
            },
            child: Text(l10n.toolApprovalDeny),
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context) {
    _showToolDetail(context, widget.part);
  }

  /// Show full-size image using ImageViewerPage for save/share/copy support.
  /// [path] can be a local file path or HTTP URL.
  void _showFullImage(BuildContext context, String path) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        pageBuilder: (_, __, ___) => ImageViewerPage(images: [path]),
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        transitionsBuilder: (context, anim, sec, child) {
          final curved = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.02),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }
}

class _AskUserToolCard extends StatefulWidget {
  const _AskUserToolCard({required this.part});

  final ToolUIPart part;

  @override
  State<_AskUserToolCard> createState() => _AskUserToolCardState();
}

class _AskUserToolCardState extends State<_AskUserToolCard> {
  bool? _expanded;

  bool get _answered =>
      widget.part.content?.trim().isNotEmpty == true && !widget.part.loading;

  @override
  void didUpdateWidget(covariant _AskUserToolCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasAnswered =
        oldWidget.part.content?.trim().isNotEmpty == true &&
        !oldWidget.part.loading;
    if (!wasAnswered && _answered) {
      _expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = _chatSurfaceForegroundPalette(context);
    final l10n = AppLocalizations.of(context)!;
    final expanded = _expanded ?? true;
    return _buildSharedChatSurface(
      context,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      defaultColor: cs.primaryContainer.withValues(alpha: isDark ? 0.25 : 0.30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IosCardPress(
            onTap: () => setState(() => _expanded = !expanded),
            borderRadius: BorderRadius.circular(10),
            baseColor: Colors.transparent,
            pressedScale: 1,
            padding: EdgeInsets.zero,
            child: Row(
              children: [
                Icon(
                  Lucide.MessageCircleQuestionMark,
                  size: 18,
                  color: fg.strong,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _askUserToolTitleFor(l10n, widget.part.arguments),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: AppFontWeights.emphasis,
                      color: fg.strong,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_answered) ...[
                  Text(
                    l10n.askUserCardAnswered,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: AppFontWeights.emphasis,
                      color: fg.muted,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(
                  expanded ? Lucide.ChevronUp : Lucide.ChevronDown,
                  size: 16,
                  color: fg.muted,
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topLeft,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _AskUserInlineBody(part: widget.part),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _AskUserInlineBody extends StatefulWidget {
  const _AskUserInlineBody({required this.part, this.compact = false});

  final ToolUIPart part;
  final bool compact;

  @override
  State<_AskUserInlineBody> createState() => _AskUserInlineBodyState();
}

class _AskUserInlineBodyState extends State<_AskUserInlineBody> {
  final Map<String, String> _singleAnswers = <String, String>{};
  final Map<String, Set<String>> _multiAnswers = <String, Set<String>>{};
  final Map<String, TextEditingController> _textControllers =
      <String, TextEditingController>{};
  final Set<String> _skippedQuestions = <String>{};
  bool _submittingRecovered = false;

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String id) {
    return _textControllers.putIfAbsent(id, TextEditingController.new);
  }

  bool _hasAnswer(AskUserQuestion question) {
    if (_skippedQuestions.contains(question.id)) return true;
    final textValue = _controllerFor(question.id).text.trim();
    if (textValue.isNotEmpty) return true;
    return switch (question.kind) {
      AskUserQuestionKind.single =>
        (_singleAnswers[question.id] ?? '').trim().isNotEmpty,
      AskUserQuestionKind.multi =>
        (_multiAnswers[question.id] ?? const <String>{}).isNotEmpty,
    };
  }

  bool _canSubmit(List<AskUserQuestion> questions) {
    return questions.isNotEmpty && questions.every(_hasAnswer);
  }

  Map<String, AskUserAnswerValue> _buildAnswers(
    List<AskUserQuestion> questions,
  ) {
    final out = <String, AskUserAnswerValue>{};
    for (final question in questions) {
      if (_skippedQuestions.contains(question.id)) {
        out[question.id] = AskUserAnswerValue.skipped(kind: question.kind);
        continue;
      }
      final textValue = _controllerFor(question.id).text.trim();
      switch (question.kind) {
        case AskUserQuestionKind.single:
          final selected = _singleAnswers[question.id] ?? '';
          if (textValue.isNotEmpty && textValue != selected) {
            out[question.id] = AskUserAnswerValue.single(
              value: textValue,
              custom: true,
            );
            break;
          }
          out[question.id] = AskUserAnswerValue.single(
            value: selected,
            custom: false,
          );
          break;
        case AskUserQuestionKind.multi:
          final selectedValues =
              (_multiAnswers[question.id] ?? const <String>{}).toList();
          if (textValue.isNotEmpty && !selectedValues.contains(textValue)) {
            selectedValues.add(textValue);
            out[question.id] = AskUserAnswerValue.multi(
              value: selectedValues,
              custom: true,
            );
            break;
          }
          out[question.id] = AskUserAnswerValue.multi(
            value: selectedValues,
            custom: false,
          );
          break;
      }
    }
    return out;
  }

  String _answerLabel(
    BuildContext context,
    AskUserQuestion question,
    Map<dynamic, dynamic> answers,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final raw = answers[question.id];
    if (raw is! Map) return '';
    if (raw['skipped'] == true) return l10n.askUserCardSkipped;
    final value = raw['value'];
    if (value is List) {
      return value.map((item) => item.toString()).join(', ');
    }
    return value?.toString() ?? '';
  }

  Map<dynamic, dynamic> _answeredValues(String content) {
    try {
      final payload = jsonDecode(content) as Map<String, dynamic>;
      final answers = payload['answers'];
      if (answers is Map) return answers;
    } catch (_) {}
    return const <dynamic, dynamic>{};
  }

  void _clearSkip(String questionId) {
    _skippedQuestions.remove(questionId);
  }

  Future<void> _submitAnswers(
    AskUserInteractionService askUserService,
    List<AskUserQuestion> questions,
    AskUserRequest? pendingRequest,
  ) async {
    final answers = _buildAnswers(questions);
    if (pendingRequest != null) {
      askUserService.answer(widget.part.id, answers);
      return;
    }

    final action = _RecoveredAskUserAction.maybeOf(context);
    final onRecoveredAnswer = action?.onSubmit;
    if (onRecoveredAnswer == null || _submittingRecovered) return;
    final partId = widget.part.id;
    final conversationId = action!.conversationId;
    setState(() => _submittingRecovered = true);
    try {
      await onRecoveredAnswer(widget.part, AskUserResult.answer(answers));
    } finally {
      if (mounted) {
        final current = _RecoveredAskUserAction.maybeOf(context);
        if (widget.part.id == partId &&
            current?.conversationId == conversationId) {
          setState(() => _submittingRecovered = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = _chatSurfaceForegroundPalette(context);
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final askUserService = context.watch<AskUserInteractionService>();
    final pendingRequest = askUserService.pendingRequests[widget.part.id];
    final storedQuestions = AskUserInteractionService.normalizeQuestions(
      widget.part.arguments,
    );
    final questions = pendingRequest?.questions ?? storedQuestions;
    final answered = widget.part.content?.trim().isNotEmpty == true;
    final invalid = questions.isEmpty && !answered;
    final answeredValues = answered
        ? _answeredValues(widget.part.content ?? '')
        : const <dynamic, dynamic>{};

    final children = <Widget>[
      if (invalid)
        Text(
          l10n.askUserCardInactive,
          style: TextStyle(fontSize: 12, height: 1.35, color: fg.body),
        )
      else if (answered)
        for (final question in questions) ...[
          _AskUserAnsweredQuestion(
            question: question,
            answer: _answerLabel(context, question, answeredValues),
          ),
          if (question != questions.last) const SizedBox(height: 10),
        ]
      else ...[
        for (final question in questions) ...[
          _AskUserQuestionView(
            question: question,
            selectedSingle: _singleAnswers[question.id],
            selectedMulti: _multiAnswers[question.id] ?? const <String>{},
            textController: _controllerFor(question.id),
            skipped: _skippedQuestions.contains(question.id),
            showQuestionText: true,
            onOtherChanged: (value) {
              setState(() {
                _clearSkip(question.id);
                if (question.kind == AskUserQuestionKind.single &&
                    value.trim().isNotEmpty) {
                  _singleAnswers.remove(question.id);
                }
              });
            },
            onSelectSingle: (value) {
              setState(() {
                _clearSkip(question.id);
                _singleAnswers[question.id] = value;
                _controllerFor(question.id).clear();
              });
            },
            onToggleMulti: (value) {
              setState(() {
                _clearSkip(question.id);
                final set = _multiAnswers[question.id]?.toSet() ?? <String>{};
                if (set.contains(value)) {
                  set.remove(value);
                } else {
                  set.add(value);
                }
                _multiAnswers[question.id] = set;
              });
            },
            onToggleSkip: () {
              setState(() {
                if (_skippedQuestions.contains(question.id)) {
                  _skippedQuestions.remove(question.id);
                } else {
                  _singleAnswers.remove(question.id);
                  _multiAnswers.remove(question.id);
                  _controllerFor(question.id).clear();
                  _skippedQuestions.add(question.id);
                }
              });
            },
          ),
          const SizedBox(height: 12),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: _AskUserSubmitButton(
            label: l10n.askUserCardSubmit,
            color: cs.primary,
            onTap:
                _canSubmit(questions) &&
                    !_submittingRecovered &&
                    (pendingRequest != null ||
                        _RecoveredAskUserAction.maybeOf(context)?.onSubmit !=
                            null)
                ? () =>
                      _submitAnswers(askUserService, questions, pendingRequest)
                : null,
          ),
        ),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _AskUserQuestionView extends StatelessWidget {
  const _AskUserQuestionView({
    required this.question,
    required this.selectedSingle,
    required this.selectedMulti,
    required this.textController,
    required this.skipped,
    required this.showQuestionText,
    required this.onOtherChanged,
    required this.onSelectSingle,
    required this.onToggleMulti,
    required this.onToggleSkip,
  });

  final AskUserQuestion question;
  final String? selectedSingle;
  final Set<String> selectedMulti;
  final TextEditingController textController;
  final bool skipped;
  final bool showQuestionText;
  final ValueChanged<String> onOtherChanged;
  final ValueChanged<String> onSelectSingle;
  final ValueChanged<String> onToggleMulti;
  final VoidCallback onToggleSkip;

  @override
  Widget build(BuildContext context) {
    final fg = _chatSurfaceForegroundPalette(context);
    final isMulti = question.kind == AskUserQuestionKind.multi;
    final questionText = Text(
      question.question,
      style: TextStyle(fontSize: 13, height: 1.35, color: fg.body),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: showQuestionText ? questionText : const SizedBox()),
            const SizedBox(width: 8),
            _AskUserSkipPill(selected: skipped, onTap: onToggleSkip),
          ],
        ),
        const SizedBox(height: 8),
        if (question.options.isNotEmpty) ...[
          for (final entry in question.options.asMap().entries) ...[
            _AskUserOptionRow(
              index: entry.key + 1,
              label: entry.value,
              multi: isMulti,
              selected: isMulti
                  ? selectedMulti.contains(entry.value)
                  : selectedSingle == entry.value,
              disabled: skipped,
              onTap: () => isMulti
                  ? onToggleMulti(entry.value)
                  : onSelectSingle(entry.value),
            ),
            const SizedBox(height: 7),
          ],
        ],
        _AskUserOtherRow(
          index: question.options.length + 1,
          multi: isMulti,
          selected: textController.text.trim().isNotEmpty,
          controller: textController,
          disabled: skipped,
          onChanged: onOtherChanged,
        ),
      ],
    );
  }
}

class _AskUserAnsweredQuestion extends StatelessWidget {
  const _AskUserAnsweredQuestion({
    required this.question,
    required this.answer,
  });

  final AskUserQuestion question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = _chatSurfaceForegroundPalette(context);
    final displayAnswer = answer.trim().isEmpty
        ? AppLocalizations.of(context)!.askUserCardSkipped
        : answer.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.question,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: fg.body,
              fontWeight: AppFontWeights.semibold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            displayAnswer,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: cs.primary.withValues(alpha: 0.86),
              fontWeight: AppFontWeights.semibold,
            ),
          ),
        ],
      ),
    );
  }
}

class _AskUserOptionRow extends StatelessWidget {
  const _AskUserOptionRow({
    required this.index,
    required this.label,
    required this.multi,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final int index;
  final String label;
  final bool multi;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = _chatSurfaceForegroundPalette(context);
    final bg = selected
        ? cs.primary.withValues(alpha: 0.09)
        : Colors.transparent;
    return IosCardPress(
      borderRadius: BorderRadius.circular(14),
      baseColor: bg,
      pressedScale: disabled ? 1 : 0.995,
      padding: EdgeInsets.zero,
      onTap: disabled ? null : onTap,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: bg,
        ),
        child: Row(
          children: [
            if (multi)
              IosCheckbox(
                value: selected,
                onChanged: disabled ? null : (_) => onTap(),
                size: 18,
                hitTestSize: 24,
                activeColor: cs.primary,
                semanticLabel: label,
              )
            else
              _AskUserIndexBadge(index: index, selected: selected),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.25,
                  fontWeight: AppFontWeights.medium,
                  color: selected ? cs.primary : fg.strong,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AskUserOtherRow extends StatelessWidget {
  const _AskUserOtherRow({
    required this.index,
    required this.multi,
    required this.selected,
    required this.controller,
    required this.disabled,
    required this.onChanged,
  });

  final int index;
  final bool multi;
  final bool selected;
  final TextEditingController controller;
  final bool disabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = _chatSurfaceForegroundPalette(context);
    final l10n = AppLocalizations.of(context)!;
    final effectiveSelected = selected;
    final bg = effectiveSelected
        ? cs.primary.withValues(alpha: 0.09)
        : Colors.transparent;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (multi)
            IgnorePointer(
              child: IosCheckbox(
                value: effectiveSelected,
                onChanged: disabled ? null : (_) {},
                size: 18,
                hitTestSize: 24,
                activeColor: cs.primary,
                semanticLabel: l10n.askUserCardSomethingElse,
              ),
            )
          else
            _AskUserIndexBadge(index: index, selected: effectiveSelected),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              enabled: !disabled,
              controller: controller,
              minLines: 1,
              maxLines: 2,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: l10n.askUserCardCustomHint,
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: TextStyle(fontSize: 13, height: 1.25, color: fg.strong),
            ),
          ),
        ],
      ),
    );
  }
}

class _AskUserIndexBadge extends StatelessWidget {
  const _AskUserIndexBadge({required this.index, required this.selected});

  final int index;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = _chatSurfaceForegroundPalette(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected
            ? cs.primary.withValues(alpha: 0.13)
            : cs.onSurface.withValues(alpha: isDark ? 0.08 : 0.05),
        border: Border.all(
          color: selected
              ? cs.primary.withValues(alpha: 0.28)
              : cs.onSurface.withValues(alpha: isDark ? 0.10 : 0.07),
        ),
      ),
      child: Text(
        '$index',
        style: TextStyle(
          fontSize: 11,
          fontWeight: AppFontWeights.emphasis,
          color: selected ? cs.primary : fg.muted,
        ),
      ),
    );
  }
}

class _AskUserSkipPill extends StatelessWidget {
  const _AskUserSkipPill({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = _chatSurfaceForegroundPalette(context);
    final l10n = AppLocalizations.of(context)!;
    return IosCardPress(
      borderRadius: BorderRadius.circular(7),
      baseColor: Colors.transparent,
      pressedScale: 0.98,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(
          l10n.askUserCardSkip,
          style: TextStyle(
            fontSize: 11,
            fontWeight: AppFontWeights.semibold,
            color: selected ? cs.primary.withValues(alpha: 0.78) : fg.muted,
          ),
        ),
      ),
    );
  }
}

class _AskUserSubmitButton extends StatelessWidget {
  const _AskUserSubmitButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final cs = Theme.of(context).colorScheme;
    return IosCardPress(
      borderRadius: BorderRadius.circular(14),
      baseColor: enabled
          ? color.withValues(alpha: 0.86)
          : cs.surfaceContainerHighest.withValues(alpha: 0.45),
      pressedScale: enabled ? 0.985 : 1,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Lucide.ArrowUp,
              size: 15,
              color: enabled
                  ? cs.onPrimary
                  : cs.onSurface.withValues(alpha: 0.38),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: AppFontWeights.heavy,
                color: enabled
                    ? cs.onPrimary
                    : cs.onSurface.withValues(alpha: 0.38),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tactile button for tool approval actions (approve / deny).
class _ApprovalButton extends StatelessWidget {
  const _ApprovalButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;

  /// When true, uses a solid fill background; when false, outline style.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled
              ? color.withValues(alpha: isDark ? 0.25 : 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withValues(alpha: filled ? 0.5 : 0.35),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: AppFontWeights.semibold,
            color: enabled ? color : color.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}

class _SourcesSummaryCard extends StatelessWidget {
  const _SourcesSummaryCard({
    required this.count,
    required this.items,
    required this.onTap,
  });

  final int count;
  final List<Map<String, dynamic>> items;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final label = l10n.chatMessageWidgetCitationsCount(count);
    final isDark = theme.brightness == Brightness.dark;

    return IosCardPress(
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: cs.onSurface.withValues(alpha: isDark ? 0.16 : 0.10),
        width: 0.8,
      ),
      baseColor: Colors.transparent,
      pressedScale: 1.0,
      duration: const Duration(milliseconds: 260),
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 18),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SourceFaviconStack(items: items),
            const SizedBox(width: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontSize: 12,
                height: 1,
                fontWeight: AppFontWeights.semibold,
                color: cs.onSurface.withValues(alpha: isDark ? 0.90 : 0.86),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceFaviconStack extends StatelessWidget {
  const _SourceFaviconStack({required this.items});

  final List<Map<String, dynamic>> items;

  static const double _iconSize = 16;
  static const double _slotSize = 18;
  static const double _overlapStep = 11;
  static const int _maxIcons = 3;

  @override
  Widget build(BuildContext context) {
    final domains = _domains();
    if (domains.isEmpty) {
      return const _SourceFaviconFallback(size: _slotSize);
    }

    return SizedBox(
      width: _slotSize + (domains.length - 1) * _overlapStep,
      height: _slotSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < domains.length; i++)
            PositionedDirectional(
              start: i * _overlapStep,
              top: 1,
              child: _SourceFavicon(domain: domains[i]),
            ),
        ],
      ),
    );
  }

  List<String> _domains() {
    final seen = <String>{};
    final domains = <String>[];
    for (final item in items) {
      final url = (item['url'] ?? '').toString();
      final host = _tryNormalizeExternalUri(url)?.host ?? '';
      if (host.isEmpty || !seen.add(host)) {
        continue;
      }
      domains.add(host);
      if (domains.length == _maxIcons) {
        break;
      }
    }
    return domains;
  }
}

class _SourceFavicon extends StatelessWidget {
  const _SourceFavicon({required this.domain});

  final String domain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = cs.onSurface.withValues(alpha: isDark ? 0.14 : 0.06);

    return Container(
      width: _SourceFaviconStack._iconSize,
      height: _SourceFaviconStack._iconSize,
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : cs.surface,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        'https://favicone.com/$domain',
        width: _SourceFaviconStack._iconSize,
        height: _SourceFaviconStack._iconSize,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const _SourceFaviconFallback(size: _SourceFaviconStack._iconSize),
      ),
    );
  }
}

class _SourceFaviconFallback extends StatelessWidget {
  const _SourceFaviconFallback({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: Icon(
        Lucide.Globe,
        size: size * 0.72,
        color: cs.onSurface.withValues(alpha: 0.52),
      ),
    );
  }
}

class _ReasoningSection extends StatefulWidget {
  const _ReasoningSection({
    required this.text,
    required this.expanded,
    required this.loading,
    required this.startAt,
    required this.finishedAt,
    // ignore: unused_element_parameter
    this.onToggle,
  });

  final String text;
  final bool expanded;
  final bool loading;
  final DateTime? startAt;
  final DateTime? finishedAt;
  final VoidCallback? onToggle;

  @override
  State<_ReasoningSection> createState() => _ReasoningSectionState();
}

class _ReasoningSectionState extends State<_ReasoningSection> {
  // Use ValueNotifier to only update elapsed time display, not rebuild entire widget
  final ValueNotifier<int> _elapsedTick = ValueNotifier<int>(0);
  Timer? _elapsedTimer;
  final ScrollController _scroll = ScrollController();
  bool _hasOverflow = false;

  String _sanitize(String s) {
    return s.replaceAll('\r', '').trim();
  }

  String _elapsed() {
    final start = widget.startAt;
    if (start == null) return '';
    final end = widget.finishedAt ?? (widget.loading ? DateTime.now() : start);
    final ms = end.difference(start).inMilliseconds;
    return '(${(ms / 1000).toStringAsFixed(1)}s)';
  }

  void _syncElapsedTimer() {
    if (widget.loading && widget.finishedAt == null) {
      _elapsedTimer ??= Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (mounted) _elapsedTick.value++;
      });
    } else {
      _elapsedTimer?.cancel();
      _elapsedTimer = null;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.loading) _syncElapsedTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOverflow();
      if (widget.loading && _scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _ReasoningSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncElapsedTimer();
    if (widget.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _elapsedTick.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _checkOverflow() {
    if (!_scroll.hasClients) return;
    final over = _scroll.position.maxScrollExtent > 0.5;
    if (over != _hasOverflow && mounted) setState(() => _hasOverflow = over);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = _chatSurfaceForegroundPalette(context);
    final l10n = AppLocalizations.of(context)!;
    final enableReasoningMarkdown = context.select<SettingsProvider, bool>(
      (s) => s.enableReasoningMarkdown,
    );
    final loading = widget.loading;

    // Android-like surface style
    final curve = const Cubic(0.2, 0.8, 0.2, 1);

    // Build a compact header with optional scrolling preview when loading
    Widget header = IosCardPress(
      borderRadius: BorderRadius.circular(12),
      baseColor: Colors.transparent,
      pressedScale: 1.0,
      duration: const Duration(milliseconds: 220),
      onTap: widget.onToggle,
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            ReasoningIcons.thinkingCardIcon(size: 18, color: fg.strong),
            const SizedBox(width: 8),
            ThinkingSheen(
              enabled: loading,
              color: fg.strong,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.chatMessageWidgetDeepThinking,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: AppFontWeights.emphasis,
                      color: fg.strong,
                    ),
                  ),
                  if (widget.startAt != null) ...[
                    const SizedBox(width: 8),
                    ValueListenableBuilder<int>(
                      valueListenable: _elapsedTick,
                      builder: (context, _, __) => Text(
                        _elapsed(),
                        style: TextStyle(fontSize: 13, color: fg.medium),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // No header marquee; content area handles scrolling when loading
            const Spacer(),
            AnimatedRotation(
              turns: widget.expanded ? 0.25 : 0.0, // right -> down
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOutCubic,
              child: Icon(Lucide.ChevronRight, size: 18, color: fg.strong),
            ),
          ],
        ),
      ),
    );

    // 抽公共样式，继承当前 DefaultTextStyle（从而继承正确的颜色）
    final TextStyle baseStyle = DefaultTextStyle.of(
      context,
    ).style.copyWith(fontSize: 12.5, height: 1.32);

    const StrutStyle baseStrut = StrutStyle(
      forceStrutHeight: true,
      fontSize: 12.5,
      height: 1.32,
      leading: 0,
    );

    const TextHeightBehavior baseTHB = TextHeightBehavior(
      applyHeightToFirstAscent: false,
      applyHeightToLastDescent: false,
      leadingDistribution: TextLeadingDistribution.proportional,
    );

    final bool isLoading = loading;
    final display = _sanitize(widget.text);

    // 未加载：不要再指定 color: fg，让它继承和"加载中"相同的颜色
    Widget reasoningContent(String text) {
      if (enableReasoningMarkdown) {
        return RepaintBoundary(
          child: MarkdownWithCodeHighlight(
            text: text.isNotEmpty ? text : '…',
            baseStyle: baseStyle,
            streaming: isLoading,
          ),
        );
      }
      return Text(
        text.isNotEmpty ? text : '…',
        style: baseStyle,
        strutStyle: baseStrut,
        textHeightBehavior: baseTHB,
      );
    }

    Widget body = Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
      child: reasoningContent(display),
    );

    if (isLoading && !widget.expanded) {
      body = Padding(
        padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 80),
          child: _hasOverflow
              ? ShaderMask(
                  shaderCallback: (rect) {
                    final h = rect.height;
                    const double topFade = 12.0;
                    const double bottomFade = 28.0;
                    final double sTop = (topFade / h).clamp(0.0, 1.0);
                    final double sBot = (1.0 - bottomFade / h).clamp(0.0, 1.0);
                    return LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: const [
                        Color(
                          0x00FFFFFF,
                        ), // color-gate: ignore (dstIn alpha mask)
                        Color(
                          0xFFFFFFFF,
                        ), // color-gate: ignore (dstIn alpha mask)
                        Color(
                          0xFFFFFFFF,
                        ), // color-gate: ignore (dstIn alpha mask)
                        Color(
                          0x00FFFFFF,
                        ), // color-gate: ignore (dstIn alpha mask)
                      ],
                      stops: [0.0, sTop, sBot, 1.0],
                    ).createShader(rect);
                  },
                  blendMode: BlendMode.dstIn,
                  child: NotificationListener<ScrollUpdateNotification>(
                    onNotification: (_) {
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => _checkOverflow(),
                      );
                      return false;
                    },
                    child: SingleChildScrollView(
                      controller: _scroll,
                      physics: const BouncingScrollPhysics(),
                      child: reasoningContent(display),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  controller: _scroll,
                  physics: const NeverScrollableScrollPhysics(),
                  child: reasoningContent(display),
                ),
        ),
      );
    }

    // Enable long-press text selection in reasoning body
    body = SelectionArea(child: body);

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: curve,
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: double.infinity,
        child: _buildSharedChatSurface(
          context,
          borderRadius: BorderRadius.circular(16),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          defaultColor: cs.primaryContainer.withValues(
            alpha: isDark ? 0.25 : 0.30,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [header, if (widget.expanded || isLoading) body],
          ),
        ),
      ),
    );
  }
}
