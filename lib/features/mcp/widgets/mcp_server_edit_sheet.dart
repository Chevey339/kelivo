import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../../../core/services/haptics.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../core/providers/mcp_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_tile_button.dart';

class _HeaderEntry {
  final TextEditingController key;
  final TextEditingController value;
  _HeaderEntry(this.key, this.value);
  void dispose() {
    key.dispose();
    value.dispose();
  }
}

Future<void> showMcpServerEditSheet(BuildContext context, {String? serverId}) async {
  final cs = Theme.of(context).colorScheme;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    // Match provider sheet corner radius
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _McpServerEditSheet(serverId: serverId),
  );
}

class _McpServerEditSheet extends StatefulWidget {
  const _McpServerEditSheet({this.serverId});
  final String? serverId;

  @override
  State<_McpServerEditSheet> createState() => _McpServerEditSheetState();
}

class _McpServerEditSheetState extends State<_McpServerEditSheet> with SingleTickerProviderStateMixin {
  late final bool isEdit = widget.serverId != null;
  TabController? _tab;

  bool _enabled = true;
  final _nameCtrl = TextEditingController();
  McpTransportType _transport = McpTransportType.http;
  final _urlCtrl = TextEditingController();
  final List<_HeaderEntry> _headers = [];

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      _tab = TabController(length: 2, vsync: this);
      _tab!.addListener(_onTabChanged);
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

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tab?.removeListener(_onTabChanged);
    _tab?.dispose();
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    for (final h in _headers) {
      h.dispose();
    }
    super.dispose();
  }

  // Match provider sheet switch row style
  Widget _switchRow({required String label, required bool value, required ValueChanged<bool> onChanged}) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
        IosSwitch(value: value, onChanged: onChanged),
      ],
    );
  }

  // Simple iOS-style card wrapper, same as provider sheet
  Widget _iosCard({required List<Widget> children}) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(isDark ? 0.08 : 0.06), width: 0.6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: 10, thickness: 0.6, color: cs.outlineVariant.withOpacity(0.18)),
              children[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget _inputRow({required String label, required TextEditingController controller, String? hint}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.8))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            // Match provider sheet input background
            fillColor: isDark ? Colors.white10 : Colors.white,
            // Match provider sheet border styles
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

  // Segmented choice bar (like top tabs), used for transport type
  Widget _transportPicker() {
    final labels = ['Streamable HTTP', 'SSE'];
    final idx = _transport == McpTransportType.http ? 0 : 1;
    return _SegChoiceBar(
      labels: labels,
      selectedIndex: idx,
      onSelected: (i) => setState(() => _transport = i == 0 ? McpTransportType.http : McpTransportType.sse),
    );
  }

  Widget _basicForm() {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _iosCard(children: [
          _switchRow(label: l10n.mcpServerEditSheetEnabledLabel, value: _enabled, onChanged: (v) => setState(() => _enabled = v)),
        ]),
        const SizedBox(height: 10),
        _inputRow(label: l10n.mcpServerEditSheetNameLabel, controller: _nameCtrl, hint: 'My MCP'),
        const SizedBox(height: 10),
        Text(l10n.mcpServerEditSheetTransportLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        _transportPicker(),
        const SizedBox(height: 10),
        if (_transport == McpTransportType.sse) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(l10n.mcpServerEditSheetSseRetryHint, style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.7))),
          ),
        ],
        _inputRow(label: l10n.mcpServerEditSheetUrlLabel, controller: _urlCtrl, hint: _transport == McpTransportType.sse ? 'http://localhost:3000/sse' : 'http://localhost:3000'),
        const SizedBox(height: 16),
        Text(l10n.mcpServerEditSheetCustomHeadersTitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _headersEditor(),
      ],
    );
  }

  Widget _headersEditor() {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < _headers.length; i++) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF7F7F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _inputRow(label: l10n.mcpServerEditSheetHeaderNameLabel, controller: _headers[i].key, hint: l10n.mcpServerEditSheetHeaderNameHint),
                const SizedBox(height: 10),
                _inputRow(label: l10n.mcpServerEditSheetHeaderValueLabel, controller: _headers[i].value, hint: l10n.mcpServerEditSheetHeaderValueHint),
                Align(
                  alignment: Alignment.centerRight,
                  child: _TactileIconButton(
                    icon: Lucide.Trash,
                    color: cs.error,
                    semanticLabel: l10n.mcpServerEditSheetRemoveHeaderTooltip,
                    onTap: () => setState(() => _headers.removeAt(i)),
                  ),
                ),
              ],
            ),
          ),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: IosTileButton(
            icon: Lucide.Plus,
            label: l10n.mcpServerEditSheetAddHeader,
            backgroundColor: cs.primary,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            onTap: () => setState(() => _headers.add(_HeaderEntry(TextEditingController(), TextEditingController()))),
          ),
        ),
      ],
    );
  }

  Future<void> _onSave() async {
    final mcp = context.read<McpProvider>();
    final name = _nameCtrl.text.trim().isEmpty ? 'MCP' : _nameCtrl.text.trim();
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      showAppSnackBar(
        context,
        message: l10n.mcpServerEditSheetUrlRequired,
        type: NotificationType.warning,
      );
      return;
    }
    final headers = <String, String>{
      for (final h in _headers)
        if (h.key.text.trim().isNotEmpty) h.key.text.trim(): h.value.text.trim(),
    };
    if (isEdit) {
      final old = mcp.getById(widget.serverId!)!;
      await mcp.updateServer(old.copyWith(enabled: _enabled, name: name, transport: _transport, url: url, headers: headers));
    } else {
      await mcp.addServer(enabled: _enabled, name: name, transport: _transport, url: url, headers: headers);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final mcp = context.watch<McpProvider>();
    final server = isEdit ? mcp.getById(widget.serverId!) : null;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: isEdit ? 0.85 : 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          builder: (c, controller) => Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              // Header: centered title with close on the left (match provider sheet)
              SizedBox(
                height: 36,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        isEdit ? l10n.mcpServerEditSheetTitleEdit : l10n.mcpServerEditSheetTitleAdd,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _TactileIconButton(
                          icon: Lucide.X,
                          color: cs.onSurface,
                          size: 22,
                          semanticLabel: l10n.mcpPageCancel,
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                    ),
                    if (isEdit)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _TactileIconButton(
                            icon: Lucide.RefreshCw,
                            color: cs.primary,
                            semanticLabel: l10n.mcpServerEditSheetSyncToolsTooltip,
                            onTap: () => mcp.refreshTools(widget.serverId!),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (isEdit) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _SegTabBar(controller: _tab!, tabs: [
                    l10n.mcpServerEditSheetTabBasic,
                    l10n.mcpServerEditSheetTabTools,
                  ]),
                ),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView(
                    controller: controller,
                    children: [
                      if (!isEdit) _basicForm(),
                      if (isEdit) ...[
                        AnimatedBuilder(
                          animation: _tab!,
                          builder: (_, __) {
                            final idx = _tab!.index;
                            if (idx == 0) {
                              return _basicForm();
                            } else {
                              // Tools tab
                              final tools = server?.tools ?? const <McpToolConfig>[];
                              if (tools.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 20),
                                  child: Center(
                                    child: Text(l10n.mcpServerEditSheetNoToolsHint, style: TextStyle(color: cs.onSurface.withOpacity(0.6))),
                                  ),
                                );
                              }
                              return Column(
                                children: [
                                  for (final tool in tools) ...[
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.white10
                                            : const Color(0xFFF7F7F9),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
                                      ),
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
                                  const SizedBox(height: 10),
                                ],
                              );
                            }
                          },
                        ),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: SizedBox(
                  width: double.infinity,
                  child: IosTileButton(
                    icon: isEdit ? Lucide.Check : Lucide.Plus,
                    label: l10n.mcpServerEditSheetSave,
                    backgroundColor: cs.primary,
                    onTap: _onSave,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- iOS tactile helpers (no ripple) ---

class _TactileIconButton extends StatefulWidget {
  const _TactileIconButton({required this.icon, required this.color, required this.onTap, this.semanticLabel, this.size = 20});
  final IconData icon; final Color color; final VoidCallback onTap; final String? semanticLabel; final double size;
  @override State<_TactileIconButton> createState() => _TactileIconButtonState();
}

class _TactileIconButtonState extends State<_TactileIconButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final base = widget.color; final press = base.withOpacity(0.7);
    return Semantics(
      button: true, label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(()=>_pressed=true),
        onTapUp: (_) => setState(()=>_pressed=false),
        onTapCancel: () => setState(()=>_pressed=false),
        onTap: () { Haptics.light(); widget.onTap(); },
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(widget.icon, size: widget.size, color: _pressed ? press : base),
        ),
      ),
    );
  }
}

class _TactileRow extends StatefulWidget {
  const _TactileRow({required this.builder, this.onTap, this.pressedScale = 1.0});
  final Widget Function(bool pressed) builder; final VoidCallback? onTap; final double pressedScale;
  @override State<_TactileRow> createState() => _TactileRowState();
}

class _TactileRowState extends State<_TactileRow> {
  bool _pressed = false; void _set(bool v){ if(_pressed!=v) setState(()=>_pressed=v);} 
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap==null?null:(_)=>_set(true),
      onTapUp: widget.onTap==null?null:(_){ /* keep pressed a bit for better feel */ },
      onTapCancel: widget.onTap==null?null:()=>_set(false),
      onTap: widget.onTap==null?null:(){
        if (context.read<SettingsProvider>().hapticsOnListItemTap) Haptics.soft();
        widget.onTap!.call();
        Future.delayed(const Duration(milliseconds: 120), () { if (mounted) _set(false); });
      },
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 110), curve: Curves.easeOutCubic,
        child: widget.builder(_pressed),
      ),
    );
  }
}

