import 'package:Kelivo/features/intelligent_ui/catalog/ui_budgets.dart';
import '../../intelligent_ui/widgets/genui_clipboard.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../intelligent_ui/host/ui_copy_actions.dart';
import 'package:flutter/material.dart';

import '../../../core/models/chat_message.dart';
import '../../../utils/source_text_map.dart';
import '../../../l10n/app_localizations.dart';

import 'package:Kelivo/shared/widgets/app_selection_area.dart';
import 'quote_interaction_scope.dart';
import '../controllers/quote_editing_controller.dart' show buildQuoteTextSpan;
import 'quote_chip.dart';
import 'package:markstream/markstream.dart' show SelectableSpanAdapter;
import '../../../shared/widgets/ios_tactile.dart';
import '../../../core/services/haptics.dart';
import '../../../theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

Future<void> showSelectCopySheet(
  BuildContext context, {
  required ChatMessage message,
}) async {
  final projection = await readUiMessageText(context, message);
  if (projection == null || !context.mounted) return;
  final quotes = QuoteInteractionScope.maybeOf(context);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.overlaySurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      top: false,
      child: quotes == null
          ? _SelectCopySheet(
              message: message,
              content: projection.copyText,
              sourceMap: projection.copySourceMap,
            )
          : QuoteInteractionScope(
              controller: quotes,
              child: _SelectCopySheet(
                message: message,
                content: projection.copyText,
                sourceMap: projection.copySourceMap,
              ),
            ),
    ),
  );
}

class _SelectCopySheet extends StatelessWidget {
  const _SelectCopySheet({
    required this.message,
    required this.content,
    this.sourceMap,
  });
  final String content;
  final ChatMessage message;
  final SourceTextMap? sourceMap;

  Future<void> _copyAll(BuildContext context) => copyGenUiText(
    context,
    message.quotes.isEmpty
        ? content
        : message.quotedContent(
            AppLocalizations.of(context)!.selectionQuoteMarker,
          ),
    successMessage: AppLocalizations.of(context)!.selectCopyPageCopiedAll,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (c, sc) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 32,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IosIconButton(
                    icon: LucideIcons.code,
                    tooltip: l10n.genuiCopySourceMarkdown,
                    minSize: 44,
                    onTap: () => copyUiMessageSource(context, message),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        l10n.selectCopyPageTitle,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: AppFontWeights.semibold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  IosCardPress(
                    onTap: () {
                      Haptics.light();
                      _copyAll(context);
                    },
                    borderRadius: BorderRadius.circular(20),
                    baseColor: Colors.transparent,
                    pressedBlendStrength:
                        Theme.of(context).brightness == Brightness.dark
                        ? 0.10
                        : 0.06,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Text(
                      l10n.selectCopyPageCopyAll,
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: AppFontWeights.emphasis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Scrollbar(
                controller: sc,
                child: SingleChildScrollView(
                  controller: sc,
                  primary: false,
                  child: AppSelectionArea(
                    message: message,
                    sourceText: content,
                    sourceMap: sourceMap,
                    onQuoteSelected: () => Navigator.of(context).pop(),
                    copyByteLimit: UiBudgets.copyBytes,
                    child: Text.rich(
                      buildQuoteTextSpan(
                        text: content,
                        quotes: message.quotes,
                        token: (quote, _) => SelectableSpanAdapter(
                          selectedText: '\uFFFC',
                          child: QuoteChip(quote: quote),
                        ),
                      ),
                      style: TextStyle(fontSize: 15, height: 1.5),
                    ),
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
