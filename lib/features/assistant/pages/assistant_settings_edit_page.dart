import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/snackbar.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:characters/characters.dart';
import '../../../shared/widgets/emoji_text.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../../../desktop/desktop_context_menu.dart';
import 'package:file_picker/file_picker.dart';
import '../../../shared/widgets/emoji_picker_dialog.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../theme/design_tokens.dart';
import '../../../core/models/assistant.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/mcp_provider.dart';
import '../../model/widgets/model_select_sheet.dart';
import '../../chat/widgets/reasoning_budget_sheet.dart';
import 'assistant_regex_tab.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import '../../chat/widgets/chat_message_widget.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/preset_message.dart';
import '../../../utils/sandbox_path_resolver.dart';
import 'dart:io' show File, Platform;
import '../../../utils/avatar_cache.dart';
import '../../../utils/brand_assets.dart';
import '../../../core/models/quick_phrase.dart';
import '../../../core/providers/quick_phrase_provider.dart';
import '../../../core/providers/memory_provider.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/models/conversation.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../core/services/haptics.dart';
import '../../../shared/widgets/ios_tactile.dart';

const int _contextMessageMin = 1;
const int _contextMessageMax = 256;

int _clampContextMessages(num value) =>
    value.clamp(_contextMessageMin, _contextMessageMax).toInt();

