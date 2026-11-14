import '../../../shared/widgets/ios_tactile.dart';
import 'package:flutter/material.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/message_part.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';

Future<String?> showMiniMapSheet(
  BuildContext context,
  List<ChatMessage> messages, {
  bool selecting = false,
  Set<String>? selectedMessageIds,
  Listenable? selectionListenable,
  ValueChanged<String>? onToggleSelection,
  VoidCallback? onOpenConversationFind,
}) async {
  assert(
    !selecting || (selectedMessageIds != null && onToggleSelection != null),
    'Mini map selection mode requires selectedMessageIds and onToggleSelection.',
  );
  return await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.overlaySurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _MiniMapSheet(
      messages: messages,
      selecting: selecting,
      selectedMessageIds: selectedMessageIds,
      selectionListenable: selectionListenable,
      onToggleSelection: onToggleSelection,
      onOpenConversationFind: onOpenConversationFind,
    ),
  );
}

class _MiniMapSheet extends StatefulWidget {
  final List<ChatMessage> messages;
  final bool selecting;
  final Set<String>? selectedMessageIds;
  final Listenable? selectionListenable;
  final ValueChanged<String>? onToggleSelection;
  final VoidCallback? onOpenConversationFind;

  const _MiniMapSheet({
    required this.messages,
    this.selecting = false,
    this.selectedMessageIds,
    this.selectionListenable,
    this.onToggleSelection,
    this.onOpenConversationFind,
  });

  @override
  State<_MiniMapSheet> createState() => _MiniMapSheetState();
}

class _MiniMapSheetState extends State<_MiniMapSheet> {
  late List<_QaPair> _pairs = _buildPairs(widget.messages);

