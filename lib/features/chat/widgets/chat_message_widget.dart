import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;
import '../../../core/services/haptics.dart';
import 'package:flutter/scheduler.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../desktop/desktop_context_menu.dart';
import '../../../desktop/menu_anchor.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'dart:io' show File;
import 'package:open_filex/open_filex.dart';
// import 'package:easy_image_viewer/easy_image_viewer.dart';
import 'dart:convert';
import '../../../utils/platform_utils.dart';
import '../pages/image_viewer_page.dart';
import '../../../core/models/chat_message.dart';
import '../../../icons/lucide_adapter.dart';
// import '../../../theme/design_tokens.dart';
import '../../../core/providers/user_provider.dart';
import 'package:intl/intl.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../../utils/avatar_cache.dart';
import '../../../core/providers/tts_provider.dart';
import '../../../shared/widgets/markdown_with_highlight.dart';
import '../../../shared/widgets/typing_indicator.dart';
import '../../../shared/widgets/animated_loading_text.dart';
import '../../../shared/widgets/snackbar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/model_provider.dart';

class ChatMessageWidget extends StatefulWidget {
  final ChatMessage message;
  final Widget? modelIcon;
  final bool showModelIcon;
  // Assistant identity override
  final bool useAssistantAvatar;
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

  const ChatMessageWidget({
    super.key,
    required this.message,
    this.modelIcon,
    this.showModelIcon = true,
    this.useAssistantAvatar = false,
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
  });

  @override
  State<ChatMessageWidget> createState() => _ChatMessageWidgetState();
}

class _ChatMessageWidgetState extends State<ChatMessageWidget> {
  // Match vendor inline thinking blocks: <think>...</think> (or until end)
  static final RegExp THINKING_REGEX = RegExp(r"<think>([\s\S]*?)(?:</think>|$)", dotAll: true);
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  final ScrollController _reasoningScroll = ScrollController();
  bool _tickActive = false;
  // Local expand state for inline <think> card (defaults to expanded)
  bool? _inlineThinkExpanded;
  bool _inlineThinkManuallyToggled = false;
  bool _inlineThinkWasLoading = false;
  // User message context menu state
  final GlobalKey _userBubbleKey = GlobalKey();
  OverlayEntry? _userMenuOverlay;
  bool _userMenuActive = false; // for bubble highlight/scale
  late final Ticker _ticker = Ticker((_) {
    if (mounted && _tickActive) setState(() {});
  });

