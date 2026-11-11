import '../../../utils/utf16_safe_cut.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/models/compression_config.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/services/chat/compression_templates.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/ios_form_text_field.dart';
import '../../../theme/app_semantic_colors.dart';
import '../../../theme/app_font_weights.dart';
import 'context_dialog.dart';
import '../../../shared/responsive/screen_type_helper.dart';
import '../../../utils/platform_utils.dart';

Future<T?> showCompressionSheetOrDialog<T>(
  BuildContext context, {
  required Widget Function(bool sheet) builder,
}) {
  if (PlatformUtils.isDesktopTarget || ResponsiveHelper.isDesktop(context)) {
    return showDialog<T>(context: context, builder: (_) => builder(false));
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.overlaySurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * .9,
          ),
          child: builder(true),
        ),
      ),
    ),
  );
}

class CompressionPanel extends StatelessWidget {
  const CompressionPanel({
    super.key,
    required this.title,
    required this.child,
    required this.sheet,
    this.actions,
    this.maxWidth = 620,
    this.height = 640,
  });
  final String title;
  final Widget child;
  final bool sheet;
  final Widget? actions;
  final double maxWidth, height;
  @override
  Widget build(BuildContext context) {
    final body = SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sheet)
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 8, bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          CompressionPanelHeader(
            title: title,
            onClose: () => Navigator.pop(context),
          ),
          Expanded(child: child),
          if (actions != null) CompressionPanelFooter(child: actions!),
        ],
      ),
    );
    return sheet
        ? Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: body,
          )
        : ContextDialog(maxWidth: maxWidth, child: body);
  }
}

class CompressionPanelFooter extends StatelessWidget {
  const CompressionPanelFooter({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.only(top: 12),
    decoration: BoxDecoration(
      border: Border(
        top: BorderSide(color: context.appColors.hairline, width: .6),
      ),
    ),
    child: child,
  );
}

class CompressionDisclosure extends StatelessWidget {
  const CompressionDisclosure({
    super.key,
    required this.title,
    required this.description,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });
  final String title, description;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        expanded: expanded,
        child: CompressionSettingRow(
          label: title,
          subtitle: expanded ? null : description,
          onTap: onToggle,
          trailing: Icon(
            expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      if (expanded)
        MediaQuery.disableAnimationsOf(context)
            ? child
            : child.animate().fadeIn(duration: 160.ms),
    ],
  );
}

Future<void> showCompressionPromptPreview(
  BuildContext context,
  String prompt,
) => showCompressionSheetOrDialog<void>(
  context,
  builder: (sheet) => CompressionPanel(
    title: AppLocalizations.of(context)!.compressionLocalPreview,
    sheet: sheet,
    maxWidth: 760,
    child: SingleChildScrollView(
      child: SelectableText(
        prompt,
        style: TextStyle(
          fontSize: 14,
          height: 1.55,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    ),
  ),
);

String compressionTemplateName(
  AppLocalizations l10n,
  CompressionTemplate template,
) {
  final original = builtInCompressionTemplatesForLocale(
    l10n.localeName,
  ).where((item) => item.id == template.id).firstOrNull;
  if (original != null && template.name != original.name) return template.name;
  return switch (template.id) {
    'general' => l10n.compressionGeneral,
    'code' => l10n.compressionCode,
    'writing' => l10n.compressionWriting,
    'research' => l10n.compressionResearch,
    'roleplay' => l10n.compressionRoleplay,
    'original' => l10n.compressionOriginalPrompt,
    _ => template.name,
  };
}

String compressionTemplateDescription(
  AppLocalizations l10n,
  CompressionTemplate template,
) {
  final original = builtInCompressionTemplatesForLocale(
    l10n.localeName,
  ).where((item) => item.id == template.id).firstOrNull;
  if (original != null && template.prompt != original.prompt) {
    return truncateHeadUtf16Safe(template.prompt.split('\n').first, 160);
  }
  return switch (template.id) {
    'general' => l10n.compressionGeneralDescription,
    'code' => l10n.compressionCodeDescription,
    'writing' => l10n.compressionWritingDescription,
    'research' => l10n.compressionResearchDescription,
    'roleplay' => l10n.compressionRoleplayDescription,
    _ => truncateHeadUtf16Safe(template.prompt.split('\n').first, 160),
  };
}

class CompressionPanelHeader extends StatelessWidget {
  const CompressionPanelHeader({
    super.key,
    required this.title,
    required this.onClose,
    this.onBack,
  });
  final String title;
  final VoidCallback onClose;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final desktop =
        PlatformUtils.isDesktopTarget || ResponsiveHelper.isDesktop(context);
    Widget action(IconData icon, VoidCallback onTap, String label) =>
        IosIconButton(
          icon: icon,
          size: 20,
          minSize: 36,
          color: cs.onSurface.withValues(alpha: .62),
          onTap: onTap,
          tooltip: label,
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (onBack != null)
            action(
              LucideIcons.chevronLeft,
              onBack!,
              MaterialLocalizations.of(context).backButtonTooltip,
            )
          else if (!desktop)
            const SizedBox(width: 36),
          if (desktop && onBack != null) const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              textAlign: desktop ? TextAlign.start : TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: AppFontWeights.semibold,
                color: cs.onSurface,
              ),
            ),
          ),
          action(
            LucideIcons.x,
            onClose,
            AppLocalizations.of(context)!.statsPageClose,
          ),
        ],
      ),
    );
  }
}

