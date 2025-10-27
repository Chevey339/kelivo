import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../icons/lucide_adapter.dart' as lucide;
import '../../l10n/app_localizations.dart';
import '../../core/providers/mcp_provider.dart';
import '../../shared/widgets/snackbar.dart';
import '../../shared/widgets/ios_switch.dart';

Future<void> showDesktopMcpEditDialog(BuildContext context, {String? serverId}) async {
  final cs = Theme.of(context).colorScheme;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      backgroundColor: cs.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
        child: _DesktopMcpEditDialog(serverId: serverId),
      ),
    ),
  );
}

class _DesktopMcpEditDialog extends StatefulWidget {
  const _DesktopMcpEditDialog({this.serverId});
  final String? serverId;

  @override
  State<_DesktopMcpEditDialog> createState() => _DesktopMcpEditDialogState();
}

class _DesktopMcpEditDialogState extends State<_DesktopMcpEditDialog> with SingleTickerProviderStateMixin {
  bool get isEdit => widget.serverId != null;
  late final TabController? _tab = isEdit ? TabController(length: 2, vsync: this) : null;

  bool _enabled = true;
  final _nameCtrl = TextEditingController();
  McpTransportType _transport = McpTransportType.http;
  final _urlCtrl = TextEditingController();
  final List<_HeaderEntry> _headers = [];

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      final server = context.read<McpProvider>().getById(widget.serverId!)!;
      _enabled = server.enabled;
      _nameCtrl.text = server.name;
      _transport = server.transport;
      _urlCtrl.text = server.url;
      server.headers.forEach((k, v) {
        _headers.add(_HeaderEntry(TextEditingController(text: k), TextEditingController(text: v)));
      });
    }
  }

  @override
  void dispose() {
    _tab?.dispose();
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    for (final h in _headers) { h.dispose(); }
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final mcp = context.read<McpProvider>();
    final name = _nameCtrl.text.trim().isEmpty ? 'MCP' : _nameCtrl.text.trim();
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      showAppSnackBar(context, message: l10n.mcpServerEditSheetUrlRequired, type: NotificationType.warning);
      return;
    }
    final headers = <String, String>{ for (final h in _headers) if (h.key.text.trim().isNotEmpty) h.key.text.trim(): h.value.text.trim() };
    if (isEdit) {
      final old = mcp.getById(widget.serverId!)!;
      await mcp.updateServer(old.copyWith(enabled: _enabled, name: name, transport: _transport, url: url, headers: headers));
    } else {
      await mcp.addServer(enabled: _enabled, name: name, transport: _transport, url: url, headers: headers);
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  Widget _headerBar() {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  isEdit ? l10n.mcpServerEditSheetTitleEdit : l10n.mcpServerEditSheetTitleAdd,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            if (isEdit)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: _SmallIconBtn(
                  icon: lucide.Lucide.RefreshCw,
                  tooltip: l10n.mcpServerEditSheetSyncToolsTooltip,
                  onTap: () async {
                    await context.read<McpProvider>().refreshTools(widget.serverId!);
                  },
                ),
              ),
            _SmallIconBtn(
              icon: lucide.Lucide.X,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _basicForm() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: Row(
            children: [
              Expanded(child: Text(l10n.mcpServerEditSheetEnabledLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
              IosSwitch(value: _enabled, onChanged: (v) => setState(() => _enabled = v)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _labeledField(label: l10n.mcpServerEditSheetNameLabel, controller: _nameCtrl, hint: 'My MCP', bold: true),
        const SizedBox(height: 10),
        Text(l10n.mcpServerEditSheetTransportLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        _SegChoiceBar(
          labels: const ['Streamable HTTP', 'SSE'],
          selectedIndex: _transport == McpTransportType.http ? 0 : 1,
          onSelected: (i) => setState(() => _transport = i == 0 ? McpTransportType.http : McpTransportType.sse),
        ),
        const SizedBox(height: 10),
        if (_transport == McpTransportType.sse)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(l10n.mcpServerEditSheetSseRetryHint, style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.7))),
          ),
        _labeledField(
          label: l10n.mcpServerEditSheetUrlLabel,
          controller: _urlCtrl,
          hint: _transport == McpTransportType.sse ? 'http://localhost:3000/sse' : 'http://localhost:3000', bold: true,
        ),
        const SizedBox(height: 16),
        Text(l10n.mcpServerEditSheetCustomHeadersTitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Column(
          children: [
            for (int i = 0; i < _headers.length; i++) ...[
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _labeledField(label: l10n.mcpServerEditSheetHeaderNameLabel, controller: _headers[i].key, hint: l10n.mcpServerEditSheetHeaderNameHint, bold: false),
                    const SizedBox(height: 10),
                    _labeledField(label: l10n.mcpServerEditSheetHeaderValueLabel, controller: _headers[i].value, hint: l10n.mcpServerEditSheetHeaderValueHint, bold: false),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _SmallIconBtn(
                        icon: lucide.Lucide.Trash2,
                        tooltip: l10n.mcpServerEditSheetRemoveHeaderTooltip,
                        onTap: () => setState(() => _headers.removeAt(i)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(lucide.Lucide.Plus, size: 16),
                label: Text(l10n.mcpServerEditSheetAddHeader),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ).copyWith(
                  splashFactory: NoSplash.splashFactory,
                  overlayColor: const MaterialStatePropertyAll(Colors.transparent),
                  backgroundColor: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.hovered)) {
                      return isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05);
                    }
                    return Colors.transparent;
                  }),
                ),
                onPressed: () => setState(() => _headers.add(_HeaderEntry(TextEditingController(), TextEditingController()))),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _toolsTab() {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final server = context.watch<McpProvider>().getById(widget.serverId!);
    final tools = server?.tools ?? const <McpToolConfig>[];
    if (tools.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Text(l10n.mcpServerEditSheetNoToolsHint, style: TextStyle(color: cs.onSurface.withOpacity(0.6))),
        ),
      );
    }
    return ListView(
      children: [
        for (final tool in tools) ...[
          _card(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tool.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      if ((tool.description ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(tool.description!, style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.7))),
                      ],
                      if (tool.params.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: tool.params.map((p) {
                            final color = p.required ? cs.primary : cs.onSurface.withOpacity(0.5);
                            final bg = p.required ? cs.primary.withOpacity(0.12) : cs.onSurface.withOpacity(0.06);
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: color.withOpacity(0.5)),
                              ),
                              child: Text(p.name, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                IosSwitch(
                  value: tool.enabled,
                  onChanged: (v) => context.read<McpProvider>().setToolEnabled(server!.id, tool.name, v),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _headerBar(),
        if (isEdit)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: AnimatedBuilder(
            animation: _tab!,
            builder: (context, _) => _SegTabBar(
              controller: _tab!,
              tabs: [l10n.mcpServerEditSheetTabBasic, l10n.mcpServerEditSheetTabTools],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: isEdit
                ? AnimatedBuilder(
                    animation: _tab!,
                    builder: (context, _) => _tab!.index == 0 ? _basicForm() : _toolsTab(),
                  )
                : _basicForm(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ).copyWith(
                  splashFactory: NoSplash.splashFactory,
                  overlayColor: const MaterialStatePropertyAll(Colors.transparent),
                  backgroundColor: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.hovered)) {
                      return Color.lerp(cs.primary, Colors.white, Theme.of(context).brightness == Brightness.dark ? 0.06 : 0.08);
                    }
                    return cs.primary;
                  }),
                ),
                child: Text(l10n.mcpServerEditSheetSave),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _labeledField({required String label, required TextEditingController controller, String? hint, bool bold = false}) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: cs.onSurface.withOpacity(0.8))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: cs.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: isDark ? Colors.white10 : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.4)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: cs.primary.withOpacity(0.5)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(isDark ? 0.08 : 0.06), width: 0.6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: child,
    );
  }
}

class _HeaderEntry {
  final TextEditingController key;
  final TextEditingController value;
  _HeaderEntry(this.key, this.value);
  void dispose() { key.dispose(); value.dispose(); }
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
    final bg = _hover ? (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05)) : Colors.transparent;
    final btn = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      alignment: Alignment.center,
      child: Icon(widget.icon, size: 18, color: cs.onSurface),
    );
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: widget.tooltip == null ? btn : Tooltip(message: widget.tooltip!, child: btn),
      ),
    );
  }
}

