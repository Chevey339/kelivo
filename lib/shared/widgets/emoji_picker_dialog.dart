import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'emoji_text.dart';

/// A reusable emoji picker dialog used by both mobile and desktop.
/// Returns the chosen emoji (single grapheme) or null if cancelled.
Future<String?> showEmojiPickerDialog(
  BuildContext context, {
  String? title,
  String? hintText,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final controller = TextEditingController();
  String value = '';

  bool validGrapheme(String s) {
    final trimmed = s.characters.take(1).toString().trim();
    return trimmed.isNotEmpty && trimmed == s.trim();
  }

  const List<String> quick = <String>[
    '😀',
    '😁',
    '😂',
    '🤣',
    '😃',
    '😄',
    '😅',
    '😊',
    '😍',
    '😘',
    '😗',
    '😙',
    '😚',
    '🙂',
    '🤗',
    '🤩',
    '🫶',
    '🤝',
    '👍',
    '👎',
    '👋',
    '🙏',
    '💪',
    '🔥',
    '✨',
    '🌟',
    '💡',
    '🎉',
    '🎊',
    '🎈',
    '🌈',
    '☀️',
    '🌙',
    '⭐',
    '⚡',
    '☁️',
    '❄️',
    '🌧️',
    '🍎',
    '🍊',
    '🍋',
    '🍉',
    '🍇',
    '🍓',
    '🍒',
    '🍑',
    '🥭',
    '🍍',
    '🥝',
    '🍅',
    '🥕',
    '🌽',
    '🍞',
    '🧀',
    '🍔',
    '🍟',
    '🍕',
    '🌮',
    '🌯',
    '🍣',
    '🍜',
    '🍰',
    '🍪',
    '🍩',
    '🍫',
    '🍻',
    '☕',
    '🧋',
    '🥤',
    '⚽',
    '🏀',
    '🏈',
    '🎾',
    '🏐',
    '🎮',
    '🎧',
    '🎸',
    '🎹',
    '🎺',
    '📚',
    '✏️',
    '💼',
    '💻',
    '🖥️',
    '📱',
    '🛩️',
    '✈️',
    '🚗',
    '🚕',
    '🚙',
    '🚌',
    '🚀',
    '🛰️',
    '🧠',
    '🫀',
    '💊',
    '🩺',
    '🐶',
    '🐱',
    '🐭',
    '🐹',
    '🐰',
    '🦊',
    '🐻',
    '🐼',
    '🐨',
    '🐯',
    '🦁',
    '🐮',
    '🐷',
    '🐸',
    '🐵',
  ];

  return showDialog<String>(
    context: context,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          final media = MediaQuery.of(ctx);
          final avail = media.size.height - media.viewInsets.bottom;
          final double gridHeight = (avail * 0.28).clamp(120.0, 220.0);
          return AlertDialog(
            scrollable: true,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: cs.surface,
            title: Text(title ?? l10n.assistantEditEmojiDialogTitle),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: EmojiText(
                      value.isEmpty
                          ? '🙂'
                          : value.characters.take(1).toString(),
                      fontSize: 40,
                      optimizeEmojiAlign: true,
                      nudge: Offset.zero, // picker preview: no extra nudge
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    onChanged: (v) => setLocal(() => value = v),
                    onSubmitted: (_) {
                      if (validGrapheme(value)) {
                        Navigator.of(
                          ctx,
                        ).pop(value.characters.take(1).toString());
                      }
                    },
                    decoration: InputDecoration(
                      hintText: hintText ?? l10n.assistantEditEmojiDialogHint,
                      filled: true,
                      fillColor: Theme.of(ctx).brightness == Brightness.dark
                          ? Colors.white10
                          : const Color(0xFFF2F3F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.transparent),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.transparent),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: cs.primary.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: gridHeight,
                    child: GridView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 8,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                      itemCount: quick.length,
                      itemBuilder: (c, i) {
                        final e = quick[i];
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.of(ctx).pop(e),
                          child: Container(
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: EmojiText(
                              e,
                              fontSize: 20,
                              optimizeEmojiAlign: true,
                              nudge: Offset.zero, // picker grid: no extra nudge
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.assistantEditEmojiDialogCancel),
              ),
              TextButton(
                onPressed: validGrapheme(value)
                    ? () => Navigator.of(
                        ctx,
                      ).pop(value.characters.take(1).toString())
                    : null,
                child: Text(
                  l10n.assistantEditEmojiDialogSave,
                  style: TextStyle(
                    color: validGrapheme(value)
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.38),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  ).then((result) => result);
}