  @override
  void initState() {
    super.initState();
    _syncTicker();

    // Apply auto-collapse on first mount when inline <think> already finished
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyAutoCollapseInlineThinkIfFinished(oldWidget: null);
    });
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
    final newExtracted = THINKING_REGEX
        .allMatches(widget.message.content)
        .map((m) => (m.group(1) ?? '').trim())
        .where((s) => s.isNotEmpty)
        .join('\n\n');
    final usingInlineThinkNew = (widget.reasoningText == null || widget.reasoningText!.isEmpty) && newExtracted.isNotEmpty;
    final loadingNew = usingInlineThinkNew && widget.message.isStreaming && !widget.message.content.contains('</think>');

    bool loadingOld = false;
    if (oldWidget != null) {
      final oldExtracted = THINKING_REGEX
          .allMatches(oldWidget.message.content)
          .map((m) => (m.group(1) ?? '').trim())
          .where((s) => s.isNotEmpty)
          .join('\n\n');
      final usingInlineThinkOld = (oldWidget.reasoningText == null || oldWidget.reasoningText!.isEmpty) && oldExtracted.isNotEmpty;
      loadingOld = usingInlineThinkOld && oldWidget.message.isStreaming && !oldWidget.message.content.contains('</think>');
    }

    // Persist last loading to assist other checks
    _inlineThinkWasLoading = loadingNew;

    final autoCollapse = context.read<SettingsProvider>().autoCollapseThinking;

    // If finished now (not loading), inline think is used, and auto-collapse is on
    // Only collapse when user hasn't manually toggled; also if we don't yet have a chosen state.
    final finishedNow = usingInlineThinkNew && !loadingNew;
    final justFinished = oldWidget != null ? (loadingOld && finishedNow) : finishedNow;

    if (autoCollapse && finishedNow && justFinished) {
      if (!_inlineThinkManuallyToggled || _inlineThinkExpanded == null) {
        if (mounted) setState(() => _inlineThinkExpanded = false);
        return;
      }
    }

    // On first mount where already finished and no user choice yet, honor autoCollapse
    if (oldWidget == null && usingInlineThinkNew && !loadingNew && _inlineThinkExpanded == null) {
      if (autoCollapse) {
        if (mounted) setState(() => _inlineThinkExpanded = false);
      } else {
        if (mounted) setState(() => _inlineThinkExpanded = true);
      }
    }
  }

  void _syncTicker() {
    final loading = widget.reasoningStartAt != null && widget.reasoningFinishedAt == null;
    _tickActive = loading;
    if (loading) {
      if (!_ticker.isActive) _ticker.start();
    } else {
      if (_ticker.isActive) _ticker.stop();
    }
  }

  String _resolveModelDisplayName(SettingsProvider settings) {
    final modelId = widget.message.modelId;
    if (modelId == null || modelId.trim().isEmpty) {
      return 'AI Assistant';
    }

    final providerId = widget.message.providerId;
    if (providerId != null && providerId.isNotEmpty) {
      try {
        final cfg = settings.getProviderConfig(providerId);
        final ov = cfg.modelOverrides[modelId] as Map?;
        final name = (ov?['name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) {
          return name;
        }
      } catch (_) {
        // ignore lookup failures; fall through to inferred name.
      }
    }

    final inferred = ModelRegistry.infer(ModelInfo(id: modelId, displayName: modelId));
    final fallback = inferred.displayName.trim();
    return fallback.isNotEmpty ? fallback : modelId;
  }

  @override
  void dispose() {
    try { _userMenuOverlay?.remove(); } catch (_) {}
    _userMenuOverlay = null;
    _ticker.dispose();
    _reasoningScroll.dispose();
    super.dispose();
  }

  void _removeUserMenuOverlay() {
    try { _userMenuOverlay?.remove(); } catch (_) {}
    _userMenuOverlay = null;
    if (mounted && _userMenuActive) setState(() => _userMenuActive = false);
  }

  void _showUserContextMenu() {
    // Haptic feedback (optional)
    try { Haptics.light(); } catch (_) {}

    final box = _userBubbleKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context);
    final overlayBox = overlay?.context.findRenderObject() as RenderBox?;
    if (box == null || overlayBox == null || overlay == null) return;

    final bubbleTopLeft = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    final bubbleSize = box.size;
    final screenSize = overlayBox.size;
    final insets = MediaQuery.of(context).padding; // status bar / gesture insets
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
    final availableBelow = (screenSize.height - safeBottom) - (bubbleTopLeft.dy + bubbleSize.height + gap);
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

    if (mounted) setState(() => _userMenuActive = true);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'context-menu',
      barrierColor: Colors.black.withOpacity(0.08),
      pageBuilder: (ctx, _, __) {
        return Stack(
          children: [
            // Positioned popup
            Positioned(
              left: x,
              top: y,
              width: menuWidth,
              child: _AnimatedPopup(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1C1C1E).withOpacity(0.66)
                            : Colors.white.withOpacity(0.66),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : cs.outlineVariant.withOpacity(0.2),
                          width: 1,
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
                            await Clipboard.setData(ClipboardData(text: widget.message.content));
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
          )],
        );
      },
    ).whenComplete(() {
      if (mounted) setState(() => _userMenuActive = false);
    });
  }

  Widget _buildUserAvatar(UserProvider userProvider, ColorScheme cs) {
    Widget avatarContent;

    if (userProvider.avatarType == 'emoji' && userProvider.avatarValue != null) {
      avatarContent = Center(
        child: Text(
          userProvider.avatarValue!,
          style: const TextStyle(fontSize: 18),
        ),
      );
    } else if (userProvider.avatarType == 'url' && userProvider.avatarValue != null) {
      final url = userProvider.avatarValue!;
      avatarContent = FutureBuilder<String?>(
        future: AvatarCache.getPath(url),
        builder: (ctx, snap) {
          final p = snap.data;
          if (p != null && !kIsWeb && File(p).existsSync()) {
            return SizedBox(
              width: 32,
              height: 32,
              child: ClipOval(
                child: Image.file(
                  File(p),
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                ),
              ),
            );
          }
          if (p != null && kIsWeb && p.startsWith('data:')) {
            return SizedBox(
              width: 32,
              height: 32,
              child: ClipOval(
                child: Image.network(
                  p,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                ),
              ),
            );
          }
          return SizedBox(
            width: 32,
            height: 32,
            child: ClipOval(
              child: Image.network(
                url,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Lucide.User,
                  size: 18,
                  color: cs.primary,
                ),
              ),
            ),
          );
        },
      );
    } else if (userProvider.avatarType == 'file' && userProvider.avatarValue != null && !kIsWeb) {
      avatarContent = SizedBox(
        width: 32,
        height: 32,
        child: ClipOval(
          child: Image.file(
            File(SandboxPathResolver.fix(userProvider.avatarValue!)),
            width: 32,
            height: 32,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Icon(
              Lucide.User,
              size: 18,
              color: cs.primary,
            ),
          ),
        ),
      );
    } else {
      avatarContent = Icon(
        Lucide.User,
        size: 18,
        color: cs.primary,
      );
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.1),
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
              if (settings.showUserNameTimestamp)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      userProvider.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _dateFormat.format(widget.message.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withOpacity(0.5),
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
          // Message content (long-press for context menu)
          GestureDetector(
            onLongPressStart: (_) => _showUserContextMenu(),
            behavior: HitTestBehavior.translucent,
            child: Container(
              key: _userBubbleKey,
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? cs.primary.withOpacity(0.15)
                    : cs.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                if (parsed.text.isNotEmpty)
                  Text(
                    parsed.text,
                    style: TextStyle(
                      fontSize: 15.5, // ~112% larger default for user text
                      height: 1.4,
                      color: cs.onSurface,
                      // // Keep user text slightly bolder on non‑iOS; normal on iOS
                      // fontWeight: Theme.of(context).platform == TargetPlatform.iOS
                      //     ? FontWeight.w400
                      //     : FontWeight.w500,
                    ),
                  ),
                if (parsed.images.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Builder(builder: (context) {
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
                              Navigator.of(context).push(PageRouteBuilder(
                                pageBuilder: (_, __, ___) => ImageViewerPage(images: imgs, initialIndex: idx),
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
                                        begin: const Offset(0, 0.02), // subtle upward drift
                                        end: Offset.zero,
                                      ).animate(curved),
                                      child: child,
                                    ),
                                  );
                                },
                              ));
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Hero(
                                tag: 'img:$p',
                                child: kIsWeb
                                    ? Container(
                                        width: 96,
                                        height: 96,
                                        color: Colors.black12,
                                        child: const Icon(Icons.image_not_supported),
                                      )
                                    : Image.file(
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
                  }),
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
                          overlayColor: MaterialStateProperty.resolveWith(
                                (states) => cs.primary.withOpacity(states.contains(MaterialState.pressed) ? 0.14 : 0.08),
                          ),
                          splashColor: cs.primary.withOpacity(0.18),
                          onTap: () async {
                            try {
                              final fixed = SandboxPathResolver.fix(d.path);
                              final f = File(fixed);
                              if (!(await f.exists())) {
                                showAppSnackBar(
                                  context,
                                  message: l10n.chatMessageWidgetFileNotFound(d.fileName),
                                  type: NotificationType.error,
                                );
                                return;
                              }
                              final res = await PlatformUtils.callPlatformMethod(
                                () => OpenFilex.open(fixed, type: d.mime),
                                fallback: OpenResult(
                                  type: ResultType.error,
                                  message: 'File opening not supported on this platform',
                                ),
                              );
                              
                              if (res != null && res.type != ResultType.done) {
                                showAppSnackBar(
                                  context,
                                  message: l10n.chatMessageWidgetCannotOpenFile(res.message ?? res.type.toString()),
                                  type: NotificationType.error,
                                );
                              }
                            } catch (e) {
                              showAppSnackBar(
                                context,
                                message: l10n.chatMessageWidgetOpenFileError(e.toString()),
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
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.insert_drive_file, size: 16),
                                  const SizedBox(width: 6),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 180),
                                    child: Text(d.fileName, overflow: TextOverflow.ellipsis),
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
          if (showUserActions || showVersionSwitcher) ...[
            SizedBox(height: showUserActions ? 4 : 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (showUserActions) ...[
                  IconButton(
                    icon: Icon(Lucide.Copy, size: 16),
                    onPressed: widget.onCopy ?? () {
                      Clipboard.setData(ClipboardData(text: widget.message.content));
                      showAppSnackBar(
                        context,
                        message: l10n.chatMessageWidgetCopiedToClipboard,
                        type: NotificationType.success,
                      );
                    },
                    visualDensity: VisualDensity.compact,
                    iconSize: 16,
                  ),
                  IconButton(
                    icon: Icon(Lucide.RefreshCw, size: 16),
                    onPressed: widget.onResend,
                    tooltip: l10n.chatMessageWidgetResendTooltip,
                    visualDensity: VisualDensity.compact,
                    iconSize: 16,
                  ),
                  IconButton(
                    icon: Icon(Lucide.Ellipsis, size: 16),
                    onPressed: widget.onMore,
                    tooltip: l10n.chatMessageWidgetMoreTooltip,
                    visualDensity: VisualDensity.compact,
                    iconSize: 16,
                  ),
                ],
                if (showVersionSwitcher) ...[
                  if (showUserActions) const SizedBox(width: 8),
                  _BranchSelector(
                    index: widget.versionIndex ?? 0,
                    total: widget.versionCount ?? 1,
                    onPrev: widget.onPrevVersion,
                    onNext: widget.onNextVersion,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
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

    // Extract vendor inline <think>...</think> content (if present)
    final extractedThinking = THINKING_REGEX
        .allMatches(widget.message.content)
        .map((m) => (m.group(1) ?? '').trim())
        .where((s) => s.isNotEmpty)
        .join('\n\n');
    // Remove all <think> blocks from the visible assistant content
    final contentWithoutThink = extractedThinking.isNotEmpty
        ? widget.message.content.replaceAll(THINKING_REGEX, '').trim()
        : widget.message.content;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                widget.modelIcon ?? Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: cs.secondary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Lucide.Bot, size: 18, color: cs.secondary),
                ),
                const SizedBox(width: 8),
              ],
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (settings.showModelNameTimestamp)
                    Text(
                      widget.useAssistantAvatar
                          ? (widget.assistantName?.trim().isNotEmpty == true ? widget.assistantName!.trim() : 'Assistant')
                          : _resolveModelDisplayName(settings),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface.withOpacity(0.7),
                      ),
                    ),
                  Builder(builder: (context) {
                    final List<Widget> rowChildren = [];
                    if (settings.showModelNameTimestamp) {
                      rowChildren.add(Text(
                        _dateFormat.format(widget.message.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withOpacity(0.5),
                        ),
                      ));
                    }
                    if (widget.showTokenStats) {
                      final tokenUsage = widget.message.tokenUsage;
                      if (tokenUsage != null) {
                        if (rowChildren.isNotEmpty) rowChildren.add(const SizedBox(width: 8));
                        // Build token display parts
                        final List<String> tokenParts = [];

                        // Always show input and output
                        tokenParts.add('${tokenUsage.promptTokens}↓');
                        tokenParts.add('${tokenUsage.completionTokens}↑');

                        // Only show thinking tokens if present
                        if (tokenUsage.thoughtTokens > 0) {
                          tokenParts.add('${tokenUsage.thoughtTokens}💭');
                        }

                        // Only show cached tokens if present
                        if (tokenUsage.cachedTokens > 0) {
                          tokenParts.add('${tokenUsage.cachedTokens}♻');
                        }

                        final String tokenText = tokenParts.join(' ');

                        // Build detailed tooltip lines
                        final List<String> tooltipLines = [
                          '输入: ${tokenUsage.promptTokens}',
                          '输出: ${tokenUsage.completionTokens}',
                          if (tokenUsage.thoughtTokens > 0) '思考: ${tokenUsage.thoughtTokens}',
                          if (tokenUsage.cachedTokens > 0) '缓存: ${tokenUsage.cachedTokens}',
                          '总计: ${tokenUsage.totalTokens}',
                        ];

                        rowChildren.add(_TokenUsageDisplay(
                          tokenText: tokenText,
                          tooltipLines: tooltipLines,
                          hasCache: tokenUsage.cachedTokens > 0,
                          colorScheme: cs,
                        ));
                      } else if (widget.message.totalTokens != null) {
                        // Fallback to old totalTokens display
                        if (rowChildren.isNotEmpty) rowChildren.add(const SizedBox(width: 8));
                        rowChildren.add(Text(
                          '${widget.message.totalTokens} tokens',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withOpacity(0.5),
                          ),
                        ));
                      }
                    }
                    return rowChildren.isNotEmpty
                        ? Row(children: rowChildren)
                        : const SizedBox.shrink();
                  }),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Mixed reasoning and tool sections
          if (widget.reasoningSegments != null && widget.reasoningSegments!.isNotEmpty) ...[
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
              final hasProvidedReasoning = (widget.reasoningText != null && widget.reasoningText!.isNotEmpty) || widget.reasoningLoading;
              final effectiveReasoningText =
                  (widget.reasoningText != null && widget.reasoningText!.isNotEmpty)
                      ? widget.reasoningText!
                      : extractedThinking;
              final shouldShowReasoning = hasProvidedReasoning || effectiveReasoningText.isNotEmpty;
              if (!shouldShowReasoning) return const <Widget>[];

              // If using inline <think>, expand by default and treat as loading when streaming until </think> appears
              final usingInlineThink = (widget.reasoningText == null || widget.reasoningText!.isEmpty) && extractedThinking.isNotEmpty;
              final effectiveExpanded = usingInlineThink ? (_inlineThinkExpanded ?? true) : widget.reasoningExpanded;
              final collapsedNow = usingInlineThink && (_inlineThinkExpanded == false);
              final effectiveLoading = usingInlineThink
                  ? (widget.message.isStreaming && !widget.message.content.contains('</think>') && !collapsedNow)
                  : (widget.reasoningFinishedAt == null);

              return <Widget>[
                _ReasoningSection(
                  text: effectiveReasoningText,
                  expanded: effectiveExpanded,
                  loading: effectiveLoading,
                  startAt: usingInlineThink ? null : widget.reasoningStartAt,
                  finishedAt: usingInlineThink ? null : widget.reasoningFinishedAt,
                  onToggle: usingInlineThink
                      ? () => setState(() { _inlineThinkExpanded = !(_inlineThinkExpanded ?? true); _inlineThinkManuallyToggled = true; })
                      : widget.onToggleReasoning,
                ),
                const SizedBox(height: 8),
              ];
            }(),
            // Tool call placeholders before content 隐藏内置搜索工具卡片
            if ((widget.toolParts ?? const <ToolUIPart>[]).where((p) => p.toolName != 'builtin_search').isNotEmpty) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: widget.toolParts!
                    .where((p) => p.toolName != 'builtin_search') // 隐藏内置搜索工具卡片
                    .map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ToolCallItem(part: p),
                ))
                    .toList(),
              ),
              const SizedBox(height: 8),
            ],
          ],
          // Message content with markdown support (fill available width)
          Container(
            width: double.infinity,
            child: widget.message.isStreaming && contentWithoutThink.isEmpty
                ? AnimatedLoadingText(
                    text: l10n.chatMessageWidgetThinking,
                    textStyle: TextStyle(
                      fontSize: 14,
                      color: cs.onSurface.withOpacity(0.6),
                      fontStyle: FontStyle.italic,
                    ),
                    dotSize: 8,
                    dotGap: 3,
                    style: LoadingTextStyle.modern, // 可以切换为 shimmer, pulse, typewriter, modern
                  )
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                SelectionArea(
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(fontSize: 15.7, height: 1.5),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: double.infinity),
                      child: MarkdownWithCodeHighlight(
                        text: contentWithoutThink,
                        onCitationTap: (id) => _handleCitationTap(id),
                      ),
                    ),
                  ),
                ),
                // Inline sources removed; show a summary card at bottom instead
                if (widget.message.isStreaming)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: DotsTypingIndicator(color: cs.primary, dotSize: 7, gap: 3),
                  ),
                // Translation section (collapsible)
                if (widget.message.translation != null && widget.message.translation!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      // Match reasoning section background; no border
                      color: Theme.of(context).colorScheme.primaryContainer
                          .withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.25 : 0.30),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: const Cubic(0.2, 0.8, 0.2, 1),
                      alignment: Alignment.topCenter,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: widget.onToggleTranslation,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                          ),
                          if (widget.translationExpanded) ...[
                            const SizedBox(height: 8),
                            if (widget.message.translation == l10n.chatMessageWidgetTranslating)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
                                child: Row(
                                  children: [
                                    _LoadingIndicator(),
                                    const SizedBox(width: 8),
                                    Text(l10n.chatMessageWidgetTranslating, style: TextStyle(fontSize: 15.5, color: cs.onSurface.withOpacity(0.5), fontStyle: FontStyle.italic)),
                                  ],
                                ),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
                                child: SelectionArea(
                                  child: DefaultTextStyle.merge(
                                    style: const TextStyle(fontSize: 15.5, height: 1.4),
                                    child: MarkdownWithCodeHighlight(
                                      text: widget.message.translation!,
                                      onCitationTap: (id) => _handleCitationTap(id),
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
          // Sources summary card (tap to open full citations)
          if (_latestSearchItems().isNotEmpty) ...[
            const SizedBox(height: 8),
            _SourcesSummaryCard(
              count: _latestSearchItems().length,
              onTap: () => _showCitationsSheet(_latestSearchItems()),
            ),
          ],
          // Action buttons（生成中隐藏，完成后显示）
          if (!widget.message.isStreaming) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: Icon(Lucide.Copy, size: 16),
                  onPressed: widget.onCopy ?? () {
                    Clipboard.setData(ClipboardData(text: widget.message.content));
                    showAppSnackBar(
                      context,
                      message: l10n.chatMessageWidgetCopiedToClipboard,
                      type: NotificationType.success,
                    );
                  },
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                ),
                IconButton(
                  icon: Icon(Lucide.RefreshCw, size: 16),
                  onPressed: widget.onRegenerate,
                  tooltip: l10n.chatMessageWidgetRegenerateTooltip,
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                ),
                Consumer<TtsProvider>(
                  builder: (context, tts, _) => IconButton(
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
                      child: Icon(
                        tts.isSpeaking ? Lucide.CircleStop : Lucide.Volume2,
                        key: ValueKey(tts.isSpeaking ? 'stop' : 'speak'),
                        size: 16,
                      ),
                    ),
                    onPressed: widget.onSpeak,
                    tooltip: tts.isSpeaking ? l10n.chatMessageWidgetStopTooltip : l10n.chatMessageWidgetSpeakTooltip,
                    visualDensity: VisualDensity.compact,
                    iconSize: 16,
                  ),
                ),
                IconButton(
                  icon: Icon(Lucide.Languages, size: 16),
                  onPressed: widget.onTranslate,
                  tooltip: l10n.chatMessageWidgetTranslateTooltip,
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                ),
                IconButton(
                  icon: Icon(Lucide.Ellipsis, size: 16),
                  onPressed: widget.onMore,
                  tooltip: l10n.chatMessageWidgetMoreTooltip,
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
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
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Try resolve citation id -> url from the latest search_web tool results of this assistant message
  void _handleCitationTap(String id) async {
    final l10n = AppLocalizations.of(context)!;
    final items = _latestSearchItems();
    final match = items.cast<Map<String, dynamic>?>().firstWhere(
      (e) => (e?['id']?.toString() ?? '') == id,
      orElse: () => null,
    );
    final url = match?['url']?.toString();
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
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        showAppSnackBar(
          context,
          message: l10n.chatMessageWidgetCannotOpenUrl(url),
          type: NotificationType.error,
        );
      }
    } catch (_) {
      if (context.mounted) {
        showAppSnackBar(
          context,
          message: l10n.chatMessageWidgetOpenLinkError,
          type: NotificationType.error,
        );
      }
    }
  }

  // Extract items from the last search_web or builtin_search tool result for this assistant message
  List<Map<String, dynamic>> _latestSearchItems() {
    final parts = widget.toolParts ?? const <ToolUIPart>[];
    for (int i = parts.length - 1; i >= 0; i--) {
      final p = parts[i];
      if ((p.toolName == 'search_web' || p.toolName == 'builtin_search') && (p.content?.isNotEmpty ?? false)) {
        try {
          final obj = jsonDecode(p.content!) as Map<String, dynamic>;
          final arr = obj['items'] as List? ?? const <dynamic>[];
          return [
            for (final it in arr)
              if (it is Map)
                it.cast<String, dynamic>()
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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
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
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
                              _SourceRow(
                                index: (items[i]['index'] ?? (i + 1)).toString(),
                                title: (items[i]['title'] ?? '').toString(),
                                url: (items[i]['url'] ?? '').toString(),
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
            if (p != null && !kIsWeb && File(p).existsSync()) {
              return ClipOval(
                child: Image.file(
                  File(p),
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                ),
              );
            }
            if (p != null && kIsWeb && p.startsWith('data:')) {
              return ClipOval(
                child: Image.network(
                  p,
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
      if (!kIsWeb && (av.startsWith('/') || av.contains(':'))) {
        final fixed = SandboxPathResolver.fix(av);
        return ClipOval(
          child: Image.file(File(fixed), width: 32, height: 32, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _assistantInitial(cs)),
        );
      }
      // treat as emoji or single char label
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: cs.primary.withOpacity(0.1), shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(av.characters.take(1).toString(), style: const TextStyle(fontSize: 18)),
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
      decoration: BoxDecoration(color: cs.primary.withOpacity(0.1), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(ch, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
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
      setState(() { _opacity = 1.0; });
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
  const _MenuItem({required this.icon, required this.label, this.onTap, this.danger = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = danger ? Colors.red.shade600 : cs.onSurface;
    final ic = danger ? Colors.red.shade600 : cs.onSurface.withOpacity(0.9);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          try { Haptics.light(); } catch (_) {}
          onTap?.call();
        },
        overlayColor: MaterialStatePropertyAll(cs.primary.withOpacity(0.06)),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Icon(icon, size: 18, color: ic),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: TextStyle(fontSize: 14.5, color: fg))),
            ],
          ),
        ),
      ),
    );
  }
}

class _BranchSelector extends StatelessWidget {
  const _BranchSelector({required this.index, required this.total, this.onPrev, this.onNext});
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
        InkWell(
          onTap: canPrev ? onPrev : null,
          borderRadius: BorderRadius.circular(6),
          child: Icon(Lucide.ChevronLeft, size: 16, color: canPrev ? cs.onSurface : cs.onSurface.withOpacity(0.35)),
        ),
        const SizedBox(width: 6),
        Text('${index + 1}/$total', style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.8), fontWeight: FontWeight.w600)),
        const SizedBox(width: 6),
        InkWell(
          onTap: canNext ? onNext : null,
          borderRadius: BorderRadius.circular(6),
          child: Icon(Lucide.ChevronRight, size: 16, color: canNext ? cs.onSurface : cs.onSurface.withOpacity(0.35)),
        ),
      ],
    );
  }
}

