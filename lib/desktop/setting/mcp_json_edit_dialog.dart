import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../icons/lucide_adapter.dart' as lucide;
import '../../core/providers/mcp_provider.dart';
import '../../shared/widgets/snackbar.dart';
import '../../l10n/app_localizations.dart';
import '../../core/providers/settings_provider.dart';

Future<void> showDesktopMcpJsonEditDialog(BuildContext context) async {
  final cs = Theme.of(context).colorScheme;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      backgroundColor: cs.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const _DesktopMcpJsonEditDialog(),
    ),
  );
}

class _DesktopMcpJsonEditDialog extends StatefulWidget {
  const _DesktopMcpJsonEditDialog();
  @override
  State<_DesktopMcpJsonEditDialog> createState() =>
      _DesktopMcpJsonEditDialogState();
}

class _DesktopMcpJsonEditDialogState extends State<_DesktopMcpJsonEditDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.text = context.read<McpProvider>().exportServersAsUiJson();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      jsonDecode(_controller.text);
    } catch (e) {
      setState(() => _error = e.toString());
      showAppSnackBar(
        context,
        message: AppLocalizations.of(context)!.mcpJsonEditParseFailed,
        type: NotificationType.warning,
      );
      return;
    }

    try {
      await context.read<McpProvider>().replaceAllFromJson(_controller.text);
      if (!mounted) return;
      Navigator.of(context).maybePop();
      showAppSnackBar(
        context,
        message: AppLocalizations.of(context)!.mcpJsonEditSavedApplied,
      );
    } catch (e) {
      setState(() => _error = e.toString());
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: e.toString(),
        type: NotificationType.warning,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Resolve user-preferred code font family (Google/local/system)
    final settings = context.watch<SettingsProvider>();
    String resolveCodeFont() {
      final fam = settings.codeFontFamily;
      if (fam == null || fam.isEmpty) return 'monospace';
      if (settings.codeFontIsGoogle) {
        try {
          final s = GoogleFonts.getFont(fam);
          return s.fontFamily ?? fam;
        } catch (_) {
          return fam;
        }
      }
      return fam;
    }

    final codeFontFamily = resolveCodeFont();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 860, maxHeight: 720),
      child: SizedBox(
        width: 860,
        height: 720,
        child: Column(
          children: [
            // Header bar
            SizedBox(
              height: 52,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Text(
                      AppLocalizations.of(context)!.mcpJsonEditTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    _SmallIconBtn(
                      icon: lucide.Lucide.X,
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _controller,
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                      style: TextStyle(
                        fontFamily: codeFontFamily,
                        fontSize: 13.5,
                        height: 1.35,
                      ),
                      decoration: const InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _TextBtn(
                    label: AppLocalizations.of(
                      context,
                    )!.mcpServerEditSheetCancel,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.mcpServerEditSheetSave,
                    ),
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
