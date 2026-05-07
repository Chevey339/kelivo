import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/services.dart';
import '../../../core/services/haptics.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:open_filex/open_filex.dart';
// import 'package:easy_image_viewer/easy_image_viewer.dart';
import 'dart:convert';
import '../../home/widgets/file_processing_indicator.dart';
import '../pages/image_viewer_page.dart';
import '../../../core/models/chat_message.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../icons/reasoning_icons.dart';
// import '../../../theme/design_tokens.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/providers/assistant_provider.dart';
import 'package:intl/intl.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../../utils/avatar_cache.dart';
import '../../../utils/assistant_regex.dart';
import '../../../core/models/assistant.dart';
import '../../../core/providers/tts_provider.dart';
import '../../../shared/widgets/markdown_with_highlight.dart';
import '../../../shared/widgets/snackbar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/model_provider.dart';
import '../../../core/models/assistant_regex.dart';
import '../../../shared/widgets/ios_checkbox.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../desktop/desktop_context_menu.dart';
import '../../../desktop/menu_anchor.dart';
import '../../../shared/widgets/emoji_text.dart';
import '../../home/services/ask_user_interaction_service.dart';
import '../../home/services/local_tools_service.dart';
import '../../home/services/tool_approval_service.dart';
import '../utils/thinking_tag_parser.dart';
import 'chat_suggestion_bubbles.dart';
import 'token_display_widget.dart';

final RegExp _urlSchemeRe = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:');

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

/// Extract image paths from tool result content.
/// Returns (cleanText, imagePaths). Supports local file paths and HTTP URLs.
(String, List<String>) _parseMcpImagePaths(String? content) {
  if (content == null || content.isEmpty) return ('', const []);

  final images = <String>[];
  final imgRe = RegExp(r'\[image:(.+?)\]');

  final cleanText = content.replaceAllMapped(imgRe, (m) {
    final path = m.group(1)!;
    // Filter invalid values
    if (path.isNotEmpty && path != 'generated') {
      images.add(path);
    }
    return '';
  });

  return (cleanText.trim(), images);
}

IconData _toolIconFor(String name) {
  final localIcon = _localToolIconFor(name);
  if (localIcon != null) return localIcon;
  switch (name) {
    case 'create_memory':
      return Lucide.bookHeart;
    case 'edit_memory':
      return Lucide.bookHeart;
    case 'delete_memory':
      return Lucide.bookDashed;
    case 'search_web':
      return Lucide.Earth;
    case 'builtin_search':
      return Lucide.Search;
    default:
      return Lucide.Wrench;
  }
}

IconData? _localToolIconFor(String name) {
  if (name == LocalToolNames.askUser) {
    return Lucide.MessageCircleQuestionMark;
  }
  return switch (name) {
    LocalToolNames.timeInfo => Lucide.Calendar,
    LocalToolNames.clipboard => Lucide.Clipboard,
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
    _ => null,
  };
}

