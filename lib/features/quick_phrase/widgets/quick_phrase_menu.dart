import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/design_tokens.dart';
import '../../../core/models/quick_phrase.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../core/services/haptics.dart';

class QuickPhraseMenu extends StatelessWidget {
  const QuickPhraseMenu({
    super.key,
    required this.phrases,
    required this.onSelect,
    required this.anchorPosition,
  });

  final List<QuickPhrase> phrases;
  final ValueChanged<QuickPhrase> onSelect;
  final Offset anchorPosition;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    // Calculate menu position anchored to the input bar's global left and bottom inset
    final double menuWidth = 250;
    final double maxMenuHeight = size.height * 0.5;

    // Use provided anchor; dx is global left of input bar, dy is input bar height
    final double margin = 16;
    double left = anchorPosition.dx;
    // Clamp within screen margins
    if (left.isNaN || !left.isFinite) left = margin;
    if (left < margin) left = margin;
    if (left + menuWidth > size.width - margin) left = size.width - menuWidth - margin;

    // Place menu above input bar + keyboard with a small gap
    final double bottom = 72 + 12 + 38;

    return Stack(
      children: [
        Positioned(
          left: left,
          bottom: bottom,
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  width: menuWidth,
                  constraints: BoxConstraints(maxHeight: maxMenuHeight),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1C1C1E).withOpacity(0.66)
                        : Colors.white.withOpacity(0.66),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.08)
                          : cs.outlineVariant.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Padding(
                      //   padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      //   child: Row(
                      //     children: [
                      //       Icon(Lucide.Zap, size: 18, color: cs.primary),
                      //       const SizedBox(width: 8),
                      //       Text(
                      //         l10n.quickPhraseMenuTitle,
                      //         style: const TextStyle(
                      //           fontSize: 15,
                      //           fontWeight: FontWeight.w600,
                      //         ),
                      //       ),
                      //     ],
                      //   ),
                      // ),
                      // Divider(
                      //   height: 1,
                      //   thickness: 1,
                      //   color: cs.outlineVariant.withOpacity(0.2),
                      // ),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: phrases.length,
                          itemBuilder: (context, index) {
                            final phrase = phrases[index];
                            return IosCardPress(
                              borderRadius: BorderRadius.zero,
                              baseColor: Colors.transparent,
                              onTap: () {
                                try { Haptics.light(); } catch (_) {}
                                onSelect(phrase);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          phrase.isGlobal ? Lucide.Zap : Lucide.botMessageSquare,
                                          size: 14,
                                          color: cs.primary.withOpacity(0.7),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            phrase.title,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      phrase.content,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSurface.withOpacity(0.6),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<QuickPhrase?> showQuickPhraseMenu({
  required BuildContext context,
  required List<QuickPhrase> phrases,
  required Offset position,
}) async {
  if (phrases.isEmpty) return null;

  return await showDialog<QuickPhrase>(
    context: context,
    barrierColor: Colors.transparent,
    // barrierColor: Colors.black.withOpacity(0.08),
    barrierDismissible: true,
    builder: (ctx) {
      return GestureDetector(
        onTap: () => Navigator.of(ctx).pop(),
        child: Container(
          color: Colors.transparent,
          child: QuickPhraseMenu(
            phrases: phrases,
            onSelect: (phrase) => Navigator.of(ctx).pop(phrase),
            anchorPosition: position,
          ),
        ),
      );
    },
  );
}
