import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
import 'dart:math' as math;
import 'dart:ui';

import 'package:characters/characters.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';
import 'package:uuid/uuid.dart';

import '../../chat/widgets/chat_message_widget.dart';
import '../../chat/widgets/reasoning_budget_sheet.dart';
import '../../model/widgets/model_select_sheet.dart';
import '../../../core/models/assistant.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/conversation.dart';
import '../../../core/models/preset_message.dart';
import '../../../core/models/quick_phrase.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/mcp_provider.dart';
import '../../../core/providers/quick_phrase_provider.dart';
import '../../../core/providers/memory_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/services/haptics.dart';
import '../../../desktop/desktop_context_menu.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/emoji_picker_dialog.dart';
import '../../../shared/widgets/emoji_text.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../theme/design_tokens.dart';
import '../../../utils/avatar_cache.dart';
import '../../../utils/brand_assets.dart';
import '../../../utils/sandbox_path_resolver.dart';
import 'assistant_regex_tab.dart';

part 'assistant_settings_edit_basic_tab.dart';
part 'assistant_settings_edit_prompt_tab.dart';
part 'assistant_settings_edit_memory_tab.dart';
part 'assistant_settings_edit_quick_phrase_tab.dart';
part 'assistant_settings_edit_custom_request_tab.dart';
part 'assistant_settings_edit_mcp_tab.dart';

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
    final double innerRadius = ((pillRadius - innerPadding).clamp(
      0.0,
      pillRadius,
    )).toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availWidth = constraints.maxWidth;
        final double innerAvailWidth = availWidth - innerPadding * 2;
        final double segWidth = math.max(
          minSegWidth,
          (innerAvailWidth - gap * (tabs.length - 1)) / tabs.length,
        );
        final double rowWidth =
            segWidth * tabs.length + gap * (tabs.length - 1);

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
                      ? cs
                            .primary // 选中文字：主题色
                      : cs.onSurface.withOpacity(0.82); // 未选中：深灰
                  final Color targetTextColor = pressed
                      ? Color.lerp(baseTextColor, Colors.white, 0.22) ??
                            baseTextColor
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
  return Builder(
    builder: (context) {
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
    },
  );
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
              if (widget.haptics &&
                  context.read<SettingsProvider>().hapticsOnListItemTap)
                Haptics.soft();
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
    final isMaterialIcon =
        widget.icon != null &&
        (widget.icon == Icons.image ||
            widget.icon.runtimeType.toString().contains('MaterialIcons'));

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
            border: widget.filled ? null : Border.all(color: borderColor),
          ),
          padding: EdgeInsets.symmetric(
            vertical: widget.dense ? 8 : 12,
            horizontal: widget.dense ? 12 : 16,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Padding(
                  padding: EdgeInsets.only(left: isMaterialIcon ? 2.0 : 0.0),
                  child: Icon(widget.icon, size: 18, color: iconColor),
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

Future<void> showAssistantDesktopDialog(
  BuildContext context, {
  required String assistantId,
}) async {
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
  State<_DesktopAssistantDialogShell> createState() =>
      _DesktopAssistantDialogShellState();
}

class _DesktopAssistantDialogShellState
    extends State<_DesktopAssistantDialogShell> {
  _AssistantDesktopMenu _menu = _AssistantDesktopMenu.basic;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final a = context.watch<AssistantProvider>().getById(widget.assistantId);
    final name =
        a?.name ?? AppLocalizations.of(context)!.assistantEditPageTitle;
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
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
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
        Divider(
          height: 1,
          thickness: 0.5,
          color: cs.outlineVariant.withOpacity(0.12),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DesktopAssistantMenu(
                selected: _menu,
                onSelect: (m) => setState(() => _menu = m),
              ),
              VerticalDivider(
                width: 1,
                thickness: 0.5,
                color: cs.outlineVariant.withOpacity(0.12),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeOutCubic,
                  child: () {
                    switch (_menu) {
                      case _AssistantDesktopMenu.basic:
                        return _DesktopAssistantBasicPane(
                          assistantId: widget.assistantId,
                          key: const ValueKey('basic'),
                        );
                      case _AssistantDesktopMenu.prompts:
                        return _PromptTab(assistantId: widget.assistantId);
                      case _AssistantDesktopMenu.memory:
                        return _MemoryTab(assistantId: widget.assistantId);
                      case _AssistantDesktopMenu.quick:
                        return _QuickPhraseTab(assistantId: widget.assistantId);
                      case _AssistantDesktopMenu.custom:
                        return _CustomRequestTab(
                          assistantId: widget.assistantId,
                        );
                      case _AssistantDesktopMenu.regex:
                        return AssistantRegexDesktopPane(
                          assistantId: widget.assistantId,
                        );
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
                    ? (isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.black.withOpacity(0.04))
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
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    items[i].$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w400,
                      color: fg,
                      decoration: TextDecoration.none,
                    ),
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
  State<_DesktopAssistantBasicPane> createState() =>
      _DesktopAssistantBasicPaneState();
}

class _DesktopAssistantBasicPaneState
    extends State<_DesktopAssistantBasicPane> {
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
              child: Builder(
                builder: (context) {
                  final av = a.avatar?.trim() ?? '';
                  Widget inner;
                  if (av.isEmpty) {
                    inner = Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        (a.name.isNotEmpty ? a.name.characters.first : '?'),
                        style: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                        ),
                      ),
                    );
                  } else if (av.startsWith('http')) {
                    inner = ClipOval(
                      child: Image.network(
                        av,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      ),
                    );
                  } else if (av.startsWith('/') || av.contains(':')) {
                    final fixed = SandboxPathResolver.fix(av);
                    final f = File(fixed);
                    if (f.existsSync()) {
                      inner = ClipOval(
                        child: Image.file(
                          f,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      );
                    } else {
                      inner = Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: cs.primary.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          (a.name.isNotEmpty ? a.name.characters.first : '?'),
                          style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 22,
                          ),
                        ),
                      );
                    }
                  } else {
                    inner = Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        av.characters.take(1).toString(),
                        style: const TextStyle(fontSize: 26),
                      ),
                    );
                  }
                  return inner;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Focus(
                onFocusChange: (has) async {
                  if (!has) {
                    final v = _nameCtrl.text.trim();
                    await context.read<AssistantProvider>().updateAssistant(
                      a.copyWith(name: v),
                    );
                  }
                },
                child: TextField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: l10n.assistantEditAssistantNameLabel,
                    isDense: true,
                    filled: true,
                    fillColor: isDark
                        ? Colors.white10
                        : const Color(0xFFF7F7F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: cs.outlineVariant.withOpacity(0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: cs.primary.withOpacity(0.5),
                      ),
                    ),
                  ),
                  onSubmitted: (v) => context
                      .read<AssistantProvider>()
                      .updateAssistant(a.copyWith(name: v.trim())),
                  onEditingComplete: () => context
                      .read<AssistantProvider>()
                      .updateAssistant(a.copyWith(name: _nameCtrl.text.trim())),
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
            Text(
              text,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: help,
              decoration: BoxDecoration(
                color: cs.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              // Use themed text to respect user-selected fonts
              textStyle: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurface),
              waitDuration: const Duration(milliseconds: 300),
              child: Icon(
                Icons.help_outline,
                size: 16,
                color: cs.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    Widget sectionDivider() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: cs.outlineVariant.withOpacity(0.12),
      ),
    );

    Widget headerWithSwitch({
      required Widget title,
      required bool value,
      required ValueChanged<bool> onChanged,
    }) {
      return Row(
        children: [
          Expanded(child: title),
          IosSwitch(value: value, onChanged: onChanged),
        ],
      );
    }

    Widget simpleSwitchRow({
      required String label,
      required bool value,
      required ValueChanged<bool> onChanged,
    }) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withOpacity(0.9),
                  ),
                ),
              ),
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
                    title: labelWithHelp(
                      l10n.assistantEditTemperatureTitle,
                      l10n.assistantEditTemperatureDescription,
                    ),
                    value: a.temperature != null,
                    onChanged: (v) async {
                      if (v) {
                        await context.read<AssistantProvider>().updateAssistant(
                          a.copyWith(temperature: (a.temperature ?? 0.6)),
                        );
                      } else {
                        await context.read<AssistantProvider>().updateAssistant(
                          a.copyWith(clearTemperature: true),
                        );
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
                        label: ((a.temperature ?? 0.6).clamp(
                          0.0,
                          2.0,
                        )).toStringAsFixed(2),
                        onChanged: (v) => context
                            .read<AssistantProvider>()
                            .updateAssistant(a.copyWith(temperature: v)),
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
                    title: labelWithHelp(
                      l10n.assistantEditTopPTitle,
                      l10n.assistantEditTopPDescription,
                    ),
                    value: a.topP != null,
                    onChanged: (v) async {
                      if (v) {
                        await context.read<AssistantProvider>().updateAssistant(
                          a.copyWith(topP: (a.topP ?? 1.0)),
                        );
                      } else {
                        await context.read<AssistantProvider>().updateAssistant(
                          a.copyWith(clearTopP: true),
                        );
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
                        label: ((a.topP ?? 1.0).clamp(
                          0.0,
                          1.0,
                        )).toStringAsFixed(2),
                        onChanged: (v) => context
                            .read<AssistantProvider>()
                            .updateAssistant(a.copyWith(topP: v)),
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
                    title: labelWithHelp(
                      l10n.assistantEditContextMessagesTitle,
                      l10n.assistantEditContextMessagesDescription,
                    ),
                    value: a.limitContextMessages,
                    onChanged: (v) {
                      final next =
                          v && a.contextMessageSize < _contextMessageMin
                          ? a.copyWith(
                              limitContextMessages: v,
                              contextMessageSize: _contextMessageMin,
                            )
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
                        value: _clampContextMessages(
                          a.contextMessageSize,
                        ).toDouble(),
                        min: _contextMessageMin.toDouble(),
                        max: _contextMessageMax.toDouble(),
                        divisions: _contextMessageMax - _contextMessageMin,
                        label: _clampContextMessages(
                          a.contextMessageSize,
                        ).toString(),
                        customLabelStops: const <double>[
                          1.0,
                          32.0,
                          64.0,
                          128.0,
                          256.0,
                        ],
                        onLabelTap: a.limitContextMessages
                            ? () async {
                                final chosen =
                                    await _showContextMessageInputDialog(
                                      context,
                                      initialValue: _clampContextMessages(
                                        a.contextMessageSize,
                                      ),
                                    );
                                if (chosen != null) {
                                  await context
                                      .read<AssistantProvider>()
                                      .updateAssistant(
                                        a.copyWith(contextMessageSize: chosen),
                                      );
                                }
                              }
                            : null,
                        onChanged: (v) =>
                            context.read<AssistantProvider>().updateAssistant(
                              a.copyWith(
                                contextMessageSize: _clampContextMessages(v),
                              ),
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
                  labelWithHelp(
                    l10n.assistantEditMaxTokensTitle,
                    l10n.assistantEditMaxTokensDescription,
                  ),
                  const SizedBox(height: 8),
                  Focus(
                    onFocusChange: (has) {
                      if (!has) {
                        final trimmed = _maxTokensCtrl.text.trim();
                        final n = int.tryParse(trimmed);
                        context.read<AssistantProvider>().updateAssistant(
                          a.copyWith(
                            maxTokens: n,
                            clearMaxTokens: trimmed.isEmpty,
                          ),
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
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 20,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white10
                            : const Color(0xFFF7F7F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: cs.outlineVariant.withOpacity(0.2),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: cs.primary.withOpacity(0.5),
                          ),
                        ),
                      ),
                      style: const TextStyle(fontSize: 13.5),
                      onSubmitted: (v) {
                        final trimmed = v.trim();
                        final n = int.tryParse(trimmed);
                        context.read<AssistantProvider>().updateAssistant(
                          a.copyWith(
                            maxTokens: n,
                            clearMaxTokens: trimmed.isEmpty,
                          ),
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
                    onChanged: (v) => context
                        .read<AssistantProvider>()
                        .updateAssistant(a.copyWith(useAssistantAvatar: v)),
                  ),
                  sectionDivider(),
                  simpleSwitchRow(
                    label: l10n.assistantEditStreamOutputTitle,
                    value: a.streamOutput,
                    onChanged: (v) => context
                        .read<AssistantProvider>()
                        .updateAssistant(a.copyWith(streamOutput: v)),
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
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
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
                              await context
                                  .read<AssistantProvider>()
                                  .updateAssistant(
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
                          await context
                              .read<AssistantProvider>()
                              .updateAssistant(
                                a.copyWith(
                                  chatModelProvider: sel.providerKey,
                                  chatModelId: sel.modelId,
                                ),
                              );
                        }
                      },
                      pressedScale: 0.98,
                      builder: (pressed) {
                        final base = isDark
                            ? Colors.white10
                            : const Color(0xFFF2F3F5);
                        final pressOv = isDark
                            ? Colors.white.withOpacity(0.06)
                            : Colors.black.withOpacity(0.05);
                        final hoverOv = isDark
                            ? Colors.white.withOpacity(0.04)
                            : Colors.black.withOpacity(0.04);
                        final bgColor = pressed
                            ? Color.alphaBlend(pressOv, base)
                            : (_hoverChatModel
                                  ? Color.alphaBlend(hoverOv, base)
                                  : base);
                        final settings = context.read<SettingsProvider>();
                        String display =
                            l10n.assistantEditModelUseGlobalDefault;
                        if (a.chatModelProvider != null &&
                            a.chatModelId != null) {
                          try {
                            final cfg = settings.getProviderConfig(
                              a.chatModelProvider!,
                            );
                            final ov =
                                cfg.modelOverrides[a.chatModelId] as Map?;
                            final mdl =
                                (ov != null &&
                                    (ov['name'] as String?)?.isNotEmpty == true)
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: bgColor,
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
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
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
                  Text(
                    l10n.assistantEditChatBackgroundTitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if ((a.background ?? '').isEmpty) ...[
                    MouseRegion(
                      onEnter: (_) => setState(() => _hoverBgChooser = true),
                      onExit: (_) => setState(() => _hoverBgChooser = false),
                      child: _TactileRow(
                        onTap: () => _pickBackground(context, a),
                        pressedScale: 0.98,
                        builder: (pressed) {
                          final base = isDark
                              ? Colors.white10
                              : const Color(0xFFF2F3F5);
                          final pressOv = isDark
                              ? Colors.white.withOpacity(0.06)
                              : Colors.black.withOpacity(0.05);
                          final hoverOv = isDark
                              ? Colors.white.withOpacity(0.04)
                              : Colors.black.withOpacity(0.04);
                          final bg = pressed
                              ? Color.alphaBlend(pressOv, base)
                              : (_hoverBgChooser
                                    ? Color.alphaBlend(hoverOv, base)
                                    : base);
                          final iconColor = cs.onSurface.withOpacity(0.75);
                          final textColor = cs.onSurface.withOpacity(0.9);
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: cs.outlineVariant.withOpacity(0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 2.0),
                                  child: Icon(
                                    Icons.image,
                                    size: 18,
                                    color: iconColor,
                                  ),
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
                    ),
                  ] else ...[
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
                                .updateAssistant(
                                  a.copyWith(clearBackground: true),
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _BackgroundPreview(path: a.background!),
                    ),
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

  Future<void> _openAssistantAvatarMenu(
    BuildContext context,
    Assistant a,
  ) async {
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
              await context.read<AssistantProvider>().updateAssistant(
                a.copyWith(avatar: emoji),
              );
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
                allowedExtensions: const [
                  'png',
                  'jpg',
                  'jpeg',
                  'gif',
                  'webp',
                  'heic',
                  'heif',
                ],
              );
              final f = (res != null && res.files.isNotEmpty)
                  ? res.files.first
                  : null;
              final path = f?.path;
              if (path != null && path.isNotEmpty) {
                await context.read<AssistantProvider>().updateAssistant(
                  a.copyWith(avatar: path),
                );
              }
            } catch (_) {}
          },
        ),
        DesktopContextMenuItem(
          icon: Lucide.Link,
          label: l10n.assistantEditAvatarEnterLink,
          onTap: () async {
            await _inputAvatarUrl(context, a);
          },
        ),
        DesktopContextMenuItem(
          svgAsset: 'assets/icons/tencent-qq.svg',
          label: l10n.assistantEditAvatarImportQQ,
          onTap: () async {
            await _inputQQAvatar(context, a);
          },
        ),
        DesktopContextMenuItem(
          icon: Lucide.RotateCw,
          label: l10n.desktopAvatarMenuReset,
          onTap: () async {
            await context.read<AssistantProvider>().updateAssistant(
              a.copyWith(clearAvatar: true),
            );
          },
        ),
      ],
      offset: const Offset(0, 8),
    );
  }

  Future<void> _pickLocalAvatar(BuildContext context, Assistant a) async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 88,
      );
      if (file != null) {
        await context.read<AssistantProvider>().updateAssistant(
          a.copyWith(avatar: file.path),
        );
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
                borderSide: const BorderSide(color: Colors.transparent),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cs.primary.withOpacity(0.4)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.assistantEditImageUrlDialogCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.assistantEditImageUrlDialogSave),
            ),
          ],
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: cs.surface,
          title: Text(l10n.assistantEditAvatarChooseEmoji),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '🙂',
              filled: true,
              fillColor: Theme.of(ctx).brightness == Brightness.dark
                  ? Colors.white10
                  : const Color(0xFFF2F3F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.transparent),
              ),
              enabledBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: Colors.transparent),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cs.primary.withOpacity(0.4)),
              ),
            ),
            onChanged: (v) => value = v,
            onSubmitted: (_) {
              if (validGrapheme(value)) Navigator.of(ctx).pop(true);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.assistantEditImageUrlDialogCancel),
            ),
            TextButton(
              onPressed: validGrapheme(value)
                  ? () => Navigator.of(ctx).pop(true)
                  : null,
              child: Text(l10n.assistantEditImageUrlDialogSave),
            ),
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
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: Colors.transparent),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.primary.withOpacity(0.4)),
                  ),
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
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(l10n.assistantEditQQAvatarDialogCancel),
                ),
                TextButton(
                  onPressed: valid(value)
                      ? () => Navigator.of(ctx).pop(true)
                      : null,
                  child: Text(l10n.assistantEditQQAvatarDialogSave),
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
}
