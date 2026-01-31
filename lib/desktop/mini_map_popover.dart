import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/models/chat_message.dart';

Future<String?> showDesktopMiniMapPopover(
  BuildContext context, {
  required GlobalKey anchorKey,
  required List<ChatMessage> messages,
  bool selecting = false,
  Set<String>? selectedMessageIds,
  Listenable? selectionListenable,
  ValueChanged<String>? onToggleSelection,
}) async {
  assert(
    !selecting || (selectedMessageIds != null && onToggleSelection != null),
    'Mini map selection mode requires selectedMessageIds and onToggleSelection.',
  );
  final overlay = Overlay.of(context);
  if (overlay == null) return null;
  final keyContext = anchorKey.currentContext;
  if (keyContext == null) return null;

  final box = keyContext.findRenderObject() as RenderBox?;
  if (box == null) return null;
  final offset = box.localToGlobal(Offset.zero);
  final size = box.size;
  final anchorRect = Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height);

  final completer = Completer<String?>();

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _MiniMapPopover(
      anchorRect: anchorRect,
      anchorWidth: size.width,
      messages: messages,
      selecting: selecting,
      selectedMessageIds: selectedMessageIds,
      selectionListenable: selectionListenable,
      onToggleSelection: onToggleSelection,
      onSelect: selecting
          ? null
          : (id) {
              try { entry.remove(); } catch (_) {}
              if (!completer.isCompleted) completer.complete(id);
            },
      onClose: () {
        try { entry.remove(); } catch (_) {}
        if (!completer.isCompleted) completer.complete(null);
      },
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

class _MiniMapPopover extends StatefulWidget {
  const _MiniMapPopover({
    required this.anchorRect,
    required this.anchorWidth,
    required this.messages,
    required this.onSelect,
    required this.selecting,
    required this.selectedMessageIds,
    required this.selectionListenable,
    required this.onToggleSelection,
    required this.onClose,
  });

  final Rect anchorRect;
  final double anchorWidth;
  final List<ChatMessage> messages;
  final ValueChanged<String>? onSelect;
  final bool selecting;
  final Set<String>? selectedMessageIds;
  final Listenable? selectionListenable;
  final ValueChanged<String>? onToggleSelection;
  final VoidCallback onClose;

  @override
  State<_MiniMapPopover> createState() => _MiniMapPopoverState();
}

class _MiniMapPopoverState extends State<_MiniMapPopover>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<double> _slideY; // px translateY
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _fadeIn = curve;
    _slideY = Tween<double>(begin: 16.0, end: 0.0).animate(curve);
    WidgetsBinding.instance.addPostFrameCallback((_) async { try { await _controller.forward(); } catch (_) {} });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    try { await _controller.reverse(); } catch (_) {}
    if (mounted) widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final width = (widget.anchorWidth - 16).clamp(320.0, 800.0);
    final left = (widget.anchorRect.left + (widget.anchorRect.width - width) / 2)
        .clamp(8.0, screen.width - width - 8.0);
    final clipHeight = widget.anchorRect.top.clamp(0.0, screen.height);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _close,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: clipHeight,
          child: ClipRect(
            child: Stack(
              children: [
                Positioned(
                  left: left,
                  width: width,
                  bottom: 0,
                  child: FadeTransition(
                    opacity: _fadeIn,
                    child: AnimatedBuilder(
                      animation: _slideY,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(0, _slideY.value),
                        child: child,
                      ),
                      child: _GlassPanel(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                        child: _MiniMapList(
                          messages: widget.messages,
                          selecting: widget.selecting,
                          selectedMessageIds: widget.selectedMessageIds,
                          selectionListenable: widget.selectionListenable,
                          onTapMessage: (id) {
                            if (_closing) return;
                            if (widget.selecting) {
                              widget.onToggleSelection?.call(id);
                            } else {
                              widget.onSelect?.call(id);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child, this.borderRadius});
  final Widget child;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: (isDark ? Colors.black : Colors.white).withOpacity(isDark ? 0.28 : 0.56),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(isDark ? 0.06 : 0.18), width: 0.7),
              left: BorderSide(color: Colors.white.withOpacity(isDark ? 0.04 : 0.12), width: 0.6),
              right: BorderSide(color: Colors.white.withOpacity(isDark ? 0.04 : 0.12), width: 0.6),
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _MiniMapList extends StatelessWidget {
  const _MiniMapList({
    required this.messages,
    required this.onTapMessage,
    required this.selecting,
    this.selectedMessageIds,
    this.selectionListenable,
  });
  final List<ChatMessage> messages;
  final ValueChanged<String> onTapMessage;
  final bool selecting;
  final Set<String>? selectedMessageIds;
  final Listenable? selectionListenable;

  String _oneLine(String s) {
    var t = s
        .replaceAll(RegExp(r'<think>[\s\S]*?<\/think>', caseSensitive: false), '')
        .replaceAll(RegExp(r"\[image:[^\]]+\]"), "")
        .replaceAll(RegExp(r"\[file:[^\]]+\]"), "")
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return t;
  }

  List<_QaPair> _buildPairs(List<ChatMessage> items) {
    final pairs = <_QaPair>[];
    ChatMessage? pendingUser;
    for (final m in items) {
      if (m.role == 'user') {
        if (pendingUser != null) pairs.add(_QaPair(user: pendingUser, assistant: null));
        pendingUser = m;
      } else if (m.role == 'assistant') {
        if (pendingUser != null) {
          pairs.add(_QaPair(user: pendingUser, assistant: m));
          pendingUser = null;
        } else {
          pairs.add(_QaPair(user: null, assistant: m));
        }
      }
    }
    if (pendingUser != null) pairs.add(_QaPair(user: pendingUser, assistant: null));
    return pairs;
  }

  @override
  Widget build(BuildContext context) {
    Widget buildList(List<_QaPair> pairs) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
            primary: false,
            shrinkWrap: true,
            itemCount: pairs.length,
            itemBuilder: (context, index) {
              final p = pairs[index];
              final userSelected = selecting &&
                  selectedMessageIds != null &&
                  p.user != null &&
                  selectedMessageIds!.contains(p.user!.id);
              final assistantSelected = selecting &&
                  selectedMessageIds != null &&
                  p.assistant != null &&
                  selectedMessageIds!.contains(p.assistant!.id);

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _MiniMapRow(
                  user: p.user,
                  assistant: p.assistant,
                  userSelected: userSelected,
                  assistantSelected: assistantSelected,
                  toOneLine: _oneLine,
                  onTapMessage: onTapMessage,
                ),
              );
            },
          ),
        ),
      );
    }

    if (selecting && selectionListenable != null) {
      return AnimatedBuilder(
        animation: selectionListenable!,
        builder: (context, child) => buildList(_buildPairs(messages)),
      );
    }

    final pairs = _buildPairs(messages);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
          primary: false,
          shrinkWrap: true,
          itemCount: pairs.length,
          itemBuilder: (context, index) {
            final p = pairs[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _MiniMapRow(
                user: p.user,
                assistant: p.assistant,
                userSelected: false,
                assistantSelected: false,
                toOneLine: _oneLine,
                onTapMessage: onTapMessage,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _QaPair {
  final ChatMessage? user;
  final ChatMessage? assistant;
  _QaPair({required this.user, required this.assistant});
}

class _MiniMapRow extends StatefulWidget {
  const _MiniMapRow({
    required this.user,
    required this.assistant,
    required this.toOneLine,
    required this.onTapMessage,
    required this.userSelected,
    required this.assistantSelected,
  });
  final ChatMessage? user;
  final ChatMessage? assistant;
  final String Function(String) toOneLine;
  final ValueChanged<String> onTapMessage;
  final bool userSelected;
  final bool assistantSelected;

  @override
  State<_MiniMapRow> createState() => _MiniMapRowState();
}

class _MiniMapRowState extends State<_MiniMapRow> {
  bool _hoverUser = false;
  bool _hoverAssistant = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userText = widget.user?.content ?? '';
    final asstText = widget.assistant?.content ?? '';
    final userBorder = cs.primary.withOpacity(isDark ? 0.45 : 0.35);

    final assistantSelectedBg = (isDark ? cs.primary.withOpacity(0.18) : cs.primary.withOpacity(0.10));
    final assistantBorder = cs.primary.withOpacity(isDark ? 0.38 : 0.28);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // User bubble
        Align(
          alignment: Alignment.centerRight,
          child: MouseRegion(
            cursor: widget.user != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
            onEnter: (_) => setState(() => _hoverUser = true),
            onExit: (_) => setState(() => _hoverUser = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.user != null ? () => widget.onTapMessage(widget.user!.id) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(
                    _hoverUser
                        ? (widget.userSelected ? (isDark ? 0.32 : 0.18) : (isDark ? 0.22 : 0.14))
                        : (widget.userSelected ? (isDark ? 0.26 : 0.14) : (isDark ? 0.15 : 0.08)),
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: widget.userSelected ? Border.all(color: userBorder, width: 1) : null,
                ),
                child: Text(
                  userText.isNotEmpty ? widget.toOneLine(userText) : ' ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, height: 1.35, color: cs.onSurface, decoration: TextDecoration.none),
                  textAlign: TextAlign.left,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Assistant line
        Align(
          alignment: Alignment.centerLeft,
          child: MouseRegion(
            cursor: widget.assistant != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
            onEnter: (_) => setState(() => _hoverAssistant = true),
            onExit: (_) => setState(() => _hoverAssistant = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.assistant != null ? () => widget.onTapMessage(widget.assistant!.id) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: widget.assistantSelected
                      ? assistantSelectedBg
                      : cs.onSurface.withOpacity(
                          _hoverAssistant ? (isDark ? 0.07 : 0.05) : (isDark ? 0.05 : 0.03),
                        ),
                  borderRadius: BorderRadius.circular(16),
                  border: widget.assistantSelected ? Border.all(color: assistantBorder, width: 1) : null,
                ),
                child: Text(
                  asstText.isNotEmpty ? widget.toOneLine(asstText) : ' ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15.2, height: 1.4, decoration: TextDecoration.none),
                  textAlign: TextAlign.left,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