// Loading indicator similar to OpenAI's breathing circle
class _LoadingIndicator extends StatefulWidget {
  @override
  State<_LoadingIndicator> createState() => _LoadingIndicatorState();
}

class _LoadingIndicatorState extends State<_LoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    // Smoother, symmetric breathing with reverse to avoid jump cuts
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    )..repeat(reverse: true);

    _curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) {
        // Scale and opacity gently breathe in sync
        final scale = 0.9 + 0.2 * _curve.value; // 0.9 -> 1.1
        final opacity = 0.6 + 0.4 * _curve.value; // 0.6 -> 1.0
        final base = cs.primary;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: base.withOpacity(opacity),
              boxShadow: [
                BoxShadow(
                  color: base.withOpacity(0.35 * opacity),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        );
      },
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

class _ToolCallItem extends StatelessWidget {
  const _ToolCallItem({required this.part});
  final ToolUIPart part;

  IconData _iconFor(String name) {
    switch (name) {
      case 'create_memory':
      case 'edit_memory':
        return Lucide.Library;
      case 'delete_memory':
        return Lucide.Trash2;
      case 'search_web':
        return Lucide.Earth;
      case 'builtin_search':
        return Lucide.Search;
      default:
        return Lucide.Wrench;
    }
  }


  String _titleFor(BuildContext context, String name, Map<String, dynamic> args, {required bool isResult}) {
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
        return isResult ? l10n.chatMessageWidgetToolResult(name) : l10n.chatMessageWidgetToolCall(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = cs.primaryContainer.withOpacity(isDark ? 0.25 : 0.30);
    final fg = cs.onPrimaryContainer;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showDetail(context),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: part.loading
                    ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                  ),
                )
                    : Icon(_iconFor(part.toolName), size: 18, color: cs.secondary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _titleFor(context, part.toolName, part.arguments, isResult: !part.loading),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.secondary),
                    ),
                    // No inline result preview; tap to view details in sheet
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final argsPretty = const JsonEncoder.withIndent('  ').convert(part.arguments);
    final resultText = (part.content ?? '').isNotEmpty ? part.content! : l10n.chatMessageWidgetNoResultYet;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
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
                        Icon(_iconFor(part.toolName), size: 18, color: cs.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _titleFor(context, part.toolName, part.arguments, isResult: !part.loading),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(l10n.chatMessageWidgetArguments, style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.6))),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF7F7F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
                      ),
                      child: SelectableText(argsPretty, style: const TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(height: 12),
                    Text(l10n.chatMessageWidgetResult, style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.6))),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF7F7F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
                      ),
                      child: SelectableText(resultText, style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SourcesList extends StatelessWidget {
  const _SourcesList({required this.items});
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              l10n.chatMessageWidgetCitationsTitle(items.length),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface.withOpacity(0.75)),
            ),
          ),
          for (int i = 0; i < items.length; i++)
            _SourceRow(index: (items[i]['index'] ?? (i + 1)).toString(), title: (items[i]['title'] ?? '').toString(), url: (items[i]['url'] ?? '').toString()),
        ],
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.index, required this.title, required this.url});
  final String index;
  final String title;
  final String url;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.20),
              borderRadius: BorderRadius.circular(9),
            ),
            margin: const EdgeInsets.only(top: 2),
            child: Text(index, style: const TextStyle(fontSize: 11)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: () async {
                try {
                  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                } catch (_) {}
              },
              child: Text(
                title.isNotEmpty ? title : url,
                style: TextStyle(color: cs.primary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            // Match deep thinking (reasoning) card background
            color: cs.primaryContainer.withOpacity(
              Theme.of(context).brightness == Brightness.dark ? 0.25 : 0.30,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Lucide.BookOpen, size: 16, color: cs.secondary),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.secondary)),
            ],
          ),
        ),
      ),
    );
  }
}