Future<int?> _showContextMessageInputDialog(
  BuildContext context, {
  required int initialValue,
}) async {
  final cs = Theme.of(context).colorScheme;
  final l10n = AppLocalizations.of(context)!;
  final controller = TextEditingController(
    text: _clampContextMessages(initialValue).toString(),
  );

  int? parseValue() => int.tryParse(controller.text);

  try {
    return await showDialog<int>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final parsed = parseValue();
            void submit() {
              if (parsed == null) return;
              Navigator.of(ctx).pop(_clampContextMessages(parsed));
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(l10n.assistantEditContextMessagesTitle),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText:
                            '${l10n.assistantEditContextMessagesTitle} ($_contextMessageMin-$_contextMessageMax)',
                        helperText: '$_contextMessageMin-$_contextMessageMax',
                      ),
                      onChanged: (_) => setLocal(() {}),
                      onSubmitted: (_) => submit(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${l10n.assistantEditContextMessagesDescription} ($_contextMessageMin-$_contextMessageMax)',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withOpacity(0.65),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(l10n.assistantEditEmojiDialogCancel),
                ),
                TextButton(
                  onPressed: parsed == null ? null : submit,
                  child: Text(l10n.assistantEditEmojiDialogSave),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
  }
}

class AssistantSettingsEditPage extends StatefulWidget {
  const AssistantSettingsEditPage({super.key, required this.assistantId});
  final String assistantId;

  @override
  State<AssistantSettingsEditPage> createState() =>
      _AssistantSettingsEditPageState();
}

class _AssistantSettingsEditPageState extends State<AssistantSettingsEditPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this); //mcp
    _tabController.addListener(() {
      // Close IME when switching tabs and refresh state
      FocusManager.instance.primaryFocus?.unfocus();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final provider = context.watch<AssistantProvider>();
    final assistant = provider.getById(widget.assistantId);

    if (assistant == null) {
      return Scaffold(
        appBar: AppBar(
          leading: Tooltip(
            message: l10n.settingsPageBackButton,
            child: _TactileIconButton(
              icon: Lucide.ArrowLeft,
              color: cs.onSurface,
              size: 22,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          title: Text(l10n.assistantEditPageTitle),
          actions: const [SizedBox(width: 12)],
        ),
        body: Center(child: Text(l10n.assistantEditPageNotFound)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: Tooltip(
          message: l10n.settingsPageBackButton,
          child: _TactileIconButton(
            icon: Lucide.ArrowLeft,
            color: cs.onSurface,
            size: 22,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(
          assistant.name.isNotEmpty
              ? assistant.name
              : l10n.assistantEditPageTitle,
        ),
        actions: const [SizedBox(width: 12)],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _SegTabBar(
                    controller: _tabController,
                    tabs: [
                      l10n.assistantEditPageBasicTab,
                      l10n.assistantEditPagePromptsTab,
                      l10n.assistantEditPageMemoryTab,
                      // l10n.assistantEditPageMcpTab,
                      l10n.assistantEditPageQuickPhraseTab,
                      l10n.assistantEditPageCustomTab,
                      l10n.assistantEditPageRegexTab,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: TabBarView(
          controller: _tabController,
          children: [
            _BasicSettingsTab(assistantId: assistant.id),
            _PromptTab(assistantId: assistant.id),
            _MemoryTab(assistantId: assistant.id),
            // _McpTab(assistantId: assistant.id),
            _QuickPhraseTab(assistantId: assistant.id),
            _CustomRequestTab(assistantId: assistant.id),
            AssistantRegexTab(assistantId: assistant.id),
          ],
        ),
      ),
    );
  }
}

class _MemoryTab extends StatelessWidget {
  const _MemoryTab({required this.assistantId});
  final String assistantId;

  Future<void> _showAddEditSheet(
    BuildContext context, {
    int? id,
    String initial = '',
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final controller = TextEditingController(text: initial);
    // Desktop: custom dialog; Mobile: keep bottom sheet
    final platform = Theme.of(context).platform;
    final isDesktop = platform == TargetPlatform.macOS || platform == TargetPlatform.linux || platform == TargetPlatform.windows;
    if (isDesktop) {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) {
          return Dialog(
            backgroundColor: cs.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 44,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(child: Text(l10n.assistantEditMemoryDialogTitle, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
                          IconButton(
                            tooltip: MaterialLocalizations.of(ctx).closeButtonTooltip,
                            icon: const Icon(Lucide.X, size: 18),
                            color: cs.onSurface,
                            onPressed: () => Navigator.of(ctx).maybePop(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: controller,
                          minLines: 3,
                          maxLines: 8,
                          decoration: InputDecoration(
                            hintText: l10n.assistantEditMemoryDialogHint,
                            filled: true,
                            fillColor: Theme.of(ctx).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF7F7F9),
                            border: OutlineInputBorder(borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.2)), borderRadius: BorderRadius.circular(10)),
                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: cs.primary.withOpacity(0.5)), borderRadius: BorderRadius.circular(10)),
                          ),
                          autofocus: true,
                          onSubmitted: (_) async {
                            final text = controller.text.trim();
                            if (text.isEmpty) return;
                            final mp = context.read<MemoryProvider>();
                            if (id == null) {
                              await mp.add(assistantId: assistantId, content: text);
                            } else {
                              await mp.update(id: id, content: text);
                            }
                            if (context.mounted) Navigator.of(ctx).pop();
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _IosButton(label: l10n.assistantEditEmojiDialogCancel, onTap: () => Navigator.of(ctx).pop(), filled: false, neutral: true, dense: true),
                            const SizedBox(width: 8),
                            _IosButton(
                              label: l10n.assistantEditEmojiDialogSave,
                              onTap: () async {
                                final text = controller.text.trim();
                                if (text.isEmpty) return;
                                final mp = context.read<MemoryProvider>();
                                if (id == null) {
                                  await mp.add(assistantId: assistantId, content: text);
                                } else {
                                  await mp.update(id: id, content: text);
                                }
                                if (context.mounted) Navigator.of(ctx).pop();
                              },
                              filled: true,
                              neutral: false,
                              dense: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        final bottom = media.viewInsets.bottom;
        final maxSheetHeight =
            (media.size.height - media.padding.top - media.viewInsets.bottom - 24)
                .clamp(0.0, 560.0)
                .toDouble();
        return SafeArea(
          top: false,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxSheetHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Lucide.Library, size: 18, color: cs.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.assistantEditMemoryDialogTitle,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    fit: FlexFit.loose,
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 16,
                      decoration: InputDecoration(
                        hintText: l10n.assistantEditMemoryDialogHint,
                        filled: true,
                        fillColor: Theme.of(ctx).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF7F7F9),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.2)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: cs.primary.withOpacity(0.5)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _IosButton(
                          label: l10n.assistantEditEmojiDialogCancel,
                          icon: Lucide.X,
                          onTap: () => Navigator.of(ctx).pop(),
                          filled: false,
                          neutral: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _IosButton(
                          label: l10n.assistantEditEmojiDialogSave,
                          icon: Lucide.Check,
                          onTap: () async {
                            final text = controller.text.trim();
                            if (text.isEmpty) return;
                            final mp = context.read<MemoryProvider>();
                            if (id == null) {
                              await mp.add(assistantId: assistantId, content: text);
                            } else {
                              await mp.update(id: id, content: text);
                            }
                            if (context.mounted) Navigator.of(ctx).pop();
                          },
                          filled: true,
                          neutral: false,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ap = context.watch<AssistantProvider>();
    final a = ap.getById(assistantId)!;
    final mp = context.watch<MemoryProvider>();
    // Ensure provider loads persisted memories once
    try { WidgetsBinding.instance.addPostFrameCallback((_) { mp.initialize(); }); } catch (_) {}
    final memories = mp.getForAssistant(assistantId);

    // Align the section card visuals with the basic settings page iOS-style list cards
    Widget sectionCard({required Widget child, EdgeInsets padding = const EdgeInsets.symmetric(vertical: 6)}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              // Match Settings page: Light uses translucent white; Dark uses subtle white10
              color: isDark ? Colors.white10 : Colors.white.withOpacity(0.96),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cs.outlineVariant.withOpacity(isDark ? 0.08 : 0.06),
                width: 0.6,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(padding: padding, child: child),
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
      children: [
        // Feature switches
        sectionCard(
          child: Column(
            children: [
              _iosSwitchRow(
                context,
                icon: Lucide.bookHeart,
                label: l10n.assistantEditMemorySwitchTitle,
                value: a.enableMemory,
                onChanged: (v) async {
                  await context.read<AssistantProvider>().updateAssistant(a.copyWith(enableMemory: v));
                },
              ),
              _iosDivider(context),
              _iosSwitchRow(
                context,
                icon: Lucide.History,
                label: l10n.assistantEditRecentChatsSwitchTitle,
                value: a.enableRecentChatsReference,
                onChanged: (v) async {
                  await context.read<AssistantProvider>().updateAssistant(a.copyWith(enableRecentChatsReference: v));
                },
              ),
            ],
          ),
        ),

        // Manage memories header with add button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.assistantEditManageMemoryTitle,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              _TactileRow(
                onTap: () => _showAddEditSheet(context),
                pressedScale: 0.97,
                builder: (pressed) {
                  final color = pressed ? cs.primary.withOpacity(0.7) : cs.primary;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Lucide.Plus, size: 16, color: color),
                      const SizedBox(width: 4),
                      Text(l10n.assistantEditAddMemoryButton, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                    ],
                  );
                },
              ),
            ],
          ),
        ),

        if (memories.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              l10n.assistantEditMemoryEmpty,
              style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 12),
            ),
          ),

        // Memory list
        ...memories.map((m) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.white.withOpacity(0.96),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant.withOpacity(isDark ? 0.08 : 0.06), width: 0.6),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        m.content,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _TactileIconButton(
                      icon: Lucide.Pencil,
                      size: 18,
                      color: cs.primary,
                      onTap: () => _showAddEditSheet(context, id: m.id, initial: m.content),
                    ),
                    const SizedBox(width: 6),
                    _TactileIconButton(
                      icon: Lucide.Trash2,
                      size: 18,
                      color: cs.error,
                      onTap: () async {
                        await context.read<MemoryProvider>().delete(id: m.id);
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        // Summaries section
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.assistantEditManageSummariesTitle,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),

        Builder(
          builder: (context) {
            final chatService = context.watch<ChatService>();
            final summaries = chatService.getConversationsWithSummaryForAssistant(assistantId);

            if (summaries.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  l10n.assistantEditSummaryEmpty,
                  style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 12),
                ),
              );
            }

            return Column(
              children: summaries.map((conv) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.white.withOpacity(0.96),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outlineVariant.withOpacity(isDark ? 0.08 : 0.06), width: 0.6),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Lucide.MessageSquare, size: 14, color: cs.onSurface.withOpacity(0.5)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  conv.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurface.withOpacity(0.6),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  conv.summary ?? '',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              const SizedBox(width: 6),
                              _TactileIconButton(
                                icon: Lucide.Pencil,
                                size: 18,
                                color: cs.primary,
                                onTap: () => _showEditSummarySheet(context, conv, chatService),
                              ),
                              const SizedBox(width: 6),
                              _TactileIconButton(
                                icon: Lucide.Trash2,
                                size: 18,
                                color: cs.error,
                                onTap: () => _confirmDeleteSummary(context, conv.id, chatService),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Future<void> _showEditSummarySheet(
    BuildContext context,
    Conversation conversation,
    ChatService chatService,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final controller = TextEditingController(text: conversation.summary ?? '');
    final platform = Theme.of(context).platform;
    final isDesktop = platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux ||
        platform == TargetPlatform.windows;

    if (isDesktop) {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) {
          return Dialog(
            backgroundColor: cs.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 44,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.assistantEditSummaryDialogTitle,
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                            ),
                          ),
                          IconButton(
                            tooltip: MaterialLocalizations.of(ctx).closeButtonTooltip,
                            icon: const Icon(Lucide.X, size: 18),
                            color: cs.onSurface,
                            onPressed: () => Navigator.of(ctx).maybePop(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      conversation.title,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withOpacity(0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: controller,
                          minLines: 3,
                          maxLines: 8,
                          decoration: InputDecoration(
                            hintText: l10n.assistantEditSummaryDialogHint,
                            filled: true,
                            fillColor: Theme.of(ctx).brightness == Brightness.dark
                                ? Colors.white10
                                : const Color(0xFFF7F7F9),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.2)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: cs.primary.withOpacity(0.5)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          autofocus: true,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _IosButton(
                              label: l10n.assistantEditEmojiDialogCancel,
                              onTap: () => Navigator.of(ctx).pop(),
                              filled: false,
                              neutral: true,
                              dense: true,
                            ),
                            const SizedBox(width: 8),
                            _IosButton(
                              label: l10n.assistantEditEmojiDialogSave,
                              onTap: () async {
                                final text = controller.text.trim();
                                if (text.isEmpty) {
                                  await chatService.clearConversationSummary(conversation.id);
                                } else {
                                  await chatService.updateConversationSummary(
                                    conversation.id,
                                    text,
                                    conversation.lastSummarizedMessageCount,
                                  );
                                }
                                if (context.mounted) Navigator.of(ctx).pop();
                              },
                              filled: true,
                              neutral: false,
                              dense: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      return;
    }

    // Mobile: BottomSheet
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Lucide.FileText, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.assistantEditSummaryDialogTitle,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  conversation.title,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withOpacity(0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 16,
                  decoration: InputDecoration(
                    hintText: l10n.assistantEditSummaryDialogHint,
                    filled: true,
                    fillColor: Theme.of(ctx).brightness == Brightness.dark
                        ? Colors.white10
                        : const Color(0xFFF7F7F9),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.2)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: cs.primary.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _IosButton(
                        label: l10n.assistantEditEmojiDialogCancel,
                        icon: Lucide.X,
                        onTap: () => Navigator.of(ctx).pop(),
                        filled: false,
                        neutral: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _IosButton(
                        label: l10n.assistantEditEmojiDialogSave,
                        icon: Lucide.Check,
                        onTap: () async {
                          final text = controller.text.trim();
                          if (text.isEmpty) {
                            await chatService.clearConversationSummary(conversation.id);
                          } else {
                            await chatService.updateConversationSummary(
                              conversation.id,
                              text,
                              conversation.lastSummarizedMessageCount,
                            );
                          }
                          if (context.mounted) Navigator.of(ctx).pop();
                        },
                        filled: true,
                        neutral: false,
                      ),
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

  Future<void> _confirmDeleteSummary(
    BuildContext context,
    String conversationId,
    ChatService chatService,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.assistantEditDeleteSummaryTitle),
        content: Text(l10n.assistantEditDeleteSummaryContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.homePageCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            child: Text(l10n.assistantEditClearButton),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await chatService.clearConversationSummary(conversationId);
    }
  }
}

class _CustomRequestTab extends StatelessWidget {
  const _CustomRequestTab({required this.assistantId});
  final String assistantId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ap = context.watch<AssistantProvider>();
    final a = ap.getById(assistantId)!;

    Widget card({required Widget child}) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 20, 8), // Increased right padding
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
          boxShadow: isDark ? [] : AppShadows.soft,
        ),
        child: Padding(padding: const EdgeInsets.all(12), child: child),
      ),
    );

    void addHeader() {
      final list = List<Map<String, String>>.of(a.customHeaders);
      list.add({'name': '', 'value': ''});
      context.read<AssistantProvider>().updateAssistant(
        a.copyWith(customHeaders: list),
      );
    }

    void removeHeader(int index) {
      final list = List<Map<String, String>>.of(a.customHeaders);
      if (index >= 0 && index < list.length) {
        list.removeAt(index);
        context.read<AssistantProvider>().updateAssistant(
          a.copyWith(customHeaders: list),
        );
      }
    }

    void updateHeader(int index, {String? name, String? value}) {
      final list = List<Map<String, String>>.of(a.customHeaders);
      if (index >= 0 && index < list.length) {
        final cur = Map<String, String>.from(list[index]);
        if (name != null) cur['name'] = name;
        if (value != null) cur['value'] = value;
        list[index] = cur;
        context.read<AssistantProvider>().updateAssistant(
          a.copyWith(customHeaders: list),
        );
      }
    }

    void addBody() {
      final list = List<Map<String, String>>.of(a.customBody);
      list.add({'key': '', 'value': ''});
      context.read<AssistantProvider>().updateAssistant(
        a.copyWith(customBody: list),
      );
    }

    void removeBody(int index) {
      final list = List<Map<String, String>>.of(a.customBody);
      if (index >= 0 && index < list.length) {
        list.removeAt(index);
        context.read<AssistantProvider>().updateAssistant(
          a.copyWith(customBody: list),
        );
      }
    }

    void updateBody(int index, {String? key, String? value}) {
      final list = List<Map<String, String>>.of(a.customBody);
      if (index >= 0 && index < list.length) {
        final cur = Map<String, String>.from(list[index]);
        if (key != null) cur['key'] = key;
        if (value != null) cur['value'] = value;
        list[index] = cur;
        context.read<AssistantProvider>().updateAssistant(
          a.copyWith(customBody: list),
        );
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 16), // Reduced top padding
      children: [
        // Headers
        card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.assistantEditCustomHeadersTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _TactileRow(
                      onTap: addHeader,
                      pressedScale: 0.97,
                      builder: (pressed) {
                        final color = pressed ? cs.primary.withOpacity(0.7) : cs.primary;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Lucide.Plus, size: 16, color: color),
                            const SizedBox(width: 4),
                            Text(
                              l10n.assistantEditCustomHeadersAdd,
                              style: TextStyle(color: color, fontWeight: FontWeight.w600),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (int i = 0; i < a.customHeaders.length; i++) ...[
                _HeaderRow(
                  index: i,
                  name: a.customHeaders[i]['name'] ?? '',
                  value: a.customHeaders[i]['value'] ?? '',
                  onChanged: (k, v) => updateHeader(i, name: k, value: v),
                  onDelete: () => removeHeader(i),
                ),
                const SizedBox(height: 10),
              ],
              if (a.customHeaders.isEmpty)
                Text(
                  l10n.assistantEditCustomHeadersEmpty,
                  style: TextStyle(
                    color: cs.onSurface.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),

        // Body
        card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.assistantEditCustomBodyTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _TactileRow(
                      onTap: addBody,
                      pressedScale: 0.97,
                      builder: (pressed) {
                        final color = pressed ? cs.primary.withOpacity(0.7) : cs.primary;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Lucide.Plus, size: 16, color: color),
                            const SizedBox(width: 4),
                            Text(
                              l10n.assistantEditCustomBodyAdd,
                              style: TextStyle(color: color, fontWeight: FontWeight.w600),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (int i = 0; i < a.customBody.length; i++) ...[
                _BodyRow(
                  index: i,
                  keyName: a.customBody[i]['key'] ?? '',
                  value: a.customBody[i]['value'] ?? '',
                  onChanged: (k, v) => updateBody(i, key: k, value: v),
                  onDelete: () => removeBody(i),
                ),
                const SizedBox(height: 10),
              ],
              if (a.customBody.isEmpty)
                Text(
                  l10n.assistantEditCustomBodyEmpty,
                  style: TextStyle(
                    color: cs.onSurface.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderRow extends StatefulWidget {
  const _HeaderRow({
    required this.index,
    required this.name,
    required this.value,
    required this.onChanged,
    required this.onDelete,
  });
  final int index;
  final String name;
  final String value;
  final void Function(String name, String value) onChanged;
  final VoidCallback onDelete;

  @override
  State<_HeaderRow> createState() => _HeaderRowState();
}

class _HeaderRowState extends State<_HeaderRow> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _valCtrl;
  late final FocusNode _nameFocus;
  late final FocusNode _valFocus;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.name);
    _valCtrl = TextEditingController(text: widget.value);
    _nameFocus = FocusNode();
    _valFocus = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _HeaderRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Avoid resetting controller text while the field is focused to prevent cursor jump.
    if (oldWidget.name != widget.name && !_nameFocus.hasFocus) {
      _nameCtrl.text = widget.name;
    }
    if (oldWidget.value != widget.value && !_valFocus.hasFocus) {
      _valCtrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _valCtrl.dispose();
    _nameFocus.dispose();
    _valFocus.dispose();
    super.dispose();
  }

  InputDecoration _dec(BuildContext context, String label) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: isDark ? Colors.white10 : const Color(0xFFF2F3F5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary.withOpacity(0.4)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _nameCtrl,
                focusNode: _nameFocus,
                decoration: _dec(context, l10n.assistantEditHeaderNameLabel),
                onChanged: (v) => widget.onChanged(v, _valCtrl.text),
              ),
            ),
            const SizedBox(width: 8),
            _TactileIconButton(
              icon: Lucide.Trash2,
              color: cs.error,
              size: 20,
              onTap: widget.onDelete,
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _valCtrl,
          focusNode: _valFocus,
          decoration: _dec(context, l10n.assistantEditHeaderValueLabel),
          onChanged: (v) => widget.onChanged(_nameCtrl.text, v),
        ),
      ],
    );
  }
}

class _BodyRow extends StatefulWidget {
  const _BodyRow({
    required this.index,
    required this.keyName,
    required this.value,
    required this.onChanged,
    required this.onDelete,
  });
  final int index;
  final String keyName;
  final String value;
  final void Function(String key, String value) onChanged;
  final VoidCallback onDelete;

  @override
  State<_BodyRow> createState() => _BodyRowState();
}

class _BodyRowState extends State<_BodyRow> {
  late final TextEditingController _keyCtrl;
  late final TextEditingController _valCtrl;
  late final FocusNode _keyFocus;
  late final FocusNode _valFocus;

  @override
  void initState() {
    super.initState();
    _keyCtrl = TextEditingController(text: widget.keyName);
    _valCtrl = TextEditingController(text: widget.value);
    _keyFocus = FocusNode();
    _valFocus = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _BodyRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Avoid resetting controller text while the field is focused to prevent cursor jump.
    if (oldWidget.keyName != widget.keyName && !_keyFocus.hasFocus) {
      _keyCtrl.text = widget.keyName;
    }
    if (oldWidget.value != widget.value && !_valFocus.hasFocus) {
      _valCtrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _valCtrl.dispose();
    _keyFocus.dispose();
    _valFocus.dispose();
    super.dispose();
  }

  InputDecoration _dec(BuildContext context, String label) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: isDark ? Colors.white10 : const Color(0xFFF2F3F5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary.withOpacity(0.4)),
      ),
      alignLabelWithHint: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _keyCtrl,
                focusNode: _keyFocus,
                decoration: _dec(context, l10n.assistantEditBodyKeyLabel),
                onChanged: (v) => widget.onChanged(v, _valCtrl.text),
              ),
            ),
            const SizedBox(width: 8),
            _TactileIconButton(
              icon: Lucide.Trash2,
              color: cs.error,
              size: 20,
              onTap: widget.onDelete,
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _valCtrl,
          focusNode: _valFocus,
          minLines: 3,
          maxLines: 6,
          decoration: _dec(context, l10n.assistantEditBodyValueLabel),
          onChanged: (v) => widget.onChanged(_keyCtrl.text, v),
        ),
      ],
    );
  }
}

class _BasicSettingsTab extends StatefulWidget {
  const _BasicSettingsTab({required this.assistantId});
  final String assistantId;

  @override
  State<_BasicSettingsTab> createState() => _BasicSettingsTabState();
}

class _BasicSettingsTabState extends State<_BasicSettingsTab> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _thinkingCtrl;
  late final TextEditingController _maxTokensCtrl;
  late final TextEditingController _backgroundCtrl;

  @override
  void initState() {
    super.initState();
    final ap = context.read<AssistantProvider>();
    final a = ap.getById(widget.assistantId)!;
    _nameCtrl = TextEditingController(text: a.name);
    _thinkingCtrl = TextEditingController(
      text: a.thinkingBudget?.toString() ?? '',
    );
    _maxTokensCtrl = TextEditingController(text: a.maxTokens?.toString() ?? '');
    _backgroundCtrl = TextEditingController(text: a.background ?? '');
  }

  @override
  void didUpdateWidget(covariant _BasicSettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assistantId != widget.assistantId) {
      final ap = context.read<AssistantProvider>();
      final a = ap.getById(widget.assistantId)!;
      _nameCtrl.text = a.name;
      _thinkingCtrl.text = a.thinkingBudget?.toString() ?? '';
      _maxTokensCtrl.text = a.maxTokens?.toString() ?? '';
      _backgroundCtrl.text = a.background ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _thinkingCtrl.dispose();
    _maxTokensCtrl.dispose();
    _backgroundCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ap = context.watch<AssistantProvider>();
    final a = ap.getById(widget.assistantId)!;

    Widget titleDesc(String title, String? desc) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        if (desc != null) ...[
          const SizedBox(height: 6),
          Text(
            desc,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ],
    );

    Widget avatarWidget({double size = 56}) {
      final bg = cs.primary.withOpacity(isDark ? 0.18 : 0.12);
      Widget inner;
      final av = a.avatar?.trim();
      if (av != null && av.isNotEmpty) {
        if (av.startsWith('http')) {
          inner = FutureBuilder<String?>(
            future: AvatarCache.getPath(av),
            builder: (ctx, snap) {
              final p = snap.data;
              if (p != null && File(p).existsSync()) {
                return ClipOval(
                  child: Image.file(
                    File(p),
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
                ),
              );
            },
          );
        } else if (av.startsWith('/') || av.contains(':')) {
          final fixed = SandboxPathResolver.fix(av);
          inner = ClipOval(
            child: Image.file(
              File(fixed),
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          );
        } else {
          inner = Text(
            av,
            style: TextStyle(
              color: cs.primary,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.42,
            ),
          );
        }
      } else {
        inner = Text(
          (a.name.trim().isNotEmpty
              ? String.fromCharCode(a.name.trim().runes.first).toUpperCase()
              : 'A'),
          style: TextStyle(
            color: cs.primary,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.42,
          ),
        );
      }
      return InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _showAvatarPicker(context, a),
        child: CircleAvatar(
          radius: size / 2,
          backgroundColor: bg,
          child: inner,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Identity card (avatar + name) - iOS style
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: cs.outlineVariant.withOpacity(isDark ? 0.08 : 0.06),
              width: 0.6,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                avatarWidget(size: 64),
                const SizedBox(width: 14),
                Expanded(
                  child: _InputRow(
                    label: l10n.assistantEditAssistantNameLabel,
                    controller: _nameCtrl,
                    onChanged: (v) => context
                        .read<AssistantProvider>()
                        .updateAssistant(a.copyWith(name: v)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // iOS section card with all settings (without Use Assistant Avatar and Stream Output)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: _iosSectionCard(children: [
            // Temperature
            _iosNavRow(
              context,
              icon: Lucide.Thermometer,
              label: 'Temperature',
              detailText: a.temperature != null ? a.temperature!.toStringAsFixed(2) : l10n.assistantEditParameterDisabled,
              onTap: () => _showTemperatureSheet(context, a),
            ),
            _iosDivider(context),
            // Top P
            _iosNavRow(
              context,
              icon: Lucide.Wand2,
              label: 'Top P',
              detailText: a.topP != null ? a.topP!.toStringAsFixed(2) : l10n.assistantEditParameterDisabled,
              onTap: () => _showTopPSheet(context, a),
            ),
            _iosDivider(context),
            // Context messages
            _iosNavRow(
              context,
              icon: Lucide.MessagesSquare,
              label: l10n.assistantEditContextMessagesTitle,
              detailText: a.limitContextMessages ? a.contextMessageSize.toString() : l10n.assistantEditParameterDisabled2,
              onTap: () => _showContextMessagesSheet(context, a),
            ),
            _iosDivider(context),
            // Thinking budget
            _iosNavRow(
              context,
              icon: Lucide.Brain,
              label: l10n.assistantEditThinkingBudgetTitle,
              detailText: a.thinkingBudget?.toString() ?? '-',
              onTap: () async {
                final currentBudget = a.thinkingBudget;
                if (currentBudget != null) {
                  context.read<SettingsProvider>().setThinkingBudget(currentBudget);
                }
                await showReasoningBudgetSheet(context);
                final chosen = context.read<SettingsProvider>().thinkingBudget;
                await context.read<AssistantProvider>().updateAssistant(
                  a.copyWith(thinkingBudget: chosen),
                );
              },
            ),
            _iosDivider(context),
            // Max tokens
            _iosNavRow(
              context,
              icon: Lucide.Hash,
              label: l10n.assistantEditMaxTokensTitle,
              detailText: a.maxTokens?.toString() ?? l10n.assistantEditMaxTokensHint,
              onTap: () => _showMaxTokensSheet(context, a),
            ),
            _iosDivider(context),
            // Use assistant avatar
            _iosSwitchRow(
              context,
              icon: Lucide.User,
              label: l10n.assistantEditUseAssistantAvatarTitle,
              value: a.useAssistantAvatar,
              onChanged: (v) => context
                  .read<AssistantProvider>()
                  .updateAssistant(a.copyWith(useAssistantAvatar: v)),
            ),
            _iosDivider(context),
            // Stream output
            _iosSwitchRow(
              context,
              icon: Lucide.Zap,
              label: l10n.assistantEditStreamOutputTitle,
              value: a.streamOutput,
              onChanged: (v) => context
                  .read<AssistantProvider>()
                  .updateAssistant(a.copyWith(streamOutput: v)),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // Chat model card (moved down, styled like DefaultModelPage)
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: cs.outlineVariant.withOpacity(isDark ? 0.08 : 0.06),
              width: 0.6,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Lucide.MessageCircle, size: 18, color: cs.onSurface),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.assistantEditChatModelTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (a.chatModelProvider != null && a.chatModelId != null)
                      Tooltip(
                        message: l10n.defaultModelPageResetDefault,
                        child: _TactileIconButton(
                          icon: Lucide.RotateCcw,
                          color: cs.onSurface,
                          size: 20,
                          onTap: () async {
                            await context.read<AssistantProvider>().updateAssistant(
                              a.copyWith(clearChatModel: true),
                            );
                          },
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.assistantEditChatModelSubtitle,
                  style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.7)),
                ),
                const SizedBox(height: 8),
                _TactileRow(
                  onTap: () async {
                    final sel = await showModelSelector(context);
                    if (sel != null) {
                      await context.read<AssistantProvider>().updateAssistant(
                        a.copyWith(
                          chatModelProvider: sel.providerKey,
                          chatModelId: sel.modelId,
                        ),
                      );
                    }
                  },
                  pressedScale: 0.98,
                  builder: (pressed) {
                    final bg = isDark ? Colors.white10 : const Color(0xFFF2F3F5);
                    final overlay = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05);
                    final pressedBg = Color.alphaBlend(overlay, bg);
                    final l10n = AppLocalizations.of(context)!;
                    final settings = context.read<SettingsProvider>();
                    String display = l10n.assistantEditModelUseGlobalDefault;
                    String brandName = display;
                    if (a.chatModelProvider != null && a.chatModelId != null) {
                      try {
                        final cfg = settings.getProviderConfig(a.chatModelProvider!);
                        final ov = cfg.modelOverrides[a.chatModelId] as Map?;
                        brandName = cfg.name.isNotEmpty ? cfg.name : a.chatModelProvider!;
                        final mdl = (ov != null && (ov['name'] as String?)?.isNotEmpty == true)
                            ? (ov['name'] as String)
                            : a.chatModelId!;
                        display = mdl;
                      } catch (_) {
                        brandName = a.chatModelProvider ?? '';
                        display = a.chatModelId ?? '';
                      }
                    }
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: pressed ? pressedBg : bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          _BrandAvatarLike(name: display, size: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              display,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Chat background (separate iOS card)
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: cs.outlineVariant.withOpacity(isDark ? 0.08 : 0.06),
              width: 0.6,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Lucide.Image, size: 18, color: cs.onSurface),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.assistantEditChatBackgroundTitle,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.assistantEditChatBackgroundDescription,
                  style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.7)),
                ),
                const SizedBox(height: 8),
                if ((a.background ?? '').isEmpty) ...[
                  // Single button when no background (full width)
                  _TactileRow(
                    onTap: () => _pickBackground(context, a),
                    pressedScale: 0.98,
                    builder: (pressed) {
                      final bg = isDark ? Colors.white10 : const Color(0xFFF2F3F5);
                      final overlay = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05);
                      final pressedBg = Color.alphaBlend(overlay, bg);
                      final iconColor = cs.onSurface.withOpacity(0.75);
                      final textColor = cs.onSurface.withOpacity(0.9);
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: pressed ? pressedBg : bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: cs.outlineVariant.withOpacity(0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 2.0), // Material icon spacing
                              child: Icon(Icons.image, size: 18, color: iconColor),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.assistantEditChooseImageButton,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ] else ...[
                  // Two buttons when background exists
                  Row(
                    children: [
                      Expanded(
                        child: _IosButton(
                          label: l10n.assistantEditChooseImageButton,
                          icon: Icons.image,
                          onTap: () => _pickBackground(context, a),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _IosButton(
                          label: l10n.assistantEditClearButton,
                          icon: Lucide.X,
                          onTap: () => context
                              .read<AssistantProvider>()
                              .updateAssistant(a.copyWith(clearBackground: true)),
                        ),
                      ),
                    ],
                  ),
                ],
                if ((a.background ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _BackgroundPreview(path: a.background!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showAvatarPicker(BuildContext context, Assistant a) async {
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
        final maxH = MediaQuery.of(ctx).size.height * 0.8;
        Widget row(String text, Future<void> Function() action) {
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
                    row(l10n.assistantEditAvatarChooseImage, () async => _pickLocalImage(context, a)),
                    row(l10n.assistantEditAvatarChooseEmoji, () async {
                      final emoji = await _pickEmoji(context);
                      if (emoji != null) {
                        await context.read<AssistantProvider>().updateAssistant(
                          a.copyWith(avatar: emoji),
                        );
                      }
                    }),
                    row(l10n.assistantEditAvatarEnterLink, () async => _inputAvatarUrl(context, a)),
                    row(l10n.assistantEditAvatarImportQQ, () async => _inputQQAvatar(context, a)),
                    row(l10n.assistantEditAvatarReset, () async {
                      await context.read<AssistantProvider>().updateAssistant(
                        a.copyWith(clearAvatar: true),
                      );
                    }),
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

  Future<void> _pickBackground(BuildContext context, Assistant a) async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (file != null) {
        await context.read<AssistantProvider>().updateAssistant(
          a.copyWith(background: file.path),
        );
      }
    } catch (_) {}
  }

  Future<void> _showTemperatureSheet(BuildContext context, Assistant a) async {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      isScrollControlled: false,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: Builder(builder: (context) {
              final theme = Theme.of(context);
              final cs = theme.colorScheme;
              final isDark = theme.brightness == Brightness.dark;
              final value = context.watch<AssistantProvider>().getById(widget.assistantId)?.temperature ?? 0.6;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Temperature',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                      IosSwitch(
                        value: a.temperature != null,
                        onChanged: (v) async {
                          if (v) {
                            await context.read<AssistantProvider>().updateAssistant(
                              a.copyWith(temperature: 0.6),
                            );
                          } else {
                            await context.read<AssistantProvider>().updateAssistant(
                              a.copyWith(clearTemperature: true),
                            );
                          }
                          // Close the bottom sheet after toggle
                          Navigator.of(ctx).pop();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (a.temperature != null) ...[
                    _SliderTileNew(
                      value: value.clamp(0.0, 2.0),
                      min: 0.0,
                      max: 2.0,
                      divisions: 20,
                      label: value.toStringAsFixed(2),
                      onChanged: (v) => context
                          .read<AssistantProvider>()
                          .updateAssistant(a.copyWith(temperature: v)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.assistantEditTemperatureDescription,
                      style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.6)),
                    ),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        l10n.assistantEditParameterDisabled,
                        style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.6)),
                      ),
                    ),
                  ],
                ],
              );
            }),
          ),
        );
      },
    );
  }

  Future<void> _showTopPSheet(BuildContext context, Assistant a) async {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      isScrollControlled: false,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: Builder(builder: (context) {
              final theme = Theme.of(context);
              final cs = theme.colorScheme;
              final isDark = theme.brightness == Brightness.dark;
              final value = context.watch<AssistantProvider>().getById(widget.assistantId)?.topP ?? 1.0;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Top P',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                      IosSwitch(
                        value: a.topP != null,
                        onChanged: (v) async {
                          if (v) {
                            await context.read<AssistantProvider>().updateAssistant(
                              a.copyWith(topP: 1.0),
                            );
                          } else {
                            await context.read<AssistantProvider>().updateAssistant(
                              a.copyWith(clearTopP: true),
                            );
                          }
                          // Close the bottom sheet after toggle
                          Navigator.of(ctx).pop();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (a.topP != null) ...[
                    _SliderTileNew(
                      value: value.clamp(0.0, 1.0),
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      label: value.toStringAsFixed(2),
                      onChanged: (v) => context
                          .read<AssistantProvider>()
                          .updateAssistant(a.copyWith(topP: v)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.assistantEditTopPDescription,
                      style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.6)),
                    ),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        l10n.assistantEditParameterDisabled,
                        style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.6)),
                      ),
                    ),
                  ],
                ],
              );
            }),
          ),
        );
      },
    );
  }

  Future<void> _showContextMessagesSheet(BuildContext context, Assistant a) async {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      isScrollControlled: false,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: Builder(builder: (context) {
              final cs = Theme.of(context).colorScheme;
              final value = _clampContextMessages(
                context.watch<AssistantProvider>().getById(widget.assistantId)?.contextMessageSize ?? 20,
              );
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.assistantEditContextMessagesTitle,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                      IosSwitch(
                        value: a.limitContextMessages,
                        onChanged: (v) async {
                          final next = v && a.contextMessageSize < _contextMessageMin
                              ? a.copyWith(limitContextMessages: v, contextMessageSize: _contextMessageMin)
                              : a.copyWith(limitContextMessages: v);
                          await context.read<AssistantProvider>().updateAssistant(next);
                          // Close the bottom sheet after toggle
                          Navigator.of(ctx).pop();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (a.limitContextMessages) ...[
                    _SliderTileNew(
                      value: value.toDouble(),
                      min: _contextMessageMin.toDouble(),
                      max: _contextMessageMax.toDouble(),
                      divisions: _contextMessageMax - _contextMessageMin,
                      label: value.toString(),
                      customLabelStops: const <double>[1.0, 32.0, 64.0, 128.0, 256.0],
                      onLabelTap: () async {
                        final chosen = await _showContextMessageInputDialog(
                          context,
                          initialValue: value,
                        );
                        if (chosen != null) {
                          await context.read<AssistantProvider>().updateAssistant(
                                a.copyWith(contextMessageSize: chosen),
                              );
                        }
                      },
                      onChanged: (v) => context.read<AssistantProvider>().updateAssistant(
                        a.copyWith(contextMessageSize: _clampContextMessages(v)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.assistantEditContextMessagesDescription,
                      style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.6)),
                    ),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        l10n.assistantEditParameterDisabled2,
                        style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.6)),
                      ),
                    ),
                  ],
                ],
              );
            }),
          ),
        );
      },
    );
  }

  Future<void> _showMaxTokensSheet(BuildContext context, Assistant a) async {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: a.maxTokens?.toString() ?? '');
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
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: cs.onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(999)),
                  ),
                ),
                const SizedBox(height: 12),
                // Header with Close (X) and Save buttons
                Row(
                  children: [
                    _TactileIconButton(
                      icon: Lucide.X,
                      color: cs.onSurface,
                      size: 20,
                      onTap: () => Navigator.of(ctx).pop(),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          l10n.assistantEditMaxTokensTitle,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    _TactileRow(
                      onTap: () {
                        final val = int.tryParse(controller.text.trim());
                        context.read<AssistantProvider>().updateAssistant(
                          a.copyWith(
                            maxTokens: val,
                            clearMaxTokens: controller.text.trim().isEmpty,
                          ),
                        );
                        Navigator.of(ctx).pop();
                      },
                      pressedScale: 0.95,
                      builder: (pressed) {
                        final color = pressed ? cs.primary.withOpacity(0.7) : cs.primary;
                        return Text(
                          l10n.assistantSettingsAddSheetSave, // "Save"
                          style: TextStyle(
                            color: color,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: l10n.assistantEditMaxTokensHint,
                    filled: true,
                    fillColor: Theme.of(ctx).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF2F3F5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.4))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.4))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary.withOpacity(0.5))),
                  ),
                ),
                const SizedBox(height: 12),
                Text(l10n.assistantEditMaxTokensDescription, style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BackgroundPreview extends StatefulWidget {
  const _BackgroundPreview({required this.path});
  final String path;

  @override
  State<_BackgroundPreview> createState() => _BackgroundPreviewState();
}

class _BackgroundPreviewState extends State<_BackgroundPreview> {
  Size? _size;

  @override
  void initState() {
    super.initState();
    _resolveSize();
  }

  @override
  void didUpdateWidget(covariant _BackgroundPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _size = null;
      _resolveSize();
    }
  }

  Future<void> _resolveSize() async {
    try {
      if (widget.path.startsWith('http')) {
        // Skip network size probe; render with a sensible max height
        setState(() => _size = null);
        return;
      }
      final file = File(SandboxPathResolver.fix(widget.path));
      if (!await file.exists()) {
        setState(() => _size = null);
        return;
      }
      final bytes = await file.readAsBytes();
      final img = await decodeImageFromList(bytes);
      final s = Size(img.width.toDouble(), img.height.toDouble());
      if (mounted) setState(() => _size = s);
    } catch (_) {
      if (mounted) setState(() => _size = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNetwork = widget.path.startsWith('http');
    final imageWidget = isNetwork
        ? Image.network(widget.path, fit: BoxFit.contain)
        : (() {
            final fixed = SandboxPathResolver.fix(widget.path);
            final f = File(fixed);
            if (!f.existsSync()) {
              // Gracefully fallback to empty box when local file missing (e.g., imported from mobile)
              return const SizedBox.shrink();
            }
            return Image.file(f, fit: BoxFit.contain);
          })();
    // When size known, maintain aspect ratio; otherwise cap the height to avoid overflow
    if (_size != null && _size!.width > 0 && _size!.height > 0) {
      final ratio = _size!.width / _size!.height;
      return SizedBox(
        width: double.infinity,
        child: AspectRatio(aspectRatio: ratio, child: imageWidget),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxHeight: 280,
        minHeight: 100,
        minWidth: double.infinity,
      ),
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
        child: SizedBox(width: 400, height: 240, child: imageWidget),
      ),
    );
  }
}

class _SliderTileNew extends StatelessWidget {
  const _SliderTileNew({
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.label,
    required this.onChanged,
    this.customLabelStops,
    this.onLabelTap,
  });

  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String label;
  final ValueChanged<double> onChanged;
  final List<double>? customLabelStops;
  final VoidCallback? onLabelTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final useCustomLabels = customLabelStops != null && customLabelStops!.isNotEmpty;
    final stops = useCustomLabels
        ? (customLabelStops!
            .where((v) => v >= min && v <= max)
            .toSet()
            .toList()
          ..sort())
        : const <double>[];

    final active = cs.primary;
    final inactive = cs.onSurface.withOpacity(isDark ? 0.25 : 0.20);
    final double clamped = value.clamp(min, max);
    final double? step = (divisions != null && divisions! > 0)
        ? (max - min) / divisions!
        : null;
    // Compute a readable major interval and minor tick count
    final total = (max - min).abs();
    double interval;
    if (total <= 0) {
      interval = 1;
    } else if ((divisions ?? 0) <= 20) {
      interval = total / 4; // up to 5 major ticks inc endpoints
    } else if ((divisions ?? 0) <= 50) {
      interval = total / 5;
    } else {
      interval = total / 8;
    }
    if (interval <= 0) interval = 1;
    int minor = 0;
    if (step != null && step > 0) {
      // Ensure minor ticks align with the chosen step size
      minor = ((interval / step) - 1).round();
      if (minor < 0) minor = 0;
      if (minor > 8) minor = 8;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SfSliderTheme(
                    data: SfSliderThemeData(
                      activeTrackHeight: 8,
                      inactiveTrackHeight: 8,
                      overlayRadius: 14,
                      activeTrackColor: active,
                      inactiveTrackColor: inactive,
                      // Waterdrop tooltip uses theme primary background with onPrimary text
                      tooltipBackgroundColor: cs.primary,
                      tooltipTextStyle: TextStyle(
                        color: cs.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      thumbStrokeColor: Colors.transparent,
                      thumbStrokeWidth: 0,
                      activeTickColor: cs.onSurface.withOpacity(
                        isDark ? 0.45 : 0.35,
                      ),
                      inactiveTickColor: cs.onSurface.withOpacity(
                        isDark ? 0.30 : 0.25,
                      ),
                      activeMinorTickColor: cs.onSurface.withOpacity(
                        isDark ? 0.34 : 0.28,
                      ),
                      inactiveMinorTickColor: cs.onSurface.withOpacity(
                        isDark ? 0.24 : 0.20,
                      ),
                    ),
                    child: SfSlider(
                      value: clamped,
                      min: min,
                      max: max,
                      stepSize: step,
                      enableTooltip: true,
                      // Show the paddle tooltip only while interacting
                      shouldAlwaysShowTooltip: false,
                      showTicks: true,
                      showLabels: !useCustomLabels,
                      interval: interval,
                      minorTicksPerInterval: minor,
                      activeColor: active,
                      inactiveColor: inactive,
                      tooltipTextFormatterCallback: (actual, text) => label,
                      tooltipShape: const SfPaddleTooltipShape(),
                      labelFormatterCallback: (actual, formattedText) {
                        // Prefer integers for wide ranges, keep 2 decimals for 0..1
                        if (total <= 2.0) return actual.toStringAsFixed(2);
                        if (actual == actual.roundToDouble())
                          return actual.toStringAsFixed(0);
                        return actual.toStringAsFixed(1);
                      },
                      thumbIcon: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                          boxShadow: isDark
                              ? []
                              : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                      ),
                      onChanged: (v) =>
                          onChanged(v is num ? v.toDouble() : (v as double)),
                    ),
                  ),
                  if (useCustomLabels && stops.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (_, __) {
                        final range = (max - min).abs();
                        return SizedBox(
                          height: 18,
                          child: Stack(
                            fit: StackFit.expand,
                            children: stops.map((v) {
                              final t = range == 0 ? 0.0 : ((v - min) / range).clamp(0.0, 1.0);
                              return Align(
                                alignment: Alignment(-1 + t * 2, 0),
                                child: Text(
                                  v == v.roundToDouble()
                                      ? v.toInt().toString()
                                      : v.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurface.withOpacity(0.65),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            _ValuePill(text: label, onTap: onLabelTap),
          ],
        ),
        // Remove explicit min/max captions since ticks already indicate range
      ],
    );
  }
}

class _ValuePill extends StatelessWidget {
  const _ValuePill({required this.text, this.onTap});
  final String text;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      behavior: onTap != null ? HitTestBehavior.opaque : HitTestBehavior.deferToChild,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : cs.primary.withOpacity(0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.primary.withOpacity(isDark ? 0.28 : 0.22)),
          boxShadow: isDark ? [] : AppShadows.soft,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            text,
            style: TextStyle(
              color: cs.primary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

extension _AssistantAvatarActions on _BasicSettingsTabState {
  Future<String?> _pickEmoji(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    String value = '';
    bool validGrapheme(String s) {
      final trimmed = s.characters.take(1).toString().trim();
      return trimmed.isNotEmpty && trimmed == s.trim();
    }

    final List<String> quick = const [
      '😀',
      '😁',
      '😂',
      '🤣',
      '😃',
      '😄',
      '😅',
      '😊',
      '😍',
      '😘',
      '😗',
      '😙',
      '😚',
      '🙂',
      '🤗',
      '🤩',
      '🫶',
      '🤝',
      '👍',
      '👎',
      '👋',
      '🙏',
      '💪',
      '🔥',
      '✨',
      '🌟',
      '💡',
      '🎉',
      '🎊',
      '🎈',
      '🌈',
      '☀️',
      '🌙',
      '⭐',
      '⚡',
      '☁️',
      '❄️',
      '🌧️',
      '🍎',
      '🍊',
      '🍋',
      '🍉',
      '🍇',
      '🍓',
      '🍒',
      '🍑',
      '🥭',
      '🍍',
      '🥝',
      '🍅',
      '🥕',
      '🌽',
      '🍞',
      '🧀',
      '🍔',
      '🍟',
      '🍕',
      '🌮',
      '🌯',
      '🍣',
      '🍜',
      '🍰',
      '🍪',
      '🍩',
      '🍫',
      '🍻',
      '☕',
      '🧋',
      '🥤',
      '⚽',
      '🏀',
      '🏈',
      '🎾',
      '🏐',
      '🎮',
      '🎧',
      '🎸',
      '🎹',
      '🎺',
      '📚',
      '✏️',
      '💼',
      '💻',
      '🖥️',
      '📱',
      '🛩️',
      '✈️',
      '🚗',
      '🚕',
      '🚙',
      '🚌',
      '🚀',
      '🛰️',
      '🧠',
      '🫀',
      '💊',
      '🩺',
      '🐶',
      '🐱',
      '🐭',
      '🐹',
      '🐰',
      '🦊',
      '🐻',
      '🐼',
      '🐨',
      '🐯',
      '🦁',
      '🐮',
      '🐷',
      '🐸',
      '🐵',
    ];
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final media = MediaQuery.of(ctx);
            final avail = media.size.height - media.viewInsets.bottom;
            final double gridHeight = (avail * 0.28).clamp(120.0, 220.0);
            return AlertDialog(
              scrollable: true,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: cs.surface,
              title: Text(l10n.assistantEditEmojiDialogTitle),
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
                      value.isEmpty
                          ? '🙂'
                          : value.characters.take(1).toString(),
                      fontSize: 40,
                      optimizeEmojiAlign: true,
                      nudge: Offset.zero, // picker preview: no extra nudge
                    ),
                  ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      onChanged: (v) => setLocal(() => value = v),
                      onSubmitted: (_) {
                        if (validGrapheme(value))
                          Navigator.of(
                            ctx,
                          ).pop(value.characters.take(1).toString());
                      },
                      decoration: InputDecoration(
                        hintText: l10n.assistantEditEmojiDialogHint,
                        filled: true,
                        fillColor: Theme.of(ctx).brightness == Brightness.dark
                            ? Colors.white10
                            : const Color(0xFFF2F3F5),
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
                          borderSide: BorderSide(
                            color: cs.primary.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: gridHeight,
                      child: GridView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
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
                  child: Text(l10n.assistantEditEmojiDialogCancel),
                ),
                TextButton(
                  onPressed: validGrapheme(value)
                      ? () => Navigator.of(
                          ctx,
                        ).pop(value.characters.take(1).toString())
                      : null,
                  child: Text(
                    l10n.assistantEditEmojiDialogSave,
                    style: TextStyle(
                      color: validGrapheme(value)
                          ? cs.primary
                          : cs.onSurface.withOpacity(0.38),
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
  }

  Future<void> _inputAvatarUrl(BuildContext context, Assistant a) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        bool valid(String s) =>
            s.trim().startsWith('http://') || s.trim().startsWith('https://');
        String value = '';
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: cs.surface,
              title: Text(l10n.assistantEditImageUrlDialogTitle),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.assistantEditImageUrlDialogHint,
                  filled: true,
                  fillColor: Theme.of(ctx).brightness == Brightness.dark
                      ? Colors.white10
                      : const Color(0xFFF2F3F5),
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
                  child: Text(l10n.assistantEditImageUrlDialogCancel),
                ),
                TextButton(
                  onPressed: valid(value)
                      ? () => Navigator.of(ctx).pop(true)
                      : null,
                  child: Text(
                    l10n.assistantEditImageUrlDialogSave,
                    style: TextStyle(
                      color: valid(value)
                          ? cs.primary
                          : cs.onSurface.withOpacity(0.38),
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
      final url = controller.text.trim();
      if (url.isNotEmpty) {
        await context.read<AssistantProvider>().updateAssistant(
          a.copyWith(avatar: url),
        );
      }
    }
  }

  Future<void> _inputQQAvatar(BuildContext context, Assistant a) async {
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
          final firstWeights = <int>[128, 4, 2, 1];
          final firstTotal = firstWeights.fold<int>(0, (a, b) => a + b);
          int r2 = rnd.nextInt(firstTotal) + 1;
          int idx = 0;
          int a2 = 0;
          for (int i = 0; i < firstGroups.length; i++) {
            a2 += firstWeights[i];
            if (r2 <= a2) {
              idx = i;
              break;
            }
          }
          final group = firstGroups[idx];
          sb.write(group[rnd.nextInt(group.length)]);
          for (int i = 1; i < chosenLen; i++) {
            sb.write(rnd.nextInt(10));
          }
          return sb.toString();
        }

        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: cs.surface,
              title: Text(l10n.assistantEditQQAvatarDialogTitle),
              content: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: l10n.assistantEditQQAvatarDialogHint,
                  filled: true,
                  fillColor: Theme.of(ctx).brightness == Brightness.dark
                      ? Colors.white10
                      : const Color(0xFFF2F3F5),
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
                    const int maxTries = 20;
                    bool applied = false;
                    for (int i = 0; i < maxTries; i++) {
                      final qq = randomQQ();
                      final url =
                          'https://q2.qlogo.cn/headimg_dl?dst_uin=' +
                          qq +
                          '&spec=100';
                      try {
                        final resp = await http
                            .get(Uri.parse(url))
                            .timeout(const Duration(seconds: 5));
                        if (resp.statusCode == 200 &&
                            resp.bodyBytes.isNotEmpty) {
                          await context
                              .read<AssistantProvider>()
                              .updateAssistant(a.copyWith(avatar: url));
                          applied = true;
                          break;
                        }
                      } catch (_) {}
                    }
                    if (applied) {
                      if (Navigator.of(ctx).canPop())
                        Navigator.of(ctx).pop(false);
                    } else {
                      showAppSnackBar(
                        context,
                        message: l10n.assistantEditQQAvatarFailedMessage,
                        type: NotificationType.error,
                      );
                    }
                  },
                  child: Text(l10n.assistantEditQQAvatarRandomButton),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(l10n.assistantEditQQAvatarDialogCancel),
                    ),
                    TextButton(
                      onPressed: valid(value)
                          ? () => Navigator.of(ctx).pop(true)
                          : null,
                      child: Text(
                        l10n.assistantEditQQAvatarDialogSave,
                        style: TextStyle(
                          color: valid(value)
                              ? cs.primary
                              : cs.onSurface.withOpacity(0.38),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
    if (ok == true) {
      final qq = controller.text.trim();
      if (qq.isNotEmpty) {
        final url =
            'https://q2.qlogo.cn/headimg_dl?dst_uin=' + qq + '&spec=100';
        await context.read<AssistantProvider>().updateAssistant(
          a.copyWith(avatar: url),
        );
      }
    }
  }

  Future<void> _pickLocalImage(BuildContext context, Assistant a) async {
    if (kIsWeb) {
      await _inputAvatarUrl(context, a);
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
        await context.read<AssistantProvider>().updateAssistant(
          a.copyWith(avatar: file.path),
        );
        return;
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      showAppSnackBar(
        context,
        message: l10n.assistantEditGalleryErrorMessage,
        type: NotificationType.error,
      );
      await _inputAvatarUrl(context, a);
      return;
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      showAppSnackBar(
        context,
        message: l10n.assistantEditGeneralErrorMessage,
        type: NotificationType.error,
      );
      await _inputAvatarUrl(context, a);
      return;
    }
  }
}

class _PromptTab extends StatefulWidget {
  const _PromptTab({required this.assistantId});
  final String assistantId;

  @override
  State<_PromptTab> createState() => _PromptTabState();
}

class _PromptTabState extends State<_PromptTab> {
  late final TextEditingController _sysCtrl;
  late final TextEditingController _tmplCtrl;
  late final FocusNode _sysFocus;
  late final FocusNode _tmplFocus;
  late final TextEditingController _presetCtrl;
  bool _showPresetInput = false;
  String _presetRole = 'user';
  final GlobalKey _presetHeaderKey = GlobalKey(debugLabel: 'presetHeader');

  @override
  void initState() {
    super.initState();
    final ap = context.read<AssistantProvider>();
    final a = ap.getById(widget.assistantId)!;
    _sysCtrl = TextEditingController(text: a.systemPrompt);
    _tmplCtrl = TextEditingController(text: a.messageTemplate);
    _sysFocus = FocusNode(debugLabel: 'systemPromptFocus');
    _tmplFocus = FocusNode(debugLabel: 'messageTemplateFocus');
    _presetCtrl = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant _PromptTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assistantId != widget.assistantId) {
      final ap = context.read<AssistantProvider>();
      final a = ap.getById(widget.assistantId)!;
      _sysCtrl.text = a.systemPrompt;
      _tmplCtrl.text = a.messageTemplate;
    }
  }

  @override
  void dispose() {
    _sysCtrl.dispose();
    _tmplCtrl.dispose();
    _sysFocus.dispose();
    _tmplFocus.dispose();
    _presetCtrl.dispose();
    super.dispose();
  }

  void _insertAtCursor(TextEditingController controller, String toInsert) {
    final text = controller.text;
    final sel = controller.selection;
    final start = (sel.start >= 0 && sel.start <= text.length)
        ? sel.start
        : text.length;
    final end = (sel.end >= 0 && sel.end <= text.length && sel.end >= start)
        ? sel.end
        : start;
    final nextText = text.replaceRange(start, end, toInsert);
    controller.value = controller.value.copyWith(
      text: nextText,
      selection: TextSelection.collapsed(offset: start + toInsert.length),
      composing: TextRange.empty,
    );
  }

  void _insertNewlineAtCursor() {
    _insertAtCursor(_sysCtrl, '\n');
    final ap = context.read<AssistantProvider>();
    final a = ap.getById(widget.assistantId)!;
    ap.updateAssistant(a.copyWith(systemPrompt: _sysCtrl.text));
    setState(() {});
  }

  Future<void> _importSystemPrompt() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final res = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const ['txt','md','json','js','html','xml','py','java','kt','dart','ts','tsx','markdown','mdx','yml','yaml'],
      );
      if (res == null || res.files.isEmpty) return;
      final picked = res.files.first;
      String? content;
      if (picked.bytes != null && picked.bytes!.isNotEmpty) {
        content = utf8.decode(picked.bytes!, allowMalformed: true);
      } else if (!kIsWeb && picked.path != null && picked.path!.isNotEmpty) {
        content = await File(picked.path!).readAsString();
      }
      if (!mounted) return;
      if (content == null || content.trim().isEmpty) {
        showAppSnackBar(
          context,
          message: l10n.assistantEditSystemPromptImportEmpty,
          type: NotificationType.error,
        );
        return;
      }
      _sysCtrl.text = content;
      _sysCtrl.selection =
          TextSelection.collapsed(offset: _sysCtrl.text.length);
      final ap = context.read<AssistantProvider>();
      final a = ap.getById(widget.assistantId);
      if (a != null) {
        await ap.updateAssistant(a.copyWith(systemPrompt: _sysCtrl.text));
      }
      showAppSnackBar(
        context,
        message: l10n.assistantEditSystemPromptImportSuccess,
        type: NotificationType.success,
      );
      Future.microtask(() => _sysFocus.requestFocus());
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: l10n.assistantEditSystemPromptImportFailed,
        type: NotificationType.error,
      );
    }
  }

  Future<void> _applySystemPromptChange(String value) async {
    final ap = context.read<AssistantProvider>();
    final a = ap.getById(widget.assistantId);
    if (a == null) return;
    _sysCtrl.text = value;
    _sysCtrl.selection = TextSelection.collapsed(offset: _sysCtrl.text.length);
    await ap.updateAssistant(a.copyWith(systemPrompt: value));
    if (mounted) setState(() {});
  }

  Future<String?> _showSystemPromptMobileSheet(String initial) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _SystemPromptMobileSheet(initial: initial),
    );
  }

  Future<String?> _showSystemPromptDesktopDialog(String initial) {
    return showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'system-prompt-editor',
      barrierColor: Colors.black.withOpacity(0.12),
      pageBuilder: (ctx, _, __) {
        return _SystemPromptDesktopDialog(initial: initial);
      },
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _openSystemPromptEditor() async {
    final platform = Theme.of(context).platform;
    final bool isDesktop = kIsWeb ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux ||
        platform == TargetPlatform.windows;
    final initial = _sysCtrl.text;
    final String? next = isDesktop
        ? await _showSystemPromptDesktopDialog(initial)
        : await _showSystemPromptMobileSheet(initial);
    if (!mounted || next == null || next == _sysCtrl.text) return;
    await _applySystemPromptChange(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final ap = context.watch<AssistantProvider>();
    final a = ap.getById(widget.assistantId)!;

    Widget chips(List<String> items, void Function(String v) onPick) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in items)
              ActionChip(
                label: Text(t, style: const TextStyle(fontSize: 12)),
                onPressed: () => onPick(t),
              ),
          ],
        ),
      );
    }

    final sysVars = const [
      '{cur_date}',
      '{cur_time}',
      '{cur_datetime}',
      '{model_id}',
      '{model_name}',
      '{locale}',
      '{timezone}',
      '{system_version}',
      '{device_info}',
      '{battery_level}',
      '{nickname}',
    ];
    final tmplVars = const [
      '{{ role }}',
      '{{ message }}',
      '{{ time }}',
      '{{ date }}',
    ];

    // Helper to render link-like variable chips
    Widget linkWrap(List<String> vars, void Function(String v) onPick) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            for (final t in vars)
              InkWell(
                onTap: () => onPick(t),
                child: Text(
                  t,
                  style: TextStyle(
                    color: cs.primary,
                    decoration: TextDecoration.underline,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // Sample preview for message template
    final now = DateTime.now();
    // final ts = zh
    //     ? DateFormat('yyyy年M月d日 a h:mm:ss', 'zh').format(now)
    //     : DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    final sampleUser = l10n.assistantEditSampleUser;
    final sampleMsg = l10n.assistantEditSampleMessage;
    final sampleReply = l10n.assistantEditSampleReply;

    String processed(String tpl) {
      final t = (tpl.trim().isEmpty ? '{{ message }}' : tpl);
      // Simple replacements consistent with PromptTransformer
      final locale = Localizations.localeOf(context);
      final dateStr = locale.languageCode == 'zh'
          ? DateFormat('yyyy年M月d日', 'zh').format(now)
          : DateFormat('yyyy-MM-dd').format(now);
      final timeStr = locale.languageCode == 'zh'
          ? DateFormat('a h:mm:ss', 'zh').format(now)
          : DateFormat('HH:mm:ss').format(now);
      return t
          .replaceAll('{{ role }}', 'user')
          .replaceAll('{{ message }}', sampleMsg)
          .replaceAll('{{ time }}', timeStr)
          .replaceAll('{{ date }}', dateStr);
    }

    // System Prompt Card (no border, iOS style)
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sysCard = Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.assistantEditSystemPromptTitle,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                IosIconButton(
                  icon: Lucide.Maximize2,
                  size: 20,
                  padding: const EdgeInsets.all(8),
                  minSize: 38,
                  color: cs.primary,
                  onTap: _openSystemPromptEditor,
                  semanticLabel: l10n.assistantEditSystemPromptTitle,
                ),
                const SizedBox(width: 4),
                _IosButton(
                  label: l10n.assistantEditSystemPromptImportButton,
                  icon: Icons.file_open,
                  dense: true,
                  neutral: false,
                  onTap: _importSystemPrompt,
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _sysCtrl,
              focusNode: _sysFocus,
              onChanged: (v) => context
                  .read<AssistantProvider>()
                  .updateAssistant(a.copyWith(systemPrompt: v)),
              // minLines: 1,
              maxLines: 8,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              enableInteractiveSelection: true,
              decoration: InputDecoration(
                hintText: l10n.assistantEditSystemPromptHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withOpacity(0.35),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.primary.withOpacity(0.5)),
                ),
                contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.assistantEditAvailableVariables,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            _VarExplainList(
              items: [
                (l10n.assistantEditVariableDate, '{cur_date}'),
                (l10n.assistantEditVariableTime, '{cur_time}'),
                (l10n.assistantEditVariableDatetime, '{cur_datetime}'),
                (l10n.assistantEditVariableModelId, '{model_id}'),
                (l10n.assistantEditVariableModelName, '{model_name}'),
                (l10n.assistantEditVariableLocale, '{locale}'),
                (l10n.assistantEditVariableTimezone, '{timezone}'),
                (l10n.assistantEditVariableSystemVersion, '{system_version}'),
                (l10n.assistantEditVariableDeviceInfo, '{device_info}'),
                (l10n.assistantEditVariableBatteryLevel, '{battery_level}'),
                (l10n.assistantEditVariableNickname, '{nickname}'),
                (l10n.assistantEditVariableAssistantName, '{assistant_name}'),
              ],
              onTapVar: (v) {
                _insertAtCursor(_sysCtrl, v);
                context.read<AssistantProvider>().updateAssistant(
                  a.copyWith(systemPrompt: _sysCtrl.text),
                );
                // Restore focus to the input to keep cursor active
                Future.microtask(() => _sysFocus.requestFocus());
              },
            ),
          ],
        ),
      ),
    );

    // Template Card with preview (no border, iOS style)
    final tmplCard = Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.assistantEditMessageTemplateTitle,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _tmplCtrl,
              focusNode: _tmplFocus,
              maxLines: 4,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              enableInteractiveSelection: true,
              onChanged: (v) => context
                  .read<AssistantProvider>()
                  .updateAssistant(a.copyWith(messageTemplate: v)),
              decoration: InputDecoration(
                hintText: '{{ message }}',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withOpacity(0.35),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.primary.withOpacity(0.5)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.assistantEditAvailableVariables,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            _VarExplainList(
              items: [
                (l10n.assistantEditVariableRole, '{{ role }}'),
                (l10n.assistantEditVariableMessage, '{{ message }}'),
                (l10n.assistantEditVariableTime, '{{ time }}'),
                (l10n.assistantEditVariableDate, '{{ date }}'),
              ],
              onTapVar: (v) {
                _insertAtCursor(_tmplCtrl, v);
                context.read<AssistantProvider>().updateAssistant(
                  a.copyWith(messageTemplate: _tmplCtrl.text),
                );
                // Restore focus to the input to keep cursor active
                Future.microtask(() => _tmplFocus.requestFocus());
              },
            ),

            const SizedBox(height: 12),
            Text(
              l10n.assistantEditPreviewTitle,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 6),
            // Use real chat message widgets for preview (consistent styling)
            const SizedBox(height: 6),
            Builder(
              builder: (context) {
                final userMsg = ChatMessage(
                  role: 'user',
                  content: processed(_tmplCtrl.text),
                  conversationId: 'preview',
                );
                final botMsg = ChatMessage(
                  role: 'assistant',
                  content: sampleReply,
                  conversationId: 'preview',
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ChatMessageWidget(
                      message: userMsg,
                      showModelIcon: false,
                      showTokenStats: false,
                    ),
                    ChatMessageWidget(
                      message: botMsg,
                      showModelIcon: false,
                      showTokenStats: false,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );

    // Preset conversation card
    Widget presetCard() {
      final a = ap.getById(widget.assistantId)!;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final items = a.presetMessages;
      final isDesktop = Theme.of(context).platform == TargetPlatform.macOS || Theme.of(context).platform == TargetPlatform.linux || Theme.of(context).platform == TargetPlatform.windows;

      Widget dragWrapper({required int index, required Widget child}) {
        return isDesktop
            ? ReorderableDragStartListener(index: index, child: child)
            : ReorderableDelayedDragStartListener(index: index, child: child);
      }

      Widget headerButtons() {
        Widget makeButtons() => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _HoverPillButton(
                  icon: Lucide.User,
                  color: cs.primary,
                  label: l10n.assistantEditPresetAddUser,
                  onTap: () {
                    setState(() {
                      _presetRole = 'user';
                      _presetCtrl.text = '';
                      _showPresetInput = true;
                    });
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final ctx = _presetHeaderKey.currentContext;
                      if (ctx != null) {
                        Scrollable.ensureVisible(ctx, alignment: 0.0, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
                      }
                    });
                  },
                ),
                _HoverPillButton(
                  icon: Lucide.Bot,
                  color: cs.secondary,
                  label: l10n.assistantEditPresetAddAssistant,
                  onTap: () {
                    setState(() {
                      _presetRole = 'assistant';
                      _presetCtrl.text = '';
                      _showPresetInput = true;
                    });
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final ctx = _presetHeaderKey.currentContext;
                      if (ctx != null) {
                        Scrollable.ensureVisible(ctx, alignment: 0.0, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
                      }
                    });
                  },
                ),
              ],
            );

        return Container(
          key: _presetHeaderKey,
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              final textScale = MediaQuery.of(ctx).textScaleFactor;
              final narrow = constraints.maxWidth < 420 || textScale > 1.15;
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.assistantEditPresetTitle,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    makeButtons(),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.assistantEditPresetTitle,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                  makeButtons(),
                ],
              );
            },
          ),
        );
      }

      final baseBg = isDark ? Colors.white10 : Colors.white.withOpacity(0.96);

      return Container(
        decoration: BoxDecoration(color: baseBg, borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              headerButtons(),
              const SizedBox(height: 10),

              if (items.isEmpty)
                Text(l10n.assistantEditPresetEmpty, style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 12)),

              if (items.isNotEmpty)
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  proxyDecorator: (child, index, anim) {
                    // No extra elevation/shadow while dragging; keep rounded clip only
                    return AnimatedBuilder(
                      animation: anim,
                      builder: (_, __) => ClipRRect(borderRadius: BorderRadius.circular(18), child: child),
                    );
                  },
                  itemCount: items.length,
                  onReorder: (oldIndex, newIndex) async {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final list = List<PresetMessage>.of(a.presetMessages);
                    final item = list.removeAt(oldIndex);
                    list.insert(newIndex, item);
                    await context.read<AssistantProvider>().updateAssistant(a.copyWith(presetMessages: list));
                  },
                  itemBuilder: (ctx, i) {
                    final m = items[i];
                    final card = _PresetMessageCard(
                      role: m.role,
                      content: m.content,
                      onEdit: () async => _showEditPresetDialog(context, a, m),
                      onDelete: () async {
                        final list = List<PresetMessage>.of(a.presetMessages);
                        list.removeWhere((e) => e.id == m.id);
                        await context.read<AssistantProvider>().updateAssistant(a.copyWith(presetMessages: list));
                      },
                    );
                    return KeyedSubtree(
                      key: ValueKey(m.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: dragWrapper(index: i, child: card),
                      ),
                    );
                  },
                ),

              // Input area at the bottom
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: !_showPresetInput
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _presetCtrl,
                                minLines: 1,
                                maxLines: 6,
                                decoration: InputDecoration(
                                  hintText: _presetRole == 'assistant' ? l10n.assistantEditPresetInputHintAssistant : l10n.assistantEditPresetInputHintUser,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.35))),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary.withOpacity(0.5))),
                                  contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                                ),
                                autofocus: false,
                                onSubmitted: (_) async {
                                  final text = _presetCtrl.text.trim();
                                  if (text.isEmpty) return;
                                  final list = List<PresetMessage>.of(a.presetMessages);
                                  list.add(PresetMessage(role: _presetRole, content: text));
                                  await context.read<AssistantProvider>().updateAssistant(a.copyWith(presetMessages: list));
                                  if (!mounted) return;
                                  setState(() {
                                    _showPresetInput = false;
                                    _presetCtrl.clear();
                                  });
                                },
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _IosButton(label: l10n.assistantEditEmojiDialogCancel, onTap: () { setState(() { _showPresetInput = false; _presetCtrl.clear(); }); }, filled: false, neutral: true, dense: true),
                                  const SizedBox(width: 8),
                                  _IosButton(label: l10n.assistantEditEmojiDialogSave, onTap: () async { final text = _presetCtrl.text.trim(); if (text.isEmpty) return; final list = List<PresetMessage>.of(a.presetMessages); list.add(PresetMessage(role: _presetRole, content: text)); await context.read<AssistantProvider>().updateAssistant(a.copyWith(presetMessages: list)); if (!mounted) return; setState(() { _showPresetInput = false; _presetCtrl.clear(); }); }, filled: true, neutral: false, dense: true),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      children: [
        sysCard,
        const SizedBox(height: 12),
        tmplCard,
        const SizedBox(height: 12),
        presetCard(),
      ],
    );
  }
}

