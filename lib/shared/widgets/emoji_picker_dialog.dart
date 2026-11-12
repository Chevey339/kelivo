import 'package:flutter/material.dart';
import '../../desktop/widgets/desktop_form_dialog.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_semantic_colors.dart';
import 'emoji_text.dart';
import 'ios_form_text_field.dart';
import 'ios_tactile.dart';
import 'ios_text_button.dart';

/// Shared by avatar editors on mobile and desktop.
Future<String?> showEmojiPickerDialog(
  BuildContext context, {
  String? title,
  String? hintText,
}) => showDialog<String>(
  context: context,
  builder: (_) => _EmojiPickerDialog(title: title, hintText: hintText),
);

class _EmojiPickerDialog extends StatefulWidget {
  const _EmojiPickerDialog({this.title, this.hintText});
  final String? title;
  final String? hintText;
  @override
  State<_EmojiPickerDialog> createState() => _EmojiPickerDialogState();
}

class _EmojiPickerDialogState extends State<_EmojiPickerDialog> {
  final controller = TextEditingController();
  bool get valid {
    final value = controller.text.trim();
    return value.isNotEmpty && value.characters.length == 1;
  }

  void submit() {
    if (valid) Navigator.of(context).pop(controller.text.trim());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  static const List<String> quick = <String>[
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: MediaQuery.viewInsetsOf(context) + const EdgeInsets.all(24),
      child: DesktopFormDialog(
        constraints: BoxConstraints(
          maxWidth: 380,
          maxHeight: MediaQuery.sizeOf(context).height * .7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: CustomScrollView(
                shrinkWrap: true,
                slivers: [
                  SliverToBoxAdapter(
                    child: DesktopFormDialogHeader(
                      title: widget.title ?? l10n.assistantEditEmojiDialogTitle,
                      onClose: () => Navigator.of(context).pop(),
                      closeTooltip: l10n.assistantEditEmojiDialogCancel,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: context.appColors.surfaceFill,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: EmojiText(
                              controller.text.isEmpty
                                  ? '🙂'
                                  : controller.text.characters.first,
                              fontSize: 28,
                              optimizeEmojiAlign: true,
                              nudge: Offset.zero,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: IosFormTextField(
                              label: '',
                              inlineLabel: false,
                              outerPadding: EdgeInsets.zero,
                              controller: controller,
                              autofocus: true,
                              hintText:
                                  widget.hintText ??
                                  l10n.assistantEditEmojiDialogHint,
                              onChanged: (_) => setState(() {}),
                              onSubmitted: (_) => submit(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid.builder(
                      itemCount: quick.length,
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 60,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                      itemBuilder: (context, index) => IosCardPress(
                        focusable: true,
                        haptics: false,
                        pressedBlendStrength: .04,
                        baseColor: cs.primary.withValues(alpha: .06),
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => Navigator.of(context).pop(quick[index]),
                        child: Center(
                          child: EmojiText(
                            quick[index],
                            fontSize: 22,
                            optimizeEmojiAlign: true,
                            nudge: Offset.zero,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IosTextButton(
                    label: l10n.assistantEditEmojiDialogCancel,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  IosTextButton(
                    label: l10n.assistantEditEmojiDialogSave,
                    onPressed: valid ? submit : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