class _IosOutlineButton extends StatelessWidget {
  const _IosOutlineButton({required this.label, required this.onTap});
  final String label; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _TactileRow(
      pressedScale: 0.98,
      onTap: onTap,
      builder: (pressed) {
        final overlay = pressed ? (Theme.of(context).brightness==Brightness.dark ? Colors.black.withOpacity(0.04) : Colors.white.withOpacity(0.04)) : Colors.transparent;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160), curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: overlay,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.primary.withOpacity(0.5)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
        );
      },
    );
  }
}

class _IosFilledButton extends StatelessWidget {
  const _IosFilledButton({required this.label, required this.onTap, this.icon});
  final String label; final VoidCallback onTap; final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _TactileRow(
      pressedScale: 0.98,
      onTap: onTap,
      builder: (pressed) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160), curve: Curves.easeOutCubic,
          decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: cs.onPrimary),
                const SizedBox(width: 6),
              ],
              Text(label, style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.w600)),
            ],
          ),
        );
      },
    );
  }
}

// Generic segmented choice bar (visual style matches provider segmented tabs)
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
              child: _TactileRow(
                onTap: () => onSelected(index),
                builder: (pressed) {
                  final Color baseBg = selected ? cs.primary.withOpacity(0.14) : Colors.transparent;
                  final Color bg = baseBg;
                  final Color baseTextColor = selected ? cs.primary : cs.onSurface.withOpacity(0.82);
                  final Color targetTextColor = pressed
                      ? Color.lerp(baseTextColor, Colors.white, 0.22) ?? baseTextColor
                      : baseTextColor;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(innerRadius),
                    ),
                    alignment: Alignment.center,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: TweenAnimationBuilder<Color?>(
                        tween: ColorTween(end: targetTextColor),
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOutCubic,
                        builder: (context, color, _) {
                          return Text(
                            labels[index],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color ?? baseTextColor,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
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

// Copy of provider segmented tab to match style
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

    return LayoutBuilder(
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
              child: _TactileRow(
                onTap: () => controller.animateTo(index),
                builder: (pressed) {
                  // Background does not change on press; only selected shows subtle tint
                  final Color baseBg = selected ? cs.primary.withOpacity(0.14) : Colors.transparent;
                  final Color bg = baseBg;

                  // Text color lightens slightly on press
                  final Color baseTextColor = selected ? cs.primary : cs.onSurface.withOpacity(0.82);
                  final Color targetTextColor = pressed
                      ? Color.lerp(baseTextColor, Colors.white, 0.22) ?? baseTextColor
                      : baseTextColor;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(innerRadius),
                    ),
                    alignment: Alignment.center,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: TweenAnimationBuilder<Color?>(
                        tween: ColorTween(end: targetTextColor),
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOutCubic,
                        builder: (context, color, _) {
                          return Text(
                            tabs[index],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color ?? baseTextColor,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
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
  }
}