class _PresetMessageCard extends StatefulWidget {
  const _PresetMessageCard({required this.role, required this.content, required this.onEdit, required this.onDelete});
  final String role; // 'user' | 'assistant'
  final String content;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  @override
  State<_PresetMessageCard> createState() => _PresetMessageCardState();
}

class _PresetMessageCardState extends State<_PresetMessageCard> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseBg = isDark ? Colors.white10 : Colors.white.withOpacity(0.96);
    final borderColor = _hover ? cs.primary.withOpacity(isDark ? 0.35 : 0.45) : cs.outlineVariant.withOpacity(isDark ? 0.12 : 0.08);
    final icon = widget.role == 'assistant' ? Lucide.Bot : Lucide.User;
    final badgeColor = widget.role == 'assistant' ? cs.secondary : cs.primary;

    final card = Container(
      decoration: BoxDecoration(color: baseBg, borderRadius: BorderRadius.circular(18), border: Border.all(color: borderColor, width: 1.0)),
      padding: const EdgeInsets.all(14),
      constraints: const BoxConstraints(minHeight: 64),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Icon(icon, size: 18, color: badgeColor),
        const SizedBox(width: 10),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(widget.content, maxLines: 4, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, color: cs.onSurface.withOpacity(0.9))),
          ),
        ),
        const SizedBox(width: 8),
        _HoverIconButton(icon: Lucide.Settings2, onTap: widget.onEdit),
        const SizedBox(width: 4),
        _HoverIconButton(icon: Lucide.Trash2, onTap: widget.onDelete),
      ]),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: card,
    );
  }
}

