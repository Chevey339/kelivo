import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:characters/characters.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../../icons/lucide_adapter.dart';
import 'package:provider/provider.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/services/api/chat_api_service.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/models/chat_item.dart';
import '../../../core/providers/user_provider.dart';
import '../../settings/pages/settings_page.dart';
import '../../translate/pages/translate_page.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/update_provider.dart';
import '../../../core/models/assistant.dart';
import '../../assistant/pages/assistant_settings_edit_page.dart';
import '../../chat/pages/chat_history_page.dart';
import '../../../desktop/chat_history_dialog.dart';
import 'package:flutter/services.dart';
import 'dart:io' show File;
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/snackbar.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:animations/animations.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../../utils/avatar_cache.dart';
import 'dart:ui' as ui;
import '../../../shared/widgets/ios_tactile.dart';
import '../../../core/services/haptics.dart';
import '../../../desktop/desktop_context_menu.dart';
import '../../../desktop/menu_anchor.dart';
import '../../../shared/widgets/emoji_text.dart';
import '../../../core/providers/tag_provider.dart';
import '../../assistant/pages/tags_manager_page.dart';
import '../../assistant/widgets/tags_manager_dialog.dart';
import '../../assistant/widgets/assistant_select_sheet.dart';
import '../../../desktop/hotkeys/sidebar_tab_bus.dart';
import 'dart:async';

class SideDrawer extends StatefulWidget {
  const SideDrawer({
    super.key,
    required this.userName,
    required this.assistantName,
    this.onSelectConversation,
    this.onNewConversation,
    this.closePickerTicker,
    this.loadingConversationIds = const <String>{},
    this.embedded = false,
    this.embeddedWidth,
    this.showBottomBar = true,
    this.useDesktopTabs = false,
    this.desktopAssistantsOnly = false,
    this.desktopTopicsOnly = false,
  });

  final String userName;
  final String assistantName;
  final FutureOr<void> Function(String id, {bool closeDrawer})? onSelectConversation;
  final FutureOr<void> Function({bool closeDrawer})? onNewConversation;
  final ValueNotifier<int>? closePickerTicker;
  final Set<String> loadingConversationIds;
  final bool embedded; // when true, render as a fixed side panel instead of a Drawer
  final double? embeddedWidth; // optional explicit width for embedded mode
  final bool showBottomBar; // desktop can hide this bottom area
  final bool useDesktopTabs; // desktop-only: show tabs (Assistants/Topics)
  final bool desktopAssistantsOnly; // desktop-only: show only assistants list
  final bool desktopTopicsOnly; // desktop-only: show only topics list

  @override
  State<SideDrawer> createState() => _SideDrawerState();
}

class _SideDrawerState extends State<SideDrawer> with TickerProviderStateMixin {
  bool get _isDesktop => defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  final GlobalKey _assistantTileKey = GlobalKey();
  OverlayEntry? _assistantPickerEntry;
  ValueNotifier<int>? _closeTicker;
  bool _assistantsExpanded = false;
  final ScrollController _listController = ScrollController();
  bool _assistantHeaderHovered = false;
  TabController? _tabController; // desktop tabs
  StreamSubscription<int>? _tabBusSub;

  // Assistant avatar renderer shared across drawer views
  Widget _assistantAvatar(BuildContext context, Assistant? a, {double size = 28, VoidCallback? onTap}) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final av = a?.avatar?.trim() ?? '';
    final name = a?.name ?? '';
    
    Widget avatar;
      if (av.isNotEmpty) {
        if (av.startsWith('http')) {
          avatar = FutureBuilder<String?>(
            future: AvatarCache.getPath(av),
            builder: (ctx, snap) {
              final p = snap.data;
              if (p != null && File(p).existsSync()) {
                return ClipOval(
                  child: Image(
                    image: FileImage(File(p)),
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                  ),
                );
              }
              return ClipOval(
                child: Image.network(
                  av,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => _assistantInitialAvatar(cs, name, size),
                ),
              );
            },
          );
        } else if (!kIsWeb && (av.startsWith('/') || av.contains(':'))) {
          final fixed = SandboxPathResolver.fix(av);
          final f = File(fixed);
          if (f.existsSync()) {
            avatar = ClipOval(
              child: Image(
                image: FileImage(f),
                width: size,
                height: size,
                fit: BoxFit.cover,
              ),
            );
          } else {
            avatar = _assistantInitialAvatar(cs, name, size);
          }
        } else {
          avatar = _assistantEmojiAvatar(cs, av, size);
        }
      } else {
        avatar = _assistantInitialAvatar(cs, name, size);
      }
    
