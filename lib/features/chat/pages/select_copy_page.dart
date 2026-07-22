import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../core/models/chat_message.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/snackbar.dart';
import 'package:KelivoDev/theme/app_font_weights.dart';

class SelectCopyPage extends StatelessWidget {
  const SelectCopyPage({super.key, required this.message});
  final ChatMessage message;

  void _copyAll(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    // Ensure there is a text input connection on iOS before showing system copy UI
    // Here we bypass system menu by writing directly to clipboard and showing a snackbar
    await Clipboard.setData(ClipboardData(text: message.content));
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      message: l10n.selectCopyPageCopiedAll,
      type: NotificationType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.selectCopyPageTitle),
        actions: [
          TextButton.icon(
            onPressed: () => _copyAll(context),
            icon: Icon(Lucide.Copy, size: 18, color: cs.primary),
            label: Text(
              l10n.selectCopyPageCopyAll,
              style: TextStyle(
                color: cs.primary,
                fontWeight: AppFontWeights.semibold,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Scrollbar(
            child: SingleChildScrollView(
              child: SelectionArea(
                child: Text(
                  message.content,
                  style: TextStyle(fontSize: 15, height: 1.5),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