/// Uses the existing model-settings field style, with a shared width for values.
class CompressionNumberRow extends StatefulWidget {
  const CompressionNumberRow({
    super.key,
    required this.label,
    required this.controller,
    required this.onChanged,
    this.hint,
    this.unit,
  });
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? hint, unit;

  @override
  State<CompressionNumberRow> createState() => _CompressionNumberRowState();
}

class _CompressionNumberRowState extends State<CompressionNumberRow> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IosCardPress(
      baseColor: Colors.transparent,
      borderRadius: BorderRadius.zero,
      pressedScale: 1,
      pressedBlendStrength: 0,
      haptics: false,
      onTap: _focusNode.requestFocus,
      child: IosFormTextField(
        label: widget.label,
        controller: widget.controller,
        focusNode: _focusNode,
        hintText: widget.hint,
        keyboardType: TextInputType.number,
        fieldWidth: 120,
        textAlign: TextAlign.end,
        compact: true,
        selectAllOnFocus: true,
        outerPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        suffix: widget.unit == null
            ? null
            : SizedBox(
                width: 32,
                child: Center(
                  child: Text(
                    widget.unit!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ),
              ),
        suffixIconConstraints: const BoxConstraints.tightFor(
          width: 32,
          height: 44,
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}

class CompressionSectionTitle extends StatelessWidget {
  const CompressionSectionTitle({super.key, required this.title, this.action});
  final String title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: AppFontWeights.medium,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: .62),
            ),
          ),
        ),
        if (action != null)
          Flexible(
            child: Align(alignment: Alignment.centerRight, child: action!),
          ),
      ],
    ),
  );
}

class CompressionTemplateChoice extends StatelessWidget {
  const CompressionTemplateChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: IosCardPress(
        focusable: true,
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        baseColor: selected
            ? cs.primary.withValues(alpha: .10)
            : context.appColors.surfaceFill,
        border: Border.all(
          color: selected
              ? cs.primary.withValues(alpha: .35)
              : Colors.transparent,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Center(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: selected ? cs.primary : cs.onSurface.withValues(alpha: .8),
              fontWeight: selected
                  ? AppFontWeights.semibold
                  : AppFontWeights.regular,
            ),
          ),
        ),
      ),
    );
  }
}

IconData compressionTemplateIcon(CompressionTemplate template) =>
    switch (template.scene) {
      'code' => LucideIcons.code,
      'writing' => LucideIcons.pencil,
      'research' => LucideIcons.search,
      'roleplay' => LucideIcons.user,
      _ => LucideIcons.messageSquare,
    };

class CompressionSettingRow extends StatelessWidget {
  const CompressionSettingRow({
    super.key,
    required this.label,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });
  final String label;
  final String? subtitle;
  final Widget? leading, trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IosCardPress(
      baseColor: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      focusable: true,
      onTap: onTap,
      haptics: false,
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: AppFontWeights.medium,
                    color: cs.onSurface,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: cs.onSurface.withValues(alpha: .58),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ] else if (onTap != null) ...[
            const SizedBox(width: 12),
            Icon(
              LucideIcons.chevronRight,
              size: 17,
              color: cs.onSurface.withValues(alpha: .4),
            ),
          ],
        ],
      ),
    );
  }
}

/// The quick switch is conversation-scoped; advanced settings expose notify
/// and dynamic inheritance. It does not change any template or recipe.
class AutoCompressionControl extends StatefulWidget {
  const AutoCompressionControl({super.key, required this.conversationId});
  final String conversationId;
  @override
  State<AutoCompressionControl> createState() => _AutoCompressionControlState();
}

class _AutoCompressionControlState extends State<AutoCompressionControl> {
  CompressionConfig? _config;
  bool _saving = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final chat = context.read<ChatService>();
    final settings = context.read<SettingsProvider>();
    final value = await chat.compressionConfig(
      widget.conversationId,
      settings.compressionDefaults,
    );
    if (mounted) setState(() => _config = value);
  }

  Future<void> _toggle(bool enabled) async {
    if (_saving) return;
    setState(() => _saving = true);
    final chat = context.read<ChatService>();
    try {
      await chat.setAutoCompressionEnabled(widget.conversationId, enabled);
      if (mounted) await _load();
    } catch (error) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: error.toString(),
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ContextActionRow(
      icon: LucideIcons.sparkles,
      label: l10n.compressionAutoTitle,
      onTap: _config == null || _saving
          ? null
          : () => _toggle(_config!.mode != AutoCompressionMode.auto),
      trailing: IosSwitch(
        value: _config?.mode == AutoCompressionMode.auto,
        semanticLabel: l10n.compressionAutoTitle,
        onChanged: _config == null || _saving ? null : _toggle,
      ),
    );
  }
}
