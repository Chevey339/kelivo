import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/services.dart';
import '../../../core/services/haptics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:open_filex/open_filex.dart';
// import 'package:easy_image_viewer/easy_image_viewer.dart';
import 'dart:convert';
import '../../home/widgets/file_processing_indicator.dart';
import '../pages/image_viewer_page.dart';
import '../../../core/models/chat_message.dart';
import '../../../icons/lucide_adapter.dart';
// import '../../../theme/design_tokens.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/providers/assistant_provider.dart';
import 'package:intl/intl.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../../utils/avatar_cache.dart';
import '../../../utils/assistant_regex.dart';
import '../../../utils/voice_attachment_utils.dart';
import '../../../core/models/assistant.dart';
import '../../../core/providers/tts_provider.dart';
import '../../../shared/widgets/markdown_with_highlight.dart';
import '../../../shared/widgets/snackbar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/model_provider.dart';
import '../../../core/models/assistant_regex.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../core/providers/voice_message_playback_provider.dart';
import '../../../desktop/desktop_context_menu.dart';
import '../../../desktop/menu_anchor.dart';
import '../../../shared/widgets/emoji_text.dart';
import '../../home/services/tool_approval_service.dart';
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
  // Hide streaming dots when pinned globally
  final bool hideStreamingIndicator;
  // Whether files are currently being processed
  final bool isProcessingFiles;

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
    this.hideStreamingIndicator = false,
    this.isProcessingFiles = false,
  });

  @override
  State<ChatMessageWidget> createState() => _ChatMessageWidgetState();
}

class _ChatMessageWidgetState extends State<ChatMessageWidget> {
  // Match vendor inline thinking blocks: <think>...</think> or <thought>...</thought> (or until end)
  static final RegExp _thinkingRegex = RegExp(
    r"<(?:think|thought)>([\s\S]*?)(?:</(?:think|thought)>|$)",
    dotAll: true,
  );
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
      // Check whether this message is using inline <think> content
      final extracted = _thinkingRegex
          .allMatches(widget.message.content)
          .map((m) => (m.group(1) ?? '').trim())
          .where((s) => s.isNotEmpty)
          .join('\n\n');
      final usingInlineThink =
          (widget.reasoningText == null || widget.reasoningText!.isEmpty) &&
          extracted.isNotEmpty;
      final loading =
          usingInlineThink &&
          widget.message.isStreaming &&
          !widget.message.content.contains('</think>');

      if (usingInlineThink && _inlineThinkExpanded == null) {
        final autoCollapse = context
            .read<SettingsProvider>()
            .autoCollapseThinking;
        // While loading we default to expanded; once finished honor auto-collapse.
        _inlineThinkExpanded = loading
            ? true
            : !autoCollapse
            ? true
            : false;
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
    // Determine if using inline <think>
    final newExtracted = _thinkingRegex
        .allMatches(widget.message.content)
        .map((m) => (m.group(1) ?? '').trim())
        .where((s) => s.isNotEmpty)
        .join('\n\n');
    final usingInlineThinkNew =
        (widget.reasoningText == null || widget.reasoningText!.isEmpty) &&
        newExtracted.isNotEmpty;
    final loadingNew =
        usingInlineThinkNew &&
        widget.message.isStreaming &&
        !widget.message.content.contains('</think>');

    bool loadingOld = false;
    if (oldWidget != null) {
      final oldExtracted = _thinkingRegex
          .allMatches(oldWidget.message.content)
          .map((m) => (m.group(1) ?? '').trim())
          .where((s) => s.isNotEmpty)
          .join('\n\n');
      final usingInlineThinkOld =
          (oldWidget.reasoningText == null ||
              oldWidget.reasoningText!.isEmpty) &&
          oldExtracted.isNotEmpty;
      loadingOld =
          usingInlineThinkOld &&
          oldWidget.message.isStreaming &&
          !oldWidget.message.content.contains('</think>');
    }

    final autoCollapse = context.read<SettingsProvider>().autoCollapseThinking;

    // If finished now (not loading), inline think is used, and auto-collapse is on
    // Only collapse when user hasn't manually toggled; also if we don't yet have a chosen state.
    final finishedNow = usingInlineThinkNew && !loadingNew;
    final justFinished = oldWidget != null
        ? (loadingOld && finishedNow)
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
        !loadingNew &&
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

  String _voicePlaybackIdForPath(String path) {
    return '${widget.message.id}:$path';
  }

  Future<void> _handleDocumentAttachmentTap(_DocRef docRef) async {
    if (isVoiceRecordingFileName(docRef.fileName)) {
      await _toggleVoiceAttachmentPlayback(docRef);
      return;
    }
    await _openDocumentAttachment(docRef);
  }

  Future<void> _toggleVoiceAttachmentPlayback(_DocRef docRef) async {
    final l10n = AppLocalizations.of(context)!;
    final fixedPath = SandboxPathResolver.fix(docRef.path);
    final playbackId = _voicePlaybackIdForPath(fixedPath);
    final playback = context.read<VoiceMessagePlaybackProvider>();
    final ttsProvider = context.read<TtsProvider>();
    final fallbackDuration = tryParseVoiceRecordingDuration(docRef.fileName);

    if (playback.isPlayingItem(playbackId)) {
      await playback.stop();
      return;
    }

    final file = File(fixedPath);
    if (!await file.exists()) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: l10n.chatMessageWidgetFileNotFound(docRef.fileName),
        type: NotificationType.error,
      );
      return;
    }

