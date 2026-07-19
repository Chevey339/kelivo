import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../theme/app_font_weights.dart';
import '../../../icons/lucide_adapter.dart';
import '../../home/models/synthesize_task.dart';

/// Show a bottom sheet (mobile) or dialog (desktop) for selecting a
/// synthesize task type.
///
/// Returns the selected [SynthesizeTaskType], or null if cancelled.
Future<SynthesizeTaskType?> showSynthesizeTaskSelector(
  BuildContext context,
) async {
  final isDesktop =
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  if (isDesktop) {
    return showDialog<SynthesizeTaskType>(
      context: context,
      builder: (_) => _SynthesizeTaskDialog(),
    );
  }
  return showModalBottomSheet<SynthesizeTaskType>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _SynthesizeTaskSheet(),
  );
}

class _SynthesizeTaskSheet extends StatelessWidget {
  const _SynthesizeTaskSheet();

  @override
  Widget build(BuildContext context) {
    return _buildContent(context);
  }
}

class _SynthesizeTaskDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: _buildContent(context),
      ),
    );
  }
}

Widget _buildContent(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final cs = Theme.of(context).colorScheme;

  Widget buildTaskRow(SynthesizeTask task, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        height: 56,
        child: IosCardPress(
          borderRadius: BorderRadius.circular(14),
          baseColor: cs.surface,
          duration: const Duration(milliseconds: 260),
          onTap: () => Navigator.of(context).pop(task.type),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: cs.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _resolve(l10n, task.labelKey),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: AppFontWeights.semibold,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _resolve(l10n, task.descriptionKey),
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.55),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
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
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 6),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildTaskRow(synthesizeTasks[0], Lucide.FileText),
                  buildTaskRow(synthesizeTasks[1], Lucide.Shuffle),
                  buildTaskRow(synthesizeTasks[2], Lucide.MessageCircle),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String _resolve(AppLocalizations l10n, String key) {
  // Resolve ARB key via generated accessors.
  switch (key) {
    case 'multiAISynthesizeTaskSummarize':
      return l10n.multiAISynthesizeTaskSummarize;
    case 'multiAISynthesizeTaskSummarizeDesc':
      return l10n.multiAISynthesizeTaskSummarizeDesc;
    case 'multiAISynthesizeSummarizePrompt':
      return l10n.multiAISynthesizeSummarizePrompt;
    case 'multiAISynthesizeTaskFuse':
      return l10n.multiAISynthesizeTaskFuse;
    case 'multiAISynthesizeTaskFuseDesc':
      return l10n.multiAISynthesizeTaskFuseDesc;
    case 'multiAISynthesizeFusePrompt':
      return l10n.multiAISynthesizeFusePrompt;
    case 'multiAISynthesizeTaskComment':
      return l10n.multiAISynthesizeTaskComment;
    case 'multiAISynthesizeTaskCommentDesc':
      return l10n.multiAISynthesizeTaskCommentDesc;
    case 'multiAISynthesizeCommentPrompt':
      return l10n.multiAISynthesizeCommentPrompt;
    default:
      return key;
  }
}