class _SegChoiceBar extends StatelessWidget {
  const _SegChoiceBar({required this.labels, required this.selectedIndex, required this.onSelected});
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    const double outerHeight = 44;
    const double innerPadding = 4;
    const double gap = 6;
    const double minSegWidth = 88;
    final double pillRadius = 18;
    final double innerRadius = ((pillRadius - innerPadding).clamp(0.0, pillRadius)).toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availWidth = constraints.maxWidth;
        final double innerAvailWidth = availWidth - innerPadding * 2;
        final double segWidth = math.max(
          minSegWidth,
          (innerAvailWidth - gap * (labels.length - 1)) / labels.length,
        );
        final double rowWidth = segWidth * labels.length + gap * (labels.length - 1);

        final Color shellBg = isDark ? Colors.white.withOpacity(0.08) : Colors.white;

        List<Widget> children = [];
        for (int index = 0; index < labels.length; index++) {
          final bool selected = selectedIndex == index;
          children.add(
            SizedBox(
              width: segWidth,
              height: double.infinity,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => onSelected(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      color: selected ? cs.primary.withOpacity(0.14) : Colors.transparent,
                      borderRadius: BorderRadius.circular(innerRadius),
                    ),
                    alignment: Alignment.center,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        labels[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? cs.primary : cs.onSurface.withOpacity(0.82),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          if (index != labels.length - 1) children.add(const SizedBox(width: gap));
        }

        return Container(
          height: outerHeight,
          decoration: BoxDecoration(
            color: shellBg,
            borderRadius: BorderRadius.circular(pillRadius),
          ),
          clipBehavior: Clip.hardEdge,
          child: Padding(
            padding: const EdgeInsets.all(innerPadding),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: innerAvailWidth),
                child: SizedBox(width: rowWidth, child: Row(children: children)),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SegTabBar extends StatelessWidget {
  const _SegTabBar({required this.controller, required this.tabs});
  final TabController controller;
  final List<String> tabs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    const double outerHeight = 44;
    const double innerPadding = 4;
    const double gap = 6;
    const double minSegWidth = 88;
    final double pillRadius = 18;
    final double innerRadius = ((pillRadius - innerPadding).clamp(0.0, pillRadius)).toDouble();

    final content = LayoutBuilder(
      builder: (context, constraints) {
        final double availWidth = constraints.maxWidth;
        final double innerAvailWidth = availWidth - innerPadding * 2;
        final double segWidth = math.max(
          minSegWidth,
          (innerAvailWidth - gap * (tabs.length - 1)) / tabs.length,
        );
        final double rowWidth = segWidth * tabs.length + gap * (tabs.length - 1);

        final Color shellBg = isDark ? Colors.white.withOpacity(0.08) : Colors.white;

        List<Widget> children = [];
        for (int index = 0; index < tabs.length; index++) {
          final bool selected = controller.index == index;
          children.add(
            SizedBox(
              width: segWidth,
              height: double.infinity,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => controller.animateTo(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      color: selected ? cs.primary.withOpacity(0.14) : Colors.transparent,
                      borderRadius: BorderRadius.circular(innerRadius),
                    ),
                    alignment: Alignment.center,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        tabs[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? cs.primary : cs.onSurface.withOpacity(0.82),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          if (index != tabs.length - 1) children.add(const SizedBox(width: gap));
        }

        return Container(
          height: outerHeight,
          decoration: BoxDecoration(
            color: shellBg,
            borderRadius: BorderRadius.circular(pillRadius),
          ),
          clipBehavior: Clip.hardEdge,
          child: Padding(
            padding: const EdgeInsets.all(innerPadding),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: innerAvailWidth),
                child: SizedBox(width: rowWidth, child: Row(children: children)),
              ),
            ),
          ),
        );
      },
    );

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => content,
    );
  }
}