    // Add border
    final child = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.black12,
          width: 0.5,
        ),
      ),
      child: avatar,
    );

    if (onTap == null) return child;

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: child,
    );
  }

  Widget _assistantInitialAvatar(ColorScheme cs, String name, double size) {
    final letter = name.isNotEmpty ? name.characters.first : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: cs.primary,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _assistantEmojiAvatar(ColorScheme cs, String emoji, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: EmojiText(
        emoji.characters.take(1).toString(),
        fontSize: size * 0.5,
        optimizeEmojiAlign: true,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _attachCloseTicker(widget.closePickerTicker);
    _searchController.addListener(() {
      if (_query != _searchController.text) {
        setState(() => _query = _searchController.text);
      }
    });
    // Update check moved to app startup (main.dart)
    // Prepare desktop tabs controller (available when useDesktopTabs)
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
    _tabController!.addListener(_onDesktopTabChanged);
    // Reflect current index to bus and listen for external switches
    DesktopSidebarTabBus.instance.setCurrentIndex(_tabController!.index);
    _tabBusSub = DesktopSidebarTabBus.instance.stream.listen((idx) {
      if (widget.useDesktopTabs && mounted) {
        try { _tabController!.animateTo(idx, duration: const Duration(milliseconds: 140), curve: Curves.easeOutCubic); } catch (_) {}
      }
    });
  }

  void _onDesktopTabChanged() {
    if (!mounted) return;
    DesktopSidebarTabBus.instance.setCurrentIndex(_tabController?.index ?? 0);
    setState(() {}); // update search hint when switching tabs
  }

  void _showChatMenu(BuildContext context, ChatItem chat, {Offset? anchor}) async {
    final l10n = AppLocalizations.of(context)!;
    final chatService = context.read<ChatService>();
    final isPinned = chatService.getConversation(chat.id)?.isPinned ?? false;
    final isDesktop = defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;

    if (isDesktop) {
      // Desktop: glass anchored menu near cursor/button
      Offset pos = anchor ?? DesktopMenuAnchor.positionOrCenter(context);
      await showDesktopContextMenuAt(
        context,
        globalPosition: pos,
        items: [
          DesktopContextMenuItem(
            icon: Lucide.Edit,
            label: l10n.sideDrawerMenuRename,
            onTap: () async { await _renameChat(context, chat); },
          ),
          DesktopContextMenuItem(
            icon: Lucide.Pin,
            label: isPinned ? l10n.sideDrawerMenuUnpin : l10n.sideDrawerMenuPin,
            onTap: () async { await chatService.togglePinConversation(chat.id); },
          ),
          DesktopContextMenuItem(
            icon: Lucide.RefreshCw,
            label: l10n.sideDrawerMenuRegenerateTitle,
            onTap: () async { await _regenerateTitle(context, chat.id); },
          ),
          DesktopContextMenuItem(
            icon: Lucide.Shuffle,
            label: l10n.sideDrawerMenuMoveTo,
            onTap: () async {
              final conv = chatService.getConversation(chat.id);
              final movingCurrent = chatService.currentConversationId == chat.id;
              // Pre-compute next recent conversation for current assistant
              String? nextId;
              try {
                final ap = context.read<AssistantProvider>();
                final currentAid = ap.currentAssistantId;
                if (currentAid != null) {
                  final all = chatService.getAllConversations();
                  final candidates = all
                      .where((c) => c.assistantId == currentAid && c.id != chat.id)
                      .toList()
                    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
                  if (candidates.isNotEmpty) nextId = candidates.first.id;
                }
              } catch (_) {}
              final targetId = await showAssistantMoveSelector(context, excludeAssistantId: conv?.assistantId);
              if (targetId != null) {
                await chatService.moveConversationToAssistant(conversationId: chat.id, assistantId: targetId);
                if (movingCurrent || chatService.currentConversationId == null) {
                  final closeDrawer = !context.read<SettingsProvider>().keepSidebarOpenOnTopicTap;
                  if (nextId != null) {
                    widget.onSelectConversation?.call(nextId!, closeDrawer: closeDrawer);
                  } else {
                    widget.onNewConversation?.call(closeDrawer: closeDrawer);
                  }
                }
              }
            },
          ),
          DesktopContextMenuItem(
            icon: Lucide.Trash2,
            label: l10n.sideDrawerMenuDelete,
            danger: true,
            onTap: () async {
              final confirmed = await _confirmDeleteConversation(context, chat);
              if (!confirmed) return;
              final deletingCurrent = chatService.currentConversationId == chat.id;
              final nextId = _nextRecentConversation(chatService, chat.id);
              await chatService.deleteConversation(chat.id);
              showAppSnackBar(
                context,
                message: l10n.sideDrawerDeleteSnackbar(chat.title),
                type: NotificationType.success,
                duration: const Duration(seconds: 3),
              );
              _handlePostDeleteNavigation(chatService: chatService, deletingCurrent: deletingCurrent, nextConversationId: nextId);
              Navigator.of(context).maybePop();
            },
          ),
        ],
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final maxH = MediaQuery.sizeOf(ctx).height * 0.8;
        Widget row({required IconData icon, required String label, Color? color, required Future<void> Function() action}) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(
              height: 48,
              child: IosCardPress(
                borderRadius: BorderRadius.circular(14),
                baseColor: cs.surface,
                duration: const Duration(milliseconds: 260),
                onTap: () async {
                  Haptics.light();
                  Navigator.of(ctx).pop();
                  await Future<void>.delayed(const Duration(milliseconds: 10));
                  await action();
                },
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: color ?? cs.onSurface),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: color ?? cs.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: cs.onSurface.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    row(
                      icon: Lucide.Edit,
                      label: l10n.sideDrawerMenuRename,
                      action: () async { _renameChat(context, chat); },
                    ),
                    row(
                      icon: Lucide.Pin,
                      label: isPinned ? l10n.sideDrawerMenuUnpin : l10n.sideDrawerMenuPin,
                      action: () async { await chatService.togglePinConversation(chat.id); },
                    ),
                    row(
                      icon: Lucide.RefreshCw,
                      label: l10n.sideDrawerMenuRegenerateTitle,
                      action: () async { await _regenerateTitle(context, chat.id); },
                    ),
                    row(
                      icon: Lucide.Shuffle,
                      label: l10n.sideDrawerMenuMoveTo,
                      action: () async {
                        final conv = chatService.getConversation(chat.id);
                        final movingCurrent = chatService.currentConversationId == chat.id;
                        // Pre-compute next recent conversation for current assistant
                        String? nextId;
                        try {
                          final ap = context.read<AssistantProvider>();
                          final currentAid = ap.currentAssistantId;
                          if (currentAid != null) {
                            final all = chatService.getAllConversations();
                            final candidates = all
                                .where((c) => c.assistantId == currentAid && c.id != chat.id)
                                .toList()
                              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
                            if (candidates.isNotEmpty) nextId = candidates.first.id;
                          }
                        } catch (_) {}
                        final targetId = await showAssistantMoveSelector(context, excludeAssistantId: conv?.assistantId);
                        if (targetId != null) {
                          await chatService.moveConversationToAssistant(conversationId: chat.id, assistantId: targetId);
                          if (movingCurrent || chatService.currentConversationId == null) {
                            final closeDrawer = !context.read<SettingsProvider>().keepSidebarOpenOnTopicTap;
                            if (nextId != null) {
                              widget.onSelectConversation?.call(nextId!, closeDrawer: closeDrawer);
                            } else {
                              widget.onNewConversation?.call(closeDrawer: closeDrawer);
                            }
                          }
                        }
                      },
                    ),
                    row(
                      icon: Lucide.Trash,
                      label: l10n.sideDrawerMenuDelete,
                      color: Colors.redAccent,
                      action: () async {
                        final confirmed = await _confirmDeleteConversation(context, chat);
                        if (!confirmed) return;
                        final deletingCurrent = chatService.currentConversationId == chat.id;
                        final nextId = _nextRecentConversation(chatService, chat.id);
                        await chatService.deleteConversation(chat.id);
                        showAppSnackBar(
                          context,
                          message: l10n.sideDrawerDeleteSnackbar(chat.title),
                          type: NotificationType.success,
                          duration: const Duration(seconds: 3),
                        );
                        _handlePostDeleteNavigation(chatService: chatService, deletingCurrent: deletingCurrent, nextConversationId: nextId);
                        Navigator.of(context).maybePop();
                      },
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool> _confirmDeleteConversation(BuildContext context, ChatItem chat) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.sideDrawerMenuDelete),
          content: Text('${l10n.sideDrawerMenuDelete} "${chat.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.sideDrawerCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                l10n.sideDrawerMenuDelete,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  String? _nextRecentConversation(ChatService chatService, String excludeId) {
    try {
      final ap = context.read<AssistantProvider>();
      final currentAid = ap.currentAssistantId;
      if (currentAid == null) return null;
      final candidates = chatService
          .getAllConversations()
          .where((c) => c.assistantId == currentAid && c.id != excludeId)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      if (candidates.isEmpty) return null;
      return candidates.first.id;
    } catch (_) {
      return null;
    }
  }

  void _handlePostDeleteNavigation({
    required ChatService chatService,
    required bool deletingCurrent,
    required String? nextConversationId,
  }) {
    if (!(deletingCurrent || chatService.currentConversationId == null)) return;
    final closeDrawer = !context.read<SettingsProvider>().keepSidebarOpenOnTopicTap;
    final preferNewChat = context.read<SettingsProvider>().newChatAfterDelete;
    if (preferNewChat && widget.onNewConversation != null) {
      widget.onNewConversation!.call(closeDrawer: closeDrawer);
      return;
    }
    if (!preferNewChat && nextConversationId != null) {
      widget.onSelectConversation?.call(nextConversationId, closeDrawer: closeDrawer);
      return;
    }
    if (widget.onNewConversation != null) {
      widget.onNewConversation!.call(closeDrawer: closeDrawer);
      return;
    }
    if (nextConversationId != null) {
      widget.onSelectConversation?.call(nextConversationId, closeDrawer: closeDrawer);
    }
  }

  Future<void> _renameChat(BuildContext context, ChatItem chat) async {
    final controller = TextEditingController(text: chat.title);
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.sideDrawerMenuRename),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.sideDrawerRenameHint,
            ),
            onSubmitted: (_) => Navigator.of(ctx).pop(true),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.sideDrawerCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.sideDrawerOK),
            ),
          ],
        );
      },
    );
    if (ok == true) {
      await context.read<ChatService>().renameConversation(chat.id, controller.text.trim());
    }
  }

  Future<void> _regenerateTitle(BuildContext context, String conversationId) async {
    final settings = context.read<SettingsProvider>();
    final chatService = context.read<ChatService>();
    final convo = chatService.getConversation(conversationId);
    if (convo == null) return;
    // Decide model
    final provKey = settings.titleModelProvider ?? settings.currentModelProvider;
    final mdlId = settings.titleModelId ?? settings.currentModelId;
    if (provKey == null || mdlId == null) return;
    final cfg = settings.getProviderConfig(provKey);
    // Content
    final msgs = chatService.getMessages(conversationId);
    final joined = msgs.where((m) => m.content.isNotEmpty).map((m) => '${m.role == 'assistant' ? 'Assistant' : 'User'}: ${m.content}').join('\n\n');
    final content = joined.length > 3000 ? joined.substring(0, 3000) : joined;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final prompt = settings.titlePrompt.replaceAll('{locale}', locale).replaceAll('{content}', content);
    try {
      final title = (await ChatApiService.generateText(config: cfg, modelId: mdlId, prompt: prompt)).trim();
      if (title.isNotEmpty) {
        await chatService.renameConversation(conversationId, title);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _assistantPickerEntry?.remove();
    _assistantPickerEntry = null;
    _closeTicker?.removeListener(_handleCloseTick);
    _searchController.dispose();
    _listController.dispose();
    _tabController?.removeListener(_onDesktopTabChanged);
    _tabController?.dispose();
    try { _tabBusSub?.cancel(); } catch (_) {}
    super.dispose();
  }

  @override
  void deactivate() {
    _closeAssistantPicker();
    super.deactivate();
  }

  @override
  void didUpdateWidget(covariant SideDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.closePickerTicker != widget.closePickerTicker) {
      _attachCloseTicker(widget.closePickerTicker);
    }
  }

  void _attachCloseTicker(ValueNotifier<int>? ticker) {
    if (_closeTicker == ticker) return;
    _closeTicker?.removeListener(_handleCloseTick);
    _closeTicker = ticker;
    _closeTicker?.addListener(_handleCloseTick);
  }

  void _handleCloseTick() {
    _closeAssistantPicker();
  }


  String _greeting(BuildContext context) {
    final hour = DateTime.now().hour;
    final l10n = AppLocalizations.of(context)!;
    if (hour < 11) return l10n.sideDrawerGreetingMorning;
    if (hour < 13) return l10n.sideDrawerGreetingNoon;
    if (hour < 18) return l10n.sideDrawerGreetingAfternoon;
    return l10n.sideDrawerGreetingEvening;
  }

  String _dateLabel(BuildContext context, DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final aDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(aDay).inDays;
    final l10n = AppLocalizations.of(context)!;
    if (diff == 0) return l10n.sideDrawerDateToday;
    if (diff == 1) return l10n.sideDrawerDateYesterday;
    final sameYear = now.year == date.year;
    final pattern = sameYear ? l10n.sideDrawerDateShortPattern : l10n.sideDrawerDateFullPattern;
    final fmt = DateFormat(pattern);
    return fmt.format(date);
  }

  List<_ChatGroup> _groupByDate(BuildContext context, List<ChatItem> source) {
    final items = [...source];
    // group by day (truncate time)
    final map = <DateTime, List<ChatItem>>{};
    for (final c in items) {
      final d = DateTime(c.created.year, c.created.month, c.created.day);
      map.putIfAbsent(d, () => []).add(c);
    }
    // sort groups by date desc (recent first)
    final keys = map.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    return [
      for (final k in keys)
        _ChatGroup(
          label: _dateLabel(context, k),
          items: (map[k]!..sort((a, b) => b.created.compareTo(a.created)))!,
        )
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final textBase = isDark ? Colors.white : Colors.black; // 纯黑（白天），夜间自动适配
    final chatService = context.watch<ChatService>();
    final ap = context.watch<AssistantProvider>();
    final currentAssistantId = ap.currentAssistantId;
    final conversations = chatService
        .getAllConversations()
        .where((c) => c.assistantId == currentAssistantId || c.assistantId == null)
        .toList();
    // Use last-activity time (updatedAt) for ordering and grouping
    final all = conversations
        .map((c) => ChatItem(id: c.id, title: c.title, created: c.updatedAt))
        .toList();

    final base = _query.trim().isEmpty
        ? all
        : all.where((c) => c.title.toLowerCase().contains(_query.toLowerCase())).toList();
    final pinnedList = base
        .where((c) => (chatService.getConversation(c.id)?.isPinned ?? false))
        .toList()
      ..sort((a, b) => b.created.compareTo(a.created));
    final rest = base
        .where((c) => !(chatService.getConversation(c.id)?.isPinned ?? false))
        .toList();
    final groups = _groupByDate(context, rest);

    // Avatar renderer: emoji / url / file / default initial
    Widget avatarWidget(String name, UserProvider up, {double size = 40}) {
      final type = up.avatarType;
      final value = up.avatarValue;
      if (type == 'emoji' && value != null && value.isNotEmpty) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: EmojiText(
            value,
            fontSize: size * 0.5,
            optimizeEmojiAlign: true,
          ),
        );
      }
      if (type == 'url' && value != null && value.isNotEmpty) {
        return FutureBuilder<String?>(
          future: AvatarCache.getPath(value),
          builder: (ctx, snap) {
            final p = snap.data;
            if (p != null && File(p).existsSync()) {
              return ClipOval(
                child: Image(
                  image: FileImage(File(p)),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                ),
              );
            }
            return ClipOval(
              child: Image.network(
                value,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(
                  width: size,
                  height: size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Text('?', style: TextStyle(color: cs.primary, fontSize: size * 0.42, fontWeight: FontWeight.w700)),
                ),
              ),
            );
          },
        );
      }
      if (type == 'file' && value != null && value.isNotEmpty && !kIsWeb) {
        final fixed = SandboxPathResolver.fix(value);
        final f = File(fixed);
        if (f.existsSync()) {
          return ClipOval(
            child: Image(
              image: FileImage(f),
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          );
        }
      }
      // default: initial
      final letter = name.isNotEmpty ? name.characters.first : '?';
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: cs.primary.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          letter,
          style: TextStyle(
            color: cs.primary,
            fontSize: size * 0.42,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    // Desktop-only: enable tabs for embedded sidebar when requested
    final bool _assistOnly = widget.desktopAssistantsOnly && _isDesktop && widget.embedded;
    final bool _topicsOnly = widget.desktopTopicsOnly && _isDesktop && widget.embedded;
    final bool _useTabs = widget.useDesktopTabs && _isDesktop && widget.embedded && !_assistOnly && !_topicsOnly;

    final inner = SafeArea(
      child: Stack(
        children: [
            // Main column content
            Column(
              children: [
            // Fixed header + search
            Padding(
              padding: EdgeInsets.fromLTRB(16, _isDesktop ? 10 : 4, 16, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. 搜索框 + 历史按钮（固定头部）
                  if (_isDesktop)
                    // 桌面端
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                        child: Row(
                          key: ValueKey<String>((() {
                            final l10n = AppLocalizations.of(context)!;
                            String hint;
                            if (_useTabs) {
                              hint = ((_tabController?.index ?? 0) == 0)
                                  ? l10n.sideDrawerSearchAssistantsHint
                                  : l10n.sideDrawerSearchHint;
                            } else if (_assistOnly) {
                              hint = l10n.sideDrawerSearchAssistantsHint;
                            } else {
                              hint = l10n.sideDrawerSearchHint;
                            }
                            return hint;
                          })()),
                          children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: (() {
                                  final l10n = AppLocalizations.of(context)!;
                                  if (_useTabs) {
                                    return ((_tabController?.index ?? 0) == 0)
                                        ? l10n.sideDrawerSearchAssistantsHint
                                        : l10n.sideDrawerSearchHint;
                                  }
                                  if (_assistOnly) return l10n.sideDrawerSearchAssistantsHint;
                                  return l10n.sideDrawerSearchHint;
                                })(),
                                filled: true,
                                fillColor: isDark ? Colors.white10 : Colors.grey.shade200.withOpacity(0.80),
                                isDense: true,
                                isCollapsed: true,
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.only(left: 10, right: 4),
                                  child: Icon(
                                    Lucide.Search,
                                    size: 16,
                                    color: textBase.withOpacity(0.6),
                                  ),
                                ),
                                prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                                // 右侧（话题列表）不需要历史入口（左侧已有）；左侧或默认仍保留
                                suffixIcon: _topicsOnly ? null : Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: IosIconButton(
                                    size: 16,
                                    color: textBase,
                                    icon: Lucide.History,
                                    padding: const EdgeInsets.all(4),
                                    onTap: () async {
                                      final selectedId = await showChatHistoryDesktopDialog(context, assistantId: currentAssistantId);
                                      if (selectedId != null && selectedId.isNotEmpty) {
                                        final closeDrawer = !context.read<SettingsProvider>().keepSidebarOpenOnTopicTap;
                                        widget.onSelectConversation?.call(selectedId, closeDrawer: closeDrawer);
                                      }
                                    },
                                  ),
                                ),
                                suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 11,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Colors.transparent),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Colors.transparent),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Colors.transparent),
                                ),
                              ),
                              textAlignVertical: TextAlignVertical.center,
                              style: TextStyle(color: textBase, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(context)!.sideDrawerSearchHint,
                              filled: true,
                              fillColor: isDark ? Colors.white10 : Colors.grey.shade200.withOpacity(0.80),
                              isDense: true,
                              isCollapsed: true,
                              prefixIcon: Padding(
                                padding: const EdgeInsets.only(left: 10, right: 4),
                                child: Icon(
                                  Lucide.Search,
                                  size: 16,
                                  color: textBase.withOpacity(0.6),
                                ),
                              ),
                              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Colors.transparent),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Colors.transparent),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Colors.transparent),
                              ),
                            ),
                            textAlignVertical: TextAlignVertical.center,
                            style: TextStyle(color: textBase, fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 历史按钮（圆形，无水波纹）
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: IosIconButton(
                              size: 20,
                              color: textBase,
                              icon: Lucide.History,
                              padding: const EdgeInsets.all(8),
                              onTap: () async {
                                final selectedId = await Navigator.of(context).push<String>(
                                  MaterialPageRoute(builder: (_) => ChatHistoryPage(assistantId: currentAssistantId)),
                                );
                                if (selectedId != null && selectedId.isNotEmpty) {
                                  final closeDrawer = !context.read<SettingsProvider>().keepSidebarOpenOnTopicTap;
                                  widget.onSelectConversation?.call(selectedId, closeDrawer: closeDrawer);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),

                  SizedBox(height: _isDesktop ? 8 : 12),
                  
                  // 桌面端：替换为 Tab（助手 / 话题）
                  if (_useTabs)
                    _DesktopSidebarTabs(textColor: textBase, controller: _tabController!)
                  else if (!_assistOnly && !_topicsOnly)
                    // 当前助手区域（固定）
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: KeyedSubtree(
                        key: _assistantTileKey,
                        child: MouseRegion(
                          onEnter: (_) { if (_isDesktop) setState(() => _assistantHeaderHovered = true); },
                          onExit: (_) { if (_isDesktop) setState(() => _assistantHeaderHovered = false); },
                          cursor: _isDesktop ? SystemMouseCursors.click : SystemMouseCursors.basic,
                          child: IosCardPress(
                            baseColor: (() {
                              final embedded = widget.embedded;
                              final base = embedded ? Colors.transparent : cs.surface;
                              if (_isDesktop && _assistantHeaderHovered) {
                                return embedded ? cs.primary.withOpacity(0.08) : cs.surface.withOpacity(0.9);
                              }
                              return base;
                            })(),
                            borderRadius: BorderRadius.circular(16),
                            onTap: _toggleAssistantPicker,
                            onLongPress: _isDesktop ? null : () {
                              _closeAssistantPicker();
                              final id = context.read<AssistantProvider>().currentAssistantId;
                              if (id != null) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => AssistantSettingsEditPage(assistantId: id)),
                                );
                              }
                            },
                            padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
                            child: Row(
                              children: [
                                _assistantAvatar(
                                  context,
                                  ap.currentAssistant,
                                  size: 32,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    (ap.currentAssistant?.name ?? widget.assistantName),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: _isDesktop ? 14 : 15, fontWeight: FontWeight.w500, color: textBase),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                AnimatedRotation(
                                  turns: _assistantsExpanded ? 0.5 : 0.0,
                                  duration: const Duration(milliseconds: 350),
                                  curve: Curves.easeOutCubic,
                                  child: Icon(
                                    Lucide.ChevronDown,
                                    size: 18,
                                    color: textBase.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // 注意：内联助手列表已移动至下方可滚动区域
                ],
              ),
            ),

            // Scrollable area below header
            Expanded(
              child: () {
                if (_useTabs) {
                  return _DesktopTabViews(
                    controller: _tabController!,
                    listController: _listController,
                    buildAssistants: () => _buildAssistantsList(context),
                    buildConversations: () => _buildConversationsList(context, cs, textBase, chatService, pinnedList, groups, includeUpdateBanner: true),
                  );
                }
                if (_assistOnly) {
                  return ListView(
                    controller: _listController,
                    padding: const EdgeInsets.fromLTRB(10, 2, 10, 16),
                    children: [
                      _buildAssistantsList(context, inlineMode: true),
                    ],
                  );
                }
                if (_topicsOnly) {
                  final isDesktop = _isDesktop;
                  final topPad = context.watch<SettingsProvider>().showChatListDate ? (isDesktop ? 2.0 : 4.0) : 10.0;
                  return ListView(
                    controller: _listController,
                    padding: EdgeInsets.fromLTRB(10, topPad, 10, 16),
                    children: [
                      _buildConversationsList(context, cs, textBase, chatService, pinnedList, groups, includeUpdateBanner: true),
                    ],
                  );
                }
                return _LegacyListArea(
                  listController: _listController,
                  isDesktop: _isDesktop,
                  assistantsExpanded: _assistantsExpanded,
                  buildAssistants: () => _buildAssistantsList(context, inlineMode: true),
                  buildConversations: () => _buildConversationsList(context, cs, textBase, chatService, pinnedList, groups, includeUpdateBanner: true),
                );
              }(),
            ),

            if (widget.showBottomBar && (!widget.embedded || !_isDesktop)) Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                color: widget.embedded ? Colors.transparent : cs.surface,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 6),
                      // 用户头像（可点击更换）—移除水波纹
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _editAvatar(context),
                        child: avatarWidget(
                          widget.userName,
                          context.watch<UserProvider>(),
                          size: 40,
                        ),
                      ),
                      const SizedBox(width: 20),
                      // 用户名称（可点击编辑，垂直居中）
                      Expanded(
                        child: IosCardPress(
                          borderRadius: BorderRadius.circular(6),
                          baseColor: Colors.transparent,
                          onTap: () => _editUserName(context),
                          padding: const EdgeInsets.symmetric(horizontal: 0),
                          child: SizedBox(
                            height: 45,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                widget.userName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: _isDesktop ? 14 : 16,
                                  fontWeight: FontWeight.w700,
                                  color: textBase,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 翻译按钮（圆形，无水波纹）
                      SizedBox(
                        width: 45,
                        height: 45,
                        child: Center(
                          child: IosIconButton(
                            size: 22,
                            color: textBase,
                            icon: Lucide.Languages,
                            padding: const EdgeInsets.all(10),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const TranslatePage()),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // 设置按钮（圆形，无水波纹）
                      SizedBox(
                        width: 45,
                        height: 45,
                        child: Center(
                          child: IosIconButton(
                            size: 22,
                            color: textBase,
                            icon: Lucide.Settings,
                            padding: const EdgeInsets.all(10),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const SettingsPage()),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
              ],
            ),

            // iOS-style blur/fade effect above user area
            if (!widget.embedded)
              Positioned(
                left: 0,
                right: 0,
                bottom: 62, // Approximate height of user area
                child: IgnorePointer(
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          cs.surface.withOpacity(0.0),
                          cs.surface.withOpacity(0.8),
                          cs.surface.withOpacity(1.0),
                        ],
                        stops: const [0.0, 0.6, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

    if (widget.embedded) {
      return ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Material(
            color: cs.surface.withOpacity(0.60),
            child: SizedBox(
              width: widget.embeddedWidth ?? 300,
              child: inner,
            ),
          ),
        ),
      );
    }

    return Drawer(
      backgroundColor: cs.surface,
      width: MediaQuery.sizeOf(context).width,
      child: inner,
    );
  }

  void _toggleAssistantPicker() {
    final goingToExpand = !_assistantsExpanded;
    setState(() {
      _assistantsExpanded = goingToExpand;
    });
    if (goingToExpand) {
      // Smoothly reveal the assistant list at the top
      if (_listController.hasClients) {
        // Slight delay to ensure layout is ready before animating
        Future<void>.delayed(const Duration(milliseconds: 10), () {
          if (!_listController.hasClients) return;
          _listController.animateTo(
            0,
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
          );
        });
      }
    }
  }

  void _closeAssistantPicker() {
    if (!_assistantsExpanded) return;
    setState(() {
      _assistantsExpanded = false;
    });
  }

  Future<void> _handleSelectAssistant(Assistant assistant) async {
    final sp = context.read<SettingsProvider>();
    final closeDrawer = !sp.keepSidebarOpenOnAssistantTap;
    if (closeDrawer) {
      _closeAssistantPicker();
    }
    final ap = context.read<AssistantProvider>();
    await ap.setCurrentAssistant(assistant.id);
    // Desktop: optionally switch to Topics tab per user preference
    try {
      if (_isDesktop && widget.embedded && widget.useDesktopTabs && sp.desktopAutoSwitchTopics) {
        _tabController?.animateTo(1, duration: const Duration(milliseconds: 140), curve: Curves.easeOutCubic);
      }
    } catch (_) {}
    if (!mounted) return;
    final forceNewChat = sp.newChatOnAssistantSwitch && widget.onNewConversation != null;
    if (forceNewChat) {
      widget.onNewConversation?.call(closeDrawer: closeDrawer);
    } else {
      // Jump to the most recent conversation for this assistant if any,
      // otherwise create a new conversation.
      try {
        final chatService = context.read<ChatService>();
        final all = chatService.getAllConversations();
        // Filter conversations owned by this assistant and pick the newest
        final recent = all
            .where((c) => c.assistantId == assistant.id)
            .toList();
        if (recent.isNotEmpty) {
          // getAllConversations is already sorted by updatedAt desc
          widget.onSelectConversation?.call(recent.first.id, closeDrawer: closeDrawer);
        } else {
          widget.onNewConversation?.call(closeDrawer: closeDrawer);
        }
      } catch (_) {
        // Fallback: new conversation on any error
        widget.onNewConversation?.call(closeDrawer: closeDrawer);
      }
    }
    if (closeDrawer) {
      Navigator.of(context).maybePop();
    }
  }

  void _openAssistantSettings(String id) {
    _closeAssistantPicker();
    final isDesktop = defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
    if (isDesktop) {
      // Use desktop modal dialog for assistant editing on desktop
      showAssistantDesktopDialog(context, assistantId: id);
      return;
    }
    // Fallback to mobile edit page on non-desktop platforms
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AssistantSettingsEditPage(assistantId: id)),
    );
  }

}

extension on _SideDrawerState {
  Future<void> _duplicateAssistantFromMenu(Assistant assistant) async {
    final l10n = AppLocalizations.of(context)!;
    final newId = await context.read<AssistantProvider>().duplicateAssistant(
          assistant.id,
          l10n: l10n,
        );
    if (!mounted) return;
    if (newId != null) {
      showAppSnackBar(
        context,
        message: l10n.assistantSettingsCopySuccess,
        type: NotificationType.success,
      );
    }
  }

  Future<void> _showAssistantItemMenuDesktop(Assistant a, Offset globalPosition) async {
    if (!_isDesktop) return;
    final l10n = AppLocalizations.of(context)!;
    final tp = context.read<TagProvider>();
    final hasTag = tp.tagOfAssistant(a.id) != null;
    await showDesktopContextMenuAt(
      context,
      globalPosition: globalPosition,
      items: [
        DesktopContextMenuItem(
          icon: Lucide.Pencil,
          label: l10n.assistantTagsContextMenuEditAssistant,
          onTap: () => _openAssistantSettings(a.id),
        ),
        DesktopContextMenuItem(
          icon: Lucide.Copy,
          label: l10n.assistantSettingsCopyButton,
          onTap: () async {
            await _duplicateAssistantFromMenu(a);
          },
        ),
        if (hasTag)
          DesktopContextMenuItem(
            icon: Lucide.Eraser,
            label: l10n.assistantTagsClearTag,
            onTap: () async {
              await context.read<TagProvider>().unassignAssistant(a.id);
            },
          ),
        DesktopContextMenuItem(
          icon: Lucide.Bookmark,
          label: l10n.assistantTagsContextMenuManageTags,
          onTap: () async {
            _closeAssistantPicker();
            await showAssistantTagsManagerDialog(context, assistantId: a.id);
          },
        ),
        DesktopContextMenuItem(
          icon: Lucide.Trash2,
          label: l10n.assistantTagsContextMenuDeleteAssistant,
          danger: true,
          onTap: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(l10n.assistantSettingsDeleteDialogTitle),
                content: Text(l10n.assistantSettingsDeleteDialogContent),
                actions: [
                  TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l10n.assistantSettingsDeleteDialogCancel)),
                  TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l10n.assistantSettingsDeleteDialogConfirm)),
                ],
              ),
            );
            if (confirmed != true) return;
            final ok = await context.read<AssistantProvider>().deleteAssistant(a.id);
            if (!ok) {
              showAppSnackBar(context, message: l10n.assistantSettingsAtLeastOneAssistantRequired, type: NotificationType.warning);
            } else {
              try { await context.read<TagProvider>().unassignAssistant(a.id); } catch (_) {}
            }
          },
        ),
      ],
    );
  }

  Future<void> _showAssistantItemMenuMobile(Assistant a) async {
    if (_isDesktop) return;
    final l10n = AppLocalizations.of(context)!;
    final tp = context.read<TagProvider>();
    final hasTag = tp.tagOfAssistant(a.id) != null;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        Widget row(String text, IconData icon, VoidCallback onTap, {bool danger = false}) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(
              height: 48,
              child: IosCardPress(
                borderRadius: BorderRadius.circular(14),
                baseColor: cs.surface,
                duration: const Duration(milliseconds: 220),
                onTap: () {
                  Navigator.of(ctx).pop();
                  onTap();
                },
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: danger ? cs.error : cs.primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
                  ],
                ),
              ),
            ),
          );
        }
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                row(l10n.assistantTagsContextMenuEditAssistant, Lucide.Pencil, () => _openAssistantSettings(a.id)),
                row(l10n.assistantSettingsCopyButton, Lucide.Copy, () async {
                  await _duplicateAssistantFromMenu(a);
                }),
                if (hasTag)
                  row(l10n.assistantTagsClearTag, Lucide.Eraser, () async {
                    await context.read<TagProvider>().unassignAssistant(a.id);
                  }),
                row(l10n.assistantTagsContextMenuManageTags, Lucide.Bookmark, () async {
                  // Navigate to manage tags page
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TagsManagerPage(assistantId: a.id)));
                }),
                row(l10n.assistantTagsContextMenuDeleteAssistant, Lucide.Trash2, () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx2) => AlertDialog(
                      title: Text(l10n.assistantSettingsDeleteDialogTitle),
                      content: Text(l10n.assistantSettingsDeleteDialogContent),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(ctx2).pop(false), child: Text(l10n.assistantSettingsDeleteDialogCancel)),
                        TextButton(onPressed: () => Navigator.of(ctx2).pop(true), child: Text(l10n.assistantSettingsDeleteDialogConfirm)),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  final ok = await context.read<AssistantProvider>().deleteAssistant(a.id);
                  if (!ok) {
                    showAppSnackBar(context, message: l10n.assistantSettingsAtLeastOneAssistantRequired, type: NotificationType.warning);
                  } else {
                    try { await context.read<TagProvider>().unassignAssistant(a.id); } catch (_) {}
                  }
                }, danger: true),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _editAvatar(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final maxH = MediaQuery.sizeOf(ctx).height * 0.8;
        Widget row(String text, VoidCallback onTap) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(
              height: 48,
              child: IosCardPress(
                borderRadius: BorderRadius.circular(14),
                baseColor: cs.surface,
                duration: const Duration(milliseconds: 260),
                onTap: () async {
                  Haptics.light();
                  Navigator.of(ctx).pop();
                  await Future<void>.delayed(const Duration(milliseconds: 10));
                  onTap();
                },
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                ),
              ),
            ),
          );
        }
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: cs.onSurface.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    row(l10n.sideDrawerChooseImage, () async { await _pickLocalImage(context); }),
                    row(l10n.sideDrawerChooseEmoji, () async {
                      final emoji = await _pickEmoji(context);
                      if (emoji != null) {
                        await context.read<UserProvider>().setAvatarEmoji(emoji);
                      }
                    }),
                    row(l10n.sideDrawerEnterLink, () async { await _inputAvatarUrl(context); }),
                    row(l10n.sideDrawerImportFromQQ, () async { await _inputQQAvatar(context); }),
                    row(l10n.sideDrawerReset, () async { await context.read<UserProvider>().resetAvatar(); }),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<String?> _pickEmoji(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    // Provide input to allow any emoji via system emoji keyboard,
    // plus a large set of quick picks for convenience.
    final controller = TextEditingController();
    String value = '';
    bool validGrapheme(String s) {
      final trimmed = s.characters.take(1).toString().trim();
      return trimmed.isNotEmpty && trimmed == s.trim();
    }
    final List<String> quick = const [
      '😀','😁','😂','🤣','😃','😄','😅','😊','😍','😘','😗','😙','😚','🙂','🤗','🤩','🫶','🤝','👍','👎','👋','🙏','💪','🔥','✨','🌟','💡','🎉','🎊','🎈','🌈','☀️','🌙','⭐','⚡','☁️','❄️','🌧️','🍎','🍊','🍋','🍉','🍇','🍓','🍒','🍑','🥭','🍍','🥝','🍅','🥕','🌽','🍞','🧀','🍔','🍟','🍕','🌮','🌯','🍣','🍜','🍰','🍪','🍩','🍫','🍻','☕','🧋','🥤','⚽','🏀','🏈','🎾','🏐','🎮','🎧','🎸','🎹','🎺','📚','✏️','💼','💻','🖥️','📱','🛩️','✈️','🚗','🚕','🚙','🚌','🚀','🛰️','🧠','🫀','💊','🩺','🐶','🐱','🐭','🐹','🐰','🦊','🐻','🐼','🐨','🐯','🦁','🐮','🐷','🐸','🐵'
    ];
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return StatefulBuilder(builder: (ctx, setLocal) {
          // Revert to non-scrollable dialog but cap grid height
          // based on available height when keyboard is visible.
          final size = MediaQuery.sizeOf(ctx);
          final viewInsets = MediaQuery.viewInsetsOf(ctx);
          final avail = size.height - viewInsets.bottom;
          final double gridHeight = (avail * 0.28).clamp(120.0, 220.0);
          return AlertDialog(
            scrollable: true,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: cs.surface,
            title: Text(l10n.sideDrawerEmojiDialogTitle),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: EmojiText(
                      value.isEmpty ? '🙂' : value.characters.take(1).toString(),
                      fontSize: 40,
                      optimizeEmojiAlign: true,
                      nudge: Offset.zero, // mobile/desktop picker preview: no extra nudge
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    onChanged: (v) => setLocal(() => value = v),
                    onSubmitted: (_) {
                      if (validGrapheme(value)) Navigator.of(ctx).pop(value.characters.take(1).toString());
                    },
                    decoration: InputDecoration(
                      hintText: l10n.sideDrawerEmojiDialogHint,
                      filled: true,
                      fillColor: Theme.of(ctx).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF2F3F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.transparent),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.transparent),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cs.primary.withOpacity(0.4)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: gridHeight,
                    child: GridView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 8,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: quick.length,
                      itemBuilder: (c, i) {
                        final e = quick[i];
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.of(ctx).pop(e),
                          child: Container(
                            decoration: BoxDecoration(
                              color: cs.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: EmojiText(
                              e,
                              fontSize: 20,
                              optimizeEmojiAlign: true,
                              nudge: Offset.zero, // picker grid: no extra nudge
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.sideDrawerCancel),
              ),
              TextButton(
                onPressed: validGrapheme(value) ? () => Navigator.of(ctx).pop(value.characters.take(1).toString()) : null,
                child: Text(
                  l10n.sideDrawerSave,
                  style: TextStyle(
                    color: validGrapheme(value) ? cs.primary : cs.onSurface.withOpacity(0.38),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _inputAvatarUrl(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        bool valid(String s) => s.trim().startsWith('http://') || s.trim().startsWith('https://');
        String value = '';
        return StatefulBuilder(builder: (ctx, setLocal) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: cs.surface,
            title: Text(l10n.sideDrawerImageUrlDialogTitle),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.sideDrawerImageUrlDialogHint,
                filled: true,
                fillColor: Theme.of(ctx).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF2F3F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.transparent),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.transparent),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.primary.withOpacity(0.4)),
                ),
              ),
              onChanged: (v) => setLocal(() => value = v),
              onSubmitted: (_) {
                if (valid(value)) Navigator.of(ctx).pop(true);
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.sideDrawerCancel),
              ),
              TextButton(
                onPressed: valid(value) ? () => Navigator.of(ctx).pop(true) : null,
                child: Text(
                  l10n.sideDrawerSave,
                  style: TextStyle(
                    color: valid(value) ? cs.primary : cs.onSurface.withOpacity(0.38),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        });
      },
    );
    if (ok == true) {
      final url = controller.text.trim();
      if (url.isNotEmpty) {
        await context.read<UserProvider>().setAvatarUrl(url);
      }
    }
  }

  Future<void> _inputQQAvatar(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        String value = '';
        bool valid(String s) => RegExp(r'^[0-9]{5,12}$').hasMatch(s.trim());
        String randomQQ() {
          final lengths = <int>[5, 6, 7, 8, 9, 10, 11];
          final weights = <int>[1, 20, 80, 100, 500, 5000, 80];
          final total = weights.fold<int>(0, (a, b) => a + b);
          final rnd = math.Random();
          int roll = rnd.nextInt(total) + 1;
          int chosenLen = lengths.last;
          int acc = 0;
          for (int i = 0; i < lengths.length; i++) {
            acc += weights[i];
            if (roll <= acc) {
              chosenLen = lengths[i];
              break;
            }
          }
          final sb = StringBuffer();
          final firstGroups = <List<int>>[
            [1, 2],
            [3, 4],
            [5, 6, 7, 8],
            [9],
          ];
          final firstWeights = <int>[128, 4, 2, 1]; // ratio only; ensures 1-2 > 3-4 > 5-8 > 9
          final firstTotal = firstWeights.fold<int>(0, (a, b) => a + b);
          int r2 = rnd.nextInt(firstTotal) + 1;
          int idx = 0;
          int a2 = 0;
          for (int i = 0; i < firstGroups.length; i++) {
            a2 += firstWeights[i];
            if (r2 <= a2) { idx = i; break; }
          }
          final group = firstGroups[idx];
          sb.write(group[rnd.nextInt(group.length)]);
          for (int i = 1; i < chosenLen; i++) {
            sb.write(rnd.nextInt(10));
          }
          return sb.toString();
        }
        return StatefulBuilder(builder: (ctx, setLocal) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: cs.surface,
            title: Text(l10n.sideDrawerQQAvatarDialogTitle),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: l10n.sideDrawerQQAvatarInputHint,
                filled: true,
                fillColor: Theme.of(ctx).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF2F3F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.transparent),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.transparent),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.primary.withOpacity(0.4)),
                ),
              ),
              onChanged: (v) => setLocal(() => value = v),
              onSubmitted: (_) {
                if (valid(value)) Navigator.of(ctx).pop(true);
              },
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              TextButton(
                onPressed: () async {
                  // Try multiple times until a valid avatar is fetched
                  const int maxTries = 20;
                  bool applied = false;
                  for (int i = 0; i < maxTries; i++) {
                    final qq = randomQQ();
                    // debugPrint(qq);
                    final url = 'https://q2.qlogo.cn/headimg_dl?dst_uin=' + qq + '&spec=100';
                    try {
                      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
                      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
                        await context.read<UserProvider>().setAvatarUrl(url);
                        applied = true;
                        break;
                      }
                    } catch (_) {}
                  }
                  if (applied) {
                    if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop(false);
                  } else {
                    showAppSnackBar(
                      context,
                      message: l10n.sideDrawerQQAvatarFetchFailed,
                      type: NotificationType.error,
                    );
                  }
                },
                child: Text(l10n.sideDrawerRandomQQ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(l10n.sideDrawerCancel),
                  ),
                  TextButton(
                    onPressed: valid(value) ? () => Navigator.of(ctx).pop(true) : null,
                    child: Text(
                      l10n.sideDrawerSave,
                      style: TextStyle(
                        color: valid(value) ? cs.primary : cs.onSurface.withOpacity(0.38),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        });
      },
    );
    if (ok == true) {
      final qq = controller.text.trim();
      if (qq.isNotEmpty) {
        final url = 'https://q2.qlogo.cn/headimg_dl?dst_uin=' + qq + '&spec=100';
        await context.read<UserProvider>().setAvatarUrl(url);
      }
    }
  }

  Future<void> _pickLocalImage(BuildContext context) async {
    if (kIsWeb) {
      await _inputAvatarUrl(context);
      return;
    }
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 90,
      );
      if (!mounted) return;
      if (file != null) {
        await context.read<UserProvider>().setAvatarFilePath(file.path);
        return;
      }
    } on PlatformException catch (e) {
      // Gracefully degrade when plugin channel isn't available or permission denied.
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      showAppSnackBar(
        context,
        message: l10n.sideDrawerGalleryOpenError,
        type: NotificationType.error,
      );
      await _inputAvatarUrl(context);
      return;
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      showAppSnackBar(
        context,
        message: l10n.sideDrawerGeneralImageError,
        type: NotificationType.error,
      );
      await _inputAvatarUrl(context);
      return;
    }
  }
  Future<void> _editUserName(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final initial = widget.userName;
    final controller = TextEditingController(text: initial);
    const maxLen = 24;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        String value = controller.text;
        bool valid(String v) => v.trim().isNotEmpty && v.trim() != initial;
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: cs.surface,
              title: Text(l10n.sideDrawerSetNicknameTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLength: maxLen,
                    textInputAction: TextInputAction.done,
                    onChanged: (v) => setLocal(() => value = v),
                    onSubmitted: (_) {
                      if (valid(value)) Navigator.of(ctx).pop(true);
                    },
                    decoration: InputDecoration(
                      labelText: l10n.sideDrawerNicknameLabel,
                      hintText: l10n.sideDrawerNicknameHint,
                      filled: true,
                      fillColor: isDark ? Colors.white10 : const Color(0xFFF2F3F5),
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.transparent),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.transparent),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cs.primary.withOpacity(0.4)),
                      ),
                    ),
                    style: TextStyle(fontSize: 15, color: Theme.of(ctx).textTheme.bodyMedium?.color),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${value.trim().length}/$maxLen',
                      style: TextStyle(color: cs.onSurface.withOpacity(0.45), fontSize: 12),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(l10n.sideDrawerCancel),
                ),
                TextButton(
                  onPressed: valid(value) ? () => Navigator.of(ctx).pop(true) : null,
                  child: Text(
                    l10n.sideDrawerSave,
                    style: TextStyle(
                      color: valid(value) ? cs.primary : cs.onSurface.withOpacity(0.38),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  if (ok == true) {
      final text = controller.text.trim();
      if (text.isNotEmpty) {
        await context.read<UserProvider>().setName(text);
      }
    }
  }

  // Build assistants list (ungrouped + grouped by tags). When inlineMode=false (desktop tabs),
  // apply search filter on assistant names.
  Widget _buildAssistantsList(BuildContext context, {bool inlineMode = false}) {
    final ap2 = context.watch<AssistantProvider>();
    final tp = context.watch<TagProvider>();
    final isDark2 = Theme.of(context).brightness == Brightness.dark;
    final textBase2 = isDark2 ? Colors.white : Colors.black;

    List<Assistant> assistants = ap2.assistants;
    // Apply search filter when:
    // - Desktop tab mode (inlineMode == false), OR
    // - Desktop assistants-only mode (left sidebar when topics are on right)
    final shouldFilterAssistants = (!inlineMode) || (widget.desktopAssistantsOnly && _isDesktop);
    if (shouldFilterAssistants && _query.trim().isNotEmpty) {
      final q = _query.toLowerCase();
      assistants = assistants.where((a) => (a.name).toLowerCase().contains(q)).toList();
    }

    final tags = tp.tags;
    final ungrouped = assistants.where((a) => tp.tagOfAssistant(a.id) == null).toList();
    final groupedByTag = <String, List<Assistant>>{};
    for (final t in tags) {
      final list = assistants.where((a) => tp.tagOfAssistant(a.id) == t.id).toList();
      if (list.isNotEmpty) groupedByTag[t.id] = list;
    }

    Widget buildTile(Assistant a) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: _AssistantInlineTile(
          avatar: _assistantAvatar(context, a, size: _isDesktop ? 28 : 32),
          name: a.name,
          textColor: textBase2,
          embedded: widget.embedded,
          selected: ap2.currentAssistantId == a.id,
          onTap: () => _handleSelectAssistant(a),
          onEditTap: () => _openAssistantSettings(a.id),
          onLongPress: () => _showAssistantItemMenuMobile(a),
          onSecondaryTapDown: (pos) => _showAssistantItemMenuDesktop(a, pos),
        ),
      );
    }

    // Desktop: enable drag-reorder within each group; Mobile/tablet: keep static list
    final bool enableReorder = _isDesktop;

    Widget buildReorderable(List<Assistant> list, {required List<String> subsetIds}) {
      if (!enableReorder) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: list.map(buildTile).toList());
      }
      return ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        proxyDecorator: (child, index, animation) {
          // Remove default shadow/elevation and clip to rounded card only.
          return AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Material(
                  type: MaterialType.transparency,
                  child: child,
                ),
              );
            },
          );
        },
        onReorder: (oldIndex, newIndex) async {
          if (newIndex > oldIndex) newIndex -= 1;
          try {
            await context.read<AssistantProvider>().reorderAssistantsWithin(
              subsetIds: subsetIds,
              oldIndex: oldIndex,
              newIndex: newIndex,
            );
          } catch (_) {}
        },
        itemCount: list.length,
        itemBuilder: (ctx, index) {
          final a = list[index];
          final tile = buildTile(a);
          return KeyedSubtree(
            key: ValueKey('assistant-${a.id}'),
            child: ReorderableDragStartListener(
              index: index,
              enabled: enableReorder,
              child: tile,
            ),
          );
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ungrouped.isNotEmpty)
            buildReorderable(ungrouped, subsetIds: ungrouped.map((a) => a.id).toList()),
          for (final t in tags)
            if ((groupedByTag[t.id] ?? const <Assistant>[]).isNotEmpty) ...[
              const SizedBox(height: 4),
              _GroupHeader(
                title: t.name,
                collapsed: tp.isCollapsed(t.id),
                onToggle: () => tp.toggleCollapsed(t.id),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topCenter,
                child: tp.isCollapsed(t.id)
                    ? const SizedBox.shrink()
                    : buildReorderable(
                        groupedByTag[t.id]!,
                        subsetIds: (groupedByTag[t.id] ?? const <Assistant>[]) .map((a) => a.id).toList(),
                      ),
              ),
            ],
        ],
      ),
    );
  }

  // Build conversations list area, optionally including the update banner.
  Widget _buildConversationsList(
    BuildContext context,
    ColorScheme cs,
    Color textBase,
    ChatService chatService,
    List<ChatItem> pinnedList,
    List<_ChatGroup> groups, {
    bool includeUpdateBanner = false,
  }) {
    final children = <Widget>[];
    if (includeUpdateBanner) {
      children.add(Builder(builder: (context) {
        final settings = context.watch<SettingsProvider>();
        final upd = context.watch<UpdateProvider>();
        if (!settings.showAppUpdates) return const SizedBox.shrink();
        final info = upd.available;
        if (upd.checking && info == null) return const SizedBox.shrink();
        if (info == null) return const SizedBox.shrink();
        final url = info.bestDownloadUrl();
        if (url == null || url.isEmpty) return const SizedBox.shrink();
        final ver = info.version;
        final build = info.build;
        final l10n = AppLocalizations.of(context)!;
        final title = build != null
            ? l10n.sideDrawerUpdateTitleWithBuild(ver, build)
            : l10n.sideDrawerUpdateTitle(ver);
        final cs2 = Theme.of(context).colorScheme;
        final isDark2 = Theme.of(context).brightness == Brightness.dark;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: isDark2 ? Colors.white10 : const Color(0xFFF2F3F5),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final uri = Uri.parse(url);
                try {
                  // ignore: deprecated_member_use
                  await launchUrl(uri);
                } catch (_) {
                  Clipboard.setData(ClipboardData(text: url));
                  showAppSnackBar(
                    context,
                    message: l10n.sideDrawerLinkCopied,
                    type: NotificationType.success,
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Lucide.BadgeInfo, size: 18, color: cs2.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    if ((info.notes ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        info.notes!,
                        style: TextStyle(fontSize: 13, color: cs2.onSurface.withOpacity(0.8)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      }));
    }

    children.add(
      PageTransitionSwitcher(
        duration: const Duration(milliseconds: 260),
        reverse: false,
        transitionBuilder: (child, primary, secondary) => FadeThroughTransition(
          fillColor: Colors.transparent,
          animation: CurvedAnimation(parent: primary, curve: Curves.easeOutCubic),
          secondaryAnimation: CurvedAnimation(parent: secondary, curve: Curves.easeInCubic),
          child: child,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          key: ValueKey('${_query}_' + ([...pinnedList.map((c)=>c.id), ...groups.expand((g)=>g.items.map((c)=>c.id))].join(','))),
          children: [
            if (pinnedList.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 0, 6),
                child: Text(
                  AppLocalizations.of(context)!.sideDrawerPinnedLabel,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.primary),
                ).animate().fadeIn(duration: 180.ms).moveY(begin: 4, end: 0, duration: 220.ms, curve: Curves.easeOutCubic),
              ),
              Column(
                children: [
                  for (int i = 0; i < pinnedList.length; i++)
                    _ChatTile(
                      chat: pinnedList[i],
                      textColor: textBase,
                      selected: pinnedList[i].id == chatService.currentConversationId,
                      loading: widget.loadingConversationIds.contains(pinnedList[i].id),
                      onTap: () {
                        final closeDrawer = !context.read<SettingsProvider>().keepSidebarOpenOnTopicTap;
                        widget.onSelectConversation?.call(pinnedList[i].id, closeDrawer: closeDrawer);
                      },
                      onLongPress: () => _showChatMenu(context, pinnedList[i]),
                      onSecondaryTap: (pos) => _showChatMenu(context, pinnedList[i], anchor: pos),
                    ).animate(key: ValueKey('pin-${pinnedList[i].id}'))
                      .fadeIn(duration: 220.ms, delay: (20 * i).ms)
                      .moveY(begin: 8, end: 0, duration: 260.ms, curve: Curves.easeOutCubic, delay: (20 * i).ms),
                ],
              ),
              const SizedBox(height: 8),
            ],
            for (final group in groups) ...[
              if (context.watch<SettingsProvider>().showChatListDate)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 0, 6),
                  child: Text(
                    group.label,
                    textAlign: TextAlign.left,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.primary),
                  ).animate().fadeIn(duration: 180.ms).moveY(begin: 4, end: 0, duration: 220.ms, curve: Curves.easeOutCubic),
                ),
              Column(
                children: [
                  for (int j = 0; j < group.items.length; j++)
                    _ChatTile(
                      chat: group.items[j],
                      textColor: textBase,
                      selected: group.items[j].id == chatService.currentConversationId,
                      loading: widget.loadingConversationIds.contains(group.items[j].id),
                      onTap: () {
                        final closeDrawer = !context.read<SettingsProvider>().keepSidebarOpenOnTopicTap;
                        widget.onSelectConversation?.call(group.items[j].id, closeDrawer: closeDrawer);
                      },
                      onLongPress: () => _showChatMenu(context, group.items[j]),
                      onSecondaryTap: (pos) => _showChatMenu(context, group.items[j], anchor: pos),
                    ).animate(key: ValueKey('grp-${group.label}-${group.items[j].id}'))
                      .fadeIn(duration: 220.ms, delay: (16 * j).ms)
                      .moveY(begin: 6, end: 0, duration: 240.ms, curve: Curves.easeOutCubic, delay: (16 * j).ms),
                ],
              ),
              if (context.watch<SettingsProvider>().showChatListDate)
                const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );

    return Column(children: children);
  }
}

class _ChatGroup {
  final String label;
  final List<ChatItem> items;
  _ChatGroup({required this.label, required this.items});
}

class _ChatTile extends StatefulWidget {
  const _ChatTile({
    required this.chat,
    required this.textColor,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.selected = false,
    this.loading = false,
  });

  final ChatItem chat;
  final Color textColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final void Function(Offset globalPosition)? onSecondaryTap;
  final bool selected;
  final bool loading;

  @override
  State<_ChatTile> createState() => _ChatTileState();
}

class _ChatTileState extends State<_ChatTile> {
  bool _hovered = false;
  bool get _isDesktop => defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final embedded = context.findAncestorWidgetOfExactType<SideDrawer>()?.embedded ?? false;
    final Color tileColor;
    if (embedded) {
      // In tablet embedded mode, keep selected highlight, others transparent
      tileColor = widget.selected ? cs.primary.withOpacity(0.16) : Colors.transparent;
    } else {
      tileColor = widget.selected ? cs.primary.withOpacity(0.12) : cs.surface;
    }
    final base = _isDesktop && !widget.selected && _hovered
        ? (embedded ? cs.primary.withOpacity(0.08) : cs.surface.withOpacity(0.9))
        : tileColor;
    final double _vGap = _isDesktop ? 4 : 4;
    return Padding(
      padding: EdgeInsets.only(bottom: _vGap),
      child: GestureDetector(
        onSecondaryTapDown: (details) {
          if (_isDesktop) {
            widget.onSecondaryTap?.call(details.globalPosition);
          }
        },
        onLongPress: () {
          if (_isDesktop) return;
          widget.onLongPress?.call();
        },
        child: MouseRegion(
          onEnter: (_) { if (_isDesktop) setState(() => _hovered = true); },
          onExit: (_) { if (_isDesktop) setState(() => _hovered = false); },
          cursor: _isDesktop ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: IosCardPress(
          baseColor: base,
          borderRadius: BorderRadius.circular(16),
          haptics: false,
          onTap: widget.onTap,
          onLongPress: _isDesktop ? null : widget.onLongPress,
          padding: EdgeInsets.fromLTRB(_isDesktop ? 14 : 14, _isDesktop ? 9 : 10, 8, _isDesktop ? 9 : 10),
          child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.chat.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: _isDesktop ? 14 : 15,
                      color: widget.textColor,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                if (widget.loading) ...[
                  const SizedBox(width: 8),
                  _LoadingDot(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingDot extends StatefulWidget {
  @override
  State<_LoadingDot> createState() => _LoadingDotState();
}

class _LoadingDotState extends State<_LoadingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title, required this.collapsed, required this.onToggle});
  final String title;
  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textBase = cs.onSurface;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            AnimatedRotation(
              turns: collapsed ? 0.0 : 0.25, // right -> down
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: Icon(
                Lucide.ChevronRight,
                size: 16,
                color: textBase.withOpacity(0.7),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: textBase),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Desktop: Header tabs (Assistants / Topics)
class _DesktopSidebarTabs extends StatefulWidget {
  const _DesktopSidebarTabs({required this.textColor, required this.controller});
  final Color textColor;
  final TabController controller;
  @override
  State<_DesktopSidebarTabs> createState() => _DesktopSidebarTabsState();
}

class _DesktopSidebarTabsState extends State<_DesktopSidebarTabs> {
  bool _hoverLeft = false;
  bool _hoverRight = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuildOnTabChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuildOnTabChanged);
    super.dispose();
  }

  void _rebuildOnTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final idx = widget.controller.index;
    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double pad = 4;
            final double segW = (constraints.maxWidth - pad * 2) / 2;
            return Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey.shade200.withOpacity(0.80),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  // Selection knob
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOutCubic,
                    left: pad + (idx == 0 ? 0 : segW),
                    top: pad,
                    bottom: pad,
                    width: segW,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(isDark ? 0.16 : 0.12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  ),
                  // Left segment
                  Row(
                    children: [
                      Expanded(
                        child: MouseRegion(
                          onEnter: (_) => setState(() => _hoverLeft = true),
                          onExit: (_) => setState(() => _hoverLeft = false),
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => widget.controller.animateTo(0, duration: const Duration(milliseconds: 140), curve: Curves.easeOutCubic),
                            child: Stack(
                              children: [
                                // Hover wash
                                AnimatedOpacity(
                                  duration: const Duration(milliseconds: 120),
                                  curve: Curves.easeOutCubic,
                                  opacity: _hoverLeft && idx != 0 ? 1 : 0,
                                  child: Container(
                                    margin: EdgeInsets.all(pad),
                                    decoration: BoxDecoration(
                                      color: cs.primary.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                  ),
                                ),
                                // Label
                                Center(
                                  child: AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 140),
                                    curve: Curves.easeOutCubic,
                                    style: (Theme.of(context).textTheme.titleSmall ?? const TextStyle()).copyWith(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: idx == 0 ? cs.primary : widget.textColor.withOpacity(0.78),
                                    ),
                                    child: Text(l10n.desktopSidebarTabAssistants, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: MouseRegion(
                          onEnter: (_) => setState(() => _hoverRight = true),
                          onExit: (_) => setState(() => _hoverRight = false),
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => widget.controller.animateTo(1, duration: const Duration(milliseconds: 140), curve: Curves.easeOutCubic),
                            child: Stack(
                              children: [
                                AnimatedOpacity(
                                  duration: const Duration(milliseconds: 120),
                                  curve: Curves.easeOutCubic,
                                  opacity: _hoverRight && idx != 1 ? 1 : 0,
                                  child: Container(
                                    margin: EdgeInsets.all(pad),
                                    decoration: BoxDecoration(
                                      color: cs.primary.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                  ),
                                ),
                                Center(
                                  child: AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 140),
                                    curve: Curves.easeOutCubic,
                                    style: (Theme.of(context).textTheme.titleSmall ?? const TextStyle()).copyWith(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: idx == 1 ? cs.primary : widget.textColor.withOpacity(0.78),
                                    ),
                                    child: Text(l10n.desktopSidebarTabTopics, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// Desktop: TabBarView area hosting assistants and topics lists
class _DesktopTabViews extends StatelessWidget {
  const _DesktopTabViews({
    required this.controller,
    required this.listController,
    required this.buildAssistants,
    required this.buildConversations,
  });
  final TabController controller;
  final ScrollController listController;
  final Widget Function() buildAssistants;
  final Widget Function() buildConversations;

  @override
  Widget build(BuildContext context) {
    final isDesktop = defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
    final topPad = context.watch<SettingsProvider>().showChatListDate ? (isDesktop ? 2.0 : 4.0) : 10.0;
    return TabBarView(
      controller: controller,
      physics: const BouncingScrollPhysics(),
      children: [
        // Assistants
        ListView(
          controller: listController,
          padding: const EdgeInsets.fromLTRB(10, 2, 10, 16),
          children: [buildAssistants()],
        ),
        // Topics (conversations)
        ListView(
          controller: listController,
          padding: EdgeInsets.fromLTRB(10, topPad, 10, 16),
          children: [buildConversations()],
        ),
      ],
    );
  }
}

// Legacy (mobile/tablet): original single-list layout with optional inline assistants
class _LegacyListArea extends StatelessWidget {
  const _LegacyListArea({
    required this.listController,
    required this.isDesktop,
    required this.assistantsExpanded,
    required this.buildAssistants,
    required this.buildConversations,
  });
  final ScrollController listController;
  final bool isDesktop;
  final bool assistantsExpanded;
  final Widget Function() buildAssistants;
  final Widget Function() buildConversations;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: listController,
      padding: EdgeInsets.fromLTRB(
        10,
        (context.watch<SettingsProvider>().showChatListDate || assistantsExpanded)
            ? (isDesktop ? 2 : 4)
            : 10,
        10,
        16,
      ),
      children: [
        // Inline assistants
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
            child: !assistantsExpanded
                ? const SizedBox.shrink()
                : KeyedSubtree(key: const ValueKey('assistants-inline'), child: buildAssistants()),
          ),
        ),
        // Conversations
        buildConversations(),
      ],
    );
  }
}

class _AssistantInlineTile extends StatefulWidget {
  const _AssistantInlineTile({
    required this.avatar,
    required this.name,
    required this.textColor,
    required this.embedded,
    required this.onTap,
    required this.onEditTap,
    this.onLongPress,
    this.onSecondaryTapDown,
    this.selected = false,
  });

  final Widget avatar;
  final String name;
  final Color textColor;
  final bool embedded;
  final VoidCallback onTap;
  final VoidCallback onEditTap;
  final VoidCallback? onLongPress;
  final void Function(Offset globalPosition)? onSecondaryTapDown;
  final bool selected;

  @override
  State<_AssistantInlineTile> createState() => _AssistantInlineTileState();
}

class _AssistantInlineTileState extends State<_AssistantInlineTile> {
  bool _hovered = false;
  bool get _isDesktop => defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final embedded = widget.embedded;
    final Color tileColor = _isDesktop
        ? (embedded
            ? (widget.selected ? cs.primary.withOpacity(0.16) : Colors.transparent)
            : (widget.selected ? cs.primary.withOpacity(0.12) : cs.surface))
        : (embedded ? Colors.transparent : cs.surface);
    final Color bg = _isDesktop && !widget.selected && _hovered
        ? (embedded ? cs.primary.withOpacity(0.08) : cs.surface.withOpacity(0.9))
        : tileColor;
    final content = MouseRegion(
      onEnter: (_) { if (_isDesktop) setState(() => _hovered = true); },
      onExit: (_) { if (_isDesktop) setState(() => _hovered = false); },
      cursor: _isDesktop ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: IosCardPress(
        baseColor: bg,
        borderRadius: BorderRadius.circular(16),
        haptics: false,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        padding: EdgeInsets.fromLTRB(_isDesktop ? 12 : 4, 6, 12, 6),
        child: Row(
          children: [
            widget.avatar,
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                widget.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: _isDesktop ? 14 : 15, fontWeight: FontWeight.w600, color: widget.textColor),
              ),
            ),
            if (!_isDesktop) ...[
              const SizedBox(width: 8),
              IosIconButton(
                icon: Lucide.Pencil,
                size: 18,
                color: cs.onSurface.withOpacity(0.7),
                padding: const EdgeInsets.all(8),
                minSize: 36,
                onTap: widget.onEditTap,
                semanticLabel: 'Edit assistant',
              ),
            ],
          ],
        ),
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: widget.onSecondaryTapDown == null
          ? null
          : (details) => widget.onSecondaryTapDown!(details.globalPosition),
      child: content,
    );
  }
}
