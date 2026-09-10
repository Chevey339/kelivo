import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/mcp_provider.dart';
import '../../../core/services/mcp/mcp_config_import.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/form_sheet.dart';
import '../../../shared/widgets/ios_tile_button.dart';
import '../../../shared/widgets/section_card.dart';
import '../../settings/widgets/custom_theme_widgets.dart';

Future<void> showMcpJsonImport(
  BuildContext context, {
  bool desktop = false,
}) async {
  final provider = context.read<McpProvider>();
  final child = _McpJsonImport(provider: provider);
  if (desktop) {
    await showAppDialog<void>(context, maxWidth: 640, child: child);
  } else {
    await showFormSheet<void>(context, builder: (_) => child);
  }
}

class _McpJsonImport extends StatefulWidget {
  const _McpJsonImport({required this.provider});
  final McpProvider provider;
  @override
  State<_McpJsonImport> createState() => _McpJsonImportState();
}

class _McpJsonImportState extends State<_McpJsonImport> {
  final _text = TextEditingController();
  List<McpServerConfig>? _preview;
  String? _error;
  bool _saving = false;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (_preview == null) {
      try {
        setState(() {
          _preview = parseMcpConfigImport(_text.text);
          _error = null;
        });
      } catch (error) {
        setState(() => _error = error.toString());
      }
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.provider.importServers(_preview!);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return FormSheet(
      title: l10n.mcpImportJson,
      actions: Row(
        children: [
          Expanded(
            child: IosTileButton(
              icon: Lucide.X,
              label: l10n.mcpPageCancel,
              enabled: !_saving,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: IosTileButton(
              icon: _preview == null ? Lucide.Search : Lucide.Download,
              label: _preview == null
                  ? l10n.mcpImportPreview
                  : l10n.mcpImportConfirm,
              enabled: !_saving,
              backgroundColor: cs.primary,
              onTap: _submit,
            ),
          ),
        ],
      ),
      children: [
        Text(
          l10n.mcpImportJsonHint,
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        SectionCard(
          padding: const EdgeInsets.all(12),
          child: TextField(
            key: const ValueKey('mcp-import-json'),
            controller: _text,
            minLines: 6,
            maxLines: 10,
            enabled: !_saving,
            autocorrect: false,
            enableSuggestions: false,
            smartDashesType: SmartDashesType.disabled,
            smartQuotesType: SmartQuotesType.disabled,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText:
                  '{"mcpServers": {"my-server": {"command": "npx", "args": ["-y", "server"]}}}',
            ),
            onChanged: (_) => setState(() {
              _preview = null;
              _error = null;
            }),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Lucide.Clipboard, size: 16),
            label: Text(l10n.mcpImportPaste),
            onPressed: _saving
                ? null
                : () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (!mounted || data?.text == null) return;
                    setState(() {
                      _text.text = data!.text!;
                      _preview = null;
                      _error = null;
                    });
                  },
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(_error!, style: TextStyle(color: cs.error)),
          ),
        if (_preview != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.mcpImportPreview,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          SectionCard(
            padding: const EdgeInsets.all(12),
            dividers: true,
            children: [
              for (final server in _preview!)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        server.transport == McpTransportType.stdio
                            ? Lucide.Terminal
                            : Lucide.Globe,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(server.name)),
                      Text(
                        server.transport.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