String _askUserToolTitleFor(AppLocalizations l10n, Map<String, dynamic> args) {
  final questions = AskUserInteractionService.normalizeQuestions(args);
  if (questions.length == 1) return questions.first.question;
  if (questions.length > 1) {
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
    case 'create_memory':
      return l10n.chatMessageWidgetCreateMemory;
    case 'edit_memory':
      return l10n.chatMessageWidgetEditMemory;
    case 'delete_memory':
      return l10n.chatMessageWidgetDeleteMemory;
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
  BoxFit fit = BoxFit.contain,
}) {
  final cs = Theme.of(context).colorScheme;
  Widget errorWidget() => Container(
    width: height != null ? height * 0.67 : 120,
    height: height ?? 180,
    color: cs.surfaceContainerHighest,
    child: Icon(
      Lucide.ImageOff,
      size: 24,
      color: cs.onSurface.withValues(alpha: 0.5),
    ),
  );

  if (path.startsWith('http://') || path.startsWith('https://')) {
    return Image.network(
      path,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => errorWidget(),
    );
  }

  return Image.file(
    File(path),
    height: height,
    fit: fit,
    errorBuilder: (_, __, ___) => errorWidget(),
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
  final cs = Theme.of(context).colorScheme;
  final l10n = AppLocalizations.of(context)!;
  final argsPretty = const JsonEncoder.withIndent('  ').convert(part.arguments);
  final (cleanText, images) = _parseMcpImagePaths(part.content);
  final resultText = cleanText.isNotEmpty
      ? _prettyToolJson(cleanText)
      : l10n.chatMessageWidgetNoResultYet;

  final bool isDesktop =
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  if (isDesktop) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          elevation: 12,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 360,
              maxWidth: 560,
              maxHeight: 560,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Material(
                color: cs.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                      child: Row(
                        children: [
                          Icon(
                            _toolIconFor(part.toolName),
                            size: 18,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _toolTitleFor(
                                context,
                                part.toolName,
                                part.arguments,
                                isResult: !part.loading,
                              ),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Tooltip(
                            message: l10n.mcpPageClose,
                            child: IconButton(
                              icon: Icon(
                                Lucide.X,
                                size: 18,
                                color: cs.onSurface.withValues(alpha: 0.75),
                              ),
                              onPressed: () => Navigator.of(ctx).maybePop(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.chatMessageWidgetArguments,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white10
                                      : const Color(0xFFF7F7F9),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: cs.outlineVariant.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                ),
                                child: SelectableText(
                                  argsPretty,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                l10n.chatMessageWidgetResult,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white10
                                      : const Color(0xFFF7F7F9),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: cs.outlineVariant.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                ),
                                child: SelectableText(
                                  resultText,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              if (images.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  l10n.chatMessageWidgetImages,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: images.map((path) {
                                    return GestureDetector(
                                      onTap: () =>
                                          _showToolFullImage(context, path),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: _buildToolImageFromPath(
                                          context,
                                          path,
                                          height: 280,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
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
    );
    return;
  }

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
      return SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.6,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _toolIconFor(part.toolName),
                        size: 18,
                        color: cs.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _toolTitleFor(
                            context,
                            part.toolName,
                            part.arguments,
                            isResult: !part.loading,
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.chatMessageWidgetArguments,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white10
                          : const Color(0xFFF7F7F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.2),
                      ),
                    ),
                    child: SelectableText(
                      argsPretty,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.chatMessageWidgetResult,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white10
                          : const Color(0xFFF7F7F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.2),
                      ),
                    ),
                    child: SelectableText(
                      resultText,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  if (images.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.chatMessageWidgetImages,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 220,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: images.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (ctx, i) {
                          final path = images[i];
                          return GestureDetector(
                            onTap: () => _showToolFullImage(context, path),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _buildToolImageFromPath(
                                context,
                                path,
                                height: 220,
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
          ),
        ),
      );
    },
  );
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
  final int? versionIndex; // zero-based
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
  final List<String> suggestions;
  final ValueChanged<String>? onSuggestionTap;
  final Future<void> Function(ToolUIPart part, AskUserResult result)?
  onRecoveredAskUserAnswer;
  final bool canSubmitRecoveredAskUserAnswer;

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
    this.suggestions = const <String>[],
    this.onSuggestionTap,
    this.onRecoveredAskUserAnswer,
    this.canSubmitRecoveredAskUserAnswer = true,
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
  late final Ticker _ticker = Ticker((_) {
    if (mounted && _tickActive) {
      _reasoningTick.value++; // Only notify reasoning section, not full rebuild
    }
  });

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
      if (!_ticker.isActive) _ticker.start();
    } else {
      if (_ticker.isActive) _ticker.stop();
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
    return ThinkingTagParser.parseLegacyInlineBlocks(widget.message.content);
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
    _ticker.dispose();
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
      barrierColor: Colors.black.withValues(alpha: 0.08),
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
                            ? Colors.white.withValues(alpha: 0.08)
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
                          color: isDark
                              ? const Color(0xFF1C1C1E).withValues(alpha: 0.66)
                              : Colors.white.withValues(alpha: 0.66),
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
                              _MenuItem(
                                icon: Lucide.Pencil,
                                label: l10n.messageMoreSheetEdit,
                                onTap: () {
                                  Navigator.of(ctx).pop();
                                  (widget.onEdit ?? widget.onMore)?.call();
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

  Widget _buildUserAvatar(UserProvider userProvider, ColorScheme cs) {
    Widget avatarContent;

    if (userProvider.avatarType == 'emoji' &&
        userProvider.avatarValue != null) {
      final bool isIOS = defaultTargetPlatform == TargetPlatform.iOS;
      final double fs = 18;
      final Offset? nudge = isIOS ? Offset(fs * 0.065, fs * -0.05) : null;
      avatarContent = Center(
        child: EmojiText(
          userProvider.avatarValue!,
          fontSize: fs,
          optimizeEmojiAlign: true,
          nudge: nudge,
        ),
      );
    } else if (userProvider.avatarType == 'url' &&
        userProvider.avatarValue != null) {
      final url = userProvider.avatarValue!;
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
    } else if (userProvider.avatarType == 'file' &&
        userProvider.avatarValue != null) {
      final fixed = SandboxPathResolver.fix(userProvider.avatarValue!);
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
    try {
      final obj = jsonDecode(widget.message.content) as Map<String, dynamic>;
      toolName = (obj['tool'] ?? 'tool').toString();
      final a = obj['arguments'];
      if (a is Map<String, dynamic>) args = a;
      result = (obj['result'] ?? '').toString();
    } catch (_) {}

    final part = ToolUIPart(
      id: widget.message.id,
      toolName: toolName,
      arguments: args,
      content: result,
      loading: false,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: _ToolCallItem(
        part: part,
        onRecoveredAnswer: widget.onRecoveredAskUserAnswer,
        canSubmitRecoveredAnswer: widget.canSubmitRecoveredAskUserAnswer,
      ),
    );
  }

  Widget _buildUserMessage() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userProvider = context.watch<UserProvider>();
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final parsed = _parseUserContent(widget.message.content);
    final assistant = _assistantForMessage();
    final visualText = applyAssistantRegexes(
      parsed.text,
      assistant: assistant,
      scope: AssistantRegexScope.user,
      target: AssistantRegexTransformTarget.visual,
    );
    final showUserActions = settings.showUserMessageActions;
    final showVersionSwitcher = (widget.versionCount ?? 1) > 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Header: User info and avatar
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (settings.showUserName || settings.showUserTimestamp)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (settings.showUserName)
                      Text(
                        userProvider.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    if (settings.showUserName && settings.showUserTimestamp)
                      const SizedBox(height: 2),
                    if (settings.showUserTimestamp)
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
                _buildUserAvatar(userProvider, cs),
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
              child: _buildBubbleContainer(
                context: context,
                isUser: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (visualText.isNotEmpty)
                      Builder(
                        builder: (context) {
                          final bool isDesktop =
                              defaultTargetPlatform == TargetPlatform.macOS ||
                              defaultTargetPlatform == TargetPlatform.windows ||
                              defaultTargetPlatform == TargetPlatform.linux;
                          final double baseUser = isDesktop ? 14.0 : 15.5;

                          Widget content;
                          if (settings.enableUserMarkdown) {
                            content = DefaultTextStyle.merge(
                              style: TextStyle(
                                fontSize: baseUser,
                                height: 1.45,
                              ),
                              child: MarkdownWithCodeHighlight(
                                text: visualText,
                                baseStyle: TextStyle(
                                  fontSize: baseUser,
                                  height: 1.45,
                                ),
                              ),
                            );
                          } else {
                            content = Text(
                              visualText,
                              style: TextStyle(
                                fontSize:
                                    baseUser, // slightly smaller on desktop for readability
                                height: 1.4,
                                color: cs.onSurface,
                              ),
                            );
                          }

                          // Enable desktop selection/copy for user messages
                          return isDesktop
                              ? SelectionArea(
                                  key: ValueKey('user_${widget.message.id}'),
                                  child: content,
                                )
                              : content;
                        },
                      ),
                    if (parsed.images.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final imgs = parsed.images;
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: imgs.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final p = entry.value;
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      PageRouteBuilder(
                                        pageBuilder: (_, __, ___) =>
                                            ImageViewerPage(
                                              images: imgs,
                                              initialIndex: idx,
                                            ),
                                        transitionDuration: const Duration(
                                          milliseconds: 360,
                                        ),
                                        reverseTransitionDuration:
                                            const Duration(milliseconds: 280),
                                        transitionsBuilder:
                                            (context, anim, sec, child) {
                                              final curved = CurvedAnimation(
                                                parent: anim,
                                                curve: Curves.easeOutCubic,
                                                reverseCurve:
                                                    Curves.easeInCubic,
                                              );
                                              return FadeTransition(
                                                opacity: curved,
                                                child: SlideTransition(
                                                  position: Tween<Offset>(
                                                    begin: const Offset(
                                                      0,
                                                      0.02,
                                                    ), // subtle upward drift
                                                    end: Offset.zero,
                                                  ).animate(curved),
                                                  child: child,
                                                ),
                                              );
                                            },
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Hero(
                                      tag: 'img:$p',
                                      child: Image.file(
                                        File(SandboxPathResolver.fix(p)),
                                        width: 96,
                                        height: 96,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 96,
                                          height: 96,
                                          color: Colors.black12,
                                          child: const Icon(Icons.broken_image),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                    if (parsed.docs.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: parsed.docs.map((d) {
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              overlayColor: WidgetStateProperty.resolveWith(
                                (states) => cs.primary.withValues(
                                  alpha: states.contains(WidgetState.pressed)
                                      ? 0.14
                                      : 0.08,
                                ),
                              ),
                              splashColor: cs.primary.withValues(alpha: 0.18),
                              onTap: () async {
                                try {
                                  final fixed = SandboxPathResolver.fix(d.path);
                                  final f = File(fixed);
                                  if (!(await f.exists())) {
                                    if (!mounted) return;
                                    showAppSnackBar(
                                      context,
                                      message: l10n
                                          .chatMessageWidgetFileNotFound(
                                            d.fileName,
                                          ),
                                      type: NotificationType.error,
                                    );
                                    return;
                                  }
                                  final res = await OpenFilex.open(
                                    fixed,
                                    type: d.mime,
                                  );
                                  if (res.type != ResultType.done) {
                                    if (!mounted) return;
                                    final openMessage = res.message;
                                    showAppSnackBar(
                                      context,
                                      message: l10n
                                          .chatMessageWidgetCannotOpenFile(
                                            openMessage.isNotEmpty
                                                ? openMessage
                                                : res.type.toString(),
                                          ),
                                      type: NotificationType.error,
                                    );
                                  }
                                } catch (e) {
                                  if (!mounted) return;
                                  showAppSnackBar(
                                    context,
                                    message: l10n
                                        .chatMessageWidgetOpenFileError(
                                          e.toString(),
                                        ),
                                    type: NotificationType.error,
                                  );
                                }
                              },
                              child: Ink(
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white12 : cs.surface,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.insert_drive_file,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 180,
                                        ),
                                        child: Text(
                                          d.fileName,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
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
        DesktopContextMenuItem(
          icon: Lucide.Pencil,
          label: l10n.messageMoreSheetEdit,
          onTap: () => (widget.onEdit ?? widget.onMore)?.call(),
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

  _ParsedUserContent _parseUserContent(String raw) {
    final imgRe = RegExp(r"\[image:(.+?)\]");
    final fileRe = RegExp(r"\[file:(.+?)\|(.+?)\|(.+?)\]");
    final images = <String>[];
    final docs = <_DocRef>[];
    final buffer = StringBuffer();
    int idx = 0;
    while (idx < raw.length) {
      final m1 = imgRe.matchAsPrefix(raw, idx);
      final m2 = fileRe.matchAsPrefix(raw, idx);
      if (m1 != null) {
        final p = m1.group(1)?.trim();
        if (p != null && p.isNotEmpty) images.add(p);
        idx = m1.end;
        continue;
      }
      if (m2 != null) {
        final path = m2.group(1)?.trim() ?? '';
        final name = m2.group(2)?.trim() ?? 'file';
        final mime = m2.group(3)?.trim() ?? 'text/plain';
        docs.add(_DocRef(path: path, fileName: name, mime: mime));
        idx = m2.end;
        continue;
      }
      buffer.write(raw[idx]);
      idx++;
    }
    return _ParsedUserContent(buffer.toString().trim(), images, docs);
  }

  Widget _buildAssistantTextContent(
    BuildContext context,
    String visualContent,
    SettingsProvider settings,
  ) {
    final cs = Theme.of(context).colorScheme;
    final bool isDesktop =
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
    final double baseAssistant = isDesktop ? 14.0 : 15.7;

    Widget assistantContent;
    if (settings.enableAssistantMarkdown) {
      assistantContent = MarkdownWithCodeHighlight(
        text: visualContent,
        onCitationTap: (id) => _handleCitationTap(id),
        baseStyle: TextStyle(fontSize: baseAssistant, height: 1.5),
      );
    } else {
      assistantContent = Text(
        visualContent,
        style: TextStyle(
          fontSize: baseAssistant,
          height: 1.5,
          color: cs.onSurface,
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
          !reduceMotion &&
          visualContent.isNotEmpty,
      child: assistantContent,
    );

    return RepaintBoundary(
      child: SelectionArea(
        key: ValueKey('assistant_${widget.message.id}_$visualContent'),
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
    SettingsProvider settings,
  ) {
    return SizedBox(
      width: double.infinity,
      child: _buildAssistantBubbleContainer(
        context: context,
        child: _buildAssistantTextContent(context, visualContent, settings),
      ),
    );
  }

  List<_TimelineStepData> _buildTimelineSteps(
    List<ToolUIPart> visibleTools, {
    List<ReasoningSegment>? reasoningSegments,
  }) {
    final segments =
        reasoningSegments ??
        widget.reasoningSegments ??
        const <ReasoningSegment>[];
    if (segments.isEmpty) {
      int toolCount = 0;
      return visibleTools
          .map(
            (tool) => _TimelineStepData.tool(
              tool: tool,
              reasoningCountAfter: 0,
              toolCountAfter: ++toolCount,
            ),
          )
          .toList();
    }

    final steps = <_TimelineStepData>[];
    int reasoningCount = 0;
    int toolCount = 0;
    int toolIndex = 0;

    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final int segmentToolStart = segment.toolStartIndex.clamp(
        0,
        visibleTools.length,
      );
      while (toolIndex < segmentToolStart && toolIndex < visibleTools.length) {
        steps.add(
          _TimelineStepData.tool(
            tool: visibleTools[toolIndex],
            reasoningCountAfter: reasoningCount,
            toolCountAfter: ++toolCount,
          ),
        );
        toolIndex++;
      }

      if (segment.text.isNotEmpty) {
        steps.add(
          _TimelineStepData.reasoning(
            reasoning: segment,
            reasoningCountAfter: ++reasoningCount,
            toolCountAfter: toolCount,
          ),
        );
      }

      final int nextToolBoundary = i < segments.length - 1
          ? segments[i + 1].toolStartIndex.clamp(0, visibleTools.length)
          : visibleTools.length;
      while (toolIndex < nextToolBoundary && toolIndex < visibleTools.length) {
        steps.add(
          _TimelineStepData.tool(
            tool: visibleTools[toolIndex],
            reasoningCountAfter: reasoningCount,
            toolCountAfter: ++toolCount,
          ),
        );
        toolIndex++;
      }
    }

    while (toolIndex < visibleTools.length) {
      steps.add(
        _TimelineStepData.tool(
          tool: visibleTools[toolIndex],
          reasoningCountAfter: reasoningCount,
          toolCountAfter: ++toolCount,
        ),
      );
      toolIndex++;
    }

    return steps;
  }

  List<_RenderBlock> _buildRenderBlocks(
    String visualContent, {
    List<ReasoningSegment>? reasoningSegments,
  }) {
    final visibleTools = (widget.toolParts ?? const <ToolUIPart>[])
        .where((p) => p.toolName != 'builtin_search')
        .toList();
    final steps = _buildTimelineSteps(
      visibleTools,
      reasoningSegments: reasoningSegments,
    );
    if (steps.isEmpty) {
      return visualContent.trim().isEmpty
          ? const <_RenderBlock>[]
          : <_RenderBlock>[_RenderBlock.text(visualContent)];
    }

    final offsets = widget.contentSplitOffsets;
    final reasoningCounts = widget.reasoningCountAtSplit;
    final toolCounts = widget.toolCountAtSplit;
    if (offsets == null || reasoningCounts == null || toolCounts == null) {
      final blocks = <_RenderBlock>[_RenderBlock.thinking(steps)];
      if (visualContent.trim().isNotEmpty) {
        blocks.add(_RenderBlock.text(visualContent));
      }
      return blocks;
    }

    final blocks = <_RenderBlock>[];
    int stepIndex = 0;
    int textStart = 0;

    for (int i = 0; i < offsets.length; i++) {
      final int safeOffset = offsets[i].clamp(0, visualContent.length);
      final textSlice = visualContent.substring(textStart, safeOffset);
      if (textSlice.trim().isNotEmpty) {
        blocks.add(_RenderBlock.text(textSlice.trim()));
      }

      final targetReasoning = i < reasoningCounts.length
          ? reasoningCounts[i]
          : 0;
      final targetTool = i < toolCounts.length ? toolCounts[i] : 0;
      final blockSteps = <_TimelineStepData>[];
      while (stepIndex < steps.length) {
        final step = steps[stepIndex];
        blockSteps.add(step);
        stepIndex++;
        if (step.reasoningCountAfter == targetReasoning &&
            step.toolCountAfter == targetTool) {
          break;
        }
      }
      if (blockSteps.isNotEmpty) {
        blocks.add(_RenderBlock.thinking(blockSteps));
      }
      textStart = safeOffset;
    }

    final trailingText = visualContent.substring(textStart);
    if (trailingText.trim().isNotEmpty) {
      blocks.add(_RenderBlock.text(trailingText.trim()));
    }
    if (stepIndex < steps.length) {
      blocks.add(_RenderBlock.thinking(steps.sublist(stepIndex)));
    }
    return blocks;
  }

  Widget _buildAssistantMessage() {
    final cs = Theme.of(context).colorScheme;
    final fg = _chatSurfaceForegroundPalette(context);
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final assistant = _assistantForMessage();

    final parsedInlineThinking = _legacyInlineThinkingFor(widget);
    final extractedThinking = parsedInlineThinking.thinkingTexts.join('\n\n');
    final contentWithoutThink = parsedInlineThinking.visibleContent;
    final visualContent = applyAssistantRegexes(
      contentWithoutThink,
      assistant: assistant,
      scope: AssistantRegexScope.assistant,
      target: AssistantRegexTransformTarget.visual,
    );
    final visualTranslation = widget.message.translation != null
        ? applyAssistantRegexes(
            widget.message.translation!,
            assistant: assistant,
            scope: AssistantRegexScope.assistant,
            target: AssistantRegexTransformTarget.visual,
          )
        : null;
    final translationText = visualTranslation ?? widget.message.translation;
    final bool hasTranslation =
        (translationText != null && translationText.isNotEmpty);
    final bool isTranslating =
        translationText == l10n.chatMessageWidgetTranslating;

    return Padding(
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
                    if (settings.showModelName)
                      Text(
                        widget.useAssistantName
                            ? (widget.assistantName?.trim().isNotEmpty == true
                                  ? widget.assistantName!.trim()
                                  : _assistantNameFallback())
                            : _resolveModelDisplayName(settings),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    Builder(
                      builder: (context) {
                        final List<Widget> rowChildren = [];
                        if (settings.showModelTimestamp) {
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

          // File Processing Indicator (inserted before content)
          if (widget.isProcessingFiles) ...[
            const FileProcessingIndicator(),
            const SizedBox(height: 8),
          ],
          ...() {
            final hasProvidedReasoning =
                (widget.reasoningText != null &&
                    widget.reasoningText!.isNotEmpty) ||
                widget.reasoningLoading;
            final effectiveReasoningText =
                (widget.reasoningText != null &&
                    widget.reasoningText!.isNotEmpty)
                ? widget.reasoningText!
                : extractedThinking;
            final usingInlineThink =
                (widget.reasoningText == null ||
                    widget.reasoningText!.isEmpty) &&
                extractedThinking.isNotEmpty;
            final effectiveExpanded = usingInlineThink
                ? (_inlineThinkExpanded ?? true)
                : widget.reasoningExpanded;
            final effectiveLoading = usingInlineThink
                ? false
                : (widget.reasoningFinishedAt == null);

            List<ReasoningSegment>? effectiveReasoningSegments =
                widget.reasoningSegments;
            if ((effectiveReasoningSegments == null ||
                    effectiveReasoningSegments.isEmpty) &&
                (hasProvidedReasoning || effectiveReasoningText.isNotEmpty)) {
              effectiveReasoningSegments = <ReasoningSegment>[
                ReasoningSegment(
                  text: effectiveReasoningText,
                  expanded: effectiveExpanded,
                  loading: effectiveLoading,
                  startAt: usingInlineThink ? null : widget.reasoningStartAt,
                  finishedAt: usingInlineThink
                      ? null
                      : widget.reasoningFinishedAt,
                  onToggle: usingInlineThink
                      ? () => setState(() {
                          _inlineThinkExpanded =
                              !(_inlineThinkExpanded ?? true);
                          _inlineThinkManuallyToggled = true;
                        })
                      : widget.onToggleReasoning,
                ),
              ];
            }

            final renderBlocks = _buildRenderBlocks(
              visualContent,
              reasoningSegments: effectiveReasoningSegments,
            );
            if (renderBlocks.isEmpty &&
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

            final widgets = <Widget>[];
            for (int i = 0; i < renderBlocks.length; i++) {
              final block = renderBlocks[i];
              if (block.type == _RenderBlockType.text && block.text != null) {
                widgets.add(
                  _buildAssistantTextBlock(context, block.text!, settings),
                );
              } else if (block.steps.isNotEmpty) {
                widgets.add(
                  _ChainOfThoughtCard(
                    steps: block.steps,
                    onRecoveredAnswer: widget.onRecoveredAskUserAnswer,
                    canSubmitRecoveredAnswer:
                        widget.canSubmitRecoveredAskUserAnswer,
                  ),
                );
              }
              if (i != renderBlocks.length - 1) {
                widgets.add(const SizedBox(height: 8));
              }
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
                            Icon(Lucide.Languages, size: 16, color: fg.strong),
                            const SizedBox(width: 6),
                            Text(
                              l10n.chatMessageWidgetTranslation,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
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
                                    if (settings.enableAssistantMarkdown) {
                                      translationContent =
                                          MarkdownWithCodeHighlight(
                                            text: translationText,
                                            onCitationTap: (id) =>
                                                _handleCitationTap(id),
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
                                          color: cs.onSurface,
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
          if (_latestSearchItems().isNotEmpty) ...[
            const SizedBox(height: 8),
            _SourcesSummaryCard(
              count: _latestSearchItems().length,
              onTap: () => _showCitationsSheet(_latestSearchItems()),
            ),
          ],
          // Action buttons (hidden while generating)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => SizeTransition(
              sizeFactor: anim,
              axisAlignment: -1,
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
                          builder: (context, tts, _) => SizedBox(
                            width: 28,
                            height: 28,
                            child: Center(
                              child: IosIconButton(
                                size: 16,
                                padding: EdgeInsets.all(4),
                                onTap: widget.onSpeak,
                                color: cs.onSurface.withValues(alpha: 0.9),
                                builder: (color) => AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  transitionBuilder: (child, anim) =>
                                      ScaleTransition(
                                        scale: anim,
                                        child: FadeTransition(
                                          opacity: anim,
                                          child: child,
                                        ),
                                      ),
                                  child: Icon(
                                    tts.isSpeaking
                                        ? Lucide.CircleStop
                                        : Lucide.Volume2,
                                    key: ValueKey(
                                      tts.isSpeaking ? 'stop' : 'speak',
                                    ),
                                    size: 16,
                                    color: color,
                                  ),
                                ),
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
    );
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
    if (parts.isEmpty) return const <Map<String, dynamic>>[];

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
    return out;
  }

  // Extract items from the last search_web or builtin_search tool result for this assistant message
  List<Map<String, dynamic>> _latestSearchItems() {
    final parts = widget.toolParts ?? const <ToolUIPart>[];
    for (int i = parts.length - 1; i >= 0; i--) {
      final p = parts[i];
      if ((p.toolName == 'search_web' || p.toolName == 'builtin_search') &&
          (p.content?.isNotEmpty ?? false)) {
        try {
          final obj = jsonDecode(p.content!) as Map<String, dynamic>;
          final arr = obj['items'] as List? ?? const <dynamic>[];
          return [
            for (final it in arr)
              if (it is Map) it.cast<String, dynamic>(),
          ];
        } catch (_) {
          return const <Map<String, dynamic>>[];
        }
      }
    }
    return const <Map<String, dynamic>>[];
  }

  void _showCitationsSheet(List<Map<String, dynamic>> items) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final bool isDesktop =
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;

    if (isDesktop) {
      showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) {
          return Dialog(
            elevation: 12,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 380,
                maxWidth: 460,
                maxHeight: 360,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Material(
                  color: cs.surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                        child: Row(
                          children: [
                            Icon(Lucide.BookOpen, size: 18, color: cs.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.chatMessageWidgetCitationsTitle(
                                  items.length,
                                ),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Tooltip(
                              message: l10n.mcpPageClose,
                              child: IconButton(
                                icon: Icon(
                                  Lucide.X,
                                  size: 18,
                                  color: cs.onSurface.withValues(alpha: 0.75),
                                ),
                                onPressed: () => Navigator.of(ctx).maybePop(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Body
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (int i = 0; i < items.length; i++)
                                    _SearchResultCard(
                                      index: (items[i]['index'] ?? (i + 1))
                                          .toString(),
                                      title: (items[i]['title'] ?? '')
                                          .toString(),
                                      url: (items[i]['url'] ?? '').toString(),
                                      text: (items[i]['text'] ?? '').toString(),
                                    ),
                                ],
                              ),
                            ),
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
      );
      return;
    }

    // Mobile: keep bottom sheet
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.5,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Lucide.BookOpen, size: 18, color: cs.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.chatMessageWidgetCitationsTitle(items.length),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (int i = 0; i < items.length; i++)
                              _SearchResultCard(
                                index: (items[i]['index'] ?? (i + 1))
                                    .toString(),
                                title: (items[i]['title'] ?? '').toString(),
                                url: (items[i]['url'] ?? '').toString(),
                                text: (items[i]['text'] ?? '').toString(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
        style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.message.role == 'user') return _buildUserMessage();
    if (widget.message.role == 'tool') return _buildToolMessage();
    return _buildAssistantMessage();
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

Widget _buildSharedChatSurface(
  BuildContext context, {
  required Widget child,
  required BorderRadius borderRadius,
  required EdgeInsetsGeometry padding,
  Color? defaultColor,
  bool bareOnDefault = false,
}) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final isDark = theme.brightness == Brightness.dark;
  final style = context.watch<SettingsProvider>().chatMessageBackgroundStyle;
  final paddedChild = Padding(padding: padding, child: child);

  switch (style) {
    case ChatMessageBackgroundStyle.frosted:
      return ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter.grouped(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1C1C1E).withValues(alpha: 0.66)
                  : Colors.white.withValues(alpha: 0.66),
              borderRadius: borderRadius,
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.14),
                width: 0.8,
              ),
            ),
            child: paddedChild,
          ),
        ),
      );
    case ChatMessageBackgroundStyle.solid:
      return DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: borderRadius,
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.16),
            width: 0.8,
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
}

_ChatSurfaceForegroundPalette _chatSurfaceForegroundPalette(
  BuildContext context,
) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final style = context.watch<SettingsProvider>().chatMessageBackgroundStyle;
  if (style == ChatMessageBackgroundStyle.defaultStyle) {
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

  final base = cs.onSurface;
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
    final fg = danger ? Colors.red.shade600 : cs.onSurface;
    final ic = danger
        ? Colors.red.shade600
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
                  fontWeight: FontWeight.w500,
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

  double _dotValue(int index) {
    final phase = (_controller.value - index * 0.22) * 2 * math.pi;
    return (math.sin(phase) + 1) / 2; // 0 -> 1 wave
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = widget.color ?? cs.primary;

    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final wave = _dotValue(i);
              final double scale = 0.85 + 0.15 * wave; // subtle breathing
              final double opacity = 0.45 + 0.45 * wave;
              return Padding(
                padding: EdgeInsets.only(right: i == 2 ? 0 : widget.spacing),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: widget.dotSize,
                    height: widget.dotSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: base.withValues(alpha: opacity),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
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
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topLeft,
      clipBehavior: Clip.hardEdge,
      child: child,
    );
  }
}

class _ParsedUserContent {
  final String text;
  final List<String> images;
  final List<_DocRef> docs;
  _ParsedUserContent(this.text, this.images, this.docs);
}

class _DocRef {
  final String path;
  final String fileName;
  final String mime;
  _DocRef({required this.path, required this.fileName, required this.mime});
}

// UI data for MCP tool calls/results
class ToolUIPart {
  final String id;
  final String toolName;
  final Map<String, dynamic> arguments;
  final String? content; // null means still loading/result not yet available
  final bool loading;
  const ToolUIPart({
    required this.id,
    required this.toolName,
    required this.arguments,
    this.content,
    this.loading = false,
  });
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
}

enum _RenderBlockType { text, thinking }

class _RenderBlock {
  const _RenderBlock.text(this.text)
    : type = _RenderBlockType.text,
      steps = const <_TimelineStepData>[];

  const _RenderBlock.thinking(this.steps)
    : type = _RenderBlockType.thinking,
      text = null;

  final _RenderBlockType type;
  final String? text;
  final List<_TimelineStepData> steps;
}

class _TimelineStepData {
  const _TimelineStepData.reasoning({
    required this.reasoning,
    required this.reasoningCountAfter,
    required this.toolCountAfter,
  }) : tool = null;

  const _TimelineStepData.tool({
    required this.tool,
    required this.reasoningCountAfter,
    required this.toolCountAfter,
  }) : reasoning = null;

  final ReasoningSegment? reasoning;
  final ToolUIPart? tool;
  final int reasoningCountAfter;
  final int toolCountAfter;

  bool get isReasoning => reasoning != null;
  bool get isTool => tool != null;
  bool get loading => reasoning?.loading ?? tool?.loading ?? false;
}

enum _ReasoningStepState { collapsed, preview, expanded }

const double _timelineStepPaddingV = 8;
const double _timelineIconSize = 18;
const double _timelineIconColumnWidth = 24;
const double _timelineGap = 8;
const double _timelineLineGap = 3;
const double _timelineLineX = (_timelineIconColumnWidth - 1) / 2;
const double _timelineTopLineEnd = _timelineStepPaddingV - _timelineLineGap;
const double _timelineBottomLineStart =
    _timelineStepPaddingV + _timelineIconSize + _timelineLineGap;

class _ChainOfThoughtCard extends StatefulWidget {
  const _ChainOfThoughtCard({
    required this.steps,
    this.onRecoveredAnswer,
    this.canSubmitRecoveredAnswer = true,
  });

  final List<_TimelineStepData> steps;
  final Future<void> Function(ToolUIPart part, AskUserResult result)?
  onRecoveredAnswer;
  final bool canSubmitRecoveredAnswer;

  @override
  State<_ChainOfThoughtCard> createState() => _ChainOfThoughtCardState();
}

class _ChainOfThoughtCardState extends State<_ChainOfThoughtCard> {
  bool _showAllSteps = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fg = _chatSurfaceForegroundPalette(context);
    final settings = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;
    final enableAdaptiveWidth =
        widget.steps.isNotEmpty &&
        widget.steps.every((step) => step.isReasoning) &&
        !widget.steps.any((step) => step.isReasoning && step.loading);
    final canCollapse =
        settings.collapseThinkingSteps && widget.steps.length > 2;
    final visibleSteps = canCollapse && !_showAllSteps
        ? widget.steps.sublist(widget.steps.length - 2)
        : widget.steps;
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
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
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
                          fontWeight: FontWeight.w600,
                          color: fg.strong,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ...visibleSteps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              if (step.isReasoning) {
                return _ChainOfThoughtReasoningStep(
                  step: step.reasoning!,
                  isFirst: index == 0,
                  isLast: index == visibleSteps.length - 1,
                );
              }
              return _ChainOfThoughtToolStep(
                part: step.tool!,
                isFirst: index == 0,
                isLast: index == visibleSteps.length - 1,
                onRecoveredAnswer: widget.onRecoveredAnswer,
                canSubmitRecoveredAnswer: widget.canSubmitRecoveredAnswer,
              );
            }),
          ],
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

  @override
  Widget build(BuildContext context) {
    final fg = _chatSurfaceForegroundPalette(context);
    final header = Padding(
      padding: const EdgeInsets.symmetric(vertical: _timelineStepPaddingV),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: _timelineIconColumnWidth,
            child: Center(child: icon),
          ),
          const SizedBox(width: _timelineGap),
          Expanded(child: label),
          if (extra != null) ...[const SizedBox(width: 8), extra!],
          if (indicator != null) ...[const SizedBox(width: 6), indicator!],
        ],
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (!isFirst)
          Positioned(
            left: _timelineLineX,
            top: 0,
            height: _timelineTopLineEnd,
            child: Container(width: 1, color: fg.divider),
          ),
        if (!isLast)
          Positioned(
            left: _timelineLineX,
            top: _timelineBottomLineStart,
            bottom: 0,
            child: Container(width: 1, color: fg.divider),
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IosCardPress(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              baseColor: Colors.transparent,
              pressedScale: 1,
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              child: header,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: const Cubic(0.2, 0.8, 0.2, 1),
              alignment: Alignment.topLeft,
              child: contentVisible && content != null
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
    );
  }
}

class _ChainOfThoughtReasoningStep extends StatefulWidget {
  const _ChainOfThoughtReasoningStep({
    required this.step,
    required this.isFirst,
    required this.isLast,
  });

  final ReasoningSegment step;
  final bool isFirst;
  final bool isLast;

  @override
  State<_ChainOfThoughtReasoningStep> createState() =>
      _ChainOfThoughtReasoningStepState();
}

class _ChainOfThoughtReasoningStepState
    extends State<_ChainOfThoughtReasoningStep> {
  final ValueNotifier<int> _elapsedTick = ValueNotifier<int>(0);
  late final Ticker _ticker = Ticker((_) {
    if (mounted) _elapsedTick.value++;
  });
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

  @override
  void initState() {
    super.initState();
    if (widget.step.loading) _ticker.start();
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
    if (widget.step.loading) {
      if (!_ticker.isActive) _ticker.start();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    } else if (_ticker.isActive) {
      _ticker.stop();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
  }

  @override
  void dispose() {
    _ticker.dispose();
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
    final settings = context.watch<SettingsProvider>();
    final state = _stepState;
    final display = _sanitize(widget.step.text);
    final label = Row(
      children: [
        _Shimmer(
          enabled: widget.step.loading,
          child: Text(
            l10n.chatMessageWidgetDeepThinking,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: fg.strong,
            ),
          ),
        ),
        if (widget.step.startAt != null) ...[
          const SizedBox(width: 6),
          ValueListenableBuilder<int>(
            valueListenable: _elapsedTick,
            builder: (context, _, __) => _Shimmer(
              enabled: widget.step.loading,
              child: Text(
                _elapsed(),
                style: TextStyle(fontSize: 13, color: fg.medium),
              ),
            ),
          ),
        ],
      ],
    );

    final icon = SizedBox(
      width: 18,
      height: 18,
      child: Center(
        child: _Shimmer(
          enabled: widget.step.loading,
          child: ReasoningIcons.thinkingCardIcon(size: 18, color: fg.strong),
        ),
      ),
    );

    Widget reasoningContent(String text) {
      if (settings.enableReasoningMarkdown) {
        return RepaintBoundary(
          child: MarkdownWithCodeHighlight(
            text: text.isNotEmpty ? text : '…',
            baseStyle: const TextStyle(fontSize: 12.5, height: 1.32),
          ),
        );
      }
      return Text(
        text.isNotEmpty ? text : '…',
        style: const TextStyle(fontSize: 12.5, height: 1.32),
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
                      Color(0x00FFFFFF),
                      Color(0xFFFFFFFF),
                      Color(0xFFFFFFFF),
                      Color(0x00FFFFFF),
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

    return _TimelineStepShell(
      icon: icon,
      label: label,
      isFirst: widget.isFirst,
      isLast: widget.isLast,
      onTap: widget.step.onToggle,
      indicator: widget.step.onToggle == null
          ? null
          : Icon(
              state == _ReasoningStepState.expanded
                  ? Lucide.ChevronUp
                  : Lucide.ChevronDown,
              size: 16,
              color: fg.muted,
            ),
      content: content,
      contentVisible: state != _ReasoningStepState.collapsed,
    );
  }
}

class _ChainOfThoughtToolStep extends StatefulWidget {
  const _ChainOfThoughtToolStep({
    required this.part,
    required this.isFirst,
    required this.isLast,
    this.onRecoveredAnswer,
    this.canSubmitRecoveredAnswer = true,
  });

  final ToolUIPart part;
  final bool isFirst;
  final bool isLast;
  final Future<void> Function(ToolUIPart part, AskUserResult result)?
  onRecoveredAnswer;
  final bool canSubmitRecoveredAnswer;

  @override
  State<_ChainOfThoughtToolStep> createState() =>
      _ChainOfThoughtToolStepState();
}

class _ChainOfThoughtToolStepState extends State<_ChainOfThoughtToolStep> {
  bool get _isAskUser => widget.part.toolName == LocalToolNames.askUser;
  bool? _askUserExpanded;

  bool get _askUserAnswered =>
      widget.part.content?.trim().isNotEmpty == true && !widget.part.loading;

  @override
  void didUpdateWidget(covariant _ChainOfThoughtToolStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasAnswered =
        oldWidget.part.content?.trim().isNotEmpty == true &&
        !oldWidget.part.loading;
    if (_isAskUser && !wasAnswered && _askUserAnswered) {
      _askUserExpanded = true;
    }
  }

  IconData _iconFor(String name) {
    return _toolIconFor(name);
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
    String toolCallId,
  ) {
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
              approvalService.deny(toolCallId, reason);
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
    final settings = context.watch<SettingsProvider>();
    final approvalService = context.watch<ToolApprovalService>();
    ToolApprovalRequest? pendingRequest;
    if (widget.part.id.isNotEmpty &&
        approvalService.isPending(widget.part.id)) {
      pendingRequest = approvalService.pendingRequests[widget.part.id];
    } else {
      for (final request in approvalService.pendingRequests.values) {
        if (request.toolName == widget.part.toolName) {
          pendingRequest = request;
          break;
        }
      }
    }
    final isPendingApproval = pendingRequest != null;
    final approvalRequest = pendingRequest;

    final icon = _isAskUser
        ? Icon(_iconFor(widget.part.toolName), size: 16, color: fg.strong)
        : widget.part.loading && !isPendingApproval
        ? LoadingIndicator(height: 12, dotSize: 3, spacing: 2, color: fg.strong)
        : Icon(_iconFor(widget.part.toolName), size: 16, color: fg.strong);

    final title = _titleFor(
      context,
      widget.part.toolName,
      widget.part.arguments,
      isResult: !widget.part.loading && !isPendingApproval,
    );
    final label = _Shimmer(
      enabled: widget.part.loading && !_isAskUser,
      child: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: fg.strong,
        ),
      ),
    );

    final (cleanText, _) = _parseMcpImagePaths(widget.part.content);
    final String summaryText = approvalRequest != null
        ? _argsSummary(approvalRequest.arguments)
        : cleanText.isNotEmpty
        ? cleanText
        : ((widget.part.arguments['query'] ??
                      widget.part.arguments['url'] ??
                      widget.part.arguments['text']) ??
                  '')
              .toString();
    final bool shouldShowSummary = settings.showToolResultSummary;
    final askUserExpanded = _askUserExpanded ?? true;
    final Widget? content = _isAskUser
        ? _AskUserInlineBody(
            part: widget.part,
            compact: true,
            onRecoveredAnswer: widget.onRecoveredAnswer,
            canSubmitRecoveredAnswer: widget.canSubmitRecoveredAnswer,
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
                onTap: () =>
                    approvalService.approve(approvalRequest.toolCallId),
              ),
            ],
          )
        : null;

    return _TimelineStepShell(
      icon: SizedBox(width: 16, height: 16, child: Center(child: icon)),
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
    );
  }
}

class _ToolCallItem extends StatefulWidget {
  const _ToolCallItem({
    required this.part,
    this.onRecoveredAnswer,
    this.canSubmitRecoveredAnswer = true,
  });
  final ToolUIPart part;
  final Future<void> Function(ToolUIPart part, AskUserResult result)?
  onRecoveredAnswer;
  final bool canSubmitRecoveredAnswer;

  @override
  State<_ToolCallItem> createState() => _ToolCallItemState();
}

class _ToolCallItemState extends State<_ToolCallItem> {
  // Cache image paths (local file or URL)
  List<String> _imagePaths = const [];
  String? _lastContent;

  void _updateImageCache() {
    final content = widget.part.content;
    if (content == _lastContent) return;
    _lastContent = content;

    final (_, paths) = _parseMcpImagePaths(content);
    _imagePaths = paths;
  }

  /// Build image widget from path (supports local file and HTTP URL)
  Widget _buildImageFromPath(
    String path, {
    double? height,
    BoxFit fit = BoxFit.contain,
  }) {
    final cs = Theme.of(context).colorScheme;
    Widget errorWidget() => Container(
      width: height != null ? height * 0.67 : 120,
      height: height ?? 180,
      color: cs.surfaceContainerHighest,
      child: Icon(
        Lucide.ImageOff,
        size: 24,
        color: cs.onSurface.withValues(alpha: 0.5),
      ),
    );

    if (path.startsWith('http://') || path.startsWith('https://')) {
      // HTTP URL
      return Image.network(
        path,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => errorWidget(),
      );
    } else {
      // Local file path
      return Image.file(
        File(path),
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => errorWidget(),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _updateImageCache();
  }

  @override
  void didUpdateWidget(covariant _ToolCallItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.part.content != widget.part.content) {
      _updateImageCache();
    }
  }

  IconData _iconFor(String name) {
    return _toolIconFor(name);
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
    final hasImages = _imagePaths.isNotEmpty;
    final l10n = AppLocalizations.of(context)!;

    if (widget.part.toolName == LocalToolNames.askUser) {
      return _AskUserToolCard(
        part: widget.part,
        onRecoveredAnswer: widget.onRecoveredAnswer,
        canSubmitRecoveredAnswer: widget.canSubmitRecoveredAnswer,
      );
    }

    // Check if this tool call is pending approval
    final approvalService = context.watch<ToolApprovalService>();
    final isPendingApproval =
        widget.part.loading &&
        approvalService.pendingRequests.values.any(
          (req) => req.toolName == widget.part.toolName,
        );
    // Find the matching approval request
    String? pendingToolCallId;
    if (isPendingApproval) {
      try {
        final req = approvalService.pendingRequests.values.firstWhere(
          (req) => req.toolName == widget.part.toolName,
        );
        pendingToolCallId = req.toolCallId;
      } catch (_) {}
    }

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
                        _iconFor(widget.part.toolName),
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
                      Text(
                        _titleFor(
                          context,
                          widget.part.toolName,
                          widget.part.arguments,
                          isResult: !widget.part.loading && !isPendingApproval,
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isPendingApproval ? fg.accent : fg.strong,
                        ),
                      ),
                      // "Waiting for approval" subtitle
                      if (isPendingApproval) ...[
                        const SizedBox(height: 2),
                        Text(
                          l10n.toolApprovalPending,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: fg.medium,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
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
                        pendingToolCallId!,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ApprovalButton(
                      label: l10n.toolApprovalApprove,
                      color: fg.accent,
                      filled: true,
                      onTap: () => approvalService.approve(pendingToolCallId!),
                    ),
                  ),
                ],
              ),
            ],
            // Show image thumbnails if available
            if (hasImages) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 180,
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
                        child: _buildImageFromPath(path, height: 180),
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
    String toolCallId,
  ) {
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
              approvalService.deny(toolCallId, reason);
              Navigator.of(ctx).pop();
            },
            child: Text(l10n.toolApprovalDeny),
          ),
        ],
      ),
    );
  }

  /// Try to pretty-format a string as indented JSON.
  /// Returns the original string if it is not valid JSON.
  static String _prettyJson(String raw) {
    try {
      final obj = jsonDecode(raw);
      return const JsonEncoder.withIndent('  ').convert(obj);
    } catch (_) {
      return raw;
    }
  }

  void _showDetail(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final argsPretty = const JsonEncoder.withIndent(
      '  ',
    ).convert(widget.part.arguments);
    final (cleanText, images) = _parseMcpImagePaths(widget.part.content);
    final resultText = cleanText.isNotEmpty
        ? _prettyJson(cleanText)
        : l10n.chatMessageWidgetNoResultYet;

    final bool isDesktop =
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;

    if (isDesktop) {
      showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) {
          return Dialog(
            elevation: 12,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 360,
                maxWidth: 560,
                maxHeight: 560,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Material(
                  color: cs.surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                        child: Row(
                          children: [
                            Icon(
                              _iconFor(widget.part.toolName),
                              size: 18,
                              color: cs.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _titleFor(
                                  context,
                                  widget.part.toolName,
                                  widget.part.arguments,
                                  isResult: !widget.part.loading,
                                ),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Tooltip(
                              message: l10n.mcpPageClose,
                              child: IconButton(
                                icon: Icon(
                                  Lucide.X,
                                  size: 18,
                                  color: cs.onSurface.withValues(alpha: 0.75),
                                ),
                                onPressed: () => Navigator.of(ctx).maybePop(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Body
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.chatMessageWidgetArguments,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white10
                                        : const Color(0xFFF7F7F9),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: cs.outlineVariant.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  child: SelectableText(
                                    argsPretty,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  l10n.chatMessageWidgetResult,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white10
                                        : const Color(0xFFF7F7F9),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: cs.outlineVariant.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  child: SelectableText(
                                    resultText,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                // Show images if available
                                if (images.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    l10n.chatMessageWidgetImages,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurface.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: images.map((path) {
                                      return GestureDetector(
                                        onTap: () =>
                                            _showFullImage(context, path),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: _buildImageFromPath(
                                            path,
                                            height: 280,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),
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
      );
      return;
    }

    // Mobile: bottom sheet remains
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.6,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _iconFor(widget.part.toolName),
                          size: 18,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _titleFor(
                              context,
                              widget.part.toolName,
                              widget.part.arguments,
                              isResult: !widget.part.loading,
                            ),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.chatMessageWidgetArguments,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white10
                            : const Color(0xFFF7F7F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.2),
                        ),
                      ),
                      child: SelectableText(
                        argsPretty,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.chatMessageWidgetResult,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white10
                            : const Color(0xFFF7F7F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.2),
                        ),
                      ),
                      child: SelectableText(
                        resultText,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    // Show images if available
                    if (images.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        l10n.chatMessageWidgetImages,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: images.map((path) {
                          return GestureDetector(
                            onTap: () => _showFullImage(context, path),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _buildImageFromPath(path, height: 240),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
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
  const _AskUserToolCard({
    required this.part,
    this.onRecoveredAnswer,
    this.canSubmitRecoveredAnswer = true,
  });

  final ToolUIPart part;
  final Future<void> Function(ToolUIPart part, AskUserResult result)?
  onRecoveredAnswer;
  final bool canSubmitRecoveredAnswer;

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
                      fontWeight: FontWeight.w700,
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
                      fontWeight: FontWeight.w700,
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
                    child: _AskUserInlineBody(
                      part: widget.part,
                      onRecoveredAnswer: widget.onRecoveredAnswer,
                      canSubmitRecoveredAnswer: widget.canSubmitRecoveredAnswer,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _AskUserInlineBody extends StatefulWidget {
  const _AskUserInlineBody({
    required this.part,
    this.compact = false,
    this.onRecoveredAnswer,
    this.canSubmitRecoveredAnswer = true,
  });

  final ToolUIPart part;
  final bool compact;
  final Future<void> Function(ToolUIPart part, AskUserResult result)?
  onRecoveredAnswer;
  final bool canSubmitRecoveredAnswer;

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

    final onRecoveredAnswer = widget.onRecoveredAnswer;
    if (onRecoveredAnswer == null ||
        !widget.canSubmitRecoveredAnswer ||
        _submittingRecovered) {
      return;
    }
    setState(() => _submittingRecovered = true);
    try {
      await onRecoveredAnswer(widget.part, AskUserResult.answer(answers));
    } finally {
      if (mounted) setState(() => _submittingRecovered = false);
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
                    widget.canSubmitRecoveredAnswer &&
                    (pendingRequest != null || widget.onRecoveredAnswer != null)
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
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            displayAnswer,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: cs.primary.withValues(alpha: 0.86),
              fontWeight: FontWeight.w600,
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
                  fontWeight: FontWeight.w500,
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
          fontWeight: FontWeight.w700,
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
            fontWeight: FontWeight.w600,
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
                fontWeight: FontWeight.w800,
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
            fontWeight: FontWeight.w600,
            color: enabled ? color : color.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}

/// Card-style search result item for tool detail view.
/// Shows favicon, title, text snippet, and URL in a tappable card.
class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.title,
    required this.url,
    this.text = '',
    this.index,
  });
  final String title;
  final String url;
  final String text;
  final String? index;

  static final _pureNumber = RegExp(r'^\d+$');

  String _domain(String url) {
    try {
      return _tryNormalizeExternalUri(url)?.host ?? '';
    } catch (_) {
      return '';
    }
  }

  /// A title is "real" if it is non-empty and not a pure number like "1","2".
  bool _hasRealTitle() =>
      title.isNotEmpty && !_pureNumber.hasMatch(title.trim());

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final domain = _domain(url);
    final faviconUrl = domain.isNotEmpty
        ? 'https://www.google.com/s2/favicons?domain=$domain&sz=32'
        : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: IosCardPress(
        borderRadius: BorderRadius.circular(12),
        baseColor: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.5)
            : cs.surfaceContainerHighest.withValues(alpha: 0.45),
        pressedScale: 1.0,
        duration: const Duration(milliseconds: 200),
        onTap: () async {
          final l10n = AppLocalizations.of(context)!;
          final uri = _tryNormalizeExternalUri(url);
          if (uri == null) {
            showAppSnackBar(
              context,
              message: l10n.chatMessageWidgetOpenLinkError,
              type: NotificationType.error,
            );
            return;
          }
          try {
            final ok = await launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
            );
            if (!ok && context.mounted) {
              showAppSnackBar(
                context,
                message: l10n.chatMessageWidgetCannotOpenUrl(uri.toString()),
                type: NotificationType.error,
              );
            }
          } catch (_) {
            if (!context.mounted) return;
            showAppSnackBar(
              context,
              message: l10n.chatMessageWidgetOpenLinkError,
              type: NotificationType.error,
            );
          }
        },
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Favicon with optional index badge
            SizedBox(
              width: 36,
              height: 36,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 32,
                        height: 32,
                        color: cs.surfaceContainerHigh,
                        child: faviconUrl.isNotEmpty
                            ? Image.network(
                                faviconUrl,
                                width: 32,
                                height: 32,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Icon(
                                  Lucide.Globe,
                                  size: 18,
                                  color: cs.onSurface.withValues(alpha: 0.5),
                                ),
                              )
                            : Icon(
                                Lucide.Globe,
                                size: 18,
                                color: cs.onSurface.withValues(alpha: 0.5),
                              ),
                      ),
                    ),
                  ),
                  if (index != null)
                    Positioned(
                      left: 0,
                      top: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          index!,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: cs.onPrimary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    _hasRealTitle() ? title : domain,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Text snippet
                  if (text.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      text,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  // URL
                  const SizedBox(height: 3),
                  Text(
                    url,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.4),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

class _SourcesSummaryCard extends StatelessWidget {
  const _SourcesSummaryCard({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final label = l10n.chatMessageWidgetCitationsCount(count);
    return IosCardPress(
      borderRadius: BorderRadius.circular(12),
      baseColor: cs.primaryContainer.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.25 : 0.30,
      ),
      pressedScale: 1.0,
      duration: const Duration(milliseconds: 260),
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Lucide.BookOpen, size: 16, color: cs.secondary),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.secondary,
            ),
          ),
        ],
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

class _ReasoningSectionState extends State<_ReasoningSection>
    with SingleTickerProviderStateMixin {
  // Use ValueNotifier to only update elapsed time display, not rebuild entire widget
  final ValueNotifier<int> _elapsedTick = ValueNotifier<int>(0);
  late final Ticker _ticker = Ticker((_) {
    if (mounted) _elapsedTick.value++;
  });
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

  @override
  void initState() {
    super.initState();
    if (widget.loading) _ticker.start();
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
    if (widget.loading && widget.finishedAt == null) {
      if (!_ticker.isActive) _ticker.start();
    } else {
      if (_ticker.isActive) _ticker.stop();
    }
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
    _ticker.dispose();
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
    final settings = context.watch<SettingsProvider>();
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
            _Shimmer(
              enabled: loading,
              child: Text(
                l10n.chatMessageWidgetDeepThinking,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: fg.strong,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (widget.startAt != null)
              ValueListenableBuilder<int>(
                valueListenable: _elapsedTick,
                builder: (context, _, __) => _Shimmer(
                  enabled: loading,
                  child: Text(
                    _elapsed(),
                    style: TextStyle(fontSize: 13, color: fg.medium),
                  ),
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
      if (settings.enableReasoningMarkdown) {
        return RepaintBoundary(
          child: MarkdownWithCodeHighlight(
            text: text.isNotEmpty ? text : '…',
            baseStyle: baseStyle,
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
                        Color(0x00FFFFFF),
                        Color(0xFFFFFFFF),
                        Color(0xFFFFFFFF),
                        Color(0x00FFFFFF),
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

// Lightweight shimmer effect without external dependency
class _Shimmer extends StatefulWidget {
  final Widget child;
  final bool enabled;
  const _Shimmer({required this.child, this.enabled = false});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with TickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.enabled) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant _Shimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_c.isAnimating) _c.repeat();
    if (!widget.enabled && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value; // 0..1
        return ShaderMask(
          shaderCallback: (rect) {
            final width = rect.width;
            final gradientWidth = width * 0.4;
            final dx = (width + gradientWidth) * t - gradientWidth;
            final shaderRect = Rect.fromLTWH(
              -dx,
              0,
              width + gradientWidth * 2,
              rect.height,
            );
            return LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.0),
                Colors.white.withValues(alpha: 0.35),
                Colors.white.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(shaderRect);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