class _HoverIconButton extends StatefulWidget {
  const _HoverIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  State<_HoverIconButton> createState() => _HoverIconButtonState();
}

class _HoverIconButtonState extends State<_HoverIconButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _hover ? cs.primary.withOpacity(0.10) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(widget.icon, size: 16, color: _hover ? cs.primary : cs.onSurface.withOpacity(0.9)),
        ),
      ),
    );
  }
}

class _HoverTextButton extends StatefulWidget {
  const _HoverTextButton({
    required this.label,
    required this.onTap,
    this.color,
    this.dense = false,
    this.enableHover = true,
  });

  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool dense;
  final bool enableHover;

  @override
  State<_HoverTextButton> createState() => _HoverTextButtonState();
}

class _HoverTextButtonState extends State<_HoverTextButton> {
  bool _hover = false;
  bool _press = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor =
        _press ? (widget.color ?? cs.primary).withOpacity(0.8) : (widget.color ?? cs.primary);
    final EdgeInsets padding =
        widget.dense ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8) : const EdgeInsets.symmetric(horizontal: 12, vertical: 10);
    final Color bg = (_hover || _press)
        ? (isDark ? Colors.white.withOpacity(_press ? 0.12 : 0.08) : Colors.black.withOpacity(_press ? 0.08 : 0.06))
        : Colors.transparent;

    return MouseRegion(
      onEnter: widget.enableHover ? (_) => setState(() => _hover = true) : null,
      onExit: widget.enableHover ? (_) => setState(() => _hover = false) : null,
      cursor: widget.enableHover ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _press = true),
        onTapUp: (_) => setState(() => _press = false),
        onTapCancel: () => setState(() => _press = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          padding: padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _SystemPromptMobileSheet extends StatefulWidget {
  const _SystemPromptMobileSheet({required this.initial});
  final String initial;

  @override
  State<_SystemPromptMobileSheet> createState() =>
      _SystemPromptMobileSheetState();
}

class _SystemPromptMobileSheetState extends State<_SystemPromptMobileSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.96,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 16, bottom + 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _HoverTextButton(
                  label: MaterialLocalizations.of(context).closeButtonLabel,
                  color: cs.onSurface,
                  onTap: () => Navigator.of(context).maybePop(),
                  dense: true,
                  enableHover: false,
                ),
                const Spacer(),
                _HoverTextButton(
                  label: l10n.assistantEditEmojiDialogSave,
                  color: cs.primary,
                  onTap: () => Navigator.of(context).pop(_controller.text),
                  dense: true,
                  enableHover: false,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF7F7F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: cs.outlineVariant.withOpacity(0.2),
                  ),
                ),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  keyboardType: TextInputType.multiline,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: l10n.assistantEditSystemPromptHint,
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemPromptDesktopDialog extends StatefulWidget {
  const _SystemPromptDesktopDialog({required this.initial});
  final String initial;

  @override
  State<_SystemPromptDesktopDialog> createState() =>
      _SystemPromptDesktopDialogState();
}

