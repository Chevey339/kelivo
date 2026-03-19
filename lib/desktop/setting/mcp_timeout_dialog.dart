import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/providers/mcp_provider.dart';
import '../../icons/lucide_adapter.dart' as lucide;
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/snackbar.dart';

Future<void> showDesktopMcpTimeoutDialog(BuildContext context) async {
  final cs = Theme.of(context).colorScheme;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      backgroundColor: cs.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const _DesktopMcpTimeoutDialog(),
    ),
  );
}

class _DesktopMcpTimeoutDialog extends StatefulWidget {
  const _DesktopMcpTimeoutDialog();
  @override
  State<_DesktopMcpTimeoutDialog> createState() =>
      _DesktopMcpTimeoutDialogState();
}

class _DesktopMcpTimeoutDialogState extends State<_DesktopMcpTimeoutDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final seconds = context.read<McpProvider>().requestTimeoutSeconds;
    _controller = TextEditingController(text: seconds.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = _controller.text.trim();
    final seconds = int.tryParse(raw);
    if (seconds == null || seconds <= 0) {
      showAppSnackBar(
        context,
        message: AppLocalizations.of(context)!.mcpTimeoutInvalid,
        type: NotificationType.warning,
      );
      return;
    }
    await context.read<McpProvider>().updateRequestTimeout(
      Duration(seconds: seconds),
    );
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  Text(
                    l10n.mcpTimeoutDialogTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  _SmallIconBtn(
                    icon: lucide.Lucide.X,
                    tooltip: l10n.mcpPageClose,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
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
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _ActionBtn(
                  label: l10n.mcpServerEditSheetCancel,
                  onTap: () => Navigator.of(context).maybePop(),
                  background: Colors.transparent,
                  foreground: cs.onSurface,
                  hoverBackground: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.05),
                ),
                const SizedBox(width: 8),
                _ActionBtn(
                  label: l10n.mcpServerEditSheetSave,
                  onTap: _save,
                  background: cs.primary,
                  foreground: cs.onPrimary,
                  hoverBackground: cs.primary.withValues(alpha: 0.9),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallIconBtn extends StatefulWidget {
  const _SmallIconBtn({required this.icon, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  @override
  State<_SmallIconBtn> createState() => _SmallIconBtnState();
}

class _SmallIconBtnState extends State<_SmallIconBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _hover
        ? (isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05))
        : Colors.transparent;
    final btn = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Icon(widget.icon, size: 18, color: cs.onSurface),
    );
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: widget.tooltip == null
            ? btn
            : Tooltip(message: widget.tooltip!, child: btn),
      ),
    );
  }
}

class _TextBtn extends StatefulWidget {
  const _TextBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  State<_TextBtn> createState() => _TextBtnState();
}

class _TextBtnState extends State<_TextBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _hover
        ? (isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05))
        : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(widget.label, style: TextStyle(color: cs.onSurface)),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatefulWidget {
  const _ActionBtn({
    required this.label,
    required this.onTap,
    required this.background,
    required this.foreground,
    required this.hoverBackground,
  });
  final String label;
  final VoidCallback onTap;
  final Color background;
  final Color hoverBackground;
  final Color foreground;

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bg = _hover ? widget.hoverBackground : widget.background;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
