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
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => SizedBox(
          height: MediaQuery.sizeOf(context).height * .55,
          child: panel(context),
        ),
      );
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
                child: Material(
                  elevation: 10,
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: math.max(
                        100,
                        size.height - top - padding.bottom - 12,
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
  late LanguageOption _language;
  @override
  void initState() {
    super.initState();
    _language = widget.initialLanguage;
    unawaited(widget.controller.translate(_language.displayName));
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
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.languages,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.selectionTranslate,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<LanguageOption>(
                      value: _language,
                      isExpanded: true,
                      items: [
                        for (final language in supportedLanguages)
                          DropdownMenuItem(
                            value: language,
                            child: Text(
                              languageDisplayName(l10n, language.code),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                      ],
                      onChanged: (language) {
                        if (language == null || language == _language) return;
                        setState(() => _language = language);
                        widget.onLanguageChanged?.call(language);
                        unawaited(state.translate(language.displayName));
                      },
                    ),
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(LucideIcons.x, size: 18),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsetsDirectional.only(start: 10),
                      decoration: BoxDecoration(
                        border: BorderDirectional(
                          start: BorderSide(color: cs.outlineVariant, width: 2),
                        ),
                      ),
                      child: Text(
                        state.text,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (state.status == SelectionTranslationStatus.loading)
                      Row(
                        children: [
                          const SizedBox.square(
                            dimension: 14,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          ),
                          const SizedBox(width: 8),
                          Flexible(child: Text(l10n.translating)),
                        ],
                      ),
                    if (state.result.isNotEmpty)
                      SelectableText(
                        state.result,
                        style: const TextStyle(fontSize: 15, height: 1.6),
                      ),
                    if (state.status == SelectionTranslationStatus.failed)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.error ?? '',
                            style: TextStyle(color: cs.error),
                          ),
                          TextButton.icon(
                            onPressed: () =>
                                state.translate(_language.displayName),
                            icon: const Icon(LucideIcons.rotateCw, size: 16),
                            label: Text(l10n.retry),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                IconButton(
                  tooltip: MaterialLocalizations.of(context).copyButtonLabel,
                  onPressed: busy || state.result.isEmpty
                      ? null
                      : () => Clipboard.setData(
                          ClipboardData(text: state.result),
                        ),
                  icon: const Icon(LucideIcons.copy, size: 18),
                ),
                IconButton(
                  tooltip: l10n.selectionRegenerate,
                  onPressed: busy
                      ? null
                      : () => state.translate(_language.displayName),
                  icon: const Icon(LucideIcons.refreshCw, size: 18),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
