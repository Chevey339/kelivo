import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/mcp_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/snackbar.dart';

Future<void> showMcpTimeoutSheet(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final mcp = context.read<McpProvider>();
  final controller = TextEditingController(
    text: mcp.requestTimeoutSeconds.toString(),
  );

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final bottom = MediaQuery.of(ctx).viewInsets.bottom;

      Future<void> handleSave() async {
        FocusScope.of(ctx).unfocus();
        final raw = controller.text.trim();
        final seconds = int.tryParse(raw);
        if (seconds == null || seconds <= 0) {
          showAppSnackBar(
            ctx,
            message: l10n.mcpTimeoutInvalid,
            type: NotificationType.warning,
          );
          return;
        }
        await ctx.read<McpProvider>().updateRequestTimeout(
          Duration(seconds: seconds),
        );
        if (ctx.mounted) Navigator.of(ctx).maybePop();
      }

      return Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: cs.outlineVariant.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.mcpTimeoutDialogTitle,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Text(
              l10n.mcpTimeoutSecondsLabel,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: l10n.mcpTimeoutSecondsLabel,
                suffixText: 's',
                filled: true,
                fillColor: isDark ? Colors.white10 : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: cs.primary.withValues(alpha: 0.5),
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => handleSave(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    color: isDark
                        ? Colors.white10
                        : cs.surfaceContainerHighest.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(12),
                    onPressed: () => Navigator.of(ctx).maybePop(),
                    child: Text(
                      l10n.mcpPageClose,
                      style: TextStyle(color: cs.onSurface),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CupertinoButton.filled(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    borderRadius: BorderRadius.circular(12),
                    onPressed: handleSave,
                    color: cs.primary,
                    child: Text(l10n.mcpServerEditSheetSave),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