ImageProvider _imageProviderFor(String src) {
  if (src.startsWith('http://') || src.startsWith('https://')) {
    return NetworkImage(src);
  }
  if (src.startsWith('data:')) {
    try {
      final base64Marker = 'base64,';
      final idx = src.indexOf(base64Marker);
      if (idx != -1) {
        final b64 = src.substring(idx + base64Marker.length);
        return MemoryImage(base64Decode(b64));
      }
    } catch (_) {}
  }
  return FileImage(File(src));
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

class _ReasoningSectionState extends State<_ReasoningSection> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = Ticker((_) => setState(() {}));
  final ScrollController _scroll = ScrollController();
  bool _hasOverflow = false;

  String _sanitize(String s) {
    return s.replaceAll('\r', '').trim();
  }

  String _elapsed() {
    final start = widget.startAt;
    if (start == null) return '';
    final end = widget.finishedAt ?? DateTime.now();
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
    _scroll.dispose();
    super.dispose();
  }

  void _checkOverflow() {
    if (!_scroll.hasClients) return;
    final over = _scroll.position.maxScrollExtent > 0.5;
    if (over != _hasOverflow && mounted) setState(() => _hasOverflow = over);
  }

  String _sanitizedeepthink(String s) {
    // 统一换行
    s = s.replaceAll('\r\n', '\n');

    // 去掉首尾零宽字符（模型有时会插入）
    s = s
        .replaceAll(RegExp(r'^[\u200B\u200C\u200D\uFEFF]+'), '')
        .replaceAll(RegExp(r'[\u200B\u200C\u200D\uFEFF]+$'), '');

    // 去掉**开头**的纯空白行
    s = s.replaceFirst(RegExp(r'^\s*\n+'), '');

    // 去掉**结尾**的纯空白行
    s = s.replaceFirst(RegExp(r'\n+\s*$'), '');

    return s;
  }


  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final loading = widget.loading;

    // Android-like surface style
    final bg = cs.primaryContainer.withOpacity(isDark ? 0.25 : 0.30);
    final fg = cs.onPrimaryContainer;

    final curve = const Cubic(0.2, 0.8, 0.2, 1);

    // Build a compact header with optional scrolling preview when loading
    Widget header = InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: widget.onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
              child: Text(l10n.chatMessageWidgetDeepThinking, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.secondary)),
            ),
            const SizedBox(width: 8),
            if (widget.startAt != null)
              _Shimmer(
                enabled: loading,
                child: Text(_elapsed(), style: TextStyle(fontSize: 13, color: cs.secondary.withOpacity(0.9))),
              ),
            // No header marquee; content area handles scrolling when loading
            const Spacer(),
            Icon(
              widget.expanded
                  ? Lucide.ChevronDown
                  : (loading && !widget.expanded ? Lucide.ChevronRight : Lucide.ChevronRight),
              size: 18,
              color: cs.secondary,
            ),
          ],
        ),
      ),
    );

