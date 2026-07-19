import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../icons/lucide_adapter.dart';
import 'document_processing_config.dart';

/// Bottom sheet for document processing configuration on mobile.
class DocumentProcessingSheet extends StatelessWidget {
  const DocumentProcessingSheet({super.key, this.assistantId});

  final String? assistantId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (ctx, controller) {
          return Column(
            children: [
              // Title bar
              _SheetTopBar(
                title: l10n.documentProcessingTitle,
                onBack: () => Navigator.of(ctx).maybePop(),
              ),
              // Content
              Expanded(
                child: DocumentProcessingConfigContent(
                  assistantId: assistantId,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SheetTopBar extends StatelessWidget {
  const _SheetTopBar({required this.title, this.onBack});
  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(
            color: cs.onSurface.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          IosIconButton(
            icon: Lucide.ChevronLeft,
            size: 22,
            color: cs.onSurface,
            onTap: onBack,
            semanticLabel: '',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 48), // Balance with back button
        ],
      ),
    );
  }
}

/// Shows the document processing bottom sheet on mobile.
Future<void> showDocumentProcessingSheet(
  BuildContext context, {
  String? assistantId,
}) async {
  final cs = Theme.of(context).colorScheme;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) {
      return DocumentProcessingSheet(assistantId: assistantId);
    },
  );
}