    try {
      await playback.toggle(
        playbackId: playbackId,
        path: fixedPath,
        fallbackDuration: fallbackDuration,
        beforePlay: ttsProvider.stop,
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: l10n.chatMessageWidgetVoicePlaybackFailed(e.toString()),
        type: NotificationType.error,
      );
    }
  }

  Future<void> _openDocumentAttachment(_DocRef docRef) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final fixed = SandboxPathResolver.fix(docRef.path);
      final file = File(fixed);
      if (!(await file.exists())) {
        if (!mounted) return;
        showAppSnackBar(
          context,
          message: l10n.chatMessageWidgetFileNotFound(docRef.fileName),
          type: NotificationType.error,
        );
        return;
      }
      final res = await OpenFilex.open(fixed, type: docRef.mime);
      if (res.type != ResultType.done) {
        if (!mounted) return;
        final openMessage = res.message;
        showAppSnackBar(
          context,
          message: l10n.chatMessageWidgetCannotOpenFile(
            openMessage.isNotEmpty ? openMessage : res.type.toString(),
          ),
          type: NotificationType.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: l10n.chatMessageWidgetOpenFileError(e.toString()),
        type: NotificationType.error,
      );
    }
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
      child: _ToolCallItem(part: part),
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
                          final isVoice = isVoiceRecordingFileName(d.fileName);
                          final fixedPath = SandboxPathResolver.fix(d.path);
                          final voicePlaybackId = _voicePlaybackIdForPath(
                            fixedPath,
                          );
                          final voiceDuration =
                              tryParseVoiceRecordingDuration(d.fileName) ??
                              Duration.zero;
                          final voicePlaybackState = isVoice
                              ? context.select<
                                  VoiceMessagePlaybackProvider,
                                  ({
                                    bool isPlaying,
                                    double progress,
                                    Duration? remaining,
                                  })
                                >(
                                  (provider) => (
                                    isPlaying: provider.isPlayingItem(
                                      voicePlaybackId,
                                    ),
                                    progress: provider.progressFor(
                                      voicePlaybackId,
                                    ),
                                    remaining: provider.remainingFor(
                                      voicePlaybackId,
                                    ),
                                  ),
                                )
                              : (
                                  isPlaying: false,
                                  progress: 0.0,
                                  remaining: null,
                                );
                          final isPlayingVoice = voicePlaybackState.isPlaying;
                          final voiceProgress = voicePlaybackState.progress;
                          final displayedVoiceDuration = isPlayingVoice
                              ? (voicePlaybackState.remaining ?? voiceDuration)
                              : voiceDuration;
                          final borderRadius = BorderRadius.circular(
                            isVoice ? 18 : 10,
                          );
                          final bubbleColor = isVoice
                              ? cs.primary.withValues(
                                  alpha: isPlayingVoice
                                      ? (isDark ? 0.36 : 0.24)
                                      : (isDark ? 0.28 : 0.18),
                                )
                              : (isDark ? Colors.white12 : cs.surface);
                          final progressColor = isVoice
                              ? cs.primary.withValues(
                                  alpha: isDark ? 0.46 : 0.28,
                                )
                              : Colors.transparent;
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
                                await _handleDocumentAttachmentTap(d);
                              },
                              child: Ink(
                                decoration: BoxDecoration(
                                  color: bubbleColor,
                                  borderRadius: borderRadius,
                                ),
                                child: ClipRRect(
                                  borderRadius: borderRadius,
                                  child: Stack(
                                    children: [
                                      if (isVoice && voiceProgress > 0)
                                        Positioned.fill(
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: FractionallySizedBox(
                                              widthFactor: voiceProgress,
                                              heightFactor: 1,
                                              alignment: Alignment.centerLeft,
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  color: progressColor,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isVoice
                                                  ? (isPlayingVoice
                                                        ? Lucide.CircleStop
                                                        : Lucide.AudioLines)
                                                  : Icons.insert_drive_file,
                                              size: 16,
                                              color: isVoice
                                                  ? cs.primary
                                                  : null,
                                            ),
                                            const SizedBox(width: 6),
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                maxWidth: 180,
                                              ),
                                              child: Text(
                                                isVoice
                                                    ? voiceRecordingDisplayLabelForDuration(
                                                        l10n,
                                                        displayedVoiceDuration,
                                                      )
                                                    : d.fileName,
                                                overflow: TextOverflow.ellipsis,
                                                style: isVoice
                                                    ? TextStyle(
                                                        color: isDark
                                                            ? Colors.white
                                                            : cs.primary,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      )
                                                    : null,
                                              ),
                                            ),
                                          ],
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
                                : () async {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (dctx) => AlertDialog(
                                        backgroundColor: Theme.of(
                                          dctx,
                                        ).colorScheme.surface,
                                        title: Text(
                                          l10n.chatMessageWidgetRegenerateConfirmTitle,
                                        ),
                                        content: Text(
                                          l10n.chatMessageWidgetRegenerateConfirmContent,
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(dctx).pop(false),
                                            child: Text(
                                              l10n.chatMessageWidgetRegenerateConfirmCancel,
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(dctx).pop(true),
                                            child: Text(
                                              l10n.chatMessageWidgetRegenerateConfirmOk,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (ok == true) widget.onResend!();
                                  },
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
    final style = context.watch<SettingsProvider>().chatMessageBackgroundStyle;
    BorderRadius radius = BorderRadius.circular(16);
    switch (style) {
      case ChatMessageBackgroundStyle.frosted:
        return ClipRRect(
          borderRadius: radius,
          child: BackdropFilter.grouped(
            filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1C1C1E).withValues(alpha: 0.66)
                    : Colors.white.withValues(alpha: 0.66),
                borderRadius: radius,
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.14),
                  width: 0.8,
                ),
              ),
              child: Padding(padding: const EdgeInsets.all(12), child: child),
            ),
          ),
        );
      case ChatMessageBackgroundStyle.solid:
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: radius,
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.16),
              width: 0.8,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: child,
        );
      case ChatMessageBackgroundStyle.defaultStyle:
        // Default: keep original visual — user has a tinted bubble; assistant is bare
        if (isUser) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? cs.primary.withValues(alpha: 0.15)
                  : cs.primary.withValues(alpha: 0.08),
              borderRadius: radius,
            ),
            child: child,
          );
        }
        return child;
    }
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

  Widget _buildAssistantMessage() {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final assistant = _assistantForMessage();

    // Extract vendor inline <think>...</think> content (if present)
    final extractedThinking = _thinkingRegex
        .allMatches(widget.message.content)
        .map((m) => (m.group(1) ?? '').trim())
        .where((s) => s.isNotEmpty)
        .join('\n\n');
    // Remove all <think> blocks from the visible assistant content
    final contentWithoutThink = extractedThinking.isNotEmpty
        ? widget.message.content.replaceAll(_thinkingRegex, '').trim()
        : widget.message.content;
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

          // Mixed reasoning and tool sections
          if (widget.reasoningSegments != null &&
              widget.reasoningSegments!.isNotEmpty) ...[
            // Build mixed content using tool index ranges carried by segments
            ...() {
              final List<Widget> mixedContent = [];
              final tools = widget.toolParts ?? const <ToolUIPart>[];
              final segments = widget.reasoningSegments!;

              for (int i = 0; i < segments.length; i++) {
                final seg = segments[i];

                // Add the reasoning segment (if any text)
                if (seg.text.isNotEmpty) {
                  mixedContent.add(
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ReasoningSection(
                        text: seg.text,
                        expanded: seg.expanded,
                        loading: seg.loading,
                        startAt: seg.startAt,
                        finishedAt: seg.finishedAt,
                        onToggle: seg.onToggle,
                      ),
                    ),
                  );
                }

                // Determine tool range mapped to this segment: [start, end)
                int start = seg.toolStartIndex;
                final int end = (i < segments.length - 1)
                    ? segments[i + 1].toolStartIndex
                    : tools.length;

                // Clamp to bounds and ensure non-decreasing
                if (start < 0) start = 0;
                if (start > tools.length) start = tools.length;
                final int clampedEnd = end.clamp(start, tools.length);

                for (int k = start; k < clampedEnd; k++) {
                  // Hide builtin_search tool cards; citations still appear via bottom summary card 隐藏内置搜索工具卡片
                  if (tools[k].toolName == 'builtin_search') continue;
                  mixedContent.add(
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ToolCallItem(part: tools[k]),
                    ),
                  );
                }
              }

              return mixedContent;
            }(),
          ] else ...[
            // Fallback to old behavior if no reasoning segments
            // Reasoning preview (if provided) — also support inline <think> blocks
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
              final shouldShowReasoning =
                  hasProvidedReasoning || effectiveReasoningText.isNotEmpty;
              if (!shouldShowReasoning) return const <Widget>[];

              // If using inline <think>, expand by default and treat as loading when streaming until </think> appears
              final usingInlineThink =
                  (widget.reasoningText == null ||
                      widget.reasoningText!.isEmpty) &&
                  extractedThinking.isNotEmpty;
              final effectiveExpanded = usingInlineThink
                  ? (_inlineThinkExpanded ?? true)
                  : widget.reasoningExpanded;
              final collapsedNow =
                  usingInlineThink && (_inlineThinkExpanded == false);
              final effectiveLoading = usingInlineThink
                  ? (widget.message.isStreaming &&
                        !widget.message.content.contains('</think>') &&
                        !collapsedNow)
                  : (widget.reasoningFinishedAt == null);

              return <Widget>[
                _ReasoningSection(
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
                const SizedBox(height: 8),
              ];
            }(),
            // Tool call placeholders before content 隐藏内置搜索工具卡片
            if ((widget.toolParts ?? const <ToolUIPart>[])
                .where((p) => p.toolName != 'builtin_search')
                .isNotEmpty) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: widget.toolParts!
                    .where((p) => p.toolName != 'builtin_search') // 隐藏内置搜索工具卡片
                    .map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ToolCallItem(part: p),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
            ],
          ],
          // Message content with markdown support (fill available width)
          SizedBox(
            width: double.infinity,
            child: _buildAssistantBubbleContainer(
              context: context,
              child: (widget.message.isStreaming && visualContent.isEmpty)
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: Semantics(
                        label: l10n.chatMessageWidgetThinking,
                        child: widget.hideStreamingIndicator
                            ? const SizedBox(height: 16)
                            : const LoadingIndicator(),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Builder(
                          builder: (context) {
                            final bool isDesktop =
                                defaultTargetPlatform == TargetPlatform.macOS ||
                                defaultTargetPlatform ==
                                    TargetPlatform.windows ||
                                defaultTargetPlatform == TargetPlatform.linux;
                            final double baseAssistant = isDesktop
                                ? 14.0
                                : 15.7;
                            Widget assistantContent;
                            if (settings.enableAssistantMarkdown) {
                              assistantContent = MarkdownWithCodeHighlight(
                                text: visualContent,
                                onCitationTap: (id) => _handleCitationTap(id),
                                baseStyle: TextStyle(
                                  fontSize: baseAssistant,
                                  height: 1.5,
                                ),
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
                                key: ValueKey('assistant_${widget.message.id}'),
                                child: DefaultTextStyle.merge(
                                  style: TextStyle(
                                    fontSize: baseAssistant,
                                    height: 1.5,
                                  ),
                                  child: assistantContent,
                                ),
                              ),
                            );
                          },
                        ),
                        // Inline sources removed; show a summary card at bottom instead
                        if (widget.message.isStreaming)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: widget.hideStreamingIndicator
                                ? const SizedBox(height: 16)
                                : const LoadingIndicator(),
                          ),
                        // Translation section (collapsible)
                        if (hasTranslation) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              // Match reasoning section background; no border
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(
                                    alpha:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? 0.25
                                        : 0.30,
                                  ),
                              borderRadius: BorderRadius.circular(16),
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
                                          color: cs.secondary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          l10n.chatMessageWidgetTranslation,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: cs.secondary,
                                          ),
                                        ),
                                        const Spacer(),
                                        Icon(
                                          widget.translationExpanded
                                              ? Lucide.ChevronDown
                                              : Lucide.ChevronRight,
                                          size: 18,
                                          color: cs.secondary,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (widget.translationExpanded) ...[
                                    const SizedBox(height: 8),
                                    if (isTranslating)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          8,
                                          2,
                                          8,
                                          6,
                                        ),
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
                                                        TargetPlatform
                                                            .windows ||
                                                    defaultTargetPlatform ==
                                                        TargetPlatform.linux;
                                                return Text(
                                                  l10n.chatMessageWidgetTranslating,
                                                  style: TextStyle(
                                                    fontSize: isDesktop
                                                        ? 14.0
                                                        : 15.5,
                                                    color: cs.onSurface
                                                        .withValues(alpha: 0.5),
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
                                        padding: const EdgeInsets.fromLTRB(
                                          8,
                                          2,
                                          8,
                                          6,
                                        ),
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
                                                        TargetPlatform
                                                            .windows ||
                                                    defaultTargetPlatform ==
                                                        TargetPlatform.linux;
                                                final double baseTranslation =
                                                    isDesktop ? 14.0 : 15.5;
                                                Widget translationContent;
                                                if (settings
                                                    .enableAssistantMarkdown) {
                                                  translationContent =
                                                      MarkdownWithCodeHighlight(
                                                        text: translationText,
                                                        onCitationTap: (id) =>
                                                            _handleCitationTap(
                                                              id,
                                                            ),
                                                        baseStyle: TextStyle(
                                                          fontSize:
                                                              baseTranslation,
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
                        ],
                      ],
                    ),
            ),
          ),
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
                                  : () async {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (dctx) => AlertDialog(
                                          backgroundColor: Theme.of(
                                            dctx,
                                          ).colorScheme.surface,
                                          title: Text(
                                            l10n.chatMessageWidgetRegenerateConfirmTitle,
                                          ),
                                          content: Text(
                                            l10n.chatMessageWidgetRegenerateConfirmContent,
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(dctx).pop(false),
                                              child: Text(
                                                l10n.chatMessageWidgetRegenerateConfirmCancel,
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(dctx).pop(true),
                                              child: Text(
                                                l10n.chatMessageWidgetRegenerateConfirmOk,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (ok == true) widget.onRegenerate!();
                                    },
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
  const LoadingIndicator({super.key});
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
    final base = cs.primary;

    return SizedBox(
      height: 16,
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
                padding: EdgeInsets.only(right: i == 2 ? 0 : 6),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 9,
                    height: 9,
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

class _ToolCallItem extends StatefulWidget {
  const _ToolCallItem({required this.part});
  final ToolUIPart part;

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

  String _titleFor(
    BuildContext context,
    String name,
    Map<String, dynamic> args, {
    required bool isResult,
  }) {
    final l10n = AppLocalizations.of(context)!;
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
    final hasImages = _imagePaths.isNotEmpty;
    final l10n = AppLocalizations.of(context)!;

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

    final bg = cs.primaryContainer.withValues(alpha: isDark ? 0.25 : 0.30);

    return IosCardPress(
      borderRadius: BorderRadius.circular(16),
      baseColor: bg,
      pressedScale: 1.0,
      duration: const Duration(milliseconds: 260),
      onTap: isPendingApproval ? null : () => _showDetail(context),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
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
                    child: Icon(Lucide.Shield, size: 18, color: cs.primary),
                  ),
                )
              else if (widget.part.loading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
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
                      color: cs.secondary,
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
                        color: isPendingApproval ? cs.primary : cs.secondary,
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
                          color: cs.primary.withValues(alpha: 0.8),
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: isDark ? 0.06 : 0.04),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _argsSummary(widget.part.arguments),
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: cs.onSurface.withValues(alpha: 0.6),
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
                    color: cs.primary,
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
  final VoidCallback onTap;

  /// When true, uses a solid fill background; when false, outline style.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            color: color,
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
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final loading = widget.loading;

    // Android-like surface style
    final bg = cs.primaryContainer.withValues(alpha: isDark ? 0.25 : 0.30);

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
            SvgPicture.asset(
              'assets/icons/deepthink.svg',
              width: 18,
              height: 18,
              colorFilter: ColorFilter.mode(cs.secondary, BlendMode.srcIn),
            ),
            const SizedBox(width: 8),
            _Shimmer(
              enabled: loading,
              child: Text(
                l10n.chatMessageWidgetDeepThinking,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: cs.secondary,
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
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.secondary.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ),
            // No header marquee; content area handles scrolling when loading
            const Spacer(),
            AnimatedRotation(
              turns: widget.expanded ? 0.25 : 0.0, // right -> down
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOutCubic,
              child: Icon(Lucide.ChevronRight, size: 18, color: cs.secondary),
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
      alignment: Alignment.topCenter,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
