import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/snackbar.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../../../icons/lucide_adapter.dart';
import '../../../theme/design_tokens.dart';
import '../../../core/models/assistant.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/mcp_provider.dart';
import '../../model/widgets/model_select_sheet.dart';
import '../../chat/widgets/reasoning_budget_sheet.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import '../../chat/widgets/chat_message_widget.dart';
import '../../../core/models/chat_message.dart';
import '../../../utils/sandbox_path_resolver.dart';
import 'dart:io' show File;
import '../../../utils/avatar_cache.dart';
import '../../../utils/brand_assets.dart';
import '../../../core/models/quick_phrase.dart';
import '../../../core/providers/quick_phrase_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../core/services/haptics.dart';

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
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
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
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: _SegTabBar(
                    controller: _tabController,
                    tabs: [
                      l10n.assistantEditPageBasicTab,
                      l10n.assistantEditPagePromptsTab,
                      l10n.assistantEditPageMcpTab,
                      l10n.assistantEditPageQuickPhraseTab,
                      l10n.assistantEditPageCustomTab,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _BasicSettingsTab(assistantId: assistant.id),
          _PromptTab(assistantId: assistant.id),
          _McpTab(assistantId: assistant.id),
          _QuickPhraseTab(assistantId: assistant.id),
          _CustomRequestTab(assistantId: assistant.id),
        ],
      ),
    );
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
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 16), // Added top padding
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

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.name);
    _valCtrl = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _HeaderRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name) _nameCtrl.text = widget.name;
    if (oldWidget.value != widget.value) _valCtrl.text = widget.value;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _valCtrl.dispose();
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

  @override
  void initState() {
    super.initState();
    _keyCtrl = TextEditingController(text: widget.keyName);
    _valCtrl = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _BodyRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keyName != widget.keyName) _keyCtrl.text = widget.keyName;
    if (oldWidget.value != widget.value) _valCtrl.text = widget.value;
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _valCtrl.dispose();
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
              if (p != null && !kIsWeb && File(p).existsSync()) {
                return ClipOval(
                  child: Image.file(
                    File(p),
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                  ),
                );
              }
              if (p != null && kIsWeb && p.startsWith('data:')) {
                return ClipOval(
                  child: Image.network(
                    p,
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
        } else if (!kIsWeb && (av.startsWith('/') || av.contains(':'))) {
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(l10n.assistantEditAvatarChooseImage),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _pickLocalImage(context, a);
                },
              ),
              ListTile(
                title: Text(l10n.assistantEditAvatarChooseEmoji),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final emoji = await _pickEmoji(context);
                  if (emoji != null) {
                    await context.read<AssistantProvider>().updateAssistant(
                      a.copyWith(avatar: emoji),
                    );
                  }
                },
              ),
              ListTile(
                title: Text(l10n.assistantEditAvatarEnterLink),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _inputAvatarUrl(context, a);
                },
              ),
              ListTile(
                title: Text(l10n.assistantEditAvatarImportQQ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _inputQQAvatar(context, a);
                },
              ),
              ListTile(
                title: Text(l10n.assistantEditAvatarReset),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await context.read<AssistantProvider>().updateAssistant(
                    a.copyWith(clearAvatar: true),
                  );
                },
              ),
              const SizedBox(height: 4),
            ],
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
              final theme = Theme.of(context);
              final cs = theme.colorScheme;
              final isDark = theme.brightness == Brightness.dark;
              final value = context.watch<AssistantProvider>().getById(widget.assistantId)?.contextMessageSize ?? 20;
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
                          await context.read<AssistantProvider>().updateAssistant(
                            a.copyWith(limitContextMessages: v),
                          );
                          // Close the bottom sheet after toggle
                          Navigator.of(ctx).pop();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (a.limitContextMessages) ...[
                    _SliderTileNew(
                      value: value.toDouble().clamp(0, 256),
                      min: 0,
                      max: 256,
                      divisions: 64,
                      label: value.toString(),
                      onChanged: (v) => context.read<AssistantProvider>().updateAssistant(
                        a.copyWith(contextMessageSize: v.round()),
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
        : (kIsWeb
            ? const SizedBox.shrink()
            : Image.file(
                File(SandboxPathResolver.fix(widget.path)),
                fit: BoxFit.contain,
              ));
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
  });

  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String label;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
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
    final int majorCount = (total / interval).round().clamp(1, 10);
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
              child: SfSliderTheme(
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
                  showLabels: true,
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
            ),
            const SizedBox(width: 8),
            _ValuePill(text: label),
          ],
        ),
        // Remove explicit min/max captions since ticks already indicate range
      ],
    );
  }
}

