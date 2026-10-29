import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/models/chat_message.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/api/chat_api_service.dart';
import '../../../core/services/api/stream/stream_chunk.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../desktop/desktop_context_menu.dart';
import '../../../desktop/desktop_glass_popover.dart';
import '../../../theme/app_font_weights.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_text_button.dart';
import '../../../shared/widgets/option_sheet.dart';
import 'selection_panel.dart';
import '../../home/utils/model_display_helper.dart';
import '../../settings/widgets/language_select_sheet.dart';
import '../controllers/selection_translation_controller.dart';
import 'quote_chip.dart' show selectionUsesDesktop;

Future<void> showSelectionTranslationPanel(
  BuildContext context, {
  required ChatMessage message,
  required String text,
  required Rect anchor,
}) async {
  final settings = context.read<SettingsProvider>();
  final chat = context.read<ChatService>();
  final conversation = chat.getConversation(message.conversationId);
  final assistant = context
      .read<AssistantProvider>()
      .resolveConversationAssistant(conversation?.assistantId);
  final current = resolveChatModel(
    settings,
    conversation: conversation,
    assistant: assistant,
  );
  final providerKey = settings.translateModelProvider ?? current.providerKey;
  final model = settings.translateModelId ?? current.modelId;
  final prompt = settings.translatePrompt;
  final reasoning = settings.translateGenerationReasoningFor(assistant);
  final labels = AppLocalizations.of(context)!;
  final controller = SelectionTranslationController(
    text: text,
    cancel: ChatApiService.cancelRequest,
    request: (text, language, requestId) async* {
      if (providerKey == null || model == null) {
        throw StateError(labels.homePagePleaseSetupTranslateModel);
      }
      final stream = ChatApiService.sendMessageStream(
        conversationId: message.conversationId,
        config: settings.getProviderConfig(providerKey),
        modelId: model,
        messages: [
          {
            'role': 'user',
            'content': prompt.replaceAllMapped(
              RegExp(r'\{source_text\}|\{target_lang\}'),
              (match) => match[0] == '{source_text}' ? text : language,
            ),
          },
        ],
        reasoning: reasoning,
        requestId: requestId,
        parseMarkdownImageLinks: false,
      );
      await for (final chunk in stream) {
        if (chunk is TextDelta) yield chunk.text;
      }
    },
  );
  final locale = Localizations.localeOf(context);
  final preferred =
      settings.translateTargetLang ??
      (locale.languageCode == 'zh'
          ? (locale.scriptCode == 'Hant' ? 'zh-TW' : 'zh-CN')
          : locale.languageCode);
  final initial =
      supportedLanguages
          .where(
            (language) =>
                language.code == preferred ||
                language.displayName == preferred ||
                language.displayNameZh == preferred,
          )
          .firstOrNull ??
      supportedLanguages.first;
  Widget panel(BuildContext context) => SelectionResultPanel(
    controller: controller,
    initialLanguage: initial,
    onLanguageChanged: (language) =>
        settings.setTranslateTargetLang(language.code),
  );
  try {
    if (!selectionUsesDesktop) {
      await showSelectionSheet(context, builder: panel);
    } else {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: MaterialLocalizations.of(
          context,
        ).modalBarrierDismissLabel,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 120),
        pageBuilder: (context, animation, secondaryAnimation) {
          final size = MediaQuery.sizeOf(context);
          final padding = MediaQuery.paddingOf(context);
          final width = math.min(392.0, size.width - 24);
          final left = anchor.left.clamp(
            12.0,
            math.max(12, size.width - width - 12),
          );
          final top = (anchor.bottom + 8).clamp(
            padding.top + 12,
            math.max(padding.top + 12, size.height - padding.bottom - 240),
          );
          return Stack(
            children: [
              Positioned(
                top: top.toDouble(),
                left: left.toDouble(),
                width: width,
                child: DesktopGlassPanel(
                  borderRadius: BorderRadius.circular(10),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: math.min(
                        480,
                        math.max(100, size.height - top - padding.bottom - 12),
                      ),
                    ),
                    child: panel(context),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }
  } finally {
    controller.dispose();
  }
}

class SelectionResultPanel extends StatefulWidget {
  const SelectionResultPanel({
    super.key,
    required this.controller,
    required this.initialLanguage,
    this.onLanguageChanged,
  });
  final SelectionTranslationController controller;
  final LanguageOption initialLanguage;
  final ValueChanged<LanguageOption>? onLanguageChanged;
  @override
  State<SelectionResultPanel> createState() => _SelectionResultPanelState();
}

class _SelectionResultPanelState extends State<SelectionResultPanel> {
  final _languageAnchor = GlobalKey();
  late LanguageOption _language;

  @override
  void initState() {
    super.initState();
    _language = widget.initialLanguage;
    unawaited(widget.controller.translate(_language.displayName));
  }

  Future<void> _selectLanguage() async {
    final l10n = AppLocalizations.of(context)!;
    LanguageOption? selected;
    if (selectionUsesDesktop) {
      await showDesktopAnchoredMenu(
        context,
        anchorKey: _languageAnchor,
        items: [
          for (final language in supportedLanguages)
            DesktopContextMenuItem(
              label: languageDisplayName(l10n, language.code),
              checked: language.code == _language.code,
              onTap: () => selected = language,
            ),
        ],
      );
    } else {
      selected = await showOptionSheet<LanguageOption>(
        context,
        title: l10n.languageSelectSheetTitle,
        selected: _language,
        items: [
          for (final language in supportedLanguages)
            OptionSheetItem(
              value: language,
              label: languageDisplayName(l10n, language.code),
            ),
        ],
      );
    }
    if (!mounted || selected == null || selected == _language) return;
    setState(() => _language = selected!);
    widget.onLanguageChanged?.call(_language);
    unawaited(widget.controller.translate(_language.displayName));
  }

  Widget _languageButton(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: l10n.languageSelectSheetTitle,
      child: IosCardPress(
        key: _languageAnchor,
        focusable: true,
        baseColor: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        padding: EdgeInsets.symmetric(
          horizontal: 6,
          vertical: selectionUsesDesktop ? 4 : 6,
        ),
        onTap: _selectLanguage,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                languageDisplayName(l10n, _language.code),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: selectionUsesDesktop ? 11 : 13,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(LucideIcons.chevronDown, size: 12, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final l10n = AppLocalizations.of(context)!;
      final cs = Theme.of(context).colorScheme;
      final state = widget.controller;
      final busy =
          state.status == SelectionTranslationStatus.loading ||
          state.status == SelectionTranslationStatus.streaming;
      final desktop = selectionUsesDesktop;
      final VoidCallback? copy = busy || state.result.isEmpty
          ? null
          : () => Clipboard.setData(ClipboardData(text: state.result));
      final VoidCallback? regenerate = busy
          ? null
          : () => state.translate(_language.displayName);
      final content = [
        Text(
          state.text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: desktop ? 12 : 13,
            height: desktop ? 1.45 : 1.5,
            color: cs.onSurfaceVariant,
          ),
        ),
        SizedBox(height: desktop ? 8 : 12),
        if (state.status == SelectionTranslationStatus.loading)
          Row(
            children: [
              SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  l10n.translating,
                  style: TextStyle(
                    fontSize: desktop ? 12 : null,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        if (state.result.isNotEmpty)
          SelectableText(
            state.result,
            style: TextStyle(
              fontSize: desktop ? 14 : 15,
              height: desktop ? 1.45 : 1.6,
              color: cs.onSurface,
            ),
          ),
        if (state.status == SelectionTranslationStatus.failed) ...[
          Text(
            state.error ?? '',
            style: TextStyle(fontSize: desktop ? 12 : 13, color: cs.error),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: desktop
                ? _DesktopTranslationAction(
                    label: l10n.retry,
                    icon: LucideIcons.rotateCw,
                    onTap: () => state.translate(_language.displayName),
                  )
                : IosTextButton(
                    label: l10n.retry,
                    icon: LucideIcons.rotateCw,
                    padding: EdgeInsets.zero,
                    onPressed: () => state.translate(_language.displayName),
                  ),
          ),
        ],
      ];
      if (desktop) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    LucideIcons.languages,
                    size: 13,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.selectionTranslate,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: AppFontWeights.medium,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: _languageButton(context),
                    ),
                  ),
                  IosIconButton(
                    icon: LucideIcons.x,
                    size: 14,
                    minSize: 26,
                    visualSize: 22,
                    padding: const EdgeInsets.all(4),
                    borderRadius: 6,
                    color: cs.onSurfaceVariant,
                    tooltip: l10n.commonClose,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: content,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: _DesktopTranslationAction(
                      label: MaterialLocalizations.of(context).copyButtonLabel,
                      icon: LucideIcons.copy,
                      onTap: copy,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: _DesktopTranslationAction(
                      label: l10n.selectionRegenerate,
                      icon: LucideIcons.refreshCw,
                      onTap: regenerate,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }
      return SelectionPanel(
        title: l10n.selectionTranslate,
        onClose: () => Navigator.of(context).pop(),
        headerAction: _languageButton(context),
        actions: Row(
          children: [
            Expanded(
              child: IosTextButton(
                label: MaterialLocalizations.of(context).copyButtonLabel,
                color: cs.onSurfaceVariant,
                icon: LucideIcons.copy,
                onPressed: copy,
              ),
            ),
            Expanded(
              child: IosTextButton(
                label: l10n.selectionRegenerate,
                color: cs.onSurfaceVariant,
                icon: LucideIcons.refreshCw,
                onPressed: regenerate,
              ),
            ),
          ],
        ),
        children: content,
      );
    },
  );
}

class _DesktopTranslationAction extends StatelessWidget {
  const _DesktopTranslationAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = onTap == null
        ? cs.onSurfaceVariant.withValues(alpha: .45)
        : cs.onSurface;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: IosCardPress(
        focusable: true,
        haptics: false,
        onTap: onTap,
        mouseCursor: SystemMouseCursors.basic,
        baseColor: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