  @override
  void didUpdateWidget(_MiniMapSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.messages, widget.messages)) {
      _pairs = _buildPairs(widget.messages);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (ctx, controller) {
          Widget buildList() {
            final pairs = _pairs;
            return ListView.builder(
              controller: controller,
              itemCount: pairs.length,
              itemBuilder: (context, index) {
                final pair = pairs[index];
                return _MiniMapRow(
                  pair: pair,
                  selecting: widget.selecting,
                  selectedMessageIds: widget.selectedMessageIds,
                  onToggleSelection: widget.onToggleSelection,
                );
              },
            );
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Pinned drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Pinned title
                Row(
                  children: [
                    Icon(Lucide.Map, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.miniMapTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: AppFontWeights.emphasis,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      height: 36,
                      width: 36,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Lucide.ChevronsDown,
                          size: 18,
                          color: cs.onSurface,
                        ),
                        tooltip: AppLocalizations.of(
                          context,
                        )!.miniMapScrollToBottomTooltip,
                        onPressed: () {
                          if (controller.hasClients &&
                              controller.position.maxScrollExtent > 0) {
                            controller.jumpTo(
                              controller.position.maxScrollExtent,
                            );
                          }
                        },
                      ),
                    ),
                    if (!widget.selecting &&
                        widget.onOpenConversationFind != null)
                      IosIconButton(
                        key: const ValueKey('miniMapSearchButton'),
                        icon: Lucide.Search,
                        minSize: 36,
                        tooltip: AppLocalizations.of(
                          context,
                        )!.conversationFindOpenTooltip,
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onOpenConversationFind!();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Scrollable content
                Expanded(
                  child: widget.selecting && widget.selectionListenable != null
                      ? AnimatedBuilder(
                          animation: widget.selectionListenable!,
                          builder: (context, child) => buildList(),
                        )
                      : buildList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<_QaPair> _buildPairs(List<ChatMessage> items) {
    final pairs = <_QaPair>[];
    ChatMessage? pendingUser;
    for (final m in items) {
      if (m.role == 'user') {
        // Push previous if it had no assistant
        if (pendingUser != null) {
          pairs.add(_QaPair(user: pendingUser, assistant: null));
        }
        pendingUser = m;
      } else if (m.role == 'assistant') {
        if (pendingUser != null) {
          pairs.add(_QaPair(user: pendingUser, assistant: m));
          pendingUser = null;
        } else {
          // Assistant without user: show as orphan on the right
          pairs.add(_QaPair(user: null, assistant: m));
        }
      }
    }
    if (pendingUser != null) {
      pairs.add(_QaPair(user: pendingUser, assistant: null));
    }
    return pairs;
  }
}

class _QaPair {
  final ChatMessage? user;
  final ChatMessage? assistant;
  _QaPair({required this.user, required this.assistant});
}

class _MiniMapRow extends StatelessWidget {
  final _QaPair pair;
  final bool selecting;
  final Set<String>? selectedMessageIds;
  final ValueChanged<String>? onToggleSelection;
  const _MiniMapRow({
    required this.pair,
    this.selecting = false,
    this.selectedMessageIds,
    this.onToggleSelection,
  });

  String _summaryText(ChatMessage? message) {
    if (message == null) return '';
    // ImagePart/FilePart are excluded; only TextPart contributes to the summary.
    final text = message.parts
        .whereType<TextPart>()
        .map((part) => part.text)
        .join();
    return _oneLine(text);
  }

  String _oneLine(String s) {
    // Strip vendor inline reasoning blocks if present; attachment markers are
    // no longer parsed because summaries are built from TextPart only.
    return _flattenWhitespace(
      s.replaceAll(
        RegExp(
          r'<(?:think|thought)>[\s\S]*?<\/(?:think|thought)>',
          caseSensitive: false,
        ),
        '',
      ),
    );
  }

  String _flattenWhitespace(String s) {
    return s.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Widget _bubbleLabel({
    required ChatMessage? message,
    required TextStyle style,
    required TextAlign textAlign,
  }) {
    final text = _summaryText(message);
    return Text(
      text.isNotEmpty ? text : ' ',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
      textAlign: textAlign,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userStyle = TextStyle(
      fontSize: 15.5,
      height: 1.4,
      color: cs.onSurface,
    );
    final assistantStyle = TextStyle(fontSize: 15.7, height: 1.5);

    final bool userSelected =
        selectedMessageIds != null &&
        pair.user != null &&
        selectedMessageIds!.contains(pair.user!.id);
    final bool assistantSelected =
        selectedMessageIds != null &&
        pair.assistant != null &&
        selectedMessageIds!.contains(pair.assistant!.id);

    final userBg = (isDark
        ? cs.primary.withValues(alpha: 0.15)
        : cs.primary.withValues(alpha: 0.08));
    final userSelectedBg = (isDark
        ? cs.primary.withValues(alpha: 0.26)
        : cs.primary.withValues(alpha: 0.14));
    final userBorder = cs.primary.withValues(alpha: isDark ? 0.45 : 0.35);

    final assistantBg = cs.onSurface.withValues(alpha: isDark ? 0.06 : 0.04);
    final assistantSelectedBg = (isDark
        ? cs.primary.withValues(alpha: 0.18)
        : cs.primary.withValues(alpha: 0.10));
    final assistantBorder = cs.primary.withValues(alpha: isDark ? 0.38 : 0.28);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // User bubble — match main chat style (right aligned rounded rectangle)
          Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth:
                    MediaQuery.sizeOf(context).width * 0.75 -
                    32, // subtract side paddings approx in sheet
              ),
              child: Material(
                color: Colors.transparent,
                child: selecting
                    ? GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: pair.user != null
                            ? () => onToggleSelection?.call(pair.user!.id)
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: userSelected ? userSelectedBg : userBg,
                            borderRadius: BorderRadius.circular(16),
                            border: userSelected
                                ? Border.all(color: userBorder, width: 1)
                                : null,
                          ),
                          child: _bubbleLabel(
                            message: pair.user,
                            style: userStyle,
                            textAlign: TextAlign.left,
                          ),
                        ),
                      )
                    : InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: pair.user != null
                            ? () => Navigator.of(context).pop(pair.user!.id)
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: userBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: _bubbleLabel(
                            message: pair.user,
                            style: userStyle,
                            textAlign: TextAlign.left,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Assistant message
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(
                  context,
                ).width, //* 0.75 - 32, // subtract side paddings approx in sheet
              ),
              child: Material(
                color: Colors.transparent,
                child: selecting
                    ? GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: pair.assistant != null
                            ? () => onToggleSelection?.call(pair.assistant!.id)
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: assistantSelected
                                ? assistantSelectedBg
                                : assistantBg,
                            borderRadius: BorderRadius.circular(16),
                            border: assistantSelected
                                ? Border.all(color: assistantBorder, width: 1)
                                : null,
                          ),
                          child: _bubbleLabel(
                            message: pair.assistant,
                            style: assistantStyle,
                            textAlign: TextAlign.left,
                          ),
                        ),
                      )
                    : InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: pair.assistant != null
                            ? () =>
                                  Navigator.of(context).pop(pair.assistant!.id)
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: assistantBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: _bubbleLabel(
                            message: pair.assistant,
                            style: assistantStyle,
                            textAlign: TextAlign.left,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
