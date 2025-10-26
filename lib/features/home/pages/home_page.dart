import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'dart:async';
import 'dart:convert';
// Replaced flutter_zoom_drawer with a custom InteractiveDrawer
import '../../../shared/widgets/interactive_drawer.dart';
import '../../../shared/responsive/breakpoints.dart';

import '../widgets/chat_input_bar.dart';
import '../../../core/models/chat_input_data.dart';
import '../../chat/widgets/bottom_tools_sheet.dart';
import '../widgets/side_drawer.dart';
import '../../chat/widgets/chat_message_widget.dart';
import '../../../theme/design_tokens.dart';
import '../../../icons/lucide_adapter.dart';
import 'package:provider/provider.dart';
import '../../../main.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/services/chat/prompt_transformer.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/services/api/chat_api_service.dart';
import '../../../core/services/chat/document_text_extractor.dart';
import '../../../core/services/mcp/mcp_tool_service.dart';
import '../../../core/models/token_usage.dart';
import '../../../core/providers/model_provider.dart';
import '../../../core/providers/mcp_provider.dart';
import '../../../core/providers/tts_provider.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/conversation.dart';
import '../../model/widgets/model_select_sheet.dart';
import '../../settings/widgets/language_select_sheet.dart';
import '../../chat/widgets/message_more_sheet.dart';
import '../../chat/pages/message_edit_page.dart';
import '../../chat/widgets/message_export_sheet.dart';
import '../../assistant/widgets/mcp_assistant_sheet.dart';
import '../../mcp/pages/mcp_page.dart';
import '../../provider/pages/providers_page.dart';
import '../../chat/widgets/reasoning_budget_sheet.dart';
import '../../search/widgets/search_settings_sheet.dart';
import '../widgets/mini_map_sheet.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../utils/brand_assets.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io' show File, Directory;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import '../../../core/services/search/search_tool_service.dart';
import '../../../utils/markdown_media_sanitizer.dart';
import '../../../core/services/learning_mode_store.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../../shared/animations/widgets.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../core/services/haptics.dart';
import '../../../core/models/quick_phrase.dart';
import '../../../core/providers/quick_phrase_provider.dart';
import '../../quick_phrase/widgets/quick_phrase_menu.dart';
import '../../quick_phrase/pages/quick_phrases_page.dart';
import '../../../shared/widgets/ios_checkbox.dart';
import '../../../shared/widgets/typing_indicator.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin, RouteAware {
  // Inline bottom tools panel removed; using modal bottom sheet instead
  // Animation tuning
  static const Duration _scrollAnimateDuration = Duration(milliseconds: 300);
  static const Duration _postSwitchScrollDelay = Duration(milliseconds: 220);
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final InteractiveDrawerController _drawerController = InteractiveDrawerController();
  final ValueNotifier<int> _assistantPickerCloseTick = ValueNotifier<int>(0);
  final FocusNode _inputFocus = FocusNode();
  final TextEditingController _inputController = TextEditingController();
  final ChatInputBarController _mediaController = ChatInputBarController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _inputBarKey = GlobalKey();
  late final AnimationController _convoFadeController;
  late final Animation<double> _convoFade;
  double _inputBarHeight = 72;

  late ChatService _chatService;
  Conversation? _currentConversation;
  List<ChatMessage> _messages = [];
  // Support concurrent generation per conversation
  final Map<String, StreamSubscription> _conversationStreams = <String, StreamSubscription>{}; // conversationId -> subscription
  final Set<String> _loadingConversationIds = <String>{}; // active generating conversations
  final Map<String, _ReasoningData> _reasoning = <String, _ReasoningData>{};
  final Map<String, _TranslationData> _translations = <String, _TranslationData>{};
  final Map<String, List<ToolUIPart>> _toolParts = <String, List<ToolUIPart>>{}; // assistantMessageId -> parts
  final Map<String, List<_ReasoningSegmentData>> _reasoningSegments = <String, List<_ReasoningSegmentData>>{}; // assistantMessageId -> reasoning segments
  // Message widget keys for navigation to previous question
  final Map<String, GlobalKey> _messageKeys = <String, GlobalKey>{};
  GlobalKey _keyForMessage(String id) => _messageKeys.putIfAbsent(id, () => GlobalKey(debugLabel: 'msg:$id'));
  McpProvider? _mcpProvider;
  Set<String> _connectedMcpIds = <String>{};
  bool _showJumpToBottom = false;
  bool _isUserScrolling = false;
  Timer? _userScrollTimer;

  // Sanitize/translate JSON Schema to each provider's accepted subset
  static Map<String, dynamic> _sanitizeToolParametersForProvider(Map<String, dynamic> schema, ProviderKind kind) {
    Map<String, dynamic> clone = _deepCloneMap(schema);
    clone = _sanitizeNode(clone, kind) as Map<String, dynamic>;
    return clone;
  }

  static dynamic _sanitizeNode(dynamic node, ProviderKind kind) {
    if (node is List) {
      return node.map((e) => _sanitizeNode(e, kind)).toList();
    }
    if (node is! Map) return node;

    final m = Map<String, dynamic>.from(node as Map);
    m.remove(r'$schema');
    if (m.containsKey('const')) {
      final v = m['const'];
      if (v is String || v is num || v is bool) {
        m['enum'] = [v];
      }
      m.remove('const');
    }
    for (final key in ['anyOf', 'oneOf', 'allOf', 'any_of', 'one_of', 'all_of']) {
      if (m[key] is List && (m[key] as List).isNotEmpty) {
        final first = (m[key] as List).first;
        final flattened = _sanitizeNode(first, kind);
        m.remove(key);
        if (flattened is Map<String, dynamic>) {
          m
            ..remove('type')
            ..remove('properties')
            ..remove('items');
          m.addAll(flattened);
        }
      }
    }
    final t = m['type'];
    if (t is List && t.isNotEmpty) m['type'] = t.first.toString();
    final items = m['items'];
    if (items is List && items.isNotEmpty) m['items'] = items.first;
    if (m['items'] is Map) m['items'] = _sanitizeNode(m['items'], kind);
    if (m['properties'] is Map) {
      final props = Map<String, dynamic>.from(m['properties']);
      final norm = <String, dynamic>{};
      props.forEach((k, v) {
        norm[k] = _sanitizeNode(v, kind);
      });
      m['properties'] = norm;
    }
    Set<String> allowed;
    switch (kind) {
      case ProviderKind.google:
        allowed = {'type', 'description', 'properties', 'required', 'items', 'enum'};
        break;
      case ProviderKind.openai:
      case ProviderKind.claude:
        allowed = {'type', 'description', 'properties', 'required', 'items', 'enum'};
        break;
    }
    m.removeWhere((k, v) => !allowed.contains(k));
    return m;
  }

  static Map<String, dynamic> _deepCloneMap(Map<String, dynamic> input) {
    return jsonDecode(jsonEncode(input)) as Map<String, dynamic>;
  }
  // Tablet: whether the left embedded sidebar is visible
  bool _tabletSidebarOpen = true;
  bool _learningModeEnabled = false;
  static const Duration _sidebarAnimDuration = Duration(milliseconds: 260);
  static const Curve _sidebarAnimCurve = Curves.easeOutCubic;

  // Drawer haptics for swipe-open
  double _lastDrawerValue = 0.0;
  // Removed early-open haptic; vibrate on open completion instead

  // Removed raw-pointer-based swipe-to-open; rely on drawer's own gestures

  Widget _buildAssistantBackground(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final assistant = context.watch<AssistantProvider>().currentAssistant;
    final bgRaw = (assistant?.background ?? '').trim();
    Widget? bg;
    if (bgRaw.isNotEmpty) {
      if (bgRaw.startsWith('http')) {
            bg = Image.network(bgRaw, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink());
      } else {
        try {
          final fixed = SandboxPathResolver.fix(bgRaw);
              if (!kIsWeb) {
                final f = File(fixed);
                if (f.existsSync()) {
                  bg = Image(image: FileImage(f), fit: BoxFit.cover);
                }
              }
        } catch (_) {}
      }
    }
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Base fill to avoid black background when no assistant background set
          ColoredBox(color: cs.background),
          if (bg != null) Opacity(opacity: 0.9, child: bg),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  cs.background.withOpacity(0.08),
                  cs.background.withOpacity(0.36),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  // no-op placeholders removed

  Future<void> _showLearningPromptSheet() async {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final prompt = await LearningModeStore.getPrompt();
    final controller = TextEditingController(text: prompt);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: cs.onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(999)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(l10n.bottomToolsSheetPrompt, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  maxLines: 10,
                  decoration: InputDecoration(
                    hintText: l10n.bottomToolsSheetPromptHint,
                    filled: true,
                    fillColor: Theme.of(ctx).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF2F3F5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.4))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.4))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary.withOpacity(0.5))),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () async {
                        await LearningModeStore.resetPrompt();
                        controller.text = await LearningModeStore.getPrompt();
                      },
                      child: Text(l10n.bottomToolsSheetResetDefault),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () async {
                        await LearningModeStore.setPrompt(controller.text.trim());
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      child: Text(l10n.bottomToolsSheetSave),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Anchor for chained "jump to previous question" navigation
  String? _lastJumpUserMessageId;

  // Deduplicate tool UI parts by id or by name+args when id is empty
  List<ToolUIPart> _dedupeToolPartsList(List<ToolUIPart> parts) {
    final seen = <String>{};
    final out = <ToolUIPart>[];
    for (final p in parts) {
      final id = (p.id).trim();
      final key = id.isNotEmpty ? 'id:$id' : 'name:${p.toolName}|args:${jsonEncode(p.arguments)}';
      if (seen.add(key)) out.add(p);
    }
    return out;
  }

  // Deduplicate raw persisted tool events using same criteria
  List<Map<String, dynamic>> _dedupeToolEvents(List<Map<String, dynamic>> events) {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final e in events) {
      final id = (e['id']?.toString() ?? '').trim();
      final name = (e['name']?.toString() ?? '');
      final args = ((e['arguments'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{});
      final key = id.isNotEmpty ? 'id:$id' : 'name:$name|args:${jsonEncode(args)}';
      if (seen.add(key)) out.add(e.map((k, v) => MapEntry(k.toString(), v)));
    }
    return out;
  }

  // Selection mode state for export/share
  bool _selecting = false;
  final Set<String> _selectedItems = <String>{}; // selected message ids (collapsed view)

  // Helper methods to serialize/deserialize reasoning segments
  String _serializeReasoningSegments(List<_ReasoningSegmentData> segments) {
    final list = segments.map((s) => {
      'text': s.text,
      'startAt': s.startAt?.toIso8601String(),
      'finishedAt': s.finishedAt?.toIso8601String(),
      'expanded': s.expanded,
      'toolStartIndex': s.toolStartIndex,
    }).toList();
    return jsonEncode(list);
  }

  List<_ReasoningSegmentData> _deserializeReasoningSegments(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      final list = jsonDecode(json) as List;
      return list.map((item) {
        final s = _ReasoningSegmentData();
        s.text = item['text'] ?? '';
        s.startAt = item['startAt'] != null ? DateTime.parse(item['startAt']) : null;
        s.finishedAt = item['finishedAt'] != null ? DateTime.parse(item['finishedAt']) : null;
        s.expanded = item['expanded'] ?? false;
        s.toolStartIndex = (item['toolStartIndex'] as int?) ?? 0;
        return s;
      }).toList();
    } catch (_) {
      return [];
    }
  }

  bool _isReasoningModel(String providerKey, String modelId) {
    final settings = context.read<SettingsProvider>();
    final cfg = settings.getProviderConfig(providerKey);
    final ov = cfg.modelOverrides[modelId] as Map?;
    if (ov != null) {
      final abilities = (ov['abilities'] as List?)?.map((e) => e.toString()).toList() ?? const [];
      if (abilities.map((e) => e.toLowerCase()).contains('reasoning')) return true;
    }
    final inferred = ModelRegistry.infer(ModelInfo(id: modelId, displayName: modelId));
    return inferred.abilities.contains(ModelAbility.reasoning);
  }

  // Whether current conversation is generating
  bool get _isCurrentConversationLoading {
    final cid = _currentConversation?.id;
    if (cid == null) return false;
    return _loadingConversationIds.contains(cid);
  }

  // Update loading state for a conversation and refresh UI if needed
  void _setConversationLoading(String conversationId, bool loading) {
    final prev = _loadingConversationIds.contains(conversationId);
    if (loading) {
      _loadingConversationIds.add(conversationId);
    } else {
      _loadingConversationIds.remove(conversationId);
    }
    if (mounted && prev != loading) {
      setState(() {}); // Update input bar + drawer indicators
    }
  }

  Future<void> _cancelStreaming() async {
    final cid = _currentConversation?.id;
    if (cid == null) return;
    // Cancel active stream for current conversation only
    final sub = _conversationStreams.remove(cid);
    await sub?.cancel();

    // Find the latest assistant streaming message within current conversation and mark it finished
    ChatMessage? streaming;
    for (var i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      if (m.role == 'assistant' && m.isStreaming) {
        streaming = m;
        break;
      }
    }
    if (streaming != null) {
      await _chatService.updateMessage(
        streaming.id,
        content: streaming.content,
        isStreaming: false,
        totalTokens: streaming.totalTokens,
      );
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == streaming!.id);
          if (idx != -1) {
            _messages[idx] = _messages[idx].copyWith(isStreaming: false);
          }
        });
      }
      _setConversationLoading(cid, false);

      final r = _reasoning[streaming.id];
      if (r != null) {
        if (r.finishedAt == null) {
          r.finishedAt = DateTime.now();
          await _chatService.updateMessage(
            streaming.id,
            reasoningText: r.text,
            reasoningFinishedAt: r.finishedAt,
          );
        }
        final autoCollapse = context.read<SettingsProvider>().autoCollapseThinking;
        if (autoCollapse) {
          r.expanded = false;
        }
        _reasoning[streaming.id] = r;
        if (mounted) setState(() {});
      }

      final segs = _reasoningSegments[streaming.id];
      if (segs != null && segs.isNotEmpty && segs.last.finishedAt == null) {
        segs.last.finishedAt = DateTime.now();
        final autoCollapse = context.read<SettingsProvider>().autoCollapseThinking;
        if (autoCollapse) {
          segs.last.expanded = false;
        }
        _reasoningSegments[streaming.id] = segs;
        await _chatService.updateMessage(
          streaming.id,
          reasoningSegmentsJson: _serializeReasoningSegments(segs),
        );
      }
    } else {
      _setConversationLoading(cid, false);
    }
  }

  bool _isReasoningEnabled(int? budget) {
    if (budget == null) return true; // treat null as default/auto -> enabled
    if (budget == -1) return true; // auto
    return budget >= 1024;
  }

  String _titleForLocale(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return l10n.titleForLocale;
  }

  // Version selections (groupId -> selected version index)
  Map<String, int> _versionSelections = <String, int>{};

  void _loadVersionSelections() {
    final cid = _currentConversation?.id;
    if (cid == null) {
      _versionSelections = <String, int>{};
      return;
    }
    try {
      _versionSelections = _chatService.getVersionSelections(cid);
    } catch (_) {
      _versionSelections = <String, int>{};
    }
  }

  // Restore per-message UI states (reasoning/segments/tool parts/translation) after switching conversations
  void _restoreMessageUiState() {
    // Clear first to avoid stale entries
    _reasoning.clear();
    _reasoningSegments.clear();
    _toolParts.clear();
    _translations.clear();

    for (final m in _messages) {
      if (m.role == 'assistant') {
        // Restore reasoning state
        final txt = m.reasoningText ?? '';
        if (txt.isNotEmpty || m.reasoningStartAt != null || m.reasoningFinishedAt != null) {
          final rd = _ReasoningData();
          rd.text = txt;
          rd.startAt = m.reasoningStartAt;
          rd.finishedAt = m.reasoningFinishedAt;
          rd.expanded = false;
          _reasoning[m.id] = rd;
        }

        // Restore tool events persisted for this assistant message
        try {
          final events = _dedupeToolEvents(_chatService.getToolEvents(m.id));
          if (events.isNotEmpty) {
            _toolParts[m.id] = events
                .map((e) => ToolUIPart(
                      id: (e['id'] ?? '').toString(),
                      toolName: (e['name'] ?? '').toString(),
                      arguments: (e['arguments'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
                      content: (e['content']?.toString().isNotEmpty == true) ? e['content'].toString() : null,
                      loading: !(e['content']?.toString().isNotEmpty == true),
                    ))
                .toList();
          }
        } catch (_) {}

        // Restore reasoning segments
        final segments = _deserializeReasoningSegments(m.reasoningSegmentsJson);
        if (segments.isNotEmpty) {
          _reasoningSegments[m.id] = segments;
        }
      }

      // Restore translation UI state: default collapsed
      if (m.translation != null && m.translation!.isNotEmpty) {
        final td = _TranslationData();
        td.expanded = false;
        _translations[m.id] = td;
      }
    }
  }

  List<ChatMessage> _collapseVersions(List<ChatMessage> items) {
    final Map<String, List<ChatMessage>> byGroup = <String, List<ChatMessage>>{};
    final List<String> order = <String>[];
    for (final m in items) {
      final gid = (m.groupId ?? m.id);
      final list = byGroup.putIfAbsent(gid, () {
        order.add(gid);
        return <ChatMessage>[];
      });
      list.add(m);
    }
    for (final e in byGroup.entries) {
      e.value.sort((a, b) => a.version.compareTo(b.version));
    }
    final out = <ChatMessage>[];
    for (final gid in order) {
      final vers = byGroup[gid]!;
      final sel = _versionSelections[gid];
      final idx = (sel != null && sel >= 0 && sel < vers.length) ? sel : (vers.length - 1);
      out.add(vers[idx]);
    }
    return out;
  }

  String _clearContextLabel() {
    final l10n = AppLocalizations.of(context)!;
    final assistant = context.read<AssistantProvider>().currentAssistant;
    final configured = (assistant?.limitContextMessages ?? true) ? (assistant?.contextMessageSize ?? 0) : 0;
    // Use collapsed view for counting
    final collapsed = _collapseVersions(_messages);
    // Map raw truncate index to collapsed start index
    final int tRaw = _currentConversation?.truncateIndex ?? -1;
    int startCollapsed = 0;
    if (tRaw > 0) {
      final seen = <String>{};
      final int limit = tRaw < _messages.length ? tRaw : _messages.length;
      int count = 0;
      for (int i = 0; i < limit; i++) {
        final gid0 = (_messages[i].groupId ?? _messages[i].id);
        if (seen.add(gid0)) count++;
      }
      startCollapsed = count; // inclusive start index in collapsed list
    }
    int remaining = 0;
    for (int i = 0; i < collapsed.length; i++) {
      if (i >= startCollapsed) {
        if (collapsed[i].content.trim().isNotEmpty) remaining++;
      }
    }
    if (configured > 0) {
      final actual = remaining > configured ? configured : remaining;
      return l10n.homePageClearContextWithCount(actual.toString(), configured.toString());
    }
    return l10n.homePageClearContext;
  }

  Future<void> _onClearContext() async {
    final convo = _currentConversation;
    if (convo == null) return;
    final updated = await _chatService.toggleTruncateAtTail(convo.id, defaultTitle: _titleForLocale(context));
    if (!mounted) return;
    if (updated != null) {
      setState(() {
        _currentConversation = updated;
      });
    }
    // No inline panel to close; modal sheet is dismissed before action
  }

  void _toggleTools() async {
    // Open as modal bottom sheet instead of inline overlay
    _dismissKeyboard();
    final cs = Theme.of(context).colorScheme;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: BottomToolsSheet(
            onPhotos: () {
              Navigator.of(ctx).maybePop();
              _onPickPhotos();
            },
            onCamera: () {
              Navigator.of(ctx).maybePop();
              _onPickCamera();
            },
            onUpload: () {
              Navigator.of(ctx).maybePop();
              _onPickFiles();
            },
            onClear: () async {
              Navigator.of(ctx).maybePop();
              await _onClearContext();
            },
            clearLabel: _clearContextLabel(),
          ),
        );
      },
    );
  }

  bool _isToolModel(String providerKey, String modelId) {
    final settings = context.read<SettingsProvider>();
    final cfg = settings.getProviderConfig(providerKey);
    final ov = cfg.modelOverrides[modelId] as Map?;
    if (ov != null) {
      final abilities = (ov['abilities'] as List?)?.map((e) => e.toString()).toList() ?? const [];
      if (abilities.map((e) => e.toLowerCase()).contains('tool')) return true;
    }
    final inferred = ModelRegistry.infer(ModelInfo(id: modelId, displayName: modelId));
    return inferred.abilities.contains(ModelAbility.tool);
  }

  // More page entry is temporarily removed.
  // void _openMorePage() {
  //   _dismissKeyboard();
  //   Navigator.of(context).push(
  //     MaterialPageRoute(builder: (_) => const MorePage()),
  //   );
  // }

  void _dismissKeyboard() {
    _inputFocus.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    FocusScope.of(context).unfocus();
    try { SystemChannels.textInput.invokeMethod('TextInput.hide'); } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _convoFadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
    _convoFade = CurvedAnimation(parent: _convoFadeController, curve: Curves.easeOutCubic);
    _convoFadeController.value = 1.0;
    // Use the provided ChatService instance
    _chatService = context.read<ChatService>();
    _initChat();
    _scrollController.addListener(_onScrollControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureInputBar());
    // Load learning mode for button highlight
    Future.microtask(() async {
      final v = await LearningModeStore.isEnabled();
      if (mounted) setState(() => _learningModeEnabled = v);
    });

    // Initialize quick phrases provider
    Future.microtask(() async {
      try {
        await context.read<QuickPhraseProvider>().initialize();
      } catch (_) {}
    });

    // Attach MCP provider listener to auto-join new connected servers
    try {
      _mcpProvider = context.read<McpProvider>();
      _connectedMcpIds = _mcpProvider!.connectedServers.map((s) => s.id).toSet();
      _mcpProvider!.addListener(_onMcpChanged);
    } catch (_) {}

    // 监听键盘弹出
    _inputFocus.addListener(() {
      if (_inputFocus.hasFocus) {
        // 延迟一下等待键盘完全弹出
        Future.delayed(const Duration(milliseconds: 300), () {
          _scrollToBottom();
        });
      }
    });

    // Attach drawer value listener to catch swipe-open and close events
    _drawerController.addListener(_onDrawerValueChanged);
  }

  void _onDrawerValueChanged() {
    final v = _drawerController.value;
    // If user starts opening the drawer via swipe, dismiss the keyboard once
    if (_lastDrawerValue <= 0.01 && v > 0.01) {
      _dismissKeyboard();
    }
    // Fire haptic when drawer becomes sufficiently open (completion)
    if (_lastDrawerValue < 0.95 && v >= 0.95) {
      try {
        if (context.read<SettingsProvider>().hapticsOnDrawer) {
          Haptics.drawerPulse();
        }
      } catch (_) {}
    }
    // Fire haptic when drawer becomes sufficiently closed (cancellation)
    if (_lastDrawerValue > 0.05 && v <= 0.05) {
      try {
        if (context.read<SettingsProvider>().hapticsOnDrawer) {
          Haptics.drawerPulse();
        }
      } catch (_) {}
    }
    // When transitioning from open to closing, close assistant picker overlay
    if (_lastDrawerValue >= 0.95 && v < 0.95) {
      _assistantPickerCloseTick.value++;
    }
    _lastDrawerValue = v;
  }

  // Toggle tablet sidebar (embedded mode); keep icon and haptics same style as mobile
  void _toggleTabletSidebar() {
    _dismissKeyboard();
    try {
      if (context.read<SettingsProvider>().hapticsOnDrawer) {
        Haptics.drawerPulse();
      }
    } catch (_) {}
    setState(() {
      _tabletSidebarOpen = !_tabletSidebarOpen;
    });
  }

  Widget _buildTabletSidebar(BuildContext context) {
    final sidebar = SideDrawer(
      embedded: true,
      embeddedWidth: 300,
      userName: context.watch<UserProvider>().name,
      assistantName: (() {
        final l10n = AppLocalizations.of(context)!;
        final a = context.watch<AssistantProvider>().currentAssistant;
        final n = a?.name.trim();
        return (n == null || n.isEmpty) ? l10n.homePageDefaultAssistant : n;
      })(),
      closePickerTicker: _assistantPickerCloseTick,
      loadingConversationIds: _loadingConversationIds,
        onSelectConversation: (id) {
          _switchConversationAnimated(id);
        },
        onNewConversation: () async {
          await _createNewConversationAnimated();
        },
    );

    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: _sidebarAnimDuration,
      curve: _sidebarAnimCurve,
      width: _tabletSidebarOpen ? 300 : 0,
      color: Colors.transparent,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: 0,
          maxWidth: 300,
          child: SizedBox(width: 300, child: sidebar),
        ),
      ),
    );
  }

  // ZoomDrawer state listener removed; handled by _onDrawerValueChanged

  void _onScrollControllerChanged() {
    try {
      if (!_scrollController.hasClients) return;
      
      // Detect user scrolling
      if (_scrollController.position.userScrollDirection != ScrollDirection.idle) {
        _isUserScrolling = true;
        // Reset chained jump anchor when user manually scrolls
        _lastJumpUserMessageId = null;
        
        // Cancel previous timer and set a new one
        _userScrollTimer?.cancel();
        final secs = context.read<SettingsProvider>().autoScrollIdleSeconds;
        _userScrollTimer = Timer(Duration(seconds: secs), () {
          if (mounted) {
            setState(() {
              _isUserScrolling = false;
            });
          }
        });
      }
      
      // Only show when not near bottom
      final pos = _scrollController.position;
      final atBottom = pos.pixels >= (pos.maxScrollExtent - 24);
      final shouldShow = !atBottom;
      if (_showJumpToBottom != shouldShow) {
        setState(() => _showJumpToBottom = shouldShow);
      }
    } catch (_) {}
  }

  Future<void> _initChat() async {
    await _chatService.init();
    // Respect user preference: create new chat on launch
    final prefs = context.read<SettingsProvider>();
    if (prefs.newChatOnLaunch) {
      await _createNewConversation();
    } else {
      // When disabled, jump to the most recent conversation if exists
      final conversations = _chatService.getAllConversations();
      if (conversations.isNotEmpty) {
        final recent = conversations.first; // already sorted by updatedAt desc
        _chatService.setCurrentConversation(recent.id);
        final msgs = _chatService.getMessages(recent.id);
        setState(() {
          _currentConversation = recent;
          _messages = List.of(msgs);
          _loadVersionSelections();
          _restoreMessageUiState();
        });
        // Only auto-scroll if用户未主动滚动
        if (!_isUserScrolling) _scrollToBottomSoon();
      }
    }
  }

  Future<void> _switchConversationAnimated(String id) async {
    if (_currentConversation?.id == id) return;
    try {
      await _convoFadeController.reverse();
    } catch (_) {}
    _chatService.setCurrentConversation(id);
    final convo = _chatService.getConversation(id);
    if (convo != null) {
      final msgs = _chatService.getMessages(id);
      if (mounted) {
        setState(() {
          _currentConversation = convo;
          _messages = List.of(msgs);
          _loadVersionSelections();
          _restoreMessageUiState();
        });
        // Ensure list lays out, then jump to bottom while hidden
        try { await WidgetsBinding.instance.endOfFrame; } catch (_) {}
        if (!_isUserScrolling) _scrollToBottom();
      }
    }
    if (mounted) {
      try { await _convoFadeController.forward(); } catch (_) {}
    }
  }

  Future<void> _createNewConversationAnimated() async {
    try { await _convoFadeController.reverse(); } catch (_) {}
    await _createNewConversation();
    if (mounted) {
      // New conversation typically empty; still forward fade smoothly
      try { await _convoFadeController.forward(); } catch (_) {}
    }
  }

  // _onMcpChanged defined below; remove listener in the main dispose at bottom

  Future<void> _onMcpChanged() async {
    if (!mounted) return;
    final prov = _mcpProvider;
    if (prov == null) return;
    final now = prov.connectedServers.map((s) => s.id).toSet();
    final added = now.difference(_connectedMcpIds);
    _connectedMcpIds = now;
    // Assistant-level MCP selection is managed in Assistant settings; no per-conversation merge.
  }

  Future<List<String>> _copyPickedFiles(List<XFile> files) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory("${docs.path}/upload");
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final out = <String>[];
    for (final f in files) {
      try {
        final name = f.name.isNotEmpty ? f.name : DateTime.now().millisecondsSinceEpoch.toString();
        final dest = File("${dir.path}/$name");
        await dest.writeAsBytes(await f.readAsBytes());
        out.add(dest.path);
      } catch (_) {}
    }
    return out;
  }

  Future<void> _onPickPhotos() async {
    try {
      final picker = ImagePicker();
      final files = await picker.pickMultiImage();
      if (files == null || files.isEmpty) return;
      final paths = await _copyPickedFiles(files);
      if (paths.isNotEmpty) {
        _mediaController.addImages(paths);
        if (!_isUserScrolling) _scrollToBottomSoon();
      }
    } catch (_) {}
  }

  Future<void> _onPickCamera() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.camera);
      if (file == null) return;
      final paths = await _copyPickedFiles([file]);
      if (paths.isNotEmpty) {
        _mediaController.addImages(paths);
        if (!_isUserScrolling) _scrollToBottomSoon();
      }
    } catch (_) {}
  }

  String _inferMimeByExtension(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.docx')) return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    if (lower.endsWith('.json')) return 'application/json';
    if (lower.endsWith('.js')) return 'application/javascript';
    if (lower.endsWith('.txt') || lower.endsWith('.md')) return 'text/plain';
    return 'text/plain';
  }

  Future<void> _onPickFiles() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: false,
        type: FileType.custom,
        allowedExtensions: const [
          'txt','md','json','js','pdf','docx'
        ],
      );
      if (res == null || res.files.isEmpty) return;
      final docs = <DocumentAttachment>[];
      final toCopy = <XFile>[];
      for (final f in res.files) {
        if (f.path != null && f.path!.isNotEmpty) {
          toCopy.add(XFile(f.path!));
        }
      }
      final saved = await _copyPickedFiles(toCopy);
      for (int i = 0; i < saved.length; i++) {
        final orig = res.files[i];
        final savedPath = saved[i];
        final name = orig.name;
        final mime = _inferMimeByExtension(name);
        docs.add(DocumentAttachment(path: savedPath, fileName: name, mime: mime));
      }
      if (docs.isNotEmpty) {
        _mediaController.addFiles(docs);
        if (!_isUserScrolling) _scrollToBottomSoon();
      }
    } catch (_) {}
  }

  Future<void> _createNewConversation() async {
    final ap = context.read<AssistantProvider>();
    final settings = context.read<SettingsProvider>();
    final assistantId = ap.currentAssistantId;
    // Don't change global default model - just use assistant's model if set
    final a = ap.currentAssistant;
    final conversation = await _chatService.createDraftConversation(title: _titleForLocale(context), assistantId: assistantId);
    // Default-enable MCP: select all connected servers for this conversation
    // MCP defaults are now managed per assistant; no per-conversation enabling here
    setState(() {
      _currentConversation = conversation;
      _messages = [];
      _versionSelections.clear();
      _reasoning.clear();
      _translations.clear();
      _toolParts.clear();
      _reasoningSegments.clear();
    });
    if (!_isUserScrolling) _scrollToBottomSoon();
  }

  Future<void> _sendMessage(ChatInputData input) async {
    final content = input.text.trim();
    if (content.isEmpty && input.imagePaths.isEmpty && input.documents.isEmpty) return;
    if (_currentConversation == null) await _createNewConversation();

    final settings = context.read<SettingsProvider>();
    final assistant = context.read<AssistantProvider>().currentAssistant;
    
    // Use assistant's model if set, otherwise fall back to global default
    final providerKey = assistant?.chatModelProvider ?? settings.currentModelProvider;
    final modelId = assistant?.chatModelId ?? settings.currentModelId;

    if (providerKey == null || modelId == null) {
      final l10n = AppLocalizations.of(context)!;
      showAppSnackBar(
        context,
        message: l10n.homePagePleaseSelectModel,
        type: NotificationType.warning,
      );
      return;
    }

    // Add user message
    // Persist user message; append image and document markers for display
    final imageMarkers = input.imagePaths.map((p) => '\n[image:$p]').join();
    final docMarkers = input.documents.map((d) => '\n[file:${d.path}|${d.fileName}|${d.mime}]').join();
    final userMessage = await _chatService.addMessage(
      conversationId: _currentConversation!.id,
      role: 'user',
      content: content + imageMarkers + docMarkers,
    );

    setState(() {
      _messages.add(userMessage);
    });
    _setConversationLoading(_currentConversation!.id, true);

    // 延迟滚动确保UI更新完成
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_isUserScrolling) _scrollToBottom();
    });

    // Create assistant message placeholder
    final assistantMessage = await _chatService.addMessage(
      conversationId: _currentConversation!.id,
      role: 'assistant',
      content: '',
      modelId: modelId,
      providerId: providerKey,
      isStreaming: true,
    );

    setState(() {
      _messages.add(assistantMessage);
    });

    // Haptics on generate (if enabled)
    try {
      if (context.read<SettingsProvider>().hapticsOnGenerate) {
        Haptics.light();
      }
    } catch (_) {}

    // Reset tool parts for this new assistant message
    _toolParts.remove(assistantMessage.id);

    // Initialize reasoning state only when enabled and model supports it
    final supportsReasoning = _isReasoningModel(providerKey, modelId);
    final enableReasoning = supportsReasoning && _isReasoningEnabled((assistant?.thinkingBudget) ?? settings.thinkingBudget);
    if (enableReasoning) {
      final rd = _ReasoningData();
      _reasoning[assistantMessage.id] = rd;
      await _chatService.updateMessage(
        assistantMessage.id,
        reasoningStartAt: DateTime.now(),
      );
    }

    // 添加助手消息后也滚动到底部
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_isUserScrolling) _scrollToBottom();
    });

    // Prepare messages for API
    // Apply truncateIndex and collapse versions first, then transform the last user message to include document content
    final tIndex = _currentConversation?.truncateIndex ?? -1;
    final List<ChatMessage> sourceAll = (tIndex >= 0 && tIndex <= _messages.length)
        ? _messages.sublist(tIndex)
        : List.of(_messages);
    final List<ChatMessage> source = _collapseVersions(sourceAll);
    final apiMessages = source
        .where((m) => m.content.isNotEmpty)
        .map((m) => {
              'role': m.role == 'assistant' ? 'assistant' : 'user',
              'content': m.content,
            })
        .toList();

    // Build document prompts and clean markers in last user message
    if (apiMessages.isNotEmpty) {
      // Find last user message index in apiMessages
      int lastUserIdx = -1;
      for (int i = apiMessages.length - 1; i >= 0; i--) {
        if (apiMessages[i]['role'] == 'user') { lastUserIdx = i; break; }
      }
      if (lastUserIdx != -1) {
        final raw = (apiMessages[lastUserIdx]['content'] ?? '').toString();
        final cleaned = raw
            .replaceAll(RegExp(r"\[image:.*?\]"), '')
            .replaceAll(RegExp(r"\[file:.*?\]"), '')
            .trim();
        // Build document prompts
        final filePrompts = StringBuffer();
        for (final d in input.documents) {
          try {
            final text = await DocumentTextExtractor.extract(path: d.path, mime: d.mime);
            filePrompts.writeln('## user sent a file: ${d.fileName}');
            filePrompts.writeln('<content>');
            filePrompts.writeln('```');
            filePrompts.writeln(text);
            filePrompts.writeln('```');
            filePrompts.writeln('</content>');
            filePrompts.writeln();
          } catch (_) {}
        }
        final merged = (filePrompts.toString() + cleaned).trim();
        final userText = merged.isEmpty ? cleaned : merged;
        // Apply message template if set
        final templ = (assistant?.messageTemplate ?? '{{ message }}').trim().isEmpty
            ? '{{ message }}'
            : (assistant!.messageTemplate);
        final templated = PromptTransformer.applyMessageTemplate(
          templ,
          role: 'user',
          message: userText,
          now: DateTime.now(),
        );
        apiMessages[lastUserIdx]['content'] = templated;
      }
    }

    // Inject system prompt (assistant.systemPrompt with placeholders)
    if ((assistant?.systemPrompt.trim().isNotEmpty ?? false)) {
      final vars = PromptTransformer.buildPlaceholders(
        context: context,
        assistant: assistant!,
        modelId: modelId,
        modelName: modelId,
        userNickname: context.read<UserProvider>().name,
      );
      final sys = PromptTransformer.replacePlaceholders(assistant.systemPrompt, vars);
      apiMessages.insert(0, {'role': 'system', 'content': sys});
    }

    // Determine tool support and built-in Gemini search status
    final supportsTools = _isToolModel(providerKey, modelId);
    bool _hasBuiltInGeminiSearch() {
      try {
        final cfg = settings.getProviderConfig(providerKey);
        // Only official Gemini API supports built-in search
        if (cfg.providerType != ProviderKind.google || (cfg.vertexAI == true)) return false;
        final ov = cfg.modelOverrides[modelId] as Map?;
        final list = (ov?['builtInTools'] as List?) ?? const <dynamic>[];
        return list.map((e) => e.toString().toLowerCase()).contains('search');
      } catch (_) {
        return false;
      }
    }
    final hasBuiltInSearch = _hasBuiltInGeminiSearch();

    // Optionally inject search tool usage guide (when search is enabled and not using Gemini built-in search)
    if (settings.searchEnabled && !hasBuiltInSearch) {
      final prompt = SearchToolService.getSystemPrompt();
      if (apiMessages.isNotEmpty && apiMessages.first['role'] == 'system') {
        apiMessages[0]['content'] = ((apiMessages[0]['content'] ?? '') as String) + '\n\n' + prompt;
      } else {
        apiMessages.insert(0, {'role': 'system', 'content': prompt});
      }
    }
    // Inject learning mode prompt when enabled (global)
    try {
      final lmEnabled = await LearningModeStore.isEnabled();
      if (lmEnabled) {
        final lp = await LearningModeStore.getPrompt();
        if (apiMessages.isNotEmpty && apiMessages.first['role'] == 'system') {
          apiMessages[0]['content'] = ((apiMessages[0]['content'] ?? '') as String) + '\n\n' + lp;
        } else {
          apiMessages.insert(0, {'role': 'system', 'content': lp});
        }
      }
    } catch (_) {}

    // Limit context length according to assistant settings
    if ((assistant?.limitContextMessages ?? true) && (assistant?.contextMessageSize ?? 0) > 0) {
      final keep = assistant!.contextMessageSize.clamp(1, 512).toInt();
      // Always keep the first message if it's system
      int startIdx = 0;
      if (apiMessages.isNotEmpty && apiMessages.first['role'] == 'system') {
        startIdx = 1;
      }
      final tail = apiMessages.sublist(startIdx);
      if (tail.length > keep) {
        final trimmed = tail.sublist(tail.length - keep);
        apiMessages
          ..removeRange(startIdx, apiMessages.length)
          ..addAll(trimmed);
      }
    }

    // Convert any local Markdown image links to inline base64 for model context
    for (int i = 0; i < apiMessages.length; i++) {
      final s = (apiMessages[i]['content'] ?? '').toString();
      if (s.isNotEmpty) {
        apiMessages[i]['content'] = await MarkdownMediaSanitizer.inlineLocalImagesToBase64(s);
      }
    }

    // Get provider config
    final config = settings.getProviderConfig(providerKey);

    // Stream response
    String fullContent = '';
    int totalTokens = 0;
    TokenUsage? usage;
    // Respect assistant streaming toggle: if off, buffer updates until done
    final bool streamOutput = assistant?.streamOutput ?? true;
    String _bufferedReasoning = '';
    DateTime? _reasoningStartAt;
    bool _finishHandled = false;
    bool _titleQueued = false;

    try {
      // Prepare tools (Search tool + MCP tools)
      final List<Map<String, dynamic>> toolDefs = <Map<String, dynamic>>[];
      Future<String> Function(String, Map<String, dynamic>)? onToolCall;

      // Search tool (skip when Gemini built-in search is active)
      if (settings.searchEnabled && !hasBuiltInSearch && supportsTools) {
        toolDefs.add(SearchToolService.getToolDefinition());
      }

      // MCP tools
      final mcp = context.read<McpProvider>();
      final toolSvc = context.read<McpToolService>();
      final tools = toolSvc.listAvailableToolsForAssistant(mcp, context.read<AssistantProvider>(), assistant?.id);
      if (supportsTools && tools.isNotEmpty) {
        final providerCfg = settings.getProviderConfig(providerKey);
        final providerKind = ProviderConfig.classify(providerCfg.id, explicitType: providerCfg.providerType);
        toolDefs.addAll(tools.map((t) {
          // Base schema from server or fallback
          Map<String, dynamic> baseSchema;
          if (t.schema != null && t.schema!.isNotEmpty) {
            baseSchema = Map<String, dynamic>.from(t.schema!);
          } else {
            final props = <String, dynamic>{for (final p in t.params) p.name: {'type': (p.type ?? 'string')}};
            final required = [for (final p in t.params.where((e) => e.required)) p.name];
            baseSchema = {'type': 'object', 'properties': props, if (required.isNotEmpty) 'required': required};
          }
          final sanitized = _sanitizeToolParametersForProvider(baseSchema, providerKind);
          return {
            'type': 'function',
            'function': {
              'name': t.name,
              if ((t.description ?? '').isNotEmpty) 'description': t.description,
              'parameters': sanitized,
            }
          };
        }));
      }

      if (toolDefs.isNotEmpty) {
        onToolCall = (name, args) async {
          if (name == SearchToolService.toolName && settings.searchEnabled) {
            final q = (args['query'] ?? '').toString();
            return await SearchToolService.executeSearch(q, settings);
          }
          // Fallback to MCP tools
          final text = await toolSvc.callToolTextForAssistant(
            mcp,
            context.read<AssistantProvider>(),
            assistantId: assistant?.id,
            toolName: name,
            arguments: args,
          );
          return text;
        };
      }

      // Build assistant-level custom request overrides
      Map<String, String>? aHeaders;
      Map<String, dynamic>? aBody;
      if ((assistant?.customHeaders.isNotEmpty ?? false)) {
        aHeaders = {
          for (final e in assistant!.customHeaders)
            if ((e['name'] ?? '').trim().isNotEmpty) (e['name']!.trim()): (e['value'] ?? '')
        };
        if (aHeaders.isEmpty) aHeaders = null;
      }
      if ((assistant?.customBody.isNotEmpty ?? false)) {
        aBody = {
          for (final e in assistant!.customBody)
            if ((e['key'] ?? '').trim().isNotEmpty)
              (e['key']!.trim()): (e['value'] ?? '')
        };
        if (aBody.isEmpty) aBody = null;
      }

    final stream = ChatApiService.sendMessageStream(
      config: config,
      modelId: modelId,
      messages: apiMessages,
      userImagePaths: input.imagePaths,
      thinkingBudget: assistant?.thinkingBudget ?? settings.thinkingBudget,
      temperature: assistant?.temperature,
      topP: assistant?.topP,
      maxTokens: assistant?.maxTokens,
      tools: toolDefs.isEmpty ? null : toolDefs,
        onToolCall: onToolCall,
        extraHeaders: aHeaders,
        extraBody: aBody,
      );

      Future<void> finish({bool generateTitle = true}) async {
        final shouldGenerateTitle = generateTitle && !_titleQueued;
        if (_finishHandled) {
          if (shouldGenerateTitle) {
            _titleQueued = true;
            _maybeGenerateTitleFor(assistantMessage.conversationId);
          }
          return;
        }
        _finishHandled = true;
        if (shouldGenerateTitle) {
          _titleQueued = true;
        }
        // Replace extremely long inline base64 images with local files to avoid jank
        final processedContent = await MarkdownMediaSanitizer.replaceInlineBase64Images(fullContent);
        await _chatService.updateMessage(
          assistantMessage.id,
          content: processedContent,
          totalTokens: totalTokens,
          isStreaming: false,
        );
        if (!mounted) return;
        setState(() {
          final index = _messages.indexWhere((m) => m.id == assistantMessage.id);
          if (index != -1) {
            _messages[index] = _messages[index].copyWith(
              content: processedContent,
              totalTokens: totalTokens,
              isStreaming: false,
            );
          }
        });
        _setConversationLoading(assistantMessage.conversationId, false);
        final r = _reasoning[assistantMessage.id];
        if (r != null) {
          if (r.finishedAt == null) {
            r.finishedAt = DateTime.now();
          }
          final autoCollapse = context.read<SettingsProvider>().autoCollapseThinking;
          if (autoCollapse) {
            r.expanded = false; // auto close after finish
          }
          _reasoning[assistantMessage.id] = r;
          if (mounted) setState(() {});
        }

        // Also finish any unfinished reasoning segments
        final segments = _reasoningSegments[assistantMessage.id];
        if (segments != null && segments.isNotEmpty && segments.last.finishedAt == null) {
          segments.last.finishedAt = DateTime.now();
          final autoCollapse = context.read<SettingsProvider>().autoCollapseThinking;
          if (autoCollapse) {
            segments.last.expanded = false;
          }
          _reasoningSegments[assistantMessage.id] = segments;
          if (mounted) setState(() {});
        }

        // Save reasoning segments to database
        if (segments != null && segments.isNotEmpty) {
          await _chatService.updateMessage(
            assistantMessage.id,
            reasoningSegmentsJson: _serializeReasoningSegments(segments),
          );
        }
        if (shouldGenerateTitle) {
          _maybeGenerateTitleFor(assistantMessage.conversationId);
        }
      }

      // Track stream per conversation to allow concurrent sessions
      final String _cidForStream = assistantMessage.conversationId;
      await _conversationStreams[_cidForStream]?.cancel();
      final _sub = stream.listen(
            (chunk) async {
          // Capture reasoning deltas only when reasoning is enabled
          if ((chunk.reasoning ?? '').isNotEmpty && supportsReasoning) {
            if (streamOutput) {
              final r = _reasoning[assistantMessage.id] ?? _ReasoningData();
              r.text += chunk.reasoning!;
              r.startAt ??= DateTime.now();
              // keep finishedAt as-is; don't reset to null once set
              r.expanded = false; // default collapsed while generating
              _reasoning[assistantMessage.id] = r;

              // Add to reasoning segments for mixed display
              final segments = _reasoningSegments[assistantMessage.id] ?? <_ReasoningSegmentData>[];

              if (segments.isEmpty) {
                // First reasoning segment
                final newSegment = _ReasoningSegmentData();
                newSegment.text = chunk.reasoning!;
                newSegment.startAt = DateTime.now();
                newSegment.expanded = false; // default collapsed while generating
                newSegment.toolStartIndex = (_toolParts[assistantMessage.id]?.length ?? 0);
                segments.add(newSegment);
              } else {
                // Check if we should start a new segment (after tool calls)
                final hasToolsAfterLastSegment = (_toolParts[assistantMessage.id]?.isNotEmpty ?? false);
                final lastSegment = segments.last;

                if (hasToolsAfterLastSegment && lastSegment.finishedAt != null) {
                  // Start a new segment after tools
                  final newSegment = _ReasoningSegmentData();
                  newSegment.text = chunk.reasoning!;
                  newSegment.startAt = DateTime.now();
                  newSegment.expanded = false; // default collapsed while generating
                  newSegment.toolStartIndex = (_toolParts[assistantMessage.id]?.length ?? 0);
                  segments.add(newSegment);
                } else {
                  // Continue current segment
                  lastSegment.text += chunk.reasoning!;
                  lastSegment.startAt ??= DateTime.now();
                }
              }
              _reasoningSegments[assistantMessage.id] = segments;

              // Save segments to database periodically
              await _chatService.updateMessage(
                assistantMessage.id,
                reasoningSegmentsJson: _serializeReasoningSegments(segments),
              );

              if (mounted && _currentConversation?.id == _cidForStream) setState(() {});
              await _chatService.updateMessage(
                assistantMessage.id,
                reasoningText: r.text,
                reasoningStartAt: r.startAt,
              );
            } else {
              // Buffer reasoning only; commit on finish
              _reasoningStartAt ??= DateTime.now();
              _bufferedReasoning += chunk.reasoning!;
            }
          }

          // MCP tool call placeholders
          if ((chunk.toolCalls ?? const []).isNotEmpty) {
            // Finish current reasoning segment if exists, and auto-collapse per settings
            final segments = _reasoningSegments[assistantMessage.id] ?? <_ReasoningSegmentData>[];
            if (segments.isNotEmpty && segments.last.finishedAt == null) {
              segments.last.finishedAt = DateTime.now();
              final autoCollapse = context.read<SettingsProvider>().autoCollapseThinking;
              if (autoCollapse) {
                segments.last.expanded = false;
                final rd = _reasoning[assistantMessage.id];
                if (rd != null) rd.expanded = false;
              }
              _reasoningSegments[assistantMessage.id] = segments;
              // Persist closed segment state
              await _chatService.updateMessage(
                assistantMessage.id,
                reasoningSegmentsJson: _serializeReasoningSegments(segments),
              );
            }

            // Simply append new tool calls instead of merging by ID/name
            // This allows multiple calls to the same tool
            final existing = List<ToolUIPart>.of(_toolParts[assistantMessage.id] ?? const []);
            for (final c in chunk.toolCalls!) {
              existing.add(ToolUIPart(id: c.id, toolName: c.name, arguments: c.arguments, loading: true));
            }
            if (mounted && _currentConversation?.id == _cidForStream) setState(() {
              _toolParts[assistantMessage.id] = _dedupeToolPartsList(existing);
            });

            // Persist placeholders - append new events
            try {
              final prev = _chatService.getToolEvents(assistantMessage.id);
              final newEvents = <Map<String, dynamic>>[
                ...prev,
                for (final c in chunk.toolCalls!)
                  {
                    'id': c.id,
                    'name': c.name,
                    'arguments': c.arguments,
                    'content': null,
                  },
              ];
              await _chatService.setToolEvents(assistantMessage.id, _dedupeToolEvents(newEvents));
            } catch (_) {}
          }

          // MCP tool results -> hydrate placeholders in-place (avoid extra tool message cards)
          if ((chunk.toolResults ?? const []).isNotEmpty) {
            final parts = List<ToolUIPart>.of(_toolParts[assistantMessage.id] ?? const []);
            for (final r in chunk.toolResults!) {
              // Find the first loading tool with matching ID or name
              // This ensures we update the correct placeholder even with multiple same-name tools
              int idx = -1;
              for (int i = 0; i < parts.length; i++) {
                if (parts[i].loading && (parts[i].id == r.id || (parts[i].id.isEmpty && parts[i].toolName == r.name))) {
                  idx = i;
                  break;
                }
              }

              if (idx >= 0) {
                parts[idx] = ToolUIPart(
                  id: parts[idx].id,
                  toolName: parts[idx].toolName,
                  arguments: parts[idx].arguments,
                  content: r.content,
                  loading: false,
                );
              } else {
                // If we didn't see the placeholder (edge case), append a finished part
                parts.add(ToolUIPart(
                  id: r.id,
                  toolName: r.name,
                  arguments: r.arguments,
                  content: r.content,
                  loading: false,
                ));
              }
              // Persist each event update
              try {
                await _chatService.upsertToolEvent(
                  assistantMessage.id,
                  id: r.id,
                  name: r.name,
                  arguments: r.arguments,
                  content: r.content,
                );
              } catch (_) {}
            }
            if (mounted && _currentConversation?.id == _cidForStream) setState(() {
              _toolParts[assistantMessage.id] = _dedupeToolPartsList(parts);
            });
            if (!_isUserScrolling) _scrollToBottomSoon();
          }

          if (chunk.isDone) {
            // Guard: if we have any loading tool-call placeholders, a follow-up round is coming.
            final hasLoadingTool = (_toolParts[assistantMessage.id]?.any((p) => p.loading) ?? false);
            if (hasLoadingTool) {
              // Skip finishing now; wait for follow-up round.
              return;
            }
            // Capture final usage/tokens if only provided at end
            if (chunk.totalTokens > 0) {
              totalTokens = chunk.totalTokens;
            }
            if (chunk.usage != null) {
              usage = (usage ?? const TokenUsage()).merge(chunk.usage!);
              totalTokens = usage!.totalTokens;
            }
            await finish();
            // If non-streaming, persist buffered reasoning once at the end
            if (!streamOutput && _bufferedReasoning.isNotEmpty) {
              final now = DateTime.now();
              final startAt = _reasoningStartAt ?? now;
              await _chatService.updateMessage(
                assistantMessage.id,
                reasoningText: _bufferedReasoning,
                reasoningStartAt: startAt,
                reasoningFinishedAt: now,
              );
              final autoCollapse = context.read<SettingsProvider>().autoCollapseThinking;
              _reasoning[assistantMessage.id] = _ReasoningData()
                ..text = _bufferedReasoning
                ..startAt = startAt
                ..finishedAt = now
                ..expanded = !autoCollapse;
              if (mounted && _currentConversation?.id == _cidForStream) setState(() {});
            }
            await _conversationStreams.remove(_cidForStream)?.cancel();
            final r = _reasoning[assistantMessage.id];
            if (r != null && r.finishedAt == null) {
              r.finishedAt = DateTime.now();
              await _chatService.updateMessage(
                assistantMessage.id,
                reasoningText: r.text,
                reasoningFinishedAt: r.finishedAt,
              );
            }
          } else {
            fullContent += chunk.content;
            if (chunk.totalTokens > 0) {
              totalTokens = chunk.totalTokens;
            }
            if (chunk.usage != null) {
              usage = (usage ?? const TokenUsage()).merge(chunk.usage!);
              totalTokens = usage!.totalTokens;
            }

            if (streamOutput) {
              // If content has started, consider reasoning finished and collapse (respect setting)
              if ((chunk.content).isNotEmpty) {
                final r = _reasoning[assistantMessage.id];
                if (r != null && r.startAt != null && r.finishedAt == null) {
                  r.finishedAt = DateTime.now();
                  final autoCollapse = context.read<SettingsProvider>().autoCollapseThinking;
                  if (autoCollapse) {
                    r.expanded = false; // collapse once main content starts
                  }
                  _reasoning[assistantMessage.id] = r;
                  await _chatService.updateMessage(
                    assistantMessage.id,
                    reasoningText: r.text,
                    reasoningFinishedAt: r.finishedAt,
                  );
                  if (mounted) setState(() {});
                }

                // Also finish the current reasoning segment
                final segments = _reasoningSegments[assistantMessage.id];
                if (segments != null && segments.isNotEmpty && segments.last.finishedAt == null) {
                  segments.last.finishedAt = DateTime.now();
                  final autoCollapse = context.read<SettingsProvider>().autoCollapseThinking;
                  if (autoCollapse) {
                    segments.last.expanded = false;
                  }
                  _reasoningSegments[assistantMessage.id] = segments;
                  if (mounted) setState(() {});
                  // Persist closed segment state
                  await _chatService.updateMessage(
                    assistantMessage.id,
                    reasoningSegmentsJson: _serializeReasoningSegments(segments),
                  );
                }
              }
            }

            if (streamOutput) {
              // Update UI with streaming content
              if (mounted && _currentConversation?.id == _cidForStream) {
                setState(() {
                  final index = _messages.indexWhere((m) => m.id == assistantMessage.id);
                  if (index != -1) {
                    _messages[index] = _messages[index].copyWith(
                      content: fullContent,
                      totalTokens: totalTokens,
                    );
                  }
                });
              }

              // Persist partial content so it's saved even if interrupted
              await _chatService.updateMessage(
                assistantMessage.id,
                content: fullContent,
                totalTokens: totalTokens,
              );

              // 滚动到底部显示新内容
              Future.delayed(const Duration(milliseconds: 50), () {
                if (!_isUserScrolling) _scrollToBottom();
              });
            }
          }
        },
        onError: (e) async {
          // Preserve partial content; if empty, write error message into bubble
          final errText = '${AppLocalizations.of(context)!.generationInterrupted}: $e';
          final displayContent = fullContent.isNotEmpty ? fullContent : errText;
          await _chatService.updateMessage(
            assistantMessage.id,
            content: displayContent,
            totalTokens: totalTokens,
            isStreaming: false,
          );

          if (!mounted) return;
          setState(() {
            final index = _messages.indexWhere((m) => m.id == assistantMessage.id);
            if (index != -1) {
              _messages[index] = _messages[index].copyWith(
                content: displayContent,
                isStreaming: false,
                totalTokens: totalTokens,
              );
            }
          });
          _setConversationLoading(assistantMessage.conversationId, false);

          // End reasoning on error
          final r = _reasoning[assistantMessage.id];
          if (r != null) {
            if (r.finishedAt == null) {
              r.finishedAt = DateTime.now();
              await _chatService.updateMessage(
                assistantMessage.id,
                reasoningText: r.text,
                reasoningFinishedAt: r.finishedAt,
              );
            }
            final autoCollapse = context.read<SettingsProvider>().autoCollapseThinking;
            if (autoCollapse) {
              r.expanded = false;
            }
            _reasoning[assistantMessage.id] = r;
          }

          // Also finish any unfinished reasoning segments on error
          final segments = _reasoningSegments[assistantMessage.id];
          if (segments != null && segments.isNotEmpty && segments.last.finishedAt == null) {
            segments.last.finishedAt = DateTime.now();
            final autoCollapse = context.read<SettingsProvider>().autoCollapseThinking;
            if (autoCollapse) {
              segments.last.expanded = false;
            }
            _reasoningSegments[assistantMessage.id] = segments;
            // Persist closed segment state
            try {
              await _chatService.updateMessage(
                assistantMessage.id,
                reasoningSegmentsJson: _serializeReasoningSegments(segments),
              );
            } catch (_) {}
          }

          await _conversationStreams.remove(_cidForStream)?.cancel();
          showAppSnackBar(
            context,
            message: '${AppLocalizations.of(context)!.generationInterrupted}: $e',
            type: NotificationType.error,
          );
        },
        onDone: () async {
          // If stream closed without explicit isDone chunk, finalize
          if (_loadingConversationIds.contains(_cidForStream)) {
            await finish(generateTitle: true);
          }
          await _conversationStreams.remove(_cidForStream)?.cancel();
        },
        cancelOnError: true,
      );
      _conversationStreams[_cidForStream] = _sub;
    } catch (e) {
      // Preserve partial content on outer error as well; if empty, show error text in bubble
      final errText = '${AppLocalizations.of(context)!.generationInterrupted}: $e';
      final displayContent = fullContent.isNotEmpty ? fullContent : errText;
      await _chatService.updateMessage(
        assistantMessage.id,
        content: displayContent,
        totalTokens: totalTokens,
        isStreaming: false,
      );

      setState(() {
        final index = _messages.indexWhere((m) => m.id == assistantMessage.id);
        if (index != -1) {
          _messages[index] = _messages[index].copyWith(
            content: displayContent,
            isStreaming: false,
            totalTokens: totalTokens,
          );
        }
      });
      _setConversationLoading(assistantMessage.conversationId, false);

      // End reasoning on error
      final r = _reasoning[assistantMessage.id];
      if (r != null) {
        r.finishedAt = DateTime.now();
        final autoCollapse = context.read<SettingsProvider>().autoCollapseThinking;
        if (autoCollapse) {
          r.expanded = false;
        }
        _reasoning[assistantMessage.id] = r;
        await _chatService.updateMessage(
          assistantMessage.id,
          reasoningText: r.text,
          reasoningFinishedAt: r.finishedAt,
        );
      }

      // Also finish any unfinished reasoning segments on error
      final segments = _reasoningSegments[assistantMessage.id];
      if (segments != null && segments.isNotEmpty && segments.last.finishedAt == null) {
        segments.last.finishedAt = DateTime.now();
        final autoCollapse = context.read<SettingsProvider>().autoCollapseThinking;
        if (autoCollapse) {
          segments.last.expanded = false;
        }
        _reasoningSegments[assistantMessage.id] = segments;
        // Persist closed segment state
        try {
          await _chatService.updateMessage(
            assistantMessage.id,
            reasoningSegmentsJson: _serializeReasoningSegments(segments),
          );
        } catch (_) {}
      }

      await _conversationStreams.remove(assistantMessage.conversationId)?.cancel();
      showAppSnackBar(
        context,
        message: '${AppLocalizations.of(context)!.generationInterrupted}: $e',
        type: NotificationType.error,
      );
    }
  }

  Future<void> _regenerateAtMessage(ChatMessage message) async {
    if (_currentConversation == null) return;
    // Cancel any ongoing stream
    await _cancelStreaming();

    final idx = _messages.indexWhere((m) => m.id == message.id);
    if (idx < 0) return;

    // Compute versioning target (groupId + nextVersion) and where to cut
    String? targetGroupId;
    int nextVersion = 0;
    int lastKeep;
    if (message.role == 'assistant') {
      // Keep the existing assistant message as old version
      lastKeep = idx; // remove after this
      targetGroupId = message.groupId ?? message.id;
      int maxVer = -1;
      for (final m in _messages) {
        final gid = (m.groupId ?? m.id);
        if (gid == targetGroupId) {
          if (m.version > maxVer) maxVer = m.version;
        }
      }
      nextVersion = maxVer + 1;
    } else {
      // User message: find the first assistant reply after the FIRST occurrence of this user group,
      // not after the current version's position (which may be appended at tail after edits).
      final userGroupId = message.groupId ?? message.id;
      int userFirst = -1;
      for (int i = 0; i < _messages.length; i++) {
        final gid0 = (_messages[i].groupId ?? _messages[i].id);
        if (gid0 == userGroupId) { userFirst = i; break; }
      }
      if (userFirst < 0) userFirst = idx; // fallback

      int aid = -1;
      for (int i = userFirst + 1; i < _messages.length; i++) {
        if (_messages[i].role == 'assistant') { aid = i; break; }
      }
      if (aid >= 0) {
        lastKeep = aid; // keep that assistant message as old version
        targetGroupId = _messages[aid].groupId ?? _messages[aid].id;
        int maxVer = -1;
        for (final m in _messages) {
          final gid = (m.groupId ?? m.id);
          if (gid == targetGroupId) {
            if (m.version > maxVer) maxVer = m.version;
          }
        }
        nextVersion = maxVer + 1;
      } else {
        // No assistant reply yet; keep up to the first user message occurrence and start new group
        lastKeep = userFirst;
        targetGroupId = null; // will be set to new id automatically
        nextVersion = 0;
      }
    }

    // Remove messages after lastKeep (persistently), but preserve:
    // - all versions of groups that already appeared up to lastKeep (e.g., edited user messages), and
    // - all versions of the target assistant group we are regenerating
    if (lastKeep < _messages.length - 1) {
      // Collect groups that appear at or before lastKeep
      final keepGroups = <String>{};
      for (int i = 0; i <= lastKeep && i < _messages.length; i++) {
        final g = (_messages[i].groupId ?? _messages[i].id);
        keepGroups.add(g);
      }
      if (targetGroupId != null) keepGroups.add(targetGroupId!);

      final trailing = _messages.sublist(lastKeep + 1);
      final removeIds = <String>[];
      for (final m in trailing) {
        final gid = (m.groupId ?? m.id);
        final shouldKeep = keepGroups.contains(gid);
        if (!shouldKeep) removeIds.add(m.id);
      }
      for (final id in removeIds) {
        try { await _chatService.deleteMessage(id); } catch (_) {}
        _reasoning.remove(id);
        _translations.remove(id);
        _toolParts.remove(id);
        _reasoningSegments.remove(id);
      }
      if (removeIds.isNotEmpty) {
        setState(() {
          _messages.removeWhere((m) => removeIds.contains(m.id));
        });
      }
    }

    // Start a new assistant generation from current context
    final settings = context.read<SettingsProvider>();
    final assistant = context.read<AssistantProvider>().currentAssistant;
    
    // Use assistant's model if set, otherwise fall back to global default
    final providerKey = assistant?.chatModelProvider ?? settings.currentModelProvider;
    final modelId = assistant?.chatModelId ?? settings.currentModelId;

    if (providerKey == null || modelId == null) {
      final l10n = AppLocalizations.of(context)!;
      showAppSnackBar(
        context,
        message: l10n.homePagePleaseSelectModel,
        type: NotificationType.warning,
      );
      return;
    }

    // Create assistant message placeholder (new version in target group)
    final assistantMessage = await _chatService.addMessage(
      conversationId: _currentConversation!.id,
      role: 'assistant',
      content: '',
      modelId: modelId,
      providerId: providerKey,
      isStreaming: true,
      groupId: targetGroupId,
      version: nextVersion,
    );

    // Persist selection to the latest version of this group
    final gid = assistantMessage.groupId ?? assistantMessage.id;
    _versionSelections[gid] = assistantMessage.version;
    await _chatService.setSelectedVersion(_currentConversation!.id, gid, assistantMessage.version);

    setState(() {
      _messages.add(assistantMessage);
    });
    _setConversationLoading(_currentConversation!.id, true);

    // Haptics on regenerate
    try {
      if (context.read<SettingsProvider>().hapticsOnGenerate) {
        Haptics.light();
      }
    } catch (_) {}

    // Initialize reasoning state only when enabled and model supports it
    final supportsReasoning = _isReasoningModel(providerKey, modelId);
    final enableReasoning = supportsReasoning && _isReasoningEnabled((assistant?.thinkingBudget) ?? settings.thinkingBudget);
    if (enableReasoning) {
      final rd = _ReasoningData();
      _reasoning[assistantMessage.id] = rd;
      await _chatService.updateMessage(assistantMessage.id, reasoningStartAt: DateTime.now());
    }

    // Build API messages from current context (apply truncate + collapse versions)
    final tIndex = _currentConversation?.truncateIndex ?? -1;
    final List<ChatMessage> sourceAll = (tIndex >= 0 && tIndex <= _messages.length)
        ? _messages.sublist(tIndex)
        : List.of(_messages);
    final List<ChatMessage> source = _collapseVersions(sourceAll);
    final apiMessages = source
        .where((m) => m.content.isNotEmpty)
        .map((m) => {'role': m.role == 'assistant' ? 'assistant' : 'user', 'content': m.content})
        .toList();

    // Inject system prompt
    if ((assistant?.systemPrompt.trim().isNotEmpty ?? false)) {
      final vars = PromptTransformer.buildPlaceholders(
        context: context,
        assistant: assistant!,
        modelId: modelId,
        modelName: modelId,
        userNickname: context.read<UserProvider>().name,
      );
      final sys = PromptTransformer.replacePlaceholders(assistant.systemPrompt, vars);
      apiMessages.insert(0, {'role': 'system', 'content': sys});
    }
    // Inject search tool usage guide when enabled
    if (settings.searchEnabled) {
      final prompt = SearchToolService.getSystemPrompt();
      if (apiMessages.isNotEmpty && apiMessages.first['role'] == 'system') {
        apiMessages[0]['content'] = ((apiMessages[0]['content'] ?? '') as String) + '\n\n' + prompt;
      } else {
        apiMessages.insert(0, {'role': 'system', 'content': prompt});
      }
    }
    // Inject learning mode prompt when enabled (global)
    try {
      final lmEnabled = await LearningModeStore.isEnabled();
      if (lmEnabled) {
        final lp = await LearningModeStore.getPrompt();
        if (apiMessages.isNotEmpty && apiMessages.first['role'] == 'system') {
          apiMessages[0]['content'] = ((apiMessages[0]['content'] ?? '') as String) + '\n\n' + lp;
        } else {
          apiMessages.insert(0, {'role': 'system', 'content': lp});
        }
      }
    } catch (_) {}

    // Limit context length
    if ((assistant?.limitContextMessages ?? true) && (assistant?.contextMessageSize ?? 0) > 0) {
      final keep = assistant!.contextMessageSize.clamp(1, 512).toInt();
      int startIdx = 0;
      if (apiMessages.isNotEmpty && apiMessages.first['role'] == 'system') {
        startIdx = 1;
      }
      final tail = apiMessages.sublist(startIdx);
      if (tail.length > keep) {
        final trimmed = tail.sublist(tail.length - keep);
        apiMessages..removeRange(startIdx, apiMessages.length)..addAll(trimmed);
      }
    }

    // Convert any local Markdown image links to inline base64 for model context
    for (int i = 0; i < apiMessages.length; i++) {
      final s = (apiMessages[i]['content'] ?? '').toString();
      if (s.isNotEmpty) {
        apiMessages[i]['content'] = await MarkdownMediaSanitizer.inlineLocalImagesToBase64(s);
      }
    }

    // Prepare tools (Search + MCP)
    final List<Map<String, dynamic>> toolDefs = <Map<String, dynamic>>[];
    Future<String> Function(String, Map<String, dynamic>)? onToolCall;
    try {
      if (settings.searchEnabled) {
        toolDefs.add(SearchToolService.getToolDefinition());
      }
      final mcp = context.read<McpProvider>();
      final toolSvc = context.read<McpToolService>();
      final tools = toolSvc.listAvailableToolsForAssistant(mcp, context.read<AssistantProvider>(), assistant?.id);
      final supportsTools = _isToolModel(providerKey, modelId);
      if (supportsTools && tools.isNotEmpty) {
        final providerCfg = settings.getProviderConfig(providerKey);
        final providerKind = ProviderConfig.classify(providerCfg.id, explicitType: providerCfg.providerType);
        toolDefs.addAll(tools.map((t) {
          Map<String, dynamic> baseSchema;
          if (t.schema != null && t.schema!.isNotEmpty) {
            baseSchema = Map<String, dynamic>.from(t.schema!);
          } else {
            final props = <String, dynamic>{for (final p in t.params) p.name: {'type': (p.type ?? 'string')}};
            final required = [for (final p in t.params.where((e) => e.required)) p.name];
            baseSchema = {'type': 'object', 'properties': props, if (required.isNotEmpty) 'required': required};
          }
          final sanitized = _sanitizeToolParametersForProvider(baseSchema, providerKind);
          return {
            'type': 'function',
            'function': {
              'name': t.name,
              if ((t.description ?? '').isNotEmpty) 'description': t.description,
              'parameters': sanitized,
            }
          };
        }));
      }
      if (toolDefs.isNotEmpty) {
        onToolCall = (name, args) async {
          if (name == SearchToolService.toolName && settings.searchEnabled) {
            final q = (args['query'] ?? '').toString();
            return await SearchToolService.executeSearch(q, settings);
          }
          final text = await toolSvc.callToolTextForAssistant(
            mcp,
            context.read<AssistantProvider>(),
            assistantId: assistant?.id,
            toolName: name,
            arguments: args,
          );
          return text;
        };
      }
    } catch (_) {}

    // Build assistant-level custom request overrides
    Map<String, String>? aHeaders;
    Map<String, dynamic>? aBody;
    if ((assistant?.customHeaders.isNotEmpty ?? false)) {
      aHeaders = {
        for (final e in assistant!.customHeaders)
          if ((e['name'] ?? '').trim().isNotEmpty) (e['name']!.trim()): (e['value'] ?? '')
      };
      if (aHeaders.isEmpty) aHeaders = null;
    }
    if ((assistant?.customBody.isNotEmpty ?? false)) {
      aBody = {
        for (final e in assistant!.customBody)
          if ((e['key'] ?? '').trim().isNotEmpty)
            (e['key']!.trim()): (e['value'] ?? '')
      };
      if (aBody.isEmpty) aBody = null;
    }

    final stream = ChatApiService.sendMessageStream(
      config: settings.getProviderConfig(providerKey),
      modelId: modelId,
      messages: apiMessages,
      thinkingBudget: assistant?.thinkingBudget ?? settings.thinkingBudget,
      temperature: assistant?.temperature,
      topP: assistant?.topP,
      maxTokens: assistant?.maxTokens,
      tools: toolDefs.isEmpty ? null : toolDefs,
      onToolCall: onToolCall,
      extraHeaders: aHeaders,
      extraBody: aBody,
    );

    String fullContent = '';
    int totalTokens = 0;
    TokenUsage? usage;

    // Respect assistant streaming toggle: if off, buffer updates until done
    final bool streamOutput = assistant?.streamOutput ?? true;
    String _bufferedReasoning2 = '';
    DateTime? _reasoningStartAt2;

    Future<void> finish({bool generateTitle = false}) async {
      final processedContent = await MarkdownMediaSanitizer.replaceInlineBase64Images(fullContent);
      await _chatService.updateMessage(assistantMessage.id, content: processedContent, totalTokens: totalTokens, isStreaming: false);
      if (!mounted) return;
      setState(() {
        final index = _messages.indexWhere((m) => m.id == assistantMessage.id);
        if (index != -1) {
          _messages[index] = _messages[index].copyWith(content: processedContent, totalTokens: totalTokens, isStreaming: false);
        }
      });
      _setConversationLoading(assistantMessage.conversationId, false);
      final r = _reasoning[assistantMessage.id];
      if (r != null && r.finishedAt == null) {
        r.finishedAt = DateTime.now();
        await _chatService.updateMessage(assistantMessage.id, reasoningText: r.text, reasoningFinishedAt: r.finishedAt);
      }
      final segments = _reasoningSegments[assistantMessage.id];
      if (segments != null && segments.isNotEmpty && segments.last.finishedAt == null) {
        segments.last.finishedAt = DateTime.now();
        final autoCollapse = context.read<SettingsProvider>().autoCollapseThinking;
        if (autoCollapse) segments.last.expanded = false;
        _reasoningSegments[assistantMessage.id] = segments;
        if (mounted) setState(() {});
        await _chatService.updateMessage(assistantMessage.id, reasoningSegmentsJson: _serializeReasoningSegments(segments));
      }
    }

    final String _cid = assistantMessage.conversationId;
    await _conversationStreams[_cid]?.cancel();
    final _sub2 = stream.listen((chunk) async {
      // Always capture reasoning if provided by model, even when toggle is off
      if ((chunk.reasoning ?? '').isNotEmpty) {
        if (streamOutput) {
          final r = _reasoning[assistantMessage.id] ?? _ReasoningData();
          r.text += chunk.reasoning!;
          r.startAt ??= DateTime.now();
          // keep finishedAt as-is; don't reset to null once set
          r.expanded = false; // default collapsed while generating
          _reasoning[assistantMessage.id] = r;
          final segments = _reasoningSegments[assistantMessage.id] ?? <_ReasoningSegmentData>[];
          if (segments.isEmpty) {
            final seg = _ReasoningSegmentData();
            seg.text = chunk.reasoning!;
            seg.startAt = DateTime.now();
            seg.expanded = false; // default collapsed while generating
            seg.toolStartIndex = (_toolParts[assistantMessage.id]?.length ?? 0);
            segments.add(seg);
          } else {
            final last = segments.last;
            if ((_toolParts[assistantMessage.id]?.isNotEmpty ?? false) && last.finishedAt != null) {
              final seg = _ReasoningSegmentData();
              seg.text = chunk.reasoning!;
              seg.startAt = DateTime.now();
              seg.expanded = false; // default collapsed while generating
              seg.toolStartIndex = (_toolParts[assistantMessage.id]?.length ?? 0);
              segments.add(seg);
            } else {
              last.text += chunk.reasoning!;
              last.startAt ??= DateTime.now();
            }
          }
          _reasoningSegments[assistantMessage.id] = segments;
          if (mounted) setState(() {});
          await _chatService.updateMessage(assistantMessage.id, reasoningText: r.text, reasoningStartAt: r.startAt, reasoningSegmentsJson: _serializeReasoningSegments(segments));
        } else {
          _reasoningStartAt2 ??= DateTime.now();
          _bufferedReasoning2 += chunk.reasoning!;
        }
      }

      if ((chunk.toolCalls ?? const []).isNotEmpty) {
        // Finish current reasoning segment if one is open, so follow-up reasoning becomes a new card
        final segments = _reasoningSegments[assistantMessage.id] ?? <_ReasoningSegmentData>[];
        if (segments.isNotEmpty && segments.last.finishedAt == null) {
          segments.last.finishedAt = DateTime.now();
          final autoCollapse = context.read<SettingsProvider>().autoCollapseThinking;
          if (autoCollapse) {
            segments.last.expanded = false;
            final rd = _reasoning[assistantMessage.id];
            if (rd != null) rd.expanded = false;
          }
          _reasoningSegments[assistantMessage.id] = segments;
          try {
            await _chatService.updateMessage(
              assistantMessage.id,
              reasoningSegmentsJson: _serializeReasoningSegments(segments),
            );
          } catch (_) {}
        }

        final existing = List<ToolUIPart>.of(_toolParts[assistantMessage.id] ?? const []);
        for (final c in chunk.toolCalls!) {
          existing.add(ToolUIPart(id: c.id, toolName: c.name, arguments: c.arguments, loading: true));
        }
        setState(() => _toolParts[assistantMessage.id] = _dedupeToolPartsList(existing));
        try {
          final prev = _chatService.getToolEvents(assistantMessage.id);
          final newEvents = <Map<String, dynamic>>[
            ...prev,
            for (final c in chunk.toolCalls!) {'id': c.id, 'name': c.name, 'arguments': c.arguments, 'content': null},
          ];
          await _chatService.setToolEvents(assistantMessage.id, _dedupeToolEvents(newEvents));
        } catch (_) {}
      }

      if ((chunk.toolResults ?? const []).isNotEmpty) {
        final parts = List<ToolUIPart>.of(_toolParts[assistantMessage.id] ?? const []);
        for (final r in chunk.toolResults!) {
          int idx = -1;
          for (int i = 0; i < parts.length; i++) {
            if (parts[i].loading && (parts[i].id == r.id || (parts[i].id.isEmpty && parts[i].toolName == r.name))) {
              idx = i; break;
            }
          }
          if (idx >= 0) {
            parts[idx] = ToolUIPart(id: parts[idx].id, toolName: parts[idx].toolName, arguments: parts[idx].arguments, content: r.content, loading: false);
          } else {
            parts.add(ToolUIPart(id: r.id, toolName: r.name, arguments: r.arguments, content: r.content, loading: false));
          }
          try { await _chatService.upsertToolEvent(assistantMessage.id, id: r.id, name: r.name, arguments: r.arguments, content: r.content); } catch (_) {}
        }
        setState(() => _toolParts[assistantMessage.id] = _dedupeToolPartsList(parts));
        if (!_isUserScrolling) _scrollToBottomSoon();
      }

      if (chunk.content.isNotEmpty) {
        fullContent += chunk.content;

        // Respect auto-collapse setting when main content starts: always stop timer, collapse only if enabled
        final rd = _reasoning[assistantMessage.id];
        if (rd != null && rd.startAt != null && rd.finishedAt == null) {
          rd.finishedAt = DateTime.now();
          final autoCollapse = context.read<SettingsProvider>().autoCollapseThinking;
          if (autoCollapse) rd.expanded = false;
          _reasoning[assistantMessage.id] = rd;
          try {
            await _chatService.updateMessage(
              assistantMessage.id,
              reasoningText: rd.text,
              reasoningFinishedAt: rd.finishedAt,
            );
          } catch (_) {}
          if (mounted) setState(() {});
        }
        final segs = _reasoningSegments[assistantMessage.id];
        if (segs != null && segs.isNotEmpty && segs.last.finishedAt == null) {
          segs.last.finishedAt = DateTime.now();
          final autoCollapse = context.read<SettingsProvider>().autoCollapseThinking;
          if (autoCollapse) segs.last.expanded = false;
          _reasoningSegments[assistantMessage.id] = segs;
          try {
            await _chatService.updateMessage(
              assistantMessage.id,
              reasoningSegmentsJson: _serializeReasoningSegments(segs),
            );
          } catch (_) {}
          if (mounted) setState(() {});
        }

        if (streamOutput) {
          setState(() {
            final i = _messages.indexWhere((m) => m.id == assistantMessage.id);
            if (i != -1) _messages[i] = _messages[i].copyWith(content: fullContent);
          });
        }
      }

      if (chunk.usage != null) {
        usage = (usage ?? const TokenUsage()).merge(chunk.usage!);
        totalTokens = usage!.totalTokens;
      }

      if (chunk.isDone) {
        if (chunk.totalTokens > 0) totalTokens = chunk.totalTokens;
        await finish();
        // If non-streaming, write buffered reasoning once
        if (!streamOutput && _bufferedReasoning2.isNotEmpty) {
          final now = DateTime.now();
          final startAt = _reasoningStartAt2 ?? now;
          await _chatService.updateMessage(
            assistantMessage.id,
            reasoningText: _bufferedReasoning2,
            reasoningStartAt: startAt,
            reasoningFinishedAt: now,
          );
          final autoCollapse = context.read<SettingsProvider>().autoCollapseThinking;
          _reasoning[assistantMessage.id] = _ReasoningData()
            ..text = _bufferedReasoning2
            ..startAt = startAt
            ..finishedAt = now
            ..expanded = !autoCollapse;
          if (mounted) setState(() {});
        }
        await _conversationStreams.remove(_cid)?.cancel();
      }
    },
    onError: (e) async {
      // When regenerate fails, persist error text into this assistant bubble
      final errText = '${AppLocalizations.of(context)!.generationInterrupted}: $e';
      final displayContent = fullContent.isNotEmpty ? fullContent : errText;
      await _chatService.updateMessage(
        assistantMessage.id,
        content: displayContent,
        totalTokens: totalTokens,
        isStreaming: false,
      );

      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == assistantMessage.id);
          if (index != -1) {
            _messages[index] = _messages[index].copyWith(
              content: displayContent,
              isStreaming: false,
              totalTokens: totalTokens,
            );
          }
        });
      }
      _setConversationLoading(assistantMessage.conversationId, false);

      // End reasoning on error
      final r = _reasoning[assistantMessage.id];
      if (r != null) {
        if (r.finishedAt == null) {
          r.finishedAt = DateTime.now();
          try {
            await _chatService.updateMessage(
              assistantMessage.id,
              reasoningText: r.text,
              reasoningFinishedAt: r.finishedAt,
            );
          } catch (_) {}
        }
        final autoCollapse = context.read<SettingsProvider>().autoCollapseThinking;
        if (autoCollapse) r.expanded = false;
        _reasoning[assistantMessage.id] = r;
      }

      // Also finish any unfinished reasoning segments on error
      final segments = _reasoningSegments[assistantMessage.id];
      if (segments != null && segments.isNotEmpty && segments.last.finishedAt == null) {
        segments.last.finishedAt = DateTime.now();
        final autoCollapse = context.read<SettingsProvider>().autoCollapseThinking;
        if (autoCollapse) segments.last.expanded = false;
        _reasoningSegments[assistantMessage.id] = segments;
        try {
          await _chatService.updateMessage(
            assistantMessage.id,
            reasoningSegmentsJson: _serializeReasoningSegments(segments),
          );
        } catch (_) {}
      }

      await _conversationStreams.remove(_cid)?.cancel();
      showAppSnackBar(
        context,
        message: '${AppLocalizations.of(context)!.generationInterrupted}: $e',
        type: NotificationType.error,
      );
    },
    onDone: () async {
      // Stream ended; ensure subscription cleanup
      await _conversationStreams.remove(_cid)?.cancel();
    },
    cancelOnError: true,
    );
    _conversationStreams[_cid] = _sub2;
  }

  ChatInputData _parseInputFromRaw(String raw) {
    final imgRe = RegExp(r"\[image:(.+?)\]");
    final fileRe = RegExp(r"\[file:(.+?)\|(.+?)\|(.+?)\]");
    final images = <String>[];
    final docs = <DocumentAttachment>[];
    final buffer = StringBuffer();
    int idx = 0;
    while (idx < raw.length) {
      final imgMatch = imgRe.matchAsPrefix(raw, idx);
      final fileMatch = fileRe.matchAsPrefix(raw, idx);
      if (imgMatch != null) {
        final p = imgMatch.group(1)?.trim();
        if (p != null && p.isNotEmpty) images.add(p);
        idx = imgMatch.end;
        continue;
      }
      if (fileMatch != null) {
        final path = fileMatch.group(1)?.trim() ?? '';
        final name = fileMatch.group(2)?.trim() ?? 'file';
        final mime = fileMatch.group(3)?.trim() ?? 'text/plain';
        docs.add(DocumentAttachment(path: path, fileName: name, mime: mime));
        idx = fileMatch.end;
        continue;
      }
      buffer.write(raw[idx]);
      idx++;
    }
    return ChatInputData(text: buffer.toString().trim(), imagePaths: images, documents: docs);
  }

  Future<void> _maybeGenerateTitle({bool force = false}) async {
    final convo = _currentConversation;
    if (convo == null) return;
    await _maybeGenerateTitleFor(convo.id, force: force);
  }

  Future<void> _maybeGenerateTitleFor(String conversationId, {bool force = false}) async {
    final convo = _chatService.getConversation(conversationId);
    if (convo == null) return;
    if (!force && convo.title.isNotEmpty && convo.title != _titleForLocale(context)) return;

    final settings = context.read<SettingsProvider>();
    final assistantProvider = context.read<AssistantProvider>();

    // Get assistant for this conversation
    final assistant = convo.assistantId != null
        ? assistantProvider.getById(convo.assistantId!)
        : assistantProvider.currentAssistant;

    // Decide model: prefer title model, else fall back to assistant's model, then to global default
    final provKey = settings.titleModelProvider
        ?? assistant?.chatModelProvider
        ?? settings.currentModelProvider;
    final mdlId = settings.titleModelId
        ?? assistant?.chatModelId
        ?? settings.currentModelId;
    if (provKey == null || mdlId == null) return;
    final cfg = settings.getProviderConfig(provKey);

    // Build content from messages (truncate to reasonable length)
    final msgs = _chatService.getMessages(convo.id);
    final tIndex = convo.truncateIndex;
    final List<ChatMessage> sourceAll = (tIndex >= 0 && tIndex <= msgs.length) ? msgs.sublist(tIndex) : msgs;
    final List<ChatMessage> source = _collapseVersions(sourceAll);
    final joined = source
        .where((m) => m.content.isNotEmpty)
        .map((m) => '${m.role == 'assistant' ? 'Assistant' : 'User'}: ${m.content}')
        .join('\n\n');
    final content = joined.length > 3000 ? joined.substring(0, 3000) : joined;
    final locale = Localizations.localeOf(context).toLanguageTag();

    String prompt = settings.titlePrompt
        .replaceAll('{locale}', locale)
        .replaceAll('{content}', content);

    try {
      final title = (await ChatApiService.generateText(config: cfg, modelId: mdlId, prompt: prompt)).trim();
      if (title.isNotEmpty) {
        await _chatService.renameConversation(convo.id, title);
        if (mounted && _currentConversation?.id == convo.id) {
          setState(() {
            _currentConversation = _chatService.getConversation(convo.id);
          });
        }
      }
    } catch (_) {
      // Ignore title generation failure silently
    }
  }

  void _scrollToBottom() {
    try {
      if (!_scrollController.hasClients) return;
      
      // Don't auto-scroll if user is actively scrolling
      if (_isUserScrolling) return;
      
      // Prevent using controller while it is still attached to old/new list simultaneously
      if (_scrollController.positions.length != 1) {
        // Try again after microtask when the previous list detaches
        Future.microtask(_scrollToBottom);
        return;
      }
      final max = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(max);
      if (_showJumpToBottom) {
        setState(() => _showJumpToBottom = false);
      }
    } catch (_) {
      // Ignore transient attachment errors
    }
  }

  void _forceScrollToBottom() {
    // Force scroll to bottom when user explicitly clicks the button
    _isUserScrolling = false;
    _userScrollTimer?.cancel();
    _lastJumpUserMessageId = null;
    _scrollToBottom();
  }

  // Force scroll after rebuilds when switching topics/conversations
  void _forceScrollToBottomSoon() {
    _isUserScrolling = false;
    _userScrollTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    Future.delayed(_postSwitchScrollDelay, _scrollToBottom);
  }

  void _measureInputBar() {
    try {
      final ctx = _inputBarKey.currentContext;
      if (ctx == null) return;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) return;
      final h = box.size.height;
      if ((_inputBarHeight - h).abs() > 1.0) {
        setState(() => _inputBarHeight = h);
      }
    } catch (_) {}
  }

  // Ensure scroll reaches bottom even after widget tree transitions
  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    Future.delayed(const Duration(milliseconds: 120), _scrollToBottom);
  }

  Future<void> _showQuickPhraseMenu() async {
    final assistant = context.read<AssistantProvider>().currentAssistant;
    final quickPhraseProvider = context.read<QuickPhraseProvider>();
    final globalPhrases = quickPhraseProvider.globalPhrases;
    final assistantPhrases = assistant != null
        ? quickPhraseProvider.getForAssistant(assistant.id)
        : <QuickPhrase>[];
    
    final allAvailable = [...globalPhrases, ...assistantPhrases];
    if (allAvailable.isEmpty) return;

    // Get input bar height for positioning menu above it
    final RenderBox? inputBox = _inputBarKey.currentContext?.findRenderObject() as RenderBox?;
    if (inputBox == null) return;
    
    final inputBarHeight = inputBox.size.height;
    final topLeft = inputBox.localToGlobal(Offset.zero);
    final position = Offset(topLeft.dx, inputBarHeight); // dx = global left, dy = input height
    
    // Dismiss keyboard before showing menu to prevent flickering
    _dismissKeyboard();
    
    final selected = await showQuickPhraseMenu(
      context: context,
      phrases: allAvailable,
      position: position,
    );

    if (selected != null && mounted) {
      // Insert content at cursor position
      final text = _inputController.text;
      final selection = _inputController.selection;
      final start = (selection.start >= 0 && selection.start <= text.length) 
          ? selection.start 
          : text.length;
      final end = (selection.end >= 0 && selection.end <= text.length && selection.end >= start) 
          ? selection.end 
          : start;
      
      final newText = text.replaceRange(start, end, selected.content);
      _inputController.value = _inputController.value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: start + selected.content.length),
        composing: TextRange.empty,
      );
      
      setState(() {});
      
      // Don't auto-refocus to prevent keyboard flickering on Android
      // User can tap input field if they want to continue typing
    }
  }

  // Scroll to a specific message id (from mini map selection)
  Future<void> _scrollToMessageId(String targetId) async {
    try {
      if (!mounted || !_scrollController.hasClients) return;
      final messages = _collapseVersions(_messages);
      final tIndex = messages.indexWhere((m) => m.id == targetId);
      if (tIndex < 0) return;

      // Try direct ensureVisible first
      final tKey = _messageKeys[targetId];
      final tCtx = tKey?.currentContext;
      if (tCtx != null) {
        await Scrollable.ensureVisible(
          tCtx,
          alignment: 0.1,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
        _lastJumpUserMessageId = targetId; // allow chaining with prev-question
        return;
      }

      // Coarse jump based on index ratio to bring target into build range
      final pos0 = _scrollController.position;
      final denom = (messages.length - 1).clamp(1, 1 << 30);
      final ratio = tIndex / denom;
      final coarse = (pos0.maxScrollExtent * ratio).clamp(0.0, pos0.maxScrollExtent);
      _scrollController.jumpTo(coarse);
      await WidgetsBinding.instance.endOfFrame;
      final tCtxAfterCoarse = _messageKeys[targetId]?.currentContext;
      if (tCtxAfterCoarse != null) {
        await Scrollable.ensureVisible(tCtxAfterCoarse, alignment: 0.1, duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic);
        _lastJumpUserMessageId = targetId;
        return;
      }

      // Determine direction using visible anchor indices
      final media = MediaQuery.of(context);
      final double listTop = kToolbarHeight + media.padding.top;
      final double listBottom = media.size.height - media.padding.bottom - _inputBarHeight - 8;
      int? firstVisibleIdx;
      int? lastVisibleIdx;
      for (int i = 0; i < messages.length; i++) {
        final key = _messageKeys[messages[i].id];
        final ctx = key?.currentContext;
        if (ctx == null) continue;
        final box = ctx.findRenderObject() as RenderBox?;
        if (box == null || !box.attached) continue;
        final top = box.localToGlobal(Offset.zero).dy;
        final bottom = top + box.size.height;
        final visible = bottom > listTop && top < listBottom;
        if (visible) {
          firstVisibleIdx ??= i;
          lastVisibleIdx = i;
        }
      }
      final anchor = lastVisibleIdx ?? firstVisibleIdx ?? 0;
      final dirDown = tIndex > anchor; // target below

      // Page in steps until the target builds, then ensureVisible
      const int maxAttempts = 40;
      for (int attempt = 0; attempt < maxAttempts; attempt++) {
        final ctx2 = _messageKeys[targetId]?.currentContext;
        if (ctx2 != null) {
          await Scrollable.ensureVisible(
            ctx2,
            alignment: 0.1,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOutCubic,
          );
          _lastJumpUserMessageId = targetId;
          return;
        }
        final pos = _scrollController.position;
        final viewH = media.size.height;
        final step = viewH * 0.85 * (dirDown ? 1 : -1);
        double newOffset = pos.pixels + step;
        if (newOffset < 0) newOffset = 0;
        if (newOffset > pos.maxScrollExtent) newOffset = pos.maxScrollExtent;
        if ((newOffset - pos.pixels).abs() < 1) break;
        _scrollController.jumpTo(newOffset);
        await WidgetsBinding.instance.endOfFrame;
      }
    } catch (_) {}
  }

  // Jump to the previous user message (question) above the current viewport
  Future<void> _jumpToPreviousQuestion() async {
    try {
      if (!mounted || !_scrollController.hasClients) return;
      final messages = _collapseVersions(_messages);
      if (messages.isEmpty) return;
      // Build an id->index map for quick lookup
      final Map<String, int> idxById = <String, int>{};
      for (int i = 0; i < messages.length; i++) { idxById[messages[i].id] = i; }

      // Determine anchor index: prefer last jumped user; otherwise bottom-most visible item
      int? anchor;
      if (_lastJumpUserMessageId != null && idxById.containsKey(_lastJumpUserMessageId)) {
        anchor = idxById[_lastJumpUserMessageId!];
      } else {
        final media = MediaQuery.of(context);
        final double listTop = kToolbarHeight + media.padding.top;
        final double listBottom = media.size.height - media.padding.bottom - _inputBarHeight - 8;
        int? firstVisibleIdx;
        int? lastVisibleIdx;
        for (int i = 0; i < messages.length; i++) {
          final key = _messageKeys[messages[i].id];
          final ctx = key?.currentContext;
          if (ctx == null) continue;
          final box = ctx.findRenderObject() as RenderBox?;
          if (box == null || !box.attached) continue;
          final top = box.localToGlobal(Offset.zero).dy;
          final bottom = top + box.size.height;
          final visible = bottom > listTop && top < listBottom;
          if (visible) {
            firstVisibleIdx ??= i;
            lastVisibleIdx = i;
          }
        }
        anchor = lastVisibleIdx ?? firstVisibleIdx ?? (messages.length - 1);
      }
      // Search backward for previous user message from the anchor index
      int target = -1;
      for (int i = (anchor ?? 0) - 1; i >= 0; i--) {
        if (messages[i].role == 'user') { target = i; break; }
      }
      if (target < 0) {
        // No earlier user message; jump to top instantly
        _scrollController.jumpTo(0.0);
        _lastJumpUserMessageId = null;
        return;
      }
      // If target widget is not built yet (off-screen far above), page up until it is
      const int maxAttempts = 12; // about 10 pages max
      for (int attempt = 0; attempt < maxAttempts; attempt++) {
        final tKey = _messageKeys[messages[target].id];
        final tCtx = tKey?.currentContext;
        if (tCtx != null) {
          await Scrollable.ensureVisible(
            tCtx,
            alignment: 0.08,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOutCubic,
          );
          _lastJumpUserMessageId = messages[target].id;
          return;
        }
        // Step up by ~85% of viewport height
        final pos = _scrollController.position;
        final viewH = MediaQuery.of(context).size.height;
        final step = viewH * 0.85;
        final newOffset = (pos.pixels - step) < 0 ? 0.0 : (pos.pixels - step);
        if ((pos.pixels - newOffset).abs() < 1) break; // reached top
        _scrollController.jumpTo(newOffset);
        // Let the list build newly visible children
        await WidgetsBinding.instance.endOfFrame;
      }
      // Final fallback: go to top if still not found
      _scrollController.jumpTo(0.0);
      _lastJumpUserMessageId = null;
    } catch (_) {}
  }

  // Translate message functionality
  Future<void> _translateMessage(ChatMessage message) async {
    final l10n = AppLocalizations.of(context)!;
    // Show language selector
    final language = await showLanguageSelector(context);
    if (language == null) return;

    // Check if clear translation is selected
    if (language.code == '__clear__') {
      // Clear the translation (use empty string so UI hides immediately)
      final updatedMessage = message.copyWith(translation: '');
      setState(() {
        final index = _messages.indexWhere((m) => m.id == message.id);
        if (index != -1) {
          _messages[index] = updatedMessage;
        }
        // Remove translation state
        _translations.remove(message.id);
      });
      await _chatService.updateMessage(message.id, translation: '');
      return;
    }

    final settings = context.read<SettingsProvider>();
    final assistant = context.read<AssistantProvider>().currentAssistant;

    // Check if translation model is set, fallback to assistant's model, then to global default
    final translateProvider = settings.translateModelProvider
        ?? assistant?.chatModelProvider
        ?? settings.currentModelProvider;
    final translateModelId = settings.translateModelId
        ?? assistant?.chatModelId
        ?? settings.currentModelId;

    if (translateProvider == null || translateModelId == null) {
      showAppSnackBar(
        context,
        message: l10n.homePagePleaseSetupTranslateModel,
        type: NotificationType.warning,
      );
      return;
    }

    // Extract text content from message (removing reasoning text if present)
    String textToTranslate = message.content;

    // Set loading state and initialize translation data
    final loadingMessage = message.copyWith(translation: l10n.homePageTranslating);
    setState(() {
      final index = _messages.indexWhere((m) => m.id == message.id);
      if (index != -1) {
        _messages[index] = loadingMessage;
      }
      // Initialize translation state with expanded
      _translations[message.id] = _TranslationData();
    });

    try {
      // Get translation prompt with placeholders replaced
      String prompt = settings.translatePrompt
          .replaceAll('{source_text}', textToTranslate)
          .replaceAll('{target_lang}', language.displayName);

      // Create translation request
      final provider = settings.getProviderConfig(translateProvider);

      final translationStream = ChatApiService.sendMessageStream(
        config: provider,
        modelId: translateModelId,
        messages: [
          {'role': 'user', 'content': prompt}
        ],
      );

      final buffer = StringBuffer();

      await for (final chunk in translationStream) {
        buffer.write(chunk.content);

        // Update translation in real-time
        final updatingMessage = message.copyWith(translation: buffer.toString());
        setState(() {
          final index = _messages.indexWhere((m) => m.id == message.id);
          if (index != -1) {
            _messages[index] = updatingMessage;
          }
        });
      }

      // Save final translation
      await _chatService.updateMessage(message.id, translation: buffer.toString());

    } catch (e) {
      // Clear translation on error (empty to hide immediately)
      final errorMessage = message.copyWith(translation: '');
      setState(() {
        final index = _messages.indexWhere((m) => m.id == message.id);
        if (index != -1) {
          _messages[index] = errorMessage;
        }
        // Remove translation state on error
        _translations.remove(message.id);
      });

      await _chatService.updateMessage(message.id, translation: '');

      showAppSnackBar(
        context,
        message: l10n.homePageTranslateFailed(e.toString()),
        type: NotificationType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tablet and larger: fixed side panel + constrained content
    final width = MediaQuery.sizeOf(context).width;
    if (width >= AppBreakpoints.tablet) {
      final title = ((_currentConversation?.title ?? '').trim().isNotEmpty)
          ? _currentConversation!.title
          : _titleForLocale(context);
      final cs = Theme.of(context).colorScheme;
      final settings = context.watch<SettingsProvider>();
      final assistant = context.watch<AssistantProvider>().currentAssistant;
      final providerKey = assistant?.chatModelProvider ?? settings.currentModelProvider;
      final modelId = assistant?.chatModelId ?? settings.currentModelId;
      String? providerName;
      String? modelDisplay;
      if (providerKey != null && modelId != null) {
        final cfg = settings.getProviderConfig(providerKey);
        providerName = cfg.name.isNotEmpty ? cfg.name : providerKey;
        final ov = cfg.modelOverrides[modelId] as Map?;
        modelDisplay = (ov != null && (ov['name'] as String?)?.isNotEmpty == true) ? (ov['name'] as String) : modelId;
      }
      return _buildTabletLayout(context, title: title, providerName: providerName, modelDisplay: modelDisplay, cs: cs);
    }

    final title = ((_currentConversation?.title ?? '').trim().isNotEmpty)
        ? _currentConversation!.title
        : _titleForLocale(context);
    final cs = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final assistant = context.watch<AssistantProvider>().currentAssistant;
    
    // Use assistant's model if set, otherwise fall back to global default
    final providerKey = assistant?.chatModelProvider ?? settings.currentModelProvider;
    final modelId = assistant?.chatModelId ?? settings.currentModelId;
    String? providerName;
    String? modelDisplay;
    if (providerKey != null && modelId != null) {
      final cfg = settings.getProviderConfig(providerKey);
      providerName = cfg.name.isNotEmpty ? cfg.name : providerKey;
      final ov = cfg.modelOverrides[modelId] as Map?;
      modelDisplay = (ov != null && (ov['name'] as String?)?.isNotEmpty == true) ? (ov['name'] as String) : modelId;
    }

    // Chats are seeded via ChatProvider in main.dart

    return InteractiveDrawer(
      controller: _drawerController,
      side: DrawerSide.left,
      drawerWidth: MediaQuery.sizeOf(context).width * 0.75,
      scrimColor: cs.onSurface,
      maxScrimOpacity: 0.12,
      barrierDismissible: true,
      // onScrimTap: () {
      //   // Vibrate when tapping right-side scrim to close
      //   try {
      //     if (context.read<SettingsProvider>().hapticsOnDrawer) {
      //       Haptics.drawerPulse();
      //     }
      //   } catch (_) {}
      // },
      drawer: SideDrawer(
        userName: context.watch<UserProvider>().name,
        assistantName: (() {
          final l10n = AppLocalizations.of(context)!;
          final a = context.watch<AssistantProvider>().currentAssistant;
          final n = a?.name.trim();
          return (n == null || n.isEmpty) ? l10n.homePageDefaultAssistant : n;
        })(),
        closePickerTicker: _assistantPickerCloseTick,
        loadingConversationIds: _loadingConversationIds,
        onSelectConversation: (id) {
          // Update current selection for highlight in drawer and animate switch
          _switchConversationAnimated(id);
          // // Haptic feedback when closing the sidebar
          // try {
          //   if (context.read<SettingsProvider>().hapticsOnDrawer) {
          //     Haptics.drawerPulse();
          //   }
          // } catch (_) {}
          _drawerController.close();
        },
        onNewConversation: () async {
          await _createNewConversationAnimated();
          // // Haptic feedback when closing the sidebar
          // try {
          //   if (context.read<SettingsProvider>().hapticsOnDrawer) {
          //     Haptics.drawerPulse();
          //   }
          // } catch (_) {}
          _drawerController.close();
        },
      ),
      child: Scaffold(
        // child: Scaffold(
        key: _scaffoldKey,
        resizeToAvoidBottomInset: true,
        extendBodyBehindAppBar: true,
        // backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        // centerTitle: true,
        systemOverlayStyle: (Theme.of(context).brightness == Brightness.dark)
            ? const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light, // Android icons
          statusBarBrightness: Brightness.dark, // iOS text
        )
            : const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () {
            // Always dismiss keyboard when toggling the sidebar
            _dismissKeyboard();
            _drawerController.toggle();
          },
          icon: SvgPicture.asset(
            'assets/icons/list.svg',
            width: 14,
            height: 14,
            colorFilter: ColorFilter.mode(
              Theme.of(context).iconTheme.color ?? Theme.of(context).colorScheme.onSurface,
              BlendMode.srcIn,
            ),
          ),
        ),
        titleSpacing: 2,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          // crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnimatedTextSwap(
              text: title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            if (providerName != null && modelDisplay != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => showModelSelectSheet(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 0),
                    child: AnimatedTextSwap(
                      text: '$modelDisplay ($providerName)',
                      style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.6), fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
          ],
        ),
        actions: [
          // Mini map button (to the left of new conversation)
          IconButton(
            onPressed: () async {
              final collapsed = _collapseVersions(_messages);
              final selectedId = await showMiniMapSheet(context, collapsed);
              if (!mounted) return;
              if (selectedId != null && selectedId.isNotEmpty) {
                await _scrollToMessageId(selectedId);
              }
            },
            icon: const Icon(Lucide.Map, size: 20),
            tooltip: AppLocalizations.of(context)!.miniMapTooltip,
          ),
          // Temporarily hidden: More menu button
          // IconButton(
          //   onPressed: () {
          //     Navigator.of(context).push(
          //       MaterialPageRoute(builder: (_) => const MorePage()),
          //     );
          //   },
          //   icon: const Icon(Lucide.Menu, size: 22),
          // ),
          IconButton(
            onPressed: () async {
              await _createNewConversation();
              if (mounted) {
                // Close drawer if open and scroll to bottom (fresh convo)
                _forceScrollToBottomSoon();
              }
            },
            icon: const Icon(Lucide.MessageCirclePlus, size: 22),
          ),
        ],
      ),
      body: Stack(
          children: [
            // Assistant-specific chat background + gradient overlay to improve readability
            Builder(
              builder: (context) {
              final bg = context.watch<AssistantProvider>().currentAssistant?.background;
            if (bg == null || bg.trim().isEmpty) return const SizedBox.shrink();
            ImageProvider provider;
            if (bg.startsWith('http')) {
              provider = NetworkImage(bg);
            } else {
              if (kIsWeb) return const SizedBox.shrink();
              final localPath = SandboxPathResolver.fix(bg);
              final file = File(localPath);
              if (!file.existsSync()) return const SizedBox.shrink();
              provider = FileImage(file);
            }
            return Positioned.fill(
              child: Stack(
                children: [
                  // Background image
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: provider,
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.04), BlendMode.srcATop),
                        ),
                      ),
                    ),
                  ),
                  // Vertical gradient overlay (top ~20% -> bottom ~50%) using theme background color
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              cs.background.withOpacity(0.20),
                              cs.background.withOpacity(0.50),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          // Main column content
          Padding(
            padding: EdgeInsets.only(top: kToolbarHeight + MediaQuery.of(context).padding.top),
            child: Column(
            children: [
              // Chat messages list (animate when switching topic)
              Expanded(
                child: Builder(
                    builder: (context) {
                      final __content = KeyedSubtree(
                        key: ValueKey<String>(_currentConversation?.id ?? 'none'),
                        child: (() {
                      // Stable snapshot for this build (collapse versions)
                      final messages = _collapseVersions(_messages);
                      final Map<String, List<ChatMessage>> byGroup = <String, List<ChatMessage>>{};
                      for (final m in _messages) {
                        final gid = (m.groupId ?? m.id);
                        byGroup.putIfAbsent(gid, () => <ChatMessage>[]).add(m);
                      }
                      // Map persisted truncateIndex (raw message count) to collapsed index
                      final int truncRaw = _currentConversation?.truncateIndex ?? -1;
                      int truncCollapsed = -1;
                      if (truncRaw > 0) {
                        final seen = <String>{};
                        final int limit = truncRaw < _messages.length ? truncRaw : _messages.length;
                        int count = 0;
                        for (int i = 0; i < limit; i++) {
                          final gid0 = (_messages[i].groupId ?? _messages[i].id);
                          if (seen.add(gid0)) count++;
                        }
                        truncCollapsed = count - 1;
                      }
                      final bool listLoadingTail = _isCurrentConversationLoading;
                      final list = ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 16, top: 8),
                        itemCount: messages.length + (listLoadingTail ? 1 : 0),
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        itemBuilder: (context, index) {
                          // tail loading row
                          if (listLoadingTail && index == messages.length) {
                            final cs = Theme.of(context).colorScheme;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  DotsTypingIndicator(color: cs.primary, dotSize: 8, gap: 4),
                                  const SizedBox(width: 8),
                                  Text(
                                    AppLocalizations.of(context)!.chatMessageWidgetThinking,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: cs.onSurface.withOpacity(0.55),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  )
                                ],
                              ),
                            );
                          }
                          if (index < 0 || index >= messages.length) {
                            return const SizedBox.shrink();
                          }
                          final message = messages[index];
                          final r = _reasoning[message.id];
                          final t = _translations[message.id];
                          final chatScale = context.watch<SettingsProvider>().chatFontScale;
                          final assistant = context.watch<AssistantProvider>().currentAssistant;
                          final useAssist = assistant?.useAssistantAvatar == true;
                          final l10n = AppLocalizations.of(context)!;
                          final showDivider = truncCollapsed >= 0 && index == truncCollapsed;
                          final cs = Theme.of(context).colorScheme;
                          final label = l10n.homePageClearContext;
                          final divider = Row(
                            children: [
                              Expanded(child: Divider(color: cs.outlineVariant.withOpacity(0.6), height: 1, thickness: 1)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(label, style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.6))),
                              ),
                              Expanded(child: Divider(color: cs.outlineVariant.withOpacity(0.6), height: 1, thickness: 1)),
                            ],
                          );
                          final gid = (message.groupId ?? message.id);
                          final vers = (byGroup[gid] ?? const <ChatMessage>[]).toList()..sort((a,b)=>a.version.compareTo(b.version));
                          final selectedIdx = _versionSelections[gid] ?? (vers.isNotEmpty ? vers.length - 1 : 0);
                          final total = vers.length;
                          final showMsgNav = context.watch<SettingsProvider>().showMessageNavButtons;
                          final effectiveTotal = showMsgNav ? total : 1;
                          final effectiveIndex = showMsgNav ? selectedIdx : 0;

                          return Column(
                            key: _keyForMessage(message.id),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_selecting && (message.role == 'user' || message.role == 'assistant'))
                                    Padding(
                                      padding: const EdgeInsets.only(left: 10, right: 6),
                                      child: IosCheckbox(
                                        value: _selectedItems.contains(message.id),
                                        onChanged: (v) {
                                          setState(() {
                                            if (v) {
                                              _selectedItems.add(message.id);
                                            } else {
                                              _selectedItems.remove(message.id);
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                  Expanded(
                                    child: MediaQuery(
                                      data: MediaQuery.of(context).copyWith(
                                        textScaleFactor: MediaQuery.of(context).textScaleFactor * chatScale,
                                      ),
                                      child: ChatMessageWidget(
                                  message: message,
                                  versionIndex: effectiveIndex,
                                  versionCount: effectiveTotal,
                                  onPrevVersion: (showMsgNav && selectedIdx > 0) ? () async {
                                    final next = selectedIdx - 1;
                                    _versionSelections[gid] = next;
                                    await _chatService.setSelectedVersion(_currentConversation!.id, gid, next);
                                    if (mounted) setState(() {});
                                  } : null,
                                  onNextVersion: (showMsgNav && selectedIdx < total - 1) ? () async {
                                    final next = selectedIdx + 1;
                                    _versionSelections[gid] = next;
                                    await _chatService.setSelectedVersion(_currentConversation!.id, gid, next);
                                    if (mounted) setState(() {});
                                  } : null,
                                  modelIcon: (!useAssist && message.role == 'assistant' && message.providerId != null && message.modelId != null)
                                      ? _CurrentModelIcon(providerKey: message.providerId, modelId: message.modelId, size: 30)
                                      : null,
                                  showModelIcon: useAssist ? false : context.watch<SettingsProvider>().showModelIcon,
                                  useAssistantAvatar: useAssist && message.role == 'assistant',
                                  assistantName: useAssist ? (assistant?.name ?? 'Assistant') : null,
                                  assistantAvatar: useAssist ? (assistant?.avatar ?? '') : null,
                                  showUserAvatar: context.watch<SettingsProvider>().showUserAvatar,
                                  showTokenStats: context.watch<SettingsProvider>().showTokenStats,
                                  reasoningText: (message.role == 'assistant') ? (r?.text ?? '') : null,
                                  reasoningExpanded: (message.role == 'assistant') ? (r?.expanded ?? false) : false,
                                  reasoningLoading: (message.role == 'assistant') ? (r?.finishedAt == null && (r?.text.isNotEmpty == true)) : false,
                                  reasoningStartAt: (message.role == 'assistant') ? r?.startAt : null,
                                  reasoningFinishedAt: (message.role == 'assistant') ? r?.finishedAt : null,
                                  onToggleReasoning: (message.role == 'assistant' && r != null)
                                      ? () {
                                          setState(() {
                                            r.expanded = !r.expanded;
                                          });
                                        }
                                      : null,
                                  translationExpanded: t?.expanded ?? true,
                                  onToggleTranslation: (message.translation != null && message.translation!.isNotEmpty && t != null)
                                      ? () {
                                          setState(() {
                                            t.expanded = !t.expanded;
                                          });
                                        }
                                      : null,
                                  onRegenerate: message.role == 'assistant' ? () { _regenerateAtMessage(message); } : null,
                                  onResend: message.role == 'user' ? () { _regenerateAtMessage(message); } : null,
                                  onTranslate: message.role == 'assistant'
                                      ? () {
                                          _translateMessage(message);
                                        }
                                      : null,
                                  onSpeak: message.role == 'assistant'
                                      ? () async {
                                          final tts = context.read<TtsProvider>();
                                          if (!tts.isSpeaking) {
                                            await tts.speak(message.content);
                                          } else {
                                            await tts.stop();
                                          }
                                        }
                                      : null,
                                  onEdit: message.role == 'user' ? () async {
                                    final edited = await Navigator.of(context).push<String>(
                                      MaterialPageRoute(builder: (_) => MessageEditPage(message: message)),
                                    );
                                    if (edited != null) {
                                      final newMsg = await _chatService.appendMessageVersion(messageId: message.id, content: edited);
                                      if (!mounted) return;
                                      setState(() {
                                        if (newMsg != null) {
                                          _messages.add(newMsg);
                                          final gid2 = (newMsg.groupId ?? newMsg.id);
                                          _versionSelections[gid2] = newMsg.version;
                                        }
                                      });
                                      try {
                                        if (newMsg != null && _currentConversation != null) {
                                          final gid2 = (newMsg.groupId ?? newMsg.id);
                                          await _chatService.setSelectedVersion(_currentConversation!.id, gid2, newMsg.version);
                                        }
                                      } catch (_) {}
                                    }
                                  } : null,
                                  onDelete: message.role == 'user' ? () async {
                                    final l10n = AppLocalizations.of(context)!;
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: Text(l10n.homePageDeleteMessage),
                                        content: Text(l10n.homePageDeleteMessageConfirm),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(ctx).pop(false),
                                            child: Text(l10n.homePageCancel),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.of(ctx).pop(true),
                                            child: Text(l10n.homePageDelete, style: const TextStyle(color: Colors.red)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      final id = message.id;
                                      setState(() {
                                        _messages.removeWhere((m) => m.id == id);
                                        _reasoning.remove(id);
                                        _translations.remove(id);
                                        _toolParts.remove(id);
                                        _reasoningSegments.remove(id);
                                      });
                                      await _chatService.deleteMessage(id);
                                    }
                                  } : null,
                              onMore: () async {
                                final action = await showMessageMoreSheet(context, message);
                                if (!mounted) return;
                                if (action == MessageMoreAction.delete) {
                                  final l10n = AppLocalizations.of(context)!;
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Text(l10n.homePageDeleteMessage),
                                      content: Text(l10n.homePageDeleteMessageConfirm),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(ctx).pop(false),
                                          child: Text(l10n.homePageCancel),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.of(ctx).pop(true),
                                          child: Text(l10n.homePageDelete, style: const TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    final id = message.id;
                                    setState(() {
                                      _messages.removeWhere((m) => m.id == id);
                                      _reasoning.remove(id);
                                      _translations.remove(id);
                                      _toolParts.remove(id);
                                      _reasoningSegments.remove(id);
                                    });
                                    await _chatService.deleteMessage(id);
                                  }
                                } else if (action == MessageMoreAction.edit) {
                                  final edited = await Navigator.of(context).push<String>(
                                    MaterialPageRoute(builder: (_) => MessageEditPage(message: message)),
                                  );
                                  if (edited != null) {
                                    final newMsg = await _chatService.appendMessageVersion(messageId: message.id, content: edited);
                                    if (!mounted) return;
                                    setState(() {
                                      if (newMsg != null) {
                                        _messages.add(newMsg);
                                        final gid = (newMsg.groupId ?? newMsg.id);
                                        _versionSelections[gid] = newMsg.version;
                                      }
                                    });
                                    try {
                                      if (newMsg != null && _currentConversation != null) {
                                        final gid = (newMsg.groupId ?? newMsg.id);
                                        await _chatService.setSelectedVersion(_currentConversation!.id, gid, newMsg.version);
                                      }
                                    } catch (_) {}
                                  }
                                } else if (action == MessageMoreAction.fork) {
                                  // Determine included groups up to the message's group (inclusive)
                                  final Map<String, int> groupFirstIndex = <String, int>{};
                                  final List<String> groupOrder = <String>[];
                                  for (int i = 0; i < _messages.length; i++) {
                                    final gid0 = (_messages[i].groupId ?? _messages[i].id);
                                    if (!groupFirstIndex.containsKey(gid0)) {
                                      groupFirstIndex[gid0] = i;
                                      groupOrder.add(gid0);
                                    }
                                  }
                                  final targetGroup = (message.groupId ?? message.id);
                                  final targetOrderIndex = groupOrder.indexOf(targetGroup);
                                  if (targetOrderIndex >= 0) {
                                    final includeGroups = groupOrder.take(targetOrderIndex + 1).toSet();
                                    final selected = [
                                      for (final m in _messages)
                                        if (includeGroups.contains(m.groupId ?? m.id)) m
                                    ];
                                    // Filter version selections to included groups
                                    final sel = <String, int>{};
                                    for (final gid in includeGroups) {
                                      final v = _versionSelections[gid];
                                      if (v != null) sel[gid] = v;
                                    }
                                    final newConvo = await _chatService.forkConversation(
                                      title: _titleForLocale(context),
                                      assistantId: _currentConversation?.assistantId,
                                      sourceMessages: selected,
                                      versionSelections: sel,
                                    );
                                    // Switch to the new conversation with fade animation
                                    if (!mounted) return;
                                    await _convoFadeController.reverse();
                                    _chatService.setCurrentConversation(newConvo.id);
                                    final msgs = _chatService.getMessages(newConvo.id);
                                    if (!mounted) return;
                                    setState(() {
                                      _currentConversation = newConvo;
                                      _messages = List.of(msgs);
                                      _loadVersionSelections();
                                      _restoreMessageUiState();
                                    });
                                    try { await WidgetsBinding.instance.endOfFrame; } catch (_) {}
                                    _scrollToBottom();
                                    await _convoFadeController.forward();
                                  }
                                } else if (action == MessageMoreAction.share) {
                                  // Enter selection mode and preselect up to this message (inclusive)
                                  setState(() {
                                    _selecting = true;
                                    _selectedItems.clear();
                                    for (int i = 0; i <= index && i < messages.length; i++) {
                                      final m = messages[i];
                                      final enabled0 = (m.role == 'user' || m.role == 'assistant');
                                      if (enabled0) _selectedItems.add(m.id);
                                    }
                                  });
                                }
                              },
                                  toolParts: message.role == 'assistant' ? _toolParts[message.id] : null,
                                  reasoningSegments: message.role == 'assistant'
                                      ? (() {
                                          final segments = _reasoningSegments[message.id];
                                          if (segments == null || segments.isEmpty) return null;
                                          return segments
                                              .map((s) => ReasoningSegment(
                                                    text: s.text,
                                                    expanded: s.expanded,
                                                    loading: s.finishedAt == null && s.text.isNotEmpty,
                                                    startAt: s.startAt,
                                                    finishedAt: s.finishedAt,
                                                    onToggle: () {
                                                      setState(() {
                                                        s.expanded = !s.expanded;
                                                      });
                                                    },
                                                    toolStartIndex: s.toolStartIndex,
                                                  ))
                                              .toList();
                                        })()
                                      : null,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              if (showDivider)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: AppSpacing.md),
                                  child: divider,
                                ),
                            ],
                          );
                        },
                      );
                      return list;
                        })(),
                      );
                      final isAndroid = Theme.of(context).platform == TargetPlatform.android;
                      Widget w = __content;
                      if (!isAndroid) {
                        w = w
                            .animate(key: ValueKey('mob_body_'+(_currentConversation?.id ?? 'none')))
                            .fadeIn(duration: 200.ms, curve: Curves.easeOutCubic);
                            // .slideY(begin: 0.02, end: 0, duration: 240.ms, curve: Curves.easeOutCubic);
                        w = FadeTransition(opacity: _convoFade, child: w);
                      }
                      return w;
                    },
                  ),
              ),
              // Input bar
              NotificationListener<SizeChangedLayoutNotification>(
                onNotification: (n) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => _measureInputBar());
                  return false;
                },
                child: SizeChangedLayoutNotifier(
                  child: Builder(
                    builder: (context) {
                      // Enforce model capabilities: disable MCP selection if model doesn't support tools
                      final settings = context.watch<SettingsProvider>();
                      final ap = context.watch<AssistantProvider>();
                      final a = ap.currentAssistant;
                      // Use assistant's model if set, otherwise fall back to global default
                      final pk = a?.chatModelProvider ?? settings.currentModelProvider;
                      final mid = a?.chatModelId ?? settings.currentModelId;
                      if (pk != null && mid != null) {
                        final supportsTools = _isToolModel(pk, mid);
                        if (!supportsTools && (a?.mcpServerIds.isNotEmpty ?? false)) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            final aa = ap.currentAssistant;
                            if (aa != null && aa.mcpServerIds.isNotEmpty) {
                              ap.updateAssistant(aa.copyWith(mcpServerIds: const <String>[]));
                            }
                          });
                        }
                        final supportsReasoning = _isReasoningModel(pk, mid);
                        if (!supportsReasoning && a != null) {
                          final enabledNow = _isReasoningEnabled(a.thinkingBudget ?? settings.thinkingBudget);
                          if (enabledNow) {
                            WidgetsBinding.instance.addPostFrameCallback((_) async {
                              final aa = ap.currentAssistant;
                              if (aa != null) {
                                await ap.updateAssistant(aa.copyWith(thinkingBudget: 0));
                              }
                            });
                          }
                        }
                      }
                      // Compute whether built-in built-in search (Gemini official or Claude) is active to highlight the search button
                      final currentProvider = a?.chatModelProvider ?? settings.currentModelProvider;
                      final currentModelId = a?.chatModelId ?? settings.currentModelId;
                      final cfg = (currentProvider != null)
                          ? settings.getProviderConfig(currentProvider)
                          : null;
                      bool builtinSearchActive = false;
                      if (cfg != null && currentModelId != null) {
                        final mid2 = currentModelId;
                        final isGeminiOfficial = cfg.providerType == ProviderKind.google && (cfg.vertexAI != true);
                        final isClaude = cfg.providerType == ProviderKind.claude;
                        final isOpenAIResponses = cfg.providerType == ProviderKind.openai && (cfg.useResponseApi == true);
                        if (isGeminiOfficial || isClaude || isOpenAIResponses) {
                          final ov = cfg.modelOverrides[mid2] as Map?;
                          final list = (ov?['builtInTools'] as List?) ?? const <dynamic>[];
                          builtinSearchActive = list.map((e) => e.toString().toLowerCase()).contains('search');
                        }
                      }
                      return ChatInputBar(
                        key: _inputBarKey,
                        onMore: _toggleTools,
                        // Highlight when app-level search enabled OR model built-in search enabled
                        searchEnabled: context.watch<SettingsProvider>().searchEnabled || builtinSearchActive,
                        onToggleSearch: (enabled) {
                          context.read<SettingsProvider>().setSearchEnabled(enabled);
                        },
                        onSelectModel: () => showModelSelectSheet(context),
                        onLongPressSelectModel: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ProvidersPage()),
                          );
                        },
                        onOpenMcp: () {
                          final a = context.read<AssistantProvider>().currentAssistant;
                          if (a != null) {
                            showAssistantMcpSheet(context, assistantId: a.id);
                          }
                        },
                        onLongPressMcp: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const McpPage()),
                          );
                        },
                        onStop: _cancelStreaming,
                        modelIcon: (settings.showModelIcon && ((a?.chatModelProvider ?? settings.currentModelProvider) != null) && ((a?.chatModelId ?? settings.currentModelId) != null))
                            ? _CurrentModelIcon(
                                providerKey: a?.chatModelProvider ?? settings.currentModelProvider,
                                modelId: a?.chatModelId ?? settings.currentModelId,
                                size: 40,
                                withBackground: true,
                                backgroundColor: Colors.transparent,
                              )
                            : null,
                        focusNode: _inputFocus,
                        controller: _inputController,
                        mediaController: _mediaController,
                        onConfigureReasoning: () async {
                          final assistant = context.read<AssistantProvider>().currentAssistant;
                          if (assistant != null) {
                            if (assistant.thinkingBudget != null) {
                              context.read<SettingsProvider>().setThinkingBudget(assistant.thinkingBudget);
                            }
                            await showReasoningBudgetSheet(context);
                            final chosen = context.read<SettingsProvider>().thinkingBudget;
                            await context.read<AssistantProvider>().updateAssistant(
                              assistant.copyWith(thinkingBudget: chosen),
                            );
                          }
                        },
                        reasoningActive: _isReasoningEnabled((context.watch<AssistantProvider>().currentAssistant?.thinkingBudget) ?? settings.thinkingBudget),
                        supportsReasoning: (pk != null && mid != null)
                            ? _isReasoningModel(pk, mid)
                            : false,
                        onOpenSearch: () => showSearchSettingsSheet(context),
                        onSend: (text) {
                          _sendMessage(text);
                          _inputController.clear();
                          // Dismiss keyboard after sending
                          _dismissKeyboard();
                        },
                        loading: _isCurrentConversationLoading,
                        showMcpButton: (() {
                          final pk2 = a?.chatModelProvider ?? settings.currentModelProvider;
                          final mid3 = a?.chatModelId ?? settings.currentModelId;
                          if (pk2 == null || mid3 == null) return false;
                          return _isToolModel(pk2, mid3) && context.watch<McpProvider>().servers.isNotEmpty;
                        })(),
                        mcpActive: (() {
                          final a = context.watch<AssistantProvider>().currentAssistant;
                          final connected = context.watch<McpProvider>().connectedServers;
                          final selected = a?.mcpServerIds ?? const <String>[];
                          if (selected.isEmpty || connected.isEmpty) return false;
                          return connected.any((s) => selected.contains(s.id));
                        })(),
                        showQuickPhraseButton: (() {
                          final assistant = context.watch<AssistantProvider>().currentAssistant;
                          final quickPhraseProvider = context.watch<QuickPhraseProvider>();
                          final globalCount = quickPhraseProvider.globalPhrases.length;
                          final assistantCount = assistant != null
                              ? quickPhraseProvider.getForAssistant(assistant.id).length
                              : 0;
                          return (globalCount + assistantCount) > 0;
                        })(),
                        onQuickPhrase: _showQuickPhraseMenu,
                        onLongPressQuickPhrase: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const QuickPhrasesPage()),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
            ),
          ),

          // // iOS-style blur/fade effect above input area
          // Positioned(
          //   left: 0,
          //   right: 0,
          //   bottom: _inputBarHeight,
          //   child: IgnorePointer(
          //     child: Container(
          //       height: 20,
          //       decoration: BoxDecoration(
          //         gradient: LinearGradient(
          //           begin: Alignment.topCenter,
          //           end: Alignment.bottomCenter,
          //           colors: [
          //             Theme.of(context).colorScheme.background.withOpacity(0.0),
          //             Theme.of(context).colorScheme.background.withOpacity(0.8),
          //             Theme.of(context).colorScheme.background.withOpacity(1.0),
          //           ],
          //           stops: const [0.0, 0.6, 1.0],
          //         ),
          //       ),
          //     ),
          //   ),
          // ),

          // Inline tools sheet removed; replaced by modal bottom sheet

          // Selection toolbar overlay (above input bar)
          if (_selecting)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 72),
                  child: _SelectionToolbar(
                    onCancel: () {
                      setState(() {
                        _selecting = false;
                        _selectedItems.clear();
                      });
                    },
                    onConfirm: () async {
                      final convo = _currentConversation;
                      if (convo == null) return;
                      final collapsed = _collapseVersions(_messages);
                      final selected = <ChatMessage>[];
                      for (final m in collapsed) {
                        if (_selectedItems.contains(m.id)) selected.add(m);
                      }
                      if (selected.isEmpty) {
                        final l10n = AppLocalizations.of(context)!;
                        showAppSnackBar(
                          context,
                          message: l10n.homePageSelectMessagesToShare,
                          type: NotificationType.info,
                        );
                        return;
                      }
                      setState(() { _selecting = false; });
                      await showChatExportSheet(context, conversation: convo, selectedMessages: selected);
                      if (mounted) setState(() { _selectedItems.clear(); });
                    },
                  ),
                ),
              ),
            ),

          // Scroll-to-bottom button (bottom-right, above input bar)
          Builder(builder: (context) {
            final showSetting = context.watch<SettingsProvider>().showMessageNavButtons;
            // Hide nav button in brand-new chats with no messages
            if (!showSetting || _messages.isEmpty) return const SizedBox.shrink();
            final cs = Theme.of(context).colorScheme;
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final bottomOffset = _inputBarHeight + 12;
            return Align(
              alignment: Alignment.bottomRight,
              child: SafeArea(
                top: false,
                bottom: false, // avoid double bottom inset so button hugs input bar
                child: IgnorePointer(
                  ignoring: !_showJumpToBottom,
                  child: AnimatedScale(
                    scale: _showJumpToBottom ? 1.0 : 0.9,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      opacity: _showJumpToBottom ? 1 : 0,
                      child: Padding(
                        padding: EdgeInsets.only(right: 16, bottom: bottomOffset),
                        child: ClipOval(
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withOpacity(0.06)
                                    : Colors.white.withOpacity(0.07),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.10)
                                      : Theme.of(context).colorScheme.outline.withOpacity(0.20),
                                  width: 1,
                                ),
                              ),
                              child: Material(
                                type: MaterialType.transparency,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: _forceScrollToBottom,
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Icon(
                                      Lucide.ChevronDown,
                                      size: 16,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    ),
                  ),
                ),
            );
          }),

          // Scroll-to-previous-question button (stacked above the bottom button)
          Builder(builder: (context) {
            final showSetting = context.watch<SettingsProvider>().showMessageNavButtons;
            if (!showSetting || _messages.isEmpty) return const SizedBox.shrink();
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final bottomOffset = _inputBarHeight + 12 + 52; // place above the bottom button with gap
            // Visibility follows the same logic as the bottom button (hide at bottom)
            final showUp = _showJumpToBottom;
            return Align(
              alignment: Alignment.bottomRight,
              child: SafeArea(
                top: false,
                bottom: false,
                child: IgnorePointer(
                  ignoring: !showUp,
                  child: AnimatedScale(
                    scale: showUp ? 1.0 : 0.9,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      opacity: showUp ? 1 : 0,
                      child: Padding(
                        padding: EdgeInsets.only(right: 16, bottom: bottomOffset),
                        child: ClipOval(
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withOpacity(0.06)
                                    : Colors.white.withOpacity(0.07),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.10)
                                      : Theme.of(context).colorScheme.outline.withOpacity(0.20),
                                  width: 1,
                                ),
                              ),
                              child: Material(
                                type: MaterialType.transparency,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: _jumpToPreviousQuestion,
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Icon(
                                      Lucide.ChevronUp,
                                      size: 16,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    ),
                  ),
                ),
            );
          }),
        ],
        ),
      ),
      );
  }

  Widget _buildTabletLayout(
    BuildContext context, {
    required String title,
    required String? providerName,
    required String? modelDisplay,
    required ColorScheme cs,
  }) {
    return Stack(
      children: [
        Positioned.fill(child: _buildAssistantBackground(context)),
        SizedBox.expand(
      child: Row(
      children: [
        _buildTabletSidebar(context),
        AnimatedContainer(
          duration: _sidebarAnimDuration,
          curve: _sidebarAnimCurve,
          width: _tabletSidebarOpen ? 0.6 : 0,
          child: _tabletSidebarOpen
              ? const VerticalDivider(width: 0.6, thickness: 0.5)
              : const SizedBox.shrink(),
        ),
        Expanded(
          child: Scaffold(
            key: _scaffoldKey,
            resizeToAvoidBottomInset: true,
            extendBodyBehindAppBar: true,
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              systemOverlayStyle: (Theme.of(context).brightness == Brightness.dark)
                  ? const SystemUiOverlayStyle(
                      statusBarColor: Colors.transparent,
                      statusBarIconBrightness: Brightness.light,
                      statusBarBrightness: Brightness.dark,
                    )
                  : const SystemUiOverlayStyle(
                      statusBarColor: Colors.transparent,
                      statusBarIconBrightness: Brightness.dark,
                      statusBarBrightness: Brightness.light,
                    ),
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                onPressed: _toggleTabletSidebar,
                icon: SvgPicture.asset(
                  'assets/icons/list.svg',
                  width: 14,
                  height: 14,
                  colorFilter: ColorFilter.mode(
                    Theme.of(context).iconTheme.color ?? Theme.of(context).colorScheme.onSurface,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              titleSpacing: 2,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedTextSwap(
                    text: title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  if (providerName != null && modelDisplay != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => showModelSelectSheet(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 0),
                          child: AnimatedTextSwap(
                            text: '$modelDisplay ($providerName)',
                            style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.6), fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                IconButton(
                  onPressed: () async {
                    await _createNewConversation();
                    if (mounted) _forceScrollToBottomSoon();
                  },
                  icon: const Icon(Lucide.MessageCirclePlus, size: 22),
                ),
                const SizedBox(width: 6),
              ],
            ),
            body: Stack(
              children: [

                Padding(
                  padding: EdgeInsets.only(top: kToolbarHeight + MediaQuery.of(context).padding.top),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: Column(
                        children: [
                          // Message list (add subtle animate on conversation switch)
                          Expanded(
                            child: FadeTransition(
                              opacity: _convoFade,
                              child: KeyedSubtree(
                                key: ValueKey<String>(_currentConversation?.id ?? 'none'),
                                child: (() {
                                  final messages = _collapseVersions(_messages);
                                  final Map<String, List<ChatMessage>> byGroup = <String, List<ChatMessage>>{};
                                  for (final m in _messages) {
                                    final gid = (m.groupId ?? m.id);
                                    byGroup.putIfAbsent(gid, () => <ChatMessage>[]).add(m);
                                  }
                                  // Map persisted truncateIndex (raw) to collapsed index
                                  final int truncRaw = _currentConversation?.truncateIndex ?? -1;
                                  int truncCollapsed = -1;
                                  if (truncRaw > 0) {
                                    final seen = <String>{};
                                    final int limit = truncRaw < _messages.length ? truncRaw : _messages.length;
                                    int count = 0;
                                    for (int i = 0; i < limit; i++) {
                                      final gid0 = (_messages[i].groupId ?? _messages[i].id);
                                      if (seen.add(gid0)) count++;
                                    }
                                    truncCollapsed = count - 1;
                                  }
                                  return ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.only(bottom: 16, top: 8),
                                    itemCount: messages.length,
                                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                                    itemBuilder: (context, index) {
                                      if (index < 0 || index >= messages.length) return const SizedBox.shrink();
                                      final message = messages[index];
                                      final r = _reasoning[message.id];
                                      final t = _translations[message.id];
                                      final chatScale = context.watch<SettingsProvider>().chatFontScale;
                                      final assistant = context.watch<AssistantProvider>().currentAssistant;
                                      final useAssist = assistant?.useAssistantAvatar == true;
                                      final l10n = AppLocalizations.of(context)!;
                                      final showDivider = truncCollapsed >= 0 && index == truncCollapsed;
                                      final cs = Theme.of(context).colorScheme;
                                      final label = l10n.homePageClearContext;
                                      final divider = Row(
                                        children: [
                                          Expanded(child: Divider(color: cs.outlineVariant.withOpacity(0.6), height: 1, thickness: 1)),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                            child: Text(label, style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.6))),
                                          ),
                                          Expanded(child: Divider(color: cs.outlineVariant.withOpacity(0.6), height: 1, thickness: 1)),
                                        ],
                                      );
                                      final gid = (message.groupId ?? message.id);
                                      final vers = (byGroup[gid] ?? const <ChatMessage>[]).toList()..sort((a,b)=>a.version.compareTo(b.version));
                                      final selectedIdx = _versionSelections[gid] ?? (vers.isNotEmpty ? vers.length - 1 : 0);
                                      final total = vers.length;
                                      final showMsgNav = context.watch<SettingsProvider>().showMessageNavButtons;
                                      final effectiveTotal = showMsgNav ? total : 1;
                                      final effectiveIndex = showMsgNav ? selectedIdx : 0;

                                      return Column(
                                        key: _keyForMessage(message.id),
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (_selecting && (message.role == 'user' || message.role == 'assistant'))
                                                Padding(
                                                  padding: const EdgeInsets.only(left: 10, right: 6),
                                                  child: IosCheckbox(
                                                    value: _selectedItems.contains(message.id),
                                                    onChanged: (v) {
                                                      setState(() {
                                                        if (v) {
                                                          _selectedItems.add(message.id);
                                                        } else {
                                                          _selectedItems.remove(message.id);
                                                        }
                                                      });
                                                    },
                                                  ),
                                                ),
                                              Expanded(
                                                child: MediaQuery(
                                                  data: MediaQuery.of(context).copyWith(
                                                    textScaleFactor: MediaQuery.of(context).textScaleFactor * chatScale,
                                                  ),
                                                  child: ChatMessageWidget(
                                                    message: message,
                                                    versionIndex: effectiveIndex,
                                                    versionCount: effectiveTotal,
                                                    onPrevVersion: (showMsgNav && selectedIdx > 0)
                                                        ? () async {
                                                            final next = selectedIdx - 1;
                                                            _versionSelections[gid] = next;
                                                            await _chatService.setSelectedVersion(_currentConversation!.id, gid, next);
                                                            if (mounted) setState(() {});
                                                          }
                                                        : null,
                                                    onNextVersion: (showMsgNav && selectedIdx < total - 1)
                                                        ? () async {
                                                            final next = selectedIdx + 1;
                                                            _versionSelections[gid] = next;
                                                            await _chatService.setSelectedVersion(_currentConversation!.id, gid, next);
                                                            if (mounted) setState(() {});
                                                          }
                                                        : null,
                                                    modelIcon: (!useAssist && message.role == 'assistant' && message.providerId != null && message.modelId != null)
                                                        ? _CurrentModelIcon(providerKey: message.providerId, modelId: message.modelId, size: 30)
                                                        : null,
                                                    showModelIcon: useAssist ? false : context.watch<SettingsProvider>().showModelIcon,
                                                    useAssistantAvatar: useAssist && message.role == 'assistant',
                                                    assistantName: useAssist ? (assistant?.name ?? 'Assistant') : null,
                                                    assistantAvatar: useAssist ? (assistant?.avatar ?? '') : null,
                                                    showUserAvatar: context.watch<SettingsProvider>().showUserAvatar,
                                                    showTokenStats: context.watch<SettingsProvider>().showTokenStats,
                                                    reasoningText: (message.role == 'assistant') ? (r?.text ?? '') : null,
                                                    reasoningExpanded: (message.role == 'assistant') ? (r?.expanded ?? false) : false,
                                                    reasoningLoading: (message.role == 'assistant') ? (r?.finishedAt == null && (r?.text.isNotEmpty == true)) : false,
                                                    reasoningStartAt: (message.role == 'assistant') ? r?.startAt : null,
                                                    reasoningFinishedAt: (message.role == 'assistant') ? r?.finishedAt : null,
                                                    onToggleReasoning: (message.role == 'assistant' && r != null)
                                                        ? () {
                                                            setState(() {
                                                              r.expanded = !r.expanded;
                                                            });
                                                          }
                                                        : null,
                                                    translationExpanded: t?.expanded ?? true,
                                                    onToggleTranslation: (message.translation != null && message.translation!.isNotEmpty && t != null)
                                                        ? () {
                                                            setState(() {
                                                              t.expanded = !t.expanded;
                                                            });
                                                          }
                                                        : null,
                                                    onRegenerate: message.role == 'assistant' ? () { _regenerateAtMessage(message); } : null,
                                                    onResend: message.role == 'user' ? () { _regenerateAtMessage(message); } : null,
                                                    onTranslate: message.role == 'assistant' ? () { _translateMessage(message); } : null,
                                                    onSpeak: message.role == 'assistant'
                                                        ? () async {
                                                            final tts = context.read<TtsProvider>();
                                                            if (!tts.isSpeaking) {
                                                              await tts.speak(message.content);
                                                            } else {
                                                              await tts.stop();
                                                            }
                                                          }
                                                        : null,
                                                    onEdit: message.role == 'user'
                                                        ? () async {
                                                            final edited = await Navigator.of(context).push<String>(
                                                              MaterialPageRoute(builder: (_) => MessageEditPage(message: message)),
                                                            );
                                                            if (edited != null) {
                                                              final newMsg = await _chatService.appendMessageVersion(messageId: message.id, content: edited);
                                                              if (!mounted) return;
                                                              setState(() {
                                                                if (newMsg != null) {
                                                                  _messages.add(newMsg);
                                                                  final gid2 = (newMsg.groupId ?? newMsg.id);
                                                                  _versionSelections[gid2] = newMsg.version;
                                                                }
                                                              });
                                                              try {
                                                                if (newMsg != null && _currentConversation != null) {
                                                                  final gid2 = (newMsg.groupId ?? newMsg.id);
                                                                  await _chatService.setSelectedVersion(_currentConversation!.id, gid2, newMsg.version);
                                                                }
                                                              } catch (_) {}
                                                            }
                                                          }
                                                        : null,
                                                    onDelete: message.role == 'user'
                                                        ? () async {
                                                            final l10n = AppLocalizations.of(context)!;
                                                            final confirm = await showDialog<bool>(
                                                              context: context,
                                                              builder: (ctx) => AlertDialog(
                                                                title: Text(l10n.homePageDeleteMessage),
                                                                content: Text(l10n.homePageDeleteMessageConfirm),
                                                                actions: [
                                                                  TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l10n.homePageCancel)),
                                                                  TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l10n.homePageDelete, style: const TextStyle(color: Colors.red))),
                                                                ],
                                                              ),
                                                            );
                                                            if (confirm == true) {
                                                              final id = message.id;
                                                              setState(() {
                                                                _messages.removeWhere((m) => m.id == id);
                                                                _reasoning.remove(id);
                                                                _translations.remove(id);
                                                                _toolParts.remove(id);
                                                                _reasoningSegments.remove(id);
                                                              });
                                                              await _chatService.deleteMessage(id);
                                                            }
                                                          }
                                                        : null,
                                                    onMore: () async {
                                                      final action = await showMessageMoreSheet(context, message);
                                                      if (!mounted) return;
                                                      if (action == MessageMoreAction.delete) {
                                                        final l10n = AppLocalizations.of(context)!;
                                                        final confirm = await showDialog<bool>(
                                                          context: context,
                                                          builder: (ctx) => AlertDialog(
                                                            title: Text(l10n.homePageDeleteMessage),
                                                            content: Text(l10n.homePageDeleteMessageConfirm),
                                                            actions: [
                                                              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l10n.homePageCancel)),
                                                              TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l10n.homePageDelete, style: const TextStyle(color: Colors.red))),
                                                            ],
                                                          ),
                                                        );
                                                        if (confirm == true) {
                                                          final id = message.id;
                                                          setState(() {
                                                            _messages.removeWhere((m) => m.id == id);
                                                            _reasoning.remove(id);
                                                            _translations.remove(id);
                                                            _toolParts.remove(id);
                                                            _reasoningSegments.remove(id);
                                                          });
                                                          await _chatService.deleteMessage(id);
                                                        }
                                                      } else if (action == MessageMoreAction.edit) {
                                                        final edited = await Navigator.of(context).push<String>(
                                                          MaterialPageRoute(builder: (_) => MessageEditPage(message: message)),
                                                        );
                                                        if (edited != null) {
                                                          final newMsg = await _chatService.appendMessageVersion(messageId: message.id, content: edited);
                                                          if (!mounted) return;
                                                          setState(() {
                                                            if (newMsg != null) {
                                                              _messages.add(newMsg);
                                                              final gid = (newMsg.groupId ?? newMsg.id);
                                                              _versionSelections[gid] = newMsg.version;
                                                            }
                                                          });
                                                          try {
                                                            if (newMsg != null && _currentConversation != null) {
                                                              final gid = (newMsg.groupId ?? newMsg.id);
                                                              await _chatService.setSelectedVersion(_currentConversation!.id, gid, newMsg.version);
                                                            }
                                                          } catch (_) {}
                                                        }
                                                      } else if (action == MessageMoreAction.fork) {
                                                        // Determine included groups up to the message's group (inclusive)
                                                        final Map<String, int> groupFirstIndex = <String, int>{};
                                                        final List<String> groupOrder = <String>[];
                                                        for (int i = 0; i < _messages.length; i++) {
                                                          final gid0 = (_messages[i].groupId ?? _messages[i].id);
                                                          if (!groupFirstIndex.containsKey(gid0)) {
                                                            groupFirstIndex[gid0] = i;
                                                            groupOrder.add(gid0);
                                                          }
                                                        }
                                                        final targetGroup = (message.groupId ?? message.id);
                                                        final targetOrderIndex = groupOrder.indexOf(targetGroup);
                                                        if (targetOrderIndex >= 0) {
                                                          final includeGroups = groupOrder.take(targetOrderIndex + 1).toSet();
                                                          final selected = [
                                                            for (final m in _messages)
                                                              if (includeGroups.contains(m.groupId ?? m.id)) m
                                                          ];
                                                          // Filter version selections to included groups
                                                          final sel = <String, int>{};
                                                          for (final gid in includeGroups) {
                                                            final v = _versionSelections[gid];
                                                            if (v != null) sel[gid] = v;
                                                          }
                                                          final newConvo = await _chatService.forkConversation(
                                                            title: _titleForLocale(context),
                                                            assistantId: _currentConversation?.assistantId,
                                                            sourceMessages: selected,
                                                            versionSelections: sel,
                                                          );
                                    // Switch to the new conversation with fade animation
                                    if (!mounted) return;
                                    await _convoFadeController.reverse();
                                    _chatService.setCurrentConversation(newConvo.id);
                                    final msgs = _chatService.getMessages(newConvo.id);
                                    if (!mounted) return;
                                    setState(() {
                                      _currentConversation = newConvo;
                                      _messages = List.of(msgs);
                                      _loadVersionSelections();
                                      _restoreMessageUiState();
                                    });
                                    try { await WidgetsBinding.instance.endOfFrame; } catch (_) {}
                                    _scrollToBottom();
                                    await _convoFadeController.forward();
                                                        }
                                                      } else if (action == MessageMoreAction.share) {
                                                        setState(() {
                                                          _selecting = true;
                                                          _selectedItems.clear();
                                                          final idx = messages.indexWhere((m) => m.id == message.id);
                                                          for (int i = 0; i <= idx && i < messages.length; i++) {
                                                            final m = messages[i];
                                                            final enabled0 = (m.role == 'user' || m.role == 'assistant');
                                                            if (enabled0) _selectedItems.add(m.id);
                                                          }
                                                        });
                                                      } else if (action == null) {
                                                        // do nothing
                                                      } else {
                                                        // Select action (legacy string)
                                                        setState(() {
                                                          _selecting = true;
                                                          _selectedItems.add(message.id);
                                                        });
                                                      }
                                                    },
                                                    // Ensure tool call/search/citation cards render on tablets too
                                                    toolParts: message.role == 'assistant' ? _toolParts[message.id] : null,
                                                    reasoningSegments: message.role == 'assistant'
                                                        ? (() {
                                                            final segments = _reasoningSegments[message.id];
                                                            if (segments == null || segments.isEmpty) return null;
                                                            return segments
                                                                .map((s) => ReasoningSegment(
                                                                      text: s.text,
                                                                      expanded: s.expanded,
                                                                      loading: s.finishedAt == null && s.text.isNotEmpty,
                                                                      startAt: s.startAt,
                                                                      finishedAt: s.finishedAt,
                                                                      onToggle: () {
                                                                        setState(() {
                                                                          s.expanded = !s.expanded;
                                                                        });
                                                                      },
                                                                      toolStartIndex: s.toolStartIndex,
                                                                    ))
                                                                .toList();
                                                          })()
                                                        : null,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (showDivider)
                                            Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12), child: divider),
                                        ],
                                      );
                                    },
                                  );
                                })(),
                              ).animate(key: ValueKey('tab_body_'+(_currentConversation?.id ?? 'none')))
                               .fadeIn(duration: 200.ms, curve: Curves.easeOutCubic),
                               // .slideY(begin: 0.02, end: 0, duration: 240.ms, curve: Curves.easeOutCubic),
                            ),
                          ),

                          // Input bar with max width
                          NotificationListener<SizeChangedLayoutNotification>(
                            onNotification: (n) {
                              WidgetsBinding.instance.addPostFrameCallback((_) => _measureInputBar());
                              return false;
                            },
                            child: SizeChangedLayoutNotifier(
                              child: Builder(
                                builder: (context) {
                                  final settings = context.watch<SettingsProvider>();
                                  final ap = context.watch<AssistantProvider>();
                                  final a = ap.currentAssistant;
                                  final pk = a?.chatModelProvider ?? settings.currentModelProvider;
                                  final mid = a?.chatModelId ?? settings.currentModelId;
                                  if (pk != null && mid != null) {
                                    final supportsTools = _isToolModel(pk, mid);
                                    if (!supportsTools && (a?.mcpServerIds.isNotEmpty ?? false)) {
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        final aa = ap.currentAssistant;
                                        if (aa != null && aa.mcpServerIds.isNotEmpty) {
                                          ap.updateAssistant(aa.copyWith(mcpServerIds: const <String>[]));
                                        }
                                      });
                                    }
                                    final supportsReasoning = _isReasoningModel(pk, mid);
                                    if (!supportsReasoning && a != null) {
                                      final enabledNow = _isReasoningEnabled(a.thinkingBudget ?? settings.thinkingBudget);
                                      if (enabledNow) {
                                        WidgetsBinding.instance.addPostFrameCallback((_) async {
                                          final aa = ap.currentAssistant;
                                          if (aa != null) {
                                            await ap.updateAssistant(aa.copyWith(thinkingBudget: 0));
                                          }
                                        });
                                      }
                                    }
                                  }
                                  final currentProvider = a?.chatModelProvider ?? settings.currentModelProvider;
                                  final currentModelId = a?.chatModelId ?? settings.currentModelId;
                                  final cfg = (currentProvider != null) ? settings.getProviderConfig(currentProvider) : null;
                                  bool builtinSearchActive = false;
                                  if (cfg != null && currentModelId != null) {
                                    final mid2 = currentModelId;
                                    final isGeminiOfficial = cfg.providerType == ProviderKind.google && (cfg.vertexAI != true);
                                    final isClaude = cfg.providerType == ProviderKind.claude;
                                    final isOpenAIResponses = cfg.providerType == ProviderKind.openai && (cfg.useResponseApi == true);
                                    if (isGeminiOfficial || isClaude || isOpenAIResponses) {
                                      final ov = cfg.modelOverrides[mid2] as Map?;
                                      final list = (ov?['builtInTools'] as List?) ?? const <dynamic>[];
                                      builtinSearchActive = list.map((e) => e.toString().toLowerCase()).contains('search');
                                    }
                                  }

                                  Widget input = ChatInputBar(
                                    key: _inputBarKey,
                                    onMore: _toggleTools,
                                    searchEnabled: context.watch<SettingsProvider>().searchEnabled || builtinSearchActive,
                                    onToggleSearch: (enabled) {
                                      context.read<SettingsProvider>().setSearchEnabled(enabled);
                                    },
                                    onSelectModel: () => showModelSelectSheet(context),
                                    onLongPressSelectModel: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => const ProvidersPage()),
                                      );
                                    },
                                    onOpenMcp: () {
                                      final a = context.read<AssistantProvider>().currentAssistant;
                                      if (a != null) {
                                        showAssistantMcpSheet(context, assistantId: a.id);
                                      }
                                    },
                                    onLongPressMcp: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => const McpPage()),
                                      );
                                    },
                                    // Quick Phrase button (tablet): show to the right of MCP
                                    showQuickPhraseButton: (() {
                                      final assistant = context.watch<AssistantProvider>().currentAssistant;
                                      final quickPhraseProvider = context.watch<QuickPhraseProvider>();
                                      final globalCount = quickPhraseProvider.globalPhrases.length;
                                      final assistantCount = assistant != null
                                          ? quickPhraseProvider.getForAssistant(assistant.id).length
                                          : 0;
                                      return (globalCount + assistantCount) > 0;
                                    })(),
                                    onQuickPhrase: _showQuickPhraseMenu,
                                    onLongPressQuickPhrase: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => const QuickPhrasesPage()),
                                      );
                                    },
                                    showMiniMapButton: true,
                                    onOpenMiniMap: () async {
                                      final collapsed = _collapseVersions(_messages);
                                      final selectedId = await showMiniMapSheet(context, collapsed);
                                      if (selectedId != null && selectedId.isNotEmpty) {
                                        await _scrollToMessageId(selectedId);
                                      }
                                    },
                                    onPickCamera: _onPickCamera,
                                    onPickPhotos: _onPickPhotos,
                                    onUploadFiles: _onPickFiles,
                                    onToggleLearningMode: () async {
                                      final enabled = await LearningModeStore.isEnabled();
                                      await LearningModeStore.setEnabled(!enabled);
                                      if (mounted) setState(() => _learningModeEnabled = !enabled);
                                    },
                                    onLongPressLearning: _showLearningPromptSheet,
                                    learningModeActive: _learningModeEnabled,
                                    showMoreButton: false,
                                    onClearContext: _onClearContext,
                                    onStop: _cancelStreaming,
                                    modelIcon: (settings.showModelIcon && ((a?.chatModelProvider ?? settings.currentModelProvider) != null) && ((a?.chatModelId ?? settings.currentModelId) != null))
                                        ? _CurrentModelIcon(
                                            providerKey: a?.chatModelProvider ?? settings.currentModelProvider,
                                            modelId: a?.chatModelId ?? settings.currentModelId,
                                            size: 40,
                                            withBackground: true,
                                            backgroundColor: Colors.transparent,
                                          )
                                        : null,
                                    focusNode: _inputFocus,
                                    controller: _inputController,
                                    mediaController: _mediaController,
                                    onConfigureReasoning: () async {
                                      final assistant = context.read<AssistantProvider>().currentAssistant;
                                      if (assistant != null) {
                                        if (assistant.thinkingBudget != null) {
                                          context.read<SettingsProvider>().setThinkingBudget(assistant.thinkingBudget);
                                        }
                                        await showReasoningBudgetSheet(context);
                                        final chosen = context.read<SettingsProvider>().thinkingBudget;
                                        await context.read<AssistantProvider>().updateAssistant(
                                          assistant.copyWith(thinkingBudget: chosen),
                                        );
                                      }
                                    },
                                    reasoningActive: _isReasoningEnabled((context.watch<AssistantProvider>().currentAssistant?.thinkingBudget) ?? settings.thinkingBudget),
                                    supportsReasoning: (pk != null && mid != null) ? _isReasoningModel(pk, mid) : false,
                                    onOpenSearch: () => showSearchSettingsSheet(context),
                                    onSend: (text) {
                                      _sendMessage(text);
                                      _inputController.clear();
                                      _dismissKeyboard();
                                    },
                                    loading: _isCurrentConversationLoading,
                                    showMcpButton: (() {
                                      final pk2 = a?.chatModelProvider ?? settings.currentModelProvider;
                                      final mid3 = a?.chatModelId ?? settings.currentModelId;
                                      if (pk2 == null || mid3 == null) return false;
                                      return _isToolModel(pk2, mid3) && context.watch<McpProvider>().servers.isNotEmpty;
                                    })(),
                                    mcpActive: (() {
                                      final a = context.watch<AssistantProvider>().currentAssistant;
                                      final connected = context.watch<McpProvider>().connectedServers;
                                      final selected = a?.mcpServerIds ?? const <String>[];
                                      if (selected.isEmpty || connected.isEmpty) return false;
                                      return connected.any((s) => selected.contains(s.id));
                                    })(),
                                  );

                                  input = Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 800),
                                      child: input,
                                    ),
                                  );
                                  return input;
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Selection toolbar overlay
                if (_selecting)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 72),
                        child: _SelectionToolbar(
                          onCancel: () {
                            setState(() {
                              _selecting = false;
                              _selectedItems.clear();
                            });
                          },
                          onConfirm: () async {
                            final convo = _currentConversation;
                            if (convo == null) return;
                            final collapsed = _collapseVersions(_messages);
                            final selected = <ChatMessage>[];
                            for (final m in collapsed) {
                              if (_selectedItems.contains(m.id)) selected.add(m);
                            }
                            if (selected.isEmpty) {
                              final l10n = AppLocalizations.of(context)!;
                              showAppSnackBar(
                                context,
                                message: l10n.homePageSelectMessagesToShare,
                                type: NotificationType.info,
                              );
                              return;
                            }
                            setState(() { _selecting = false; });
                            await showChatExportSheet(context, conversation: convo, selectedMessages: selected);
                            if (mounted) setState(() { _selectedItems.clear(); });
                          },
                        ),
                      ),
                    ),
                  ),

                // Scroll-to-bottom button
                Builder(builder: (context) {
                  final showSetting = context.watch<SettingsProvider>().showMessageNavButtons;
                  if (!showSetting || _messages.isEmpty) return const SizedBox.shrink();
                  final cs = Theme.of(context).colorScheme;
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  final bottomOffset = _inputBarHeight + 12;
                  return Align(
                    alignment: Alignment.bottomRight,
                    child: SafeArea(
                      top: false,
                      bottom: false,
                      child: IgnorePointer(
                        ignoring: !_showJumpToBottom,
                        child: AnimatedScale(
                          scale: _showJumpToBottom ? 1.0 : 0.9,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            opacity: _showJumpToBottom ? 1 : 0,
                            child: Padding(
                              padding: EdgeInsets.only(right: 16, bottom: bottomOffset),
                              child: ClipOval(
                                child: BackdropFilter(
                                  filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withOpacity(0.06)
                                          : Colors.white.withOpacity(0.07),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.white.withOpacity(0.10)
                                            : Theme.of(context).colorScheme.outline.withOpacity(0.20),
                                        width: 1,
                                      ),
                                    ),
                                    child: Material(
                                      type: MaterialType.transparency,
                                      shape: const CircleBorder(),
                                      child: InkWell(
                                        customBorder: const CircleBorder(),
                                        onTap: _forceScrollToBottom,
                                        child: Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Icon(
                                            Lucide.ChevronDown,
                                            size: 18,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),

                // Scroll-to-previous-question button
                Builder(builder: (context) {
                  final showSetting = context.watch<SettingsProvider>().showMessageNavButtons;
                  if (!showSetting || _messages.isEmpty) return const SizedBox.shrink();
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  final bottomOffset = _inputBarHeight + 12 + 52;
                  final showUp = _showJumpToBottom;
                  return Align(
                    alignment: Alignment.bottomRight,
                    child: SafeArea(
                      top: false,
                      bottom: false,
                      child: IgnorePointer(
                        ignoring: !showUp,
                        child: AnimatedScale(
                          scale: showUp ? 1.0 : 0.9,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            opacity: showUp ? 1 : 0,
                            child: Padding(
                              padding: EdgeInsets.only(right: 16, bottom: bottomOffset),
                              child: ClipOval(
                                child: BackdropFilter(
                                  filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white12 : Colors.black.withOpacity(0.06),
                                      border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.20)),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Material(
                                      type: MaterialType.transparency,
                                      shape: const CircleBorder(),
                                      child: InkWell(
                                        customBorder: const CircleBorder(),
                                        onTap: _jumpToPreviousQuestion,
                                        child: Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Icon(
                                            Lucide.ChevronUp,
                                            size: 18,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    ),
    ),
  ],
);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _convoFadeController.dispose();
    _mcpProvider?.removeListener(_onMcpChanged);
    // Remove drawer value listener
    _drawerController.removeListener(_onDrawerValueChanged);
    _inputFocus.dispose();
    _inputController.dispose();
    _scrollController.removeListener(_onScrollControllerChanged);
    _scrollController.dispose();
    try {
      for (final s in _conversationStreams.values) { s.cancel(); }
    } catch (_) {}
    _conversationStreams.clear();
    _userScrollTimer?.cancel();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  void _triggerConversationFade() {
    try {
      _convoFadeController.stop();
      _convoFadeController.value = 0;
      _convoFadeController.forward();
    } catch (_) {}
  }

  @override
  void didPushNext() {
    // Navigating away: drop focus so it won't be restored.
    _dismissKeyboard();
  }

  @override
  void didPopNext() {
    // Returning to this page: ensure keyboard stays closed unless user taps.
    WidgetsBinding.instance.addPostFrameCallback((_) => _dismissKeyboard());
  }
}

class _ReasoningData {
  String text = '';
  DateTime? startAt;
  DateTime? finishedAt;
  bool expanded = false;
}

class _ReasoningSegmentData {
  String text = '';
  DateTime? startAt;
  DateTime? finishedAt;
  bool expanded = true;
  int toolStartIndex = 0;
}

class _TranslationData {
  bool expanded = true; // default to expanded when translation is added
}

class _CurrentModelIcon extends StatelessWidget {
  const _CurrentModelIcon({
    required this.providerKey,
    required this.modelId,
    this.size = 28,
    this.withBackground = true,
    this.backgroundColor,
  });
  final String? providerKey;
  final String? modelId;
  final double size; // outer diameter
  final bool withBackground; // whether to draw circular background
  final Color? backgroundColor; // override background color if provided


  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (providerKey == null || modelId == null) return const SizedBox.shrink();
    String? asset = BrandAssets.assetForName(modelId!);
    asset ??= BrandAssets.assetForName(providerKey!);
    Widget inner;
    if (asset != null) {
      if (asset.endsWith('.svg')) {
        final isColorful = asset.contains('color');
        final ColorFilter? tint = (Theme.of(context).brightness == Brightness.dark && !isColorful)
            ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
            : null;
        inner = SvgPicture.asset(
          asset,
          width: size * 0.5,
          height: size * 0.5,
          colorFilter: tint,
        );
      } else {
        inner = Image.asset(asset, width: size * 0.5, height: size * 0.5, fit: BoxFit.contain);
      }
    } else {
      inner = Text(
        modelId!.isNotEmpty ? modelId!.characters.first.toUpperCase() : '?',
        style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700, fontSize: size * 0.43),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: withBackground
            ? (backgroundColor ?? (isDark ? Colors.white10 : cs.primary.withOpacity(0.1)))
            : Colors.transparent,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: SizedBox(
        width: size * 0.64,
        height: size * 0.64,
        child: Center(child: inner is SvgPicture || inner is Image ? inner : FittedBox(child: inner)),
      ),
    );
  }
}

class _SelectionToolbar extends StatelessWidget {
  const _SelectionToolbar({required this.onCancel, required this.onConfirm});
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6)),
        ],
        border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Lucide.X, size: 16),
            onPressed: onCancel,
            label: Text(l10n.homePageCancel),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            icon: const Icon(Lucide.Check, size: 16),
            onPressed: onConfirm,
            label: Text(l10n.homePageDone),
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