// 抽公共样式，继承当前 DefaultTextStyle（从而继承正确的颜色）
    final TextStyle baseStyle =
    DefaultTextStyle.of(context).style.copyWith(fontSize: 12.5, height: 1.32);

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
    Widget body = Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
      child: MarkdownWithCodeHighlight(
        text: display.isNotEmpty ? display : '…',
        baseStyle: baseStyle,
      ),
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
                WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
                return false;
              },
              child: SingleChildScrollView(
                controller: _scroll,
                physics: const BouncingScrollPhysics(),
                child: MarkdownWithCodeHighlight(
                  text: display.isNotEmpty ? display : '…',
                  baseStyle: baseStyle,
                ),
              ),
            ),
          )
              : SingleChildScrollView(
            controller: _scroll,
            physics: const NeverScrollableScrollPhysics(),
            child: MarkdownWithCodeHighlight(
              text: display.isNotEmpty ? display : '…',
              baseStyle: baseStyle,
            ),
          ),
        ),
      );
    }

    // Enable long-press text selection in reasoning body
    // body = SelectionArea(child: body);


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
            children: [
              header,
              if (widget.expanded || isLoading) body,
            ],
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
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
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
            final shaderRect = Rect.fromLTWH(-dx, 0, width + gradientWidth * 2, rect.height);
            return LinearGradient(
              colors: [
                Colors.white.withOpacity(0.0),
                Colors.white.withOpacity(0.35),
                Colors.white.withOpacity(0.0),
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

// Simple marquee that bounces horizontally if text exceeds maxWidth
class _Marquee extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double maxWidth;
  final Duration duration;
  const _Marquee({
    required this.text,
    required this.style,
    this.maxWidth = 160,
    this.duration = const Duration(milliseconds: 3000),
  });

  @override
  State<_Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<_Marquee> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _measure(String text, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: ui.TextDirection.ltr,
      textScaleFactor: MediaQuery.of(context).textScaleFactor,
    )..layout();
    return tp.width;
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.maxWidth;
    final textWidth = _measure(widget.text, widget.style);
    final needScroll = textWidth > w;
    final gap = 32.0;
    final loopWidth = textWidth + gap;
    return SizedBox(
      width: w,
      height: (widget.style.fontSize ?? 13) * 1.35,
      child: ClipRect(
        child: needScroll
            ? AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = Curves.linear.transform(_c.value);
            final dx = -loopWidth * t;
            return ShaderMask(
              shaderCallback: (rect) {
                return const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0x00FFFFFF),
                    Color(0xFFFFFFFF),
                    Color(0xFFFFFFFF),
                    Color(0x00FFFFFF),
                  ],
                  stops: [0.0, 0.07, 0.93, 1.0],
                ).createShader(rect);
              },
              blendMode: BlendMode.dstIn,
              child: Transform.translate(
                offset: Offset(dx, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.text, style: widget.style, maxLines: 1, softWrap: false),
                    SizedBox(width: gap),
                    Text(widget.text, style: widget.style, maxLines: 1, softWrap: false),
                  ],
                ),
              ),
            );
          },
        )
            : Align(alignment: Alignment.centerLeft, child: Text(widget.text, style: widget.style, maxLines: 1, softWrap: false)),
      ),
    );
  }
}

