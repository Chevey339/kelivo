import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

class FileProcessingIndicator extends StatelessWidget {
  const FileProcessingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    
    // Match _ReasoningSection styling from ChatMessageWidget
    final bg = cs.primaryContainer.withOpacity(isDark ? 0.25 : 0.30);
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.homePageProcessingFiles,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: cs.secondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
