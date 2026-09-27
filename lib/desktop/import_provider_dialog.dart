import 'package:flutter/material.dart';

import '../features/provider/widgets/import_provider_sheet.dart'
    show importProvidersFromText;
import '../icons/lucide_adapter.dart';
import '../l10n/app_localizations.dart';
import '../shared/widgets/snackbar.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';
import 'widgets/desktop_form_dialog.dart';

/// Returns the keys of the imported providers, or null when cancelled.
Future<List<String>?> showDesktopImportProviderDialog(BuildContext context) {
  return showGeneralDialog<List<String>>(
    context: context,
    barrierDismissible: true,
    barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.25),
    barrierLabel: 'import-provider-dialog',
    pageBuilder: (ctx, _, __) => const _ImportProviderDialogBody(),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _ImportProviderDialogBody extends StatefulWidget {
  const _ImportProviderDialogBody();

  @override
  State<_ImportProviderDialogBody> createState() =>
      _ImportProviderDialogBodyState();
}

class _ImportProviderDialogBodyState extends State<_ImportProviderDialogBody> {
  final _controller = TextEditingController();
  bool _importing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty || _importing) return;
    final l10n = AppLocalizations.of(context)!;
    _importing = true;
    try {
      final keys = await importProvidersFromText(context, raw);
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: l10n.importProviderSheetImportSuccessMessage(keys.length),
        type: NotificationType.success,
      );
      Navigator.of(context).pop(keys);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: l10n.importProviderSheetImportFailedMessage(e.toString()),
        type: NotificationType.error,
      );
    } finally {
      _importing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: cs.outlineVariant.withValues(alpha: 0.12),
        width: 0.6,
      ),
    );
    return DesktopFormDialog(
      constraints: const BoxConstraints(minWidth: 520, maxWidth: 560),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesktopFormDialogHeader(
            title: l10n.importProviderSheetTitle,
            closeTooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onClose: () => Navigator.of(context).maybePop(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: TextField(
              controller: _controller,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.multiline,
              minLines: 8,
              maxLines: 12,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: l10n.importProviderSheetDescription,
                filled: true,
                fillColor: context.appColors.surfaceFill,
                border: border,
                enabledBorder: border,
                focusedBorder: border.copyWith(
                  borderSide: BorderSide(
                    color: cs.primary.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
          DesktopFormDialogFooter(
            secondaryLabel: l10n.importProviderSheetCancelButton,
            onSecondary: () => Navigator.of(context).maybePop(),
            primaryIcon: Lucide.Import,
            primaryLabel: l10n.importProviderSheetImportButton,
            onPrimary: _import,
          ),
        ],
      ),
    );
  }
}