// Token usage display with hover tooltip
class _TokenUsageDisplay extends StatefulWidget {
  final String tokenText;
  final List<String> tooltipLines;
  final bool hasCache;
  final ColorScheme colorScheme;

  const _TokenUsageDisplay({
    required this.tokenText,
    required this.tooltipLines,
    required this.hasCache,
    required this.colorScheme,
  });

  @override
  State<_TokenUsageDisplay> createState() => _TokenUsageDisplayState();
}

class _TokenUsageDisplayState extends State<_TokenUsageDisplay> {
  bool _isHovering = false;
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showOverlay(BuildContext context) {
    _removeOverlay();

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx,
        top: offset.dy + size.height + 4,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          color: widget.colorScheme.surface,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: widget.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.colorScheme.outline.withOpacity(0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: widget.tooltipLines.map((line) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    line,
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.colorScheme.onSurface,
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovering = true);
        _showOverlay(context);
      },
      onExit: (_) {
        setState(() => _isHovering = false);
        _removeOverlay();
      },
      cursor: SystemMouseCursors.help,
      child: Text(
        widget.tokenText,
        style: TextStyle(
          fontSize: 11,
          color: widget.hasCache
              ? widget.colorScheme.primary.withOpacity(0.7)
              : widget.colorScheme.onSurface.withOpacity(0.5),
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
