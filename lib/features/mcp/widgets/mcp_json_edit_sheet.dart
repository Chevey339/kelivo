import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../icons/lucide_adapter.dart';
import '../../../core/providers/mcp_provider.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/providers/settings_provider.dart';

Future<void> showMcpJsonEditSheet(BuildContext context) async {
  final cs = Theme.of(context).colorScheme;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _McpJsonEditSheet(),
  );
}

class _McpJsonEditSheet extends StatefulWidget {
  @override
  State<_McpJsonEditSheet> createState() => _McpJsonEditSheetState();
}

class _McpJsonEditSheetState extends State<_McpJsonEditSheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    final mcp = context.read<McpProvider>();
    _controller.text = mcp.exportServersAsUiJson();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      // Quick JSON check before provider import for immediate feedback
      jsonDecode(_controller.text);
    } catch (e) {
      setState(() => _error = e.toString());
      showAppSnackBar(
        context,
        message: l10n.mcpJsonEditParseFailed,
        type: NotificationType.warning,
      );
      return;
    }
    try {
      await context.read<McpProvider>().replaceAllFromJson(_controller.text);
      if (!mounted) return;
      Navigator.of(context).maybePop();
      showAppSnackBar(context, message: l10n.mcpJsonEditSavedApplied);
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
    final media = MediaQuery.of(context);
    final height = media.size.height * 0.9;

    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            const SizedBox(height: 8),
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
            // const SizedBox(height: 6),
            // Header bar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Lucide.X, size: 20, color: cs.onSurface),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                  ),
                  const Spacer(),
                  Text(
                    AppLocalizations.of(context)!.mcpJsonEditTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _save,
                    icon: Icon(Lucide.Check, size: 20, color: cs.primary),
                    tooltip: AppLocalizations.of(
                      context,
                    )!.mcpServerEditSheetSave,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  bottom: media.viewInsets.bottom + 12,
                ),
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
                        height: 1.4,
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
            if (_error != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