class _SystemPromptDesktopDialogState
    extends State<_SystemPromptDesktopDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860, maxHeight: 660),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: cs.outlineVariant.withOpacity(isDark ? 0.22 : 0.18),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.assistantEditSystemPromptTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _HoverTextButton(
                          label: MaterialLocalizations.of(context)
                              .closeButtonLabel,
                          color: cs.onSurface,
                          onTap: () => Navigator.of(context).maybePop(),
                          dense: true,
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    thickness: 0.6,
                    color: cs.outlineVariant.withOpacity(0.14),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white10
                              : const Color(0xFFF7F7F9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: cs.outlineVariant.withOpacity(0.2),
                          ),
                        ),
                        child: TextField(
                          controller: _controller,
                          autofocus: true,
                          expands: true,
                          maxLines: null,
                          minLines: null,
                          keyboardType: TextInputType.multiline,
                          textAlignVertical: TextAlignVertical.top,
                          decoration: InputDecoration(
                            hintText: l10n.assistantEditSystemPromptHint,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.fromLTRB(
                                14, 14, 14, 14),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _HoverTextButton(
                        label: l10n.assistantEditEmojiDialogSave,
                        color: cs.primary,
                        onTap: () =>
                            Navigator.of(context).pop(_controller.text),
                        dense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HoverPillButton extends StatefulWidget {
  const _HoverPillButton({required this.icon, required this.color, required this.label, required this.onTap});
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  @override
  State<_HoverPillButton> createState() => _HoverPillButtonState();
}

class _HoverPillButtonState extends State<_HoverPillButton> {
  bool _hover = false;
  bool _press = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _press = true),
        onTapCancel: () => setState(() => _press = false),
        onTapUp: (_) => setState(() => _press = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: widget.color.withOpacity(_press ? 0.18 : _hover ? 0.14 : 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(widget.icon, size: 14, color: widget.color),
            const SizedBox(width: 6),
            Text(widget.label, style: TextStyle(color: widget.color, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

Future<void> _showEditPresetDialog(BuildContext context, Assistant a, PresetMessage m) async {
  final l10n = AppLocalizations.of(context)!;
  final cs = Theme.of(context).colorScheme;
  final controller = TextEditingController(text: m.content);
  final platform = Theme.of(context).platform;
  final isDesktop = platform == TargetPlatform.macOS || platform == TargetPlatform.linux || platform == TargetPlatform.windows;
  Future<void> save() async {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    final list = List<PresetMessage>.of(a.presetMessages);
    final idx = list.indexWhere((e) => e.id == m.id);
    if (idx != -1) {
      list[idx] = list[idx].copyWith(content: text);
    }
    await context.read<AssistantProvider>().updateAssistant(a.copyWith(presetMessages: list));
  }
  if (isDesktop) {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(l10n.assistantEditPresetEditDialogTitle, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
                    IconButton(
                      tooltip: MaterialLocalizations.of(ctx).closeButtonTooltip,
                      icon: const Icon(Lucide.X, size: 18),
                      color: cs.onSurface,
                      onPressed: () => Navigator.of(ctx).maybePop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  minLines: 3,
                  maxLines: 8,
                  decoration: InputDecoration(
                    hintText: m.role == 'assistant' ? l10n.assistantEditPresetInputHintAssistant : l10n.assistantEditPresetInputHintUser,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary.withOpacity(0.5))),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _IosButton(label: l10n.assistantEditEmojiDialogCancel, onTap: () => Navigator.of(ctx).pop(), filled: false, neutral: true, dense: true),
                    const SizedBox(width: 8),
                    _IosButton(label: l10n.assistantEditEmojiDialogSave, onTap: () async { await save(); if (context.mounted) Navigator.of(ctx).pop(); }, filled: true, neutral: false, dense: true),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) {
      final bottom = MediaQuery.of(ctx).viewInsets.bottom;
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Lucide.MessageSquare, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l10n.assistantEditPresetEditDialogTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                minLines: 1,
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: m.role == 'assistant' ? l10n.assistantEditPresetInputHintAssistant : l10n.assistantEditPresetInputHintUser,
                  filled: true,
                  fillColor: Theme.of(ctx).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF7F7F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.2))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cs.primary.withOpacity(0.5))),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _IosButton(
                      label: l10n.assistantEditEmojiDialogCancel,
                      icon: Lucide.X,
                      onTap: () => Navigator.of(ctx).pop(),
                      filled: false,
                      neutral: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _IosButton(
                      label: l10n.assistantEditEmojiDialogSave,
                      icon: Lucide.Check,
                      onTap: () async { await save(); if (context.mounted) Navigator.of(ctx).pop(); },
                      filled: true,
                      neutral: false,
                    ),
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

class _VarExplainList extends StatelessWidget {
  const _VarExplainList({required this.items, required this.onTapVar});
  final List<(String, String)> items; // (label, var)
  final ValueChanged<String> onTapVar;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        for (final it in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${it.$1}: ',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withOpacity(0.75),
                ),
              ),
              InkWell(
                onTap: () => onTapVar(it.$2),
                child: Text(
                  it.$2,
                  style: TextStyle(
                    color: cs.primary,
                    decoration: TextDecoration.underline,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _McpTab extends StatelessWidget {
  const _McpTab({required this.assistantId});
  final String assistantId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final ap = context.watch<AssistantProvider>();
    final a = ap.getById(assistantId)!;
    final mcp = context.watch<McpProvider>();
    final servers = mcp.servers
        .where((s) => mcp.statusFor(s.id) == McpStatus.connected)
        .toList();

    if (servers.isEmpty) {
      return Center(
        child: Text(
          l10n.assistantEditMcpNoServersMessage,
          style: TextStyle(color: cs.onSurface.withOpacity(0.6)),
        ),
      );
    }

    Widget tag(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.primary.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: cs.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      itemCount: servers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final s = servers[index];
        final tools = s.tools;
        final enabledTools = tools.where((t) => t.enabled).length;
        final isSelected = a.mcpServerIds.contains(s.id);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bg = isSelected
            ? cs.primary.withOpacity(isDark ? 0.12 : 0.10)
            : (isDark ? Colors.white10 : cs.surface);
        final borderColor = isSelected
            ? cs.primary.withOpacity(0.45)
            : cs.outlineVariant.withOpacity(0.25);

        return _TactileRow(
          onTap: () async {
            final set = a.mcpServerIds.toSet();
            if (isSelected)
              set.remove(s.id);
            else
              set.add(s.id);
            await context.read<AssistantProvider>().updateAssistant(
              a.copyWith(mcpServerIds: set.toList()),
            );
          },
          pressedScale: 1.0, // No scale on press
          builder: (pressed) {
            final overlayBg = pressed
                ? (isDark
                    ? Color.alphaBlend(Colors.white.withOpacity(0.06), bg)
                    : Color.alphaBlend(Colors.black.withOpacity(0.05), bg))
                : bg;
            return Container(
              decoration: BoxDecoration(
                color: overlayBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor, width: 0.6),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white10
                            : const Color(0xFFF2F3F5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Lucide.Terminal, size: 20, color: cs.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  s.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              tag(l10n.assistantEditMcpConnectedTag),
                              tag(
                                l10n.assistantEditMcpToolsCountTag(
                                  enabledTools.toString(),
                                  tools.length.toString(),
                                ),
                              ),
                              tag(
                                s.transport == McpTransportType.inmemory
                                    ? AppLocalizations.of(context)!.mcpTransportTagInmemory
                                    : (s.transport == McpTransportType.sse ? 'SSE' : 'HTTP'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    IosSwitch(
                      value: isSelected,
                      onChanged: (v) async {
                        final set = a.mcpServerIds.toSet();
                        if (v)
                          set.add(s.id);
                        else
                          set.remove(s.id);
                        await context.read<AssistantProvider>().updateAssistant(
                          a.copyWith(mcpServerIds: set.toList()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _QuickPhraseTab extends StatelessWidget {
  const _QuickPhraseTab({required this.assistantId});
  final String assistantId;

  Future<void> _showAddEditSheet(
    BuildContext context, {
    QuickPhrase? phrase,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    // Desktop: custom dialog; Mobile: bottom sheet
    final platform = Theme.of(context).platform;
    final isDesktop = platform == TargetPlatform.macOS || platform == TargetPlatform.linux || platform == TargetPlatform.windows;
    if (isDesktop) {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) {
          final titleCtrl = TextEditingController(text: phrase?.title ?? '');
          final contentCtrl = TextEditingController(text: phrase?.content ?? '');
          return Dialog(
            backgroundColor: cs.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 44,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              phrase == null ? l10n.quickPhraseAddTitle : l10n.quickPhraseEditTitle,
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                            ),
                          ),
                          IconButton(
                            tooltip: MaterialLocalizations.of(ctx).closeButtonTooltip,
                            icon: const Icon(Lucide.X, size: 18),
                            color: cs.onSurface,
                            onPressed: () => Navigator.of(ctx).maybePop(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: titleCtrl,
                          decoration: InputDecoration(
                            labelText: l10n.quickPhraseTitleLabel,
                            filled: true,
                            fillColor: Theme.of(ctx).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF2F3F5),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.4))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary.withOpacity(0.5))),
                          ),
                          autofocus: true,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: contentCtrl,
                          maxLines: 5,
                          decoration: InputDecoration(
                            labelText: l10n.quickPhraseContentLabel,
                            alignLabelWithHint: true,
                            filled: true,
                            fillColor: Theme.of(ctx).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF2F3F5),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.4))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary.withOpacity(0.5))),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _IosButton(label: l10n.quickPhraseCancelButton, onTap: () => Navigator.of(ctx).pop(), filled: false, neutral: true, dense: true),
                            const SizedBox(width: 8),
                            _IosButton(
                              label: l10n.quickPhraseSaveButton,
                              onTap: () async {
                                final title = titleCtrl.text.trim();
                                final content = contentCtrl.text.trim();
                                if (title.isEmpty || content.isEmpty) return;
                                if (phrase == null) {
                                  final newPhrase = QuickPhrase(id: const Uuid().v4(), title: title, content: content, isGlobal: false, assistantId: assistantId);
                                  await context.read<QuickPhraseProvider>().add(newPhrase);
                                } else {
                                  await context.read<QuickPhraseProvider>().update(phrase.copyWith(title: title, content: content));
                                }
                                if (context.mounted) Navigator.of(ctx).pop();
                              },
                              filled: true,
                              neutral: false,
                              dense: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      return;
    }
    final result = await showModalBottomSheet<Map<String, String>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return _QuickPhraseEditSheet(phrase: phrase, assistantId: assistantId);
      },
    );

    if (result != null) {
      final title = result['title']?.trim() ?? '';
      final content = result['content']?.trim() ?? '';

      if (title.isEmpty || content.isEmpty) return;

      if (phrase == null) {
        // Add new
        final newPhrase = QuickPhrase(
          id: const Uuid().v4(),
          title: title,
          content: content,
          isGlobal: false,
          assistantId: assistantId,
        );
        await context.read<QuickPhraseProvider>().add(newPhrase);
      } else {
        // Update existing
        await context.read<QuickPhraseProvider>().update(
          phrase.copyWith(title: title, content: content),
        );
      }
    }
  }

  Future<void> _deletePhrase(BuildContext context, QuickPhrase phrase) async {
    await context.read<QuickPhraseProvider>().delete(phrase.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final quickPhraseProvider = context.watch<QuickPhraseProvider>();
    final phrases = quickPhraseProvider.getForAssistant(assistantId);

    if (phrases.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Lucide.Zap, size: 64, color: cs.primary.withOpacity(0.6)),
              const SizedBox(height: 16),
              Text(
                l10n.assistantEditQuickPhraseDescription,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 200),
                child: _IosButton(
                  label: l10n.assistantEditAddQuickPhraseButton,
                  icon: Lucide.Plus,
                  filled: true,
                  neutral: false,
                  onTap: () => _showAddEditSheet(context),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
          itemCount: phrases.length,
          buildDefaultDragHandles: false,
          proxyDecorator: (child, index, animation) {
            return AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                final t = Curves.easeOut.transform(animation.value);
                return Transform.scale(
                  scale: 0.98 + 0.02 * t,
                  child: child,
                );
              },
            );
          },
          onReorder: (oldIndex, newIndex) {
            if (newIndex > oldIndex) newIndex -= 1;
            // Update immediately for smooth drop animation
            context.read<QuickPhraseProvider>().reorderPhrases(
                  oldIndex: oldIndex,
                  newIndex: newIndex,
                  assistantId: assistantId,
                );
          },
          itemBuilder: (context, index) {
            final phrase = phrases[index];
            return KeyedSubtree(
              key: ValueKey('reorder-assistant-quick-phrase-${phrase.id}'),
              child: ReorderableDelayedDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Slidable(
                    key: ValueKey(phrase.id),
                    endActionPane: ActionPane(
                      motion: const StretchMotion(),
                      extentRatio: 0.35,
                      children: [
                        CustomSlidableAction(
                          autoClose: true,
                          backgroundColor: Colors.transparent,
                          child: Container(
                            width: double.infinity,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? cs.error.withOpacity(0.22)
                                  : cs.error.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cs.error.withOpacity(0.35)),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            alignment: Alignment.center,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Lucide.Trash2, color: cs.error, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    l10n.quickPhraseDeleteButton,
                                    style: TextStyle(
                                      color: cs.error,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          onPressed: (_) => _deletePhrase(context, phrase),
                        ),
                      ],
                    ),
                    child: _TactileRow(
                      onTap: () => _showAddEditSheet(context, phrase: phrase),
                      pressedScale: 0.98,
                      builder: (pressed) {
                        final bg = isDark ? Colors.white10 : Colors.white.withOpacity(0.96);
                        final overlay = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05);
                        final pressedBg = Color.alphaBlend(overlay, bg);
                        return Container(
                          decoration: BoxDecoration(
                            color: pressed ? pressedBg : bg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: cs.outlineVariant.withOpacity(isDark ? 0.08 : 0.06),
                              width: 0.6,
                            ),
                          ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    Lucide.botMessageSquare,
                                    size: 18,
                                    color: cs.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      phrase.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Lucide.ChevronRight,
                                    size: 18,
                                    color: cs.onSurface.withOpacity(0.4),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                phrase.content,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: cs.onSurface.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        // Glass circular add button (icon-only), matching providers multi-select style
        Positioned(
          left: 0,
          right: 0,
          bottom: 60,
          child: Center(
            child: _GlassCircleButtonQP(
              icon: Lucide.Plus,
              color: cs.primary,
              onTap: () => _showAddEditSheet(context),
            ),
          ),
        ),
      ],
    );
  }
}

// Local glass circle button for Quick Phrase (icon-only, frosted background)
class _GlassCircleButtonQP extends StatefulWidget {
  const _GlassCircleButtonQP({required this.icon, required this.color, required this.onTap, this.size = 48});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size; // diameter

  @override
  State<_GlassCircleButtonQP> createState() => _GlassCircleButtonQPState();
}

class _GlassCircleButtonQPState extends State<_GlassCircleButtonQP> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final glassBase = isDark ? Colors.black.withOpacity(0.06) : Colors.white.withOpacity(0.06);
    final overlay = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05);
    final tileColor = _pressed ? Color.alphaBlend(overlay, glassBase) : glassBase;
    final borderColor = cs.outlineVariant.withOpacity(isDark ? 0.10 : 0.10);

    final child = SizedBox(
      width: widget.size,
      height: widget.size,
      child: Center(child: Icon(widget.icon, size: 18, color: widget.color)),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () { Haptics.light(); widget.onTap(); },
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 36, sigmaY: 36),
            child: Container(
              decoration: BoxDecoration(
                color: tileColor,
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 1.0),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickPhraseEditSheet extends StatefulWidget {
  const _QuickPhraseEditSheet({
    required this.phrase,
    required this.assistantId,
  });

  final QuickPhrase? phrase;
  final String? assistantId;

  @override
  State<_QuickPhraseEditSheet> createState() => _QuickPhraseEditSheetState();
}

class _QuickPhraseEditSheetState extends State<_QuickPhraseEditSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.phrase?.title ?? '');
    _contentController = TextEditingController(
      text: widget.phrase?.content ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 12),
            Center(
              child: Text(
                widget.phrase == null
                    ? l10n.quickPhraseAddTitle
                    : l10n.quickPhraseEditTitle,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.quickPhraseTitleLabel,
                filled: true,
                fillColor: isDark ? Colors.white10 : const Color(0xFFF2F3F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withOpacity(0.4),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withOpacity(0.4),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.primary.withOpacity(0.5)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: l10n.quickPhraseContentLabel,
                alignLabelWithHint: true,
                filled: true,
                fillColor: isDark ? Colors.white10 : const Color(0xFFF2F3F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withOpacity(0.4),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withOpacity(0.4),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.primary.withOpacity(0.5)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: _IosButton(
                      label: l10n.quickPhraseCancelButton,
                      onTap: () => Navigator.of(context).pop(),
                      filled: false,
                      neutral: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: _IosButton(
                      label: l10n.quickPhraseSaveButton,
                      onTap: () {
                        Navigator.of(context).pop({
                          'title': _titleController.text,
                          'content': _contentController.text,
                        });
                      },
                      icon: Lucide.Check,
                      filled: true,
                      neutral: false,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SegTabBar extends StatelessWidget {
  const _SegTabBar({required this.controller, required this.tabs});
  final TabController controller;
  final List<String> tabs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    const double outerHeight = 44;
    const double innerPadding = 4; // gap between shell and selected block
    const double gap = 6; // spacing between segments
    const double minSegWidth = 88; // ensure readability; scroll if not enough
    final double pillRadius = 18;
    final double innerRadius =
        ((pillRadius - innerPadding).clamp(0.0, pillRadius)).toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availWidth = constraints.maxWidth;
        final double innerAvailWidth = availWidth - innerPadding * 2;
        final double segWidth = math.max(
          minSegWidth,
          (innerAvailWidth - gap * (tabs.length - 1)) / tabs.length,
        );
        final double rowWidth = segWidth * tabs.length + gap * (tabs.length - 1);

        final Color shellBg = isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.white; // 白底胶囊，无边框阴影

        List<Widget> children = [];
        for (int index = 0; index < tabs.length; index++) {
          final bool selected = controller.index == index;
          children.add(
            SizedBox(
              width: segWidth,
              height: double.infinity,
              child: _TactileRow(
                onTap: () => controller.animateTo(index),
                builder: (pressed) {
                  // 背景不随按压变化：仅选中时有浅主题底色，未选中透明
                  final Color baseBg = selected
                      ? cs.primary.withOpacity(0.14)
                      : Colors.transparent;
                  final Color bg = baseBg; // 不叠加遮罩，不改变底色

                  // 仅文字在按压时变浅并有渐变
                  final Color baseTextColor = selected
                      ? cs.primary // 选中文字：主题色
                      : cs.onSurface.withOpacity(0.82); // 未选中：深灰
                  final Color targetTextColor = pressed
                      ? Color.lerp(baseTextColor, Colors.white, 0.22) ?? baseTextColor
                      : baseTextColor;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(innerRadius), // 选中块圆角
                    ),
                    alignment: Alignment.center,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: TweenAnimationBuilder<Color?>(
                        tween: ColorTween(end: targetTextColor),
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOutCubic,
                        builder: (context, color, _) {
                          return Text(
                            tabs[index],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color ?? baseTextColor,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          );
          if (index != tabs.length - 1) {
            children.add(const SizedBox(width: gap));
          }
        }

        return Container(
          height: outerHeight,
          decoration: BoxDecoration(
            color: shellBg,
            borderRadius: BorderRadius.circular(pillRadius),
          ),
          clipBehavior: Clip.hardEdge,
          child: Padding(
            padding: const EdgeInsets.all(innerPadding),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: innerAvailWidth),
                child: SizedBox(
                  width: rowWidth,
                  child: Row(children: children),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.label,
    required this.onChanged,
  });
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String label;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceVariant.withOpacity(
            Theme.of(context).brightness == Brightness.dark ? 0.18 : 0.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cs.onSurface.withOpacity(0.7),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Expanded(
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: divisions,
                  label: label,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.label,
    required this.controller,
    this.hint,
    this.onChanged,
    this.enabled = true,
    this.suffix,
    this.keyboardType,
    this.hideLabel = false,
  });
  final String label;
  final TextEditingController controller;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final bool hideLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hideLabel) ...[
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
        ],
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : const Color(0xFFF7F7F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  enabled: enabled,
                  controller: controller,
                  keyboardType: keyboardType,
                  onChanged: onChanged,
                  decoration: InputDecoration(
                    hintText: hint,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              if (suffix != null) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: suffix!,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AssistantModelCard extends StatelessWidget {
  const _AssistantModelCard({
    required this.title,
    required this.subtitle,
    required this.onPick,
    this.onLongPress,
    this.providerKey,
    this.modelId,
  });

  final String title;
  final String subtitle;
  final VoidCallback onPick;
  final VoidCallback? onLongPress;
  final String? providerKey;
  final String? modelId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String display = l10n.assistantEditModelUseGlobalDefault;
    String brandName = display;
    if (providerKey != null && modelId != null) {
      try {
        final settings = context.read<SettingsProvider>();
        final cfg = settings.getProviderConfig(providerKey!);
        final ov = cfg.modelOverrides[modelId] as Map?;
        brandName = cfg.name.isNotEmpty ? cfg.name : providerKey!;
        final mdl = (ov != null && (ov['name'] as String?)?.isNotEmpty == true)
            ? (ov['name'] as String)
            : modelId!;
        display = mdl;
      } catch (_) {
        brandName = providerKey ?? '';
        display = modelId ?? '';
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.7)),
        ),
        const SizedBox(height: 10),
        Material(
          color: isDark ? Colors.white10 : cs.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPick,
            onLongPress: onLongPress,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : cs.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
                boxShadow: isDark ? [] : AppShadows.soft,
              ),
              child: Row(
                children: [
                  _BrandAvatarLike(name: (modelId ?? display), size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      display,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Lucide.ChevronRight,
                    size: 18,
                    color: cs.onSurface.withOpacity(0.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BrandAvatarLike extends StatelessWidget {
  const _BrandAvatarLike({required this.name, this.size = 20});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Map known names to brand assets used in default_model_page
    String? asset;
    asset = BrandAssets.assetForName(name);
    if (asset != null) {
      if (asset!.endsWith('.svg')) {
        final isColorful = asset!.contains('color');
        final ColorFilter? tint = (isDark && !isColorful)
            ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
            : null;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : cs.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: SvgPicture.asset(
            asset!,
            width: size * 0.62,
            height: size * 0.62,
            colorFilter: tint,
          ),
        );
      } else {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : cs.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Image.asset(
            asset!,
            width: size * 0.62,
            height: size * 0.62,
            fit: BoxFit.contain,
          ),
        );
      }
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : cs.primary.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
        style: TextStyle(
          color: cs.primary,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}

// --- iOS-style helpers ---

class _TactileIconButton extends StatefulWidget {
  const _TactileIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.size = 22,
    this.haptics = true,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;
  final double size;
  final bool haptics;

  @override
  State<_TactileIconButton> createState() => _TactileIconButtonState();
}

class _TactileIconButtonState extends State<_TactileIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final base = widget.color;
    final pressColor = base.withOpacity(0.7);
    final icon = Icon(
      widget.icon,
      size: widget.size,
      color: _pressed ? pressColor : base,
      semanticLabel: widget.semanticLabel,
    );
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          if (widget.haptics) Haptics.light();
          // Close IME when tapping buttons
          FocusManager.instance.primaryFocus?.unfocus();
          widget.onTap();
        },
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                if (widget.haptics) Haptics.light();
                widget.onLongPress!.call();
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: icon,
        ),
      ),
    );
  }
}

Widget _iosSectionCard({required List<Widget> children}) {
  return Builder(builder: (context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final Color bg = isDark ? Colors.white10 : Colors.white.withOpacity(0.96);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outlineVariant.withOpacity(isDark ? 0.08 : 0.06),
          width: 0.6,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(children: children),
      ),
    );
  });
}

Widget _iosDivider(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Divider(
    height: 6,
    thickness: 0.6,
    indent: 54,
    endIndent: 12,
    color: cs.outlineVariant.withOpacity(0.18),
  );
}

class _AnimatedPressColor extends StatelessWidget {
  const _AnimatedPressColor({
    required this.pressed,
    required this.base,
    required this.builder,
  });
  final bool pressed;
  final Color base;
  final Widget Function(Color color) builder;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final target = pressed
        ? (Color.lerp(base, isDark ? Colors.black : Colors.white, 0.55) ?? base)
        : base;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: target),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, color, _) => builder(color ?? base),
    );
  }
}

class _TactileRow extends StatefulWidget {
  const _TactileRow({
    required this.builder,
    this.onTap,
    this.haptics = true,
    this.pressedScale = 1.0,
  });
  final Widget Function(bool pressed) builder;
  final VoidCallback? onTap;
  final bool haptics;
  final double pressedScale;

  @override
  State<_TactileRow> createState() => _TactileRowState();
}

class _TactileRowState extends State<_TactileRow> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    Widget child = widget.builder(_pressed);
    if (widget.pressedScale != 1.0) {
      child = AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: child,
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
      onTapUp: widget.onTap == null
          ? null
          : (_) async {
              await Future.delayed(const Duration(milliseconds: 60));
              if (mounted) _setPressed(false);
            },
      onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptics && context.read<SettingsProvider>().hapticsOnListItemTap) Haptics.soft();
              // Close IME when tapping segmented/tab rows or list items
              FocusManager.instance.primaryFocus?.unfocus();
              widget.onTap!.call();
            },
      child: child,
    );
  }
}

Widget _iosNavRow(
  BuildContext context, {
  required IconData icon,
  required String label,
  String? detailText,
  Widget? accessory,
  VoidCallback? onTap,
}) {
  final cs = Theme.of(context).colorScheme;
  final interactive = onTap != null;
  return _TactileRow(
    onTap: onTap,
    haptics: true,
    builder: (pressed) {
      final baseColor = cs.onSurface.withOpacity(0.9);
      return _AnimatedPressColor(
        pressed: pressed,
        base: baseColor,
        builder: (c) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                SizedBox(width: 36, child: Icon(icon, size: 20, color: c)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 15, color: c),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (detailText != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      detailText,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withOpacity(0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (accessory != null) accessory,
                if (interactive) Icon(Lucide.ChevronRight, size: 16, color: c),
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _iosSwitchRow(
  BuildContext context, {
  required IconData icon,
  required String label,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  final cs = Theme.of(context).colorScheme;
  return _TactileRow(
    onTap: () => onChanged(!value),
    builder: (pressed) {
      final baseColor = cs.onSurface.withOpacity(0.9);
      return _AnimatedPressColor(
        pressed: pressed,
        base: baseColor,
        builder: (c) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 36, child: Icon(icon, size: 20, color: c)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label, style: TextStyle(fontSize: 15, color: c)),
                ),
                IosSwitch(value: value, onChanged: onChanged),
              ],
            ),
          );
        },
      );
    },
  );
}

class _IosButton extends StatefulWidget {
  const _IosButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.filled = false,
    this.neutral = true, // Use neutral colors by default for chat background
    this.dense = false,
  });
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool filled;
  final bool neutral; // If true, use neutral colors instead of primary
  final bool dense;

  @override
  State<_IosButton> createState() => _IosButtonState();
}

class _IosButtonState extends State<_IosButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Determine if this is a Material icon (needs more spacing)
    final isMaterialIcon = widget.icon != null && 
        (widget.icon == Icons.image || widget.icon.runtimeType.toString().contains('MaterialIcons'));

    final iconColor = widget.filled 
        ? cs.onPrimary 
        : (widget.neutral ? cs.onSurface.withOpacity(0.75) : cs.primary);
    
    final textColor = widget.filled
        ? cs.onPrimary
        : (widget.neutral ? cs.onSurface.withOpacity(0.9) : cs.primary);
    
    final borderColor = widget.neutral 
        ? cs.outlineVariant.withOpacity(0.35)
        : cs.primary.withOpacity(0.45);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        Haptics.soft();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            color: widget.filled
                ? cs.primary
                : (isDark ? Colors.white10 : const Color(0xFFF2F3F5)),
            borderRadius: BorderRadius.circular(12),
            border: widget.filled
                ? null
                : Border.all(color: borderColor),
          ),
          padding: EdgeInsets.symmetric(vertical: widget.dense ? 8 : 12, horizontal: widget.dense ? 12 : 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Padding(
                  padding: EdgeInsets.only(left: isMaterialIcon ? 2.0 : 0.0),
                  child: Icon(
                    widget.icon,
                    size: 18,
                    color: iconColor,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: widget.dense ? 13 : 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== Desktop Assistant Dialog (reuses mobile tabs) =====

enum _AssistantDesktopMenu { basic, prompts, memory, quick, custom, regex }

Future<void> showAssistantDesktopDialog(BuildContext context, {required String assistantId}) async {
  final cs = Theme.of(context).colorScheme;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return Dialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860, maxHeight: 640),
          child: _DesktopAssistantDialogShell(assistantId: assistantId),
        ),
      );
    },
  );
}

class _DesktopAssistantDialogShell extends StatefulWidget {
  const _DesktopAssistantDialogShell({required this.assistantId});
  final String assistantId;
  @override
  State<_DesktopAssistantDialogShell> createState() => _DesktopAssistantDialogShellState();
}

class _DesktopAssistantDialogShellState extends State<_DesktopAssistantDialogShell> {
  _AssistantDesktopMenu _menu = _AssistantDesktopMenu.basic;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final a = context.watch<AssistantProvider>().getById(widget.assistantId);
    final name = a?.name ?? AppLocalizations.of(context)!.assistantEditPageTitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: const Icon(Lucide.X, size: 18),
                  color: cs.onSurface,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
        ),
        Divider(height: 1, thickness: 0.5, color: cs.outlineVariant.withOpacity(0.12)),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DesktopAssistantMenu(
                selected: _menu,
                onSelect: (m) => setState(() => _menu = m),
              ),
              VerticalDivider(width: 1, thickness: 0.5, color: cs.outlineVariant.withOpacity(0.12)),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeOutCubic,
                  child: () {
                    switch (_menu) {
                      case _AssistantDesktopMenu.basic:
                        return _DesktopAssistantBasicPane(assistantId: widget.assistantId, key: const ValueKey('basic'));
                      case _AssistantDesktopMenu.prompts:
                        return _PromptTab(assistantId: widget.assistantId);
                      case _AssistantDesktopMenu.memory:
                        return _MemoryTab(assistantId: widget.assistantId);
                      case _AssistantDesktopMenu.quick:
                        return _QuickPhraseTab(assistantId: widget.assistantId);
                      case _AssistantDesktopMenu.custom:
                        return _CustomRequestTab(assistantId: widget.assistantId);
                      case _AssistantDesktopMenu.regex:
                        return AssistantRegexDesktopPane(assistantId: widget.assistantId);
                    }
                  }(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DesktopAssistantMenu extends StatefulWidget {
  const _DesktopAssistantMenu({required this.selected, required this.onSelect});
  final _AssistantDesktopMenu selected;
  final ValueChanged<_AssistantDesktopMenu> onSelect;
  @override
  State<_DesktopAssistantMenu> createState() => _DesktopAssistantMenuState();
}

class _DesktopAssistantMenuState extends State<_DesktopAssistantMenu> {
  int _hover = -1;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = <(_AssistantDesktopMenu, String)>[
      (_AssistantDesktopMenu.basic, l10n.assistantEditPageBasicTab),
      (_AssistantDesktopMenu.prompts, l10n.assistantEditPagePromptsTab),
      (_AssistantDesktopMenu.memory, l10n.assistantEditPageMemoryTab),
      (_AssistantDesktopMenu.quick, l10n.assistantEditPageQuickPhraseTab),
      (_AssistantDesktopMenu.custom, l10n.assistantEditPageCustomTab),
      (_AssistantDesktopMenu.regex, l10n.assistantEditPageRegexTab),
    ];
    return SizedBox(
      width: 220,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) {
          final selected = widget.selected == items[i].$1;
          final bg = selected
              ? cs.primary.withOpacity(0.10)
              : (_hover == i
                  ? (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04))
                  : Colors.transparent);
          final fg = selected ? cs.primary : cs.onSurface.withOpacity(0.9);
          return MouseRegion(
            onEnter: (_) => setState(() => _hover = i),
            onExit: (_) => setState(() => _hover = -1),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => widget.onSelect(items[i].$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    items[i].$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w400, color: fg, decoration: TextDecoration.none),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DesktopAssistantBasicPane extends StatefulWidget {
  const _DesktopAssistantBasicPane({required this.assistantId, super.key});
  final String assistantId;
  @override
  State<_DesktopAssistantBasicPane> createState() => _DesktopAssistantBasicPaneState();
}

class _DesktopAssistantBasicPaneState extends State<_DesktopAssistantBasicPane> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _maxTokensCtrl;
  bool _hoverChatModel = false;
  bool _hoverBgChooser = false;
  final GlobalKey _avatarKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final a = context.read<AssistantProvider>().getById(widget.assistantId)!;
    _nameCtrl = TextEditingController(text: a.name);
    _maxTokensCtrl = TextEditingController(text: a.maxTokens?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant _DesktopAssistantBasicPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assistantId != widget.assistantId) {
      final a = context.read<AssistantProvider>().getById(widget.assistantId)!;
      _nameCtrl.text = a.name;
      _maxTokensCtrl.text = a.maxTokens?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _maxTokensCtrl.dispose();
    super.dispose();
  }

  String _tempTitle(BuildContext context) {
    final lc = Localizations.localeOf(context).languageCode;
    if (lc.startsWith('zh')) return '温度';
    return 'Temperature';
  }

  String _topPTitle(BuildContext context) {
    final lc = Localizations.localeOf(context).languageCode;
    if (lc.startsWith('zh')) return 'Top‑p';
    return 'Top‑p';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ap = context.watch<AssistantProvider>();
    final a = ap.getById(widget.assistantId)!;

    Widget header() {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Assistant avatar (display only)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              key: _avatarKey,
              onTapDown: (_) => _openAssistantAvatarMenu(context, a),
              child: Builder(builder: (context) {
              final av = a.avatar?.trim() ?? '';
              Widget inner;
              if (av.isEmpty) {
                inner = Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: cs.primary.withOpacity(0.15), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(
                    (a.name.isNotEmpty ? a.name.characters.first : '?'),
                    style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700, fontSize: 22),
                  ),
                );
              } else if (av.startsWith('http')) {
                inner = ClipOval(
                  child: Image.network(av, width: 56, height: 56, fit: BoxFit.cover),
                );
              } else if (av.startsWith('/') || av.contains(':')) {
                final fixed = SandboxPathResolver.fix(av);
                final f = File(fixed);
                if (f.existsSync()) {
                  inner = ClipOval(
                    child: Image.file(f, width: 56, height: 56, fit: BoxFit.cover),
                  );
                } else {
                  inner = Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: cs.primary.withOpacity(0.15), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text((a.name.isNotEmpty ? a.name.characters.first : '?'), style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700, fontSize: 22)),
                  );
                }
              } else {
                inner = Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: cs.primary.withOpacity(0.15), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(av.characters.take(1).toString(), style: const TextStyle(fontSize: 26)),
                );
              }
                return inner;
              }),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Focus(
                onFocusChange: (has) async {
                  if (!has) {
                    final v = _nameCtrl.text.trim();
                    await context.read<AssistantProvider>().updateAssistant(a.copyWith(name: v));
                  }
                },
                child: TextField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: l10n.assistantEditAssistantNameLabel,
                    isDense: true,
                    filled: true,
                    fillColor: isDark ? Colors.white10 : const Color(0xFFF7F7F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: cs.primary.withOpacity(0.5)),
                    ),
                  ),
                  onSubmitted: (v) => context.read<AssistantProvider>().updateAssistant(a.copyWith(name: v.trim())),
                  onEditingComplete: () => context.read<AssistantProvider>().updateAssistant(a.copyWith(name: _nameCtrl.text.trim())),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget labelWithHelp(String text, String help) {
      // Keep icon right next to the text (not at the far right)
      return Align(
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            Tooltip(
              message: help,
              decoration: BoxDecoration(color: cs.surfaceVariant, borderRadius: BorderRadius.circular(8)),
              // Use themed text to respect user-selected fonts
              textStyle: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface),
              waitDuration: const Duration(milliseconds: 300),
              child: Icon(Icons.help_outline, size: 16, color: cs.onSurface.withOpacity(0.7)),
            ),
          ],
        ),
      );
    }

    Widget sectionDivider() => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Divider(height: 1, thickness: 0.5, color: cs.outlineVariant.withOpacity(0.12)),
        );

    Widget headerWithSwitch({required Widget title, required bool value, required ValueChanged<bool> onChanged}) {
      return Row(
        children: [
          Expanded(child: title),
          IosSwitch(value: value, onChanged: onChanged),
        ],
      );
    }

    Widget simpleSwitchRow({required String label, required bool value, required ValueChanged<bool> onChanged}) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Expanded(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface.withOpacity(0.9)))),
              IosSwitch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      );
    }

    return Container(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header(),
            sectionDivider(),
            // Temperature
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  headerWithSwitch(
                    title: labelWithHelp(l10n.assistantEditTemperatureTitle, l10n.assistantEditTemperatureDescription),
                    value: a.temperature != null,
                    onChanged: (v) async {
                      if (v) {
                        await context.read<AssistantProvider>().updateAssistant(a.copyWith(temperature: (a.temperature ?? 0.6)));
                      } else {
                        await context.read<AssistantProvider>().updateAssistant(a.copyWith(clearTemperature: true));
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  IgnorePointer(
                    ignoring: a.temperature == null,
                    child: Opacity(
                      opacity: a.temperature == null ? 0.5 : 1.0,
                      child: _SliderTileNew(
                        value: (a.temperature ?? 0.6).clamp(0.0, 2.0),
                        min: 0.0,
                        max: 2.0,
                        divisions: 40,
                        label: ((a.temperature ?? 0.6).clamp(0.0, 2.0)).toStringAsFixed(2),
                        onChanged: (v) => context.read<AssistantProvider>().updateAssistant(a.copyWith(temperature: v)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            sectionDivider(),
            // Top-P
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  headerWithSwitch(
                    title: labelWithHelp(l10n.assistantEditTopPTitle, l10n.assistantEditTopPDescription),
                    value: a.topP != null,
                    onChanged: (v) async {
                      if (v) {
                        await context.read<AssistantProvider>().updateAssistant(a.copyWith(topP: (a.topP ?? 1.0)));
                      } else {
                        await context.read<AssistantProvider>().updateAssistant(a.copyWith(clearTopP: true));
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  IgnorePointer(
                    ignoring: a.topP == null,
                    child: Opacity(
                      opacity: a.topP == null ? 0.5 : 1.0,
                      child: _SliderTileNew(
                        value: (a.topP ?? 1.0).clamp(0.0, 1.0),
                        min: 0.0,
                        max: 1.0,
                        divisions: 20,
                        label: ((a.topP ?? 1.0).clamp(0.0, 1.0)).toStringAsFixed(2),
                        onChanged: (v) => context.read<AssistantProvider>().updateAssistant(a.copyWith(topP: v)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            sectionDivider(),
            // Context messages
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  headerWithSwitch(
                    title: labelWithHelp(l10n.assistantEditContextMessagesTitle, l10n.assistantEditContextMessagesDescription),
                    value: a.limitContextMessages,
                    onChanged: (v) {
                      final next = v && a.contextMessageSize < _contextMessageMin
                          ? a.copyWith(limitContextMessages: v, contextMessageSize: _contextMessageMin)
                          : a.copyWith(limitContextMessages: v);
                      context.read<AssistantProvider>().updateAssistant(next);
                    },
                  ),
                  const SizedBox(height: 8),
                  IgnorePointer(
                    ignoring: !a.limitContextMessages,
                    child: Opacity(
                      opacity: a.limitContextMessages ? 1.0 : 0.5,
                      child: _SliderTileNew(
                        value: _clampContextMessages(a.contextMessageSize).toDouble(),
                        min: _contextMessageMin.toDouble(),
                        max: _contextMessageMax.toDouble(),
                        divisions: _contextMessageMax - _contextMessageMin,
                        label: _clampContextMessages(a.contextMessageSize).toString(),
                        customLabelStops: const <double>[1.0, 32.0, 64.0, 128.0, 256.0],
                        onLabelTap: a.limitContextMessages
                            ? () async {
                                final chosen = await _showContextMessageInputDialog(
                                  context,
                                  initialValue: _clampContextMessages(a.contextMessageSize),
                                );
                                if (chosen != null) {
                                  await context.read<AssistantProvider>().updateAssistant(
                                        a.copyWith(contextMessageSize: chosen),
                                      );
                                }
                              }
                            : null,
                        onChanged: (v) => context.read<AssistantProvider>().updateAssistant(
                          a.copyWith(contextMessageSize: _clampContextMessages(v)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            sectionDivider(),
            // Max tokens
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  labelWithHelp(l10n.assistantEditMaxTokensTitle, l10n.assistantEditMaxTokensDescription),
                  const SizedBox(height: 8),
                  Focus(
                    onFocusChange: (has) {
                      if (!has) {
                        final trimmed = _maxTokensCtrl.text.trim();
                        final n = int.tryParse(trimmed);
                        context.read<AssistantProvider>().updateAssistant(
                          a.copyWith(maxTokens: n, clearMaxTokens: trimmed.isEmpty),
                        );
                      }
                    },
                    child: TextField(
                      controller: _maxTokensCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: l10n.assistantEditMaxTokensHint,
                        isDense: true,
                        // Increase height for desktop spec
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
                        filled: true,
                        fillColor: isDark ? Colors.white10 : const Color(0xFFF7F7F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: cs.primary.withOpacity(0.5)),
                        ),
                      ),
                      style: const TextStyle(fontSize: 13.5),
                      onSubmitted: (v) {
                        final trimmed = v.trim();
                        final n = int.tryParse(trimmed);
                        context.read<AssistantProvider>().updateAssistant(
                          a.copyWith(maxTokens: n, clearMaxTokens: trimmed.isEmpty),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            sectionDivider(),
            // Switches
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Column(
                children: [
                  simpleSwitchRow(
                    label: l10n.assistantEditUseAssistantAvatarTitle,
                    value: a.useAssistantAvatar,
                    onChanged: (v) => context.read<AssistantProvider>().updateAssistant(a.copyWith(useAssistantAvatar: v)),
                  ),
                  sectionDivider(),
                  simpleSwitchRow(
                    label: l10n.assistantEditStreamOutputTitle,
                    value: a.streamOutput,
                    onChanged: (v) => context.read<AssistantProvider>().updateAssistant(a.copyWith(streamOutput: v)),
                  ),
                ],
              ),
            ),
            sectionDivider(),
            // Chat model
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.assistantEditChatModelTitle,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (a.chatModelProvider != null && a.chatModelId != null)
                        Tooltip(
                          message: l10n.defaultModelPageResetDefault,
                          child: _TactileIconButton(
                            icon: Lucide.RotateCcw,
                            color: cs.onSurface,
                            size: 20,
                            onTap: () async {
                              await context.read<AssistantProvider>().updateAssistant(
                                    a.copyWith(clearChatModel: true),
                                  );
                            },
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  MouseRegion(
                    onEnter: (_) => setState(() => _hoverChatModel = true),
                    onExit: (_) => setState(() => _hoverChatModel = false),
                    child: _TactileRow(
                      onTap: () async {
                      final sel = await showModelSelector(context);
                      if (sel != null) {
                        await context.read<AssistantProvider>().updateAssistant(
                          a.copyWith(chatModelProvider: sel.providerKey, chatModelId: sel.modelId),
                        );
                      }
                      },
                      pressedScale: 0.98,
                      builder: (pressed) {
                        final base = isDark ? Colors.white10 : const Color(0xFFF2F3F5);
                        final pressOv = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05);
                        final hoverOv = isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04);
                        final bgColor = pressed ? Color.alphaBlend(pressOv, base) : (_hoverChatModel ? Color.alphaBlend(hoverOv, base) : base);
                        final settings = context.read<SettingsProvider>();
                        String display = l10n.assistantEditModelUseGlobalDefault;
                        if (a.chatModelProvider != null && a.chatModelId != null) {
                          try {
                            final cfg = settings.getProviderConfig(a.chatModelProvider!);
                            final ov = cfg.modelOverrides[a.chatModelId] as Map?;
                            final mdl = (ov != null && (ov['name'] as String?)?.isNotEmpty == true)
                                ? (ov['name'] as String)
                                : a.chatModelId!;
                            display = mdl;
                          } catch (_) {
                            display = a.chatModelId ?? '';
                          }
                        }
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              _BrandAvatarLike(name: display, size: 24),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  display,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            sectionDivider(),
            // Chat background
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.assistantEditChatBackgroundTitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if ((a.background ?? '').isEmpty) ...[
                    MouseRegion(
                      onEnter: (_) => setState(() => _hoverBgChooser = true),
                      onExit: (_) => setState(() => _hoverBgChooser = false),
                      child: _TactileRow(
                        onTap: () => _pickBackground(context, a),
                        pressedScale: 0.98,
                        builder: (pressed) {
                          final base = isDark ? Colors.white10 : const Color(0xFFF2F3F5);
                          final pressOv = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05);
                          final hoverOv = isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04);
                          final bg = pressed ? Color.alphaBlend(pressOv, base) : (_hoverBgChooser ? Color.alphaBlend(hoverOv, base) : base);
                          final iconColor = cs.onSurface.withOpacity(0.75);
                          final textColor = cs.onSurface.withOpacity(0.9);
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: cs.outlineVariant.withOpacity(0.35))),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Padding(padding: const EdgeInsets.only(left: 2.0), child: Icon(Icons.image, size: 18, color: iconColor)),
                                const SizedBox(width: 8),
                                Text(l10n.assistantEditChooseImageButton, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(child: _IosButton(label: l10n.assistantEditChooseImageButton, icon: Icons.image, onTap: () => _pickBackground(context, a))),
                        const SizedBox(width: 10),
                        Expanded(child: _IosButton(label: l10n.assistantEditClearButton, icon: Lucide.X, onTap: () => context.read<AssistantProvider>().updateAssistant(a.copyWith(clearBackground: true)))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(borderRadius: BorderRadius.circular(10), child: _BackgroundPreview(path: a.background!)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickBackground(BuildContext context, Assistant a) async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1920, imageQuality: 85);
      if (file != null) {
        await context.read<AssistantProvider>().updateAssistant(a.copyWith(background: file.path));
      }
    } catch (_) {}
  }

  Future<void> _openAssistantAvatarMenu(BuildContext context, Assistant a) async {
    final l10n = AppLocalizations.of(context)!;
    await showDesktopAnchoredMenu(
      context,
      anchorKey: _avatarKey,
      items: [
        DesktopContextMenuItem(
          icon: Lucide.User,
          label: l10n.desktopAvatarMenuUseEmoji,
          onTap: () async {
            final emoji = await showEmojiPickerDialog(
              context,
              title: l10n.assistantEditEmojiDialogTitle,
              hintText: l10n.assistantEditEmojiDialogHint,
            );
            if (emoji != null && emoji.isNotEmpty) {
              await context.read<AssistantProvider>().updateAssistant(a.copyWith(avatar: emoji));
            }
          },
        ),
        DesktopContextMenuItem(
          icon: Lucide.Image,
          label: l10n.desktopAvatarMenuChangeFromImage,
          onTap: () async {
            try {
              final res = await FilePicker.platform.pickFiles(
                allowMultiple: false,
                withData: false,
                type: FileType.custom,
                allowedExtensions: const ['png','jpg','jpeg','gif','webp','heic','heif'],
              );
              final f = (res != null && res.files.isNotEmpty) ? res.files.first : null;
              final path = f?.path;
              if (path != null && path.isNotEmpty) {
                await context.read<AssistantProvider>().updateAssistant(a.copyWith(avatar: path));
              }
            } catch (_) {}
          },
        ),
        DesktopContextMenuItem(
          icon: Lucide.Link,
          label: l10n.assistantEditAvatarEnterLink,
          onTap: () async { await _inputAvatarUrl(context, a); },
        ),
        DesktopContextMenuItem(
          svgAsset: 'assets/icons/tencent-qq.svg',
          label: l10n.assistantEditAvatarImportQQ,
          onTap: () async { await _inputQQAvatar(context, a); },
        ),
        DesktopContextMenuItem(
          icon: Lucide.RotateCw,
          label: l10n.desktopAvatarMenuReset,
          onTap: () async { await context.read<AssistantProvider>().updateAssistant(a.copyWith(clearAvatar: true)); },
        ),
      ],
      offset: const Offset(0, 8),
    );
  }

  Future<void> _pickLocalAvatar(BuildContext context, Assistant a) async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 88);
      if (file != null) {
        await context.read<AssistantProvider>().updateAssistant(a.copyWith(avatar: file.path));
      }
    } catch (_) {}
  }

  Future<void> _inputAvatarUrl(BuildContext context, Assistant a) async {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: cs.surface,
          title: Text(l10n.assistantEditImageUrlDialogTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.assistantEditImageUrlDialogHint,
              filled: true,
              fillColor: Theme.of(ctx).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF2F3F5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.transparent)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.transparent)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary.withOpacity(0.4))),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l10n.assistantEditImageUrlDialogCancel)),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l10n.assistantEditImageUrlDialogSave)),
          ],
        );
      },
    );
    if (ok == true) {
      final url = controller.text.trim();
      if (url.isNotEmpty) {
        await context.read<AssistantProvider>().updateAssistant(a.copyWith(avatar: url));
      }
    }
  }

  Future<String?> _inputEmojiDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final controller = TextEditingController();
    String value = '';
    bool validGrapheme(String s) {
      final trimmed = s.characters.take(1).toString().trim();
      return trimmed.isNotEmpty && trimmed == s.trim();
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: cs.surface,
          title: Text(l10n.assistantEditAvatarChooseEmoji),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '🙂',
              filled: true,
              fillColor: Theme.of(ctx).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF2F3F5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.transparent)),
              enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Colors.transparent)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary.withOpacity(0.4))),
            ),
            onChanged: (v) => value = v,
            onSubmitted: (_) {
              if (validGrapheme(value)) Navigator.of(ctx).pop(true);
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l10n.assistantEditImageUrlDialogCancel)),
            TextButton(onPressed: validGrapheme(value) ? () => Navigator.of(ctx).pop(true) : null, child: Text(l10n.assistantEditImageUrlDialogSave)),
          ],
        );
      },
    );
    if (ok == true) return controller.text.characters.take(1).toString();
    return null;
  }

  Future<void> _inputQQAvatar(BuildContext context, Assistant a) async {
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
            if (roll <= acc) { chosenLen = lengths[i]; break; }
          }
          final sb = StringBuffer();
          final firstGroups = <List<int>>[[1,2],[3,4],[5,6,7,8],[9]];
          final firstWeights = <int>[128,4,2,1];
          final firstTotal = firstWeights.fold<int>(0, (a, b) => a + b);
          int r2 = rnd.nextInt(firstTotal) + 1;
          int idx = 0; int a2 = 0;
          for (int i = 0; i < firstGroups.length; i++) { a2 += firstWeights[i]; if (r2 <= a2) { idx = i; break; } }
          final group = firstGroups[idx];
          sb.write(group[rnd.nextInt(group.length)]);
          for (int i = 1; i < chosenLen; i++) { sb.write(rnd.nextInt(10)); }
          return sb.toString();
        }
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: cs.surface,
              title: Text(l10n.assistantEditQQAvatarDialogTitle),
              content: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: l10n.assistantEditQQAvatarDialogHint,
                  filled: true,
                  fillColor: Theme.of(ctx).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF2F3F5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.transparent)),
                  enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Colors.transparent)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary.withOpacity(0.4))),
                ),
                onChanged: (v) => setLocal(() => value = v),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    const int maxTries = 20;
                    bool applied = false;
                    for (int i = 0; i < maxTries; i++) {
                      final qq = randomQQ();
                      final url = 'https://q2.qlogo.cn/headimg_dl?dst_uin=' + qq + '&spec=100';
                      try {
                        final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
                        if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
                          await context.read<AssistantProvider>().updateAssistant(a.copyWith(avatar: url));
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
                        message: l10n.assistantEditQQAvatarFailedMessage,
                        type: NotificationType.error,
                      );
                    }
                  },
                  child: Text(l10n.assistantEditQQAvatarRandomButton),
                ),
                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l10n.assistantEditQQAvatarDialogCancel)),
                TextButton(onPressed: valid(value) ? () => Navigator.of(ctx).pop(true) : null, child: Text(l10n.assistantEditQQAvatarDialogSave)),
              ],
            );
          },
        );
      },
    );
    if (ok == true) {
      final qq = controller.text.trim();
      if (qq.isNotEmpty) {
        final url = 'https://q2.qlogo.cn/headimg_dl?dst_uin=' + qq + '&spec=100';
        await context.read<AssistantProvider>().updateAssistant(a.copyWith(avatar: url));
      }
    }
  }
}