class _ValuePill extends StatelessWidget {
  const _ValuePill({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
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
                      child: Text(
                        value.isEmpty
                            ? '🙂'
                            : value.characters.take(1).toString(),
                        style: const TextStyle(fontSize: 40),
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
                              child: Text(
                                e,
                                style: const TextStyle(fontSize: 20),
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

  @override
  void initState() {
    super.initState();
    final ap = context.read<AssistantProvider>();
    final a = ap.getById(widget.assistantId)!;
    _sysCtrl = TextEditingController(text: a.systemPrompt);
    _tmplCtrl = TextEditingController(text: a.messageTemplate);
    _sysFocus = FocusNode(debugLabel: 'systemPromptFocus');
    _tmplFocus = FocusNode(debugLabel: 'messageTemplateFocus');
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
            Text(
              l10n.assistantEditSystemPromptTitle,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _sysCtrl,
              focusNode: _sysFocus,
              onChanged: (v) => context
                  .read<AssistantProvider>()
                  .updateAssistant(a.copyWith(systemPrompt: v)),
              maxLines: 8,
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      children: [sysCard, const SizedBox(height: 12), tmplCard],
    );
  }
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
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
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
                                s.transport == McpTransportType.sse
                                    ? 'SSE'
                                    : 'HTTP',
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
              FilledButton.icon(
                onPressed: () => _showAddEditSheet(context),
                icon: Icon(Lucide.Plus, size: 20),
                label: Text(l10n.assistantEditAddQuickPhraseButton),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(200, 44),
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
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
                              borderRadius: BorderRadius.circular(12),
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
        // Capsule-style add button (iOS style with border)
        Positioned(
          left: 0,
          right: 0,
          bottom: 60,
          child: Center(
            child: _TactileRow(
              onTap: () => _showAddEditSheet(context),
              pressedScale: 0.97,
              builder: (pressed) {
                final bgColor = isDark
                    ? const Color(0xFF1C1C1E)
                    : const Color(0xFFF2F3F5);
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 110),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: cs.primary,
                      width: 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Lucide.Plus, size: 20, color: cs.primary),
                      const SizedBox(width: 8),
                      Text(
                        l10n.assistantEditAddQuickPhraseButton,
                        style: TextStyle(
                          color: cs.primary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
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
            Text(
              widget.phrase == null
                  ? l10n.quickPhraseAddTitle
                  : l10n.quickPhraseEditTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      side: BorderSide(
                        color: cs.outlineVariant.withOpacity(0.35),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(l10n.quickPhraseCancelButton),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop({
                        'title': _titleController.text,
                        'content': _contentController.text,
                      });
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(l10n.quickPhraseSaveButton),
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
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = controller.index == index;
          return GestureDetector(
            onTap: () => controller.animateTo(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? cs.primary.withOpacity(0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? cs.primary
                      : cs.outlineVariant.withOpacity(0.3),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                tabs[index],
                style: TextStyle(
                  color: selected ? cs.primary : cs.onSurface.withOpacity(0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
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
              if (widget.haptics) Haptics.soft();
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
  });
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool filled;
  final bool neutral; // If true, use neutral colors instead of primary

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
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
