import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../shared/widgets/ios_switch.dart';

import '../l10n/app_localizations.dart';
import '../icons/lucide_adapter.dart' as lucide;
import '../core/providers/settings_provider.dart';

Future<String?> showDesktopAddProviderDialog(BuildContext context) async {
  String? result;
  await showGeneralDialog<String?>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'add-provider-dialog',
    barrierColor: Colors.black.withOpacity(0.25),
    pageBuilder: (ctx, _, __) => const _AddProviderDialogBody(),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(opacity: curved, child: ScaleTransition(scale: Tween<double>(begin: 0.98, end: 1).animate(curved), child: child));
    },
  ).then((v) => result = v);
  return result;
}

class _AddProviderDialogBody extends StatefulWidget {
  const _AddProviderDialogBody();
  @override
  State<_AddProviderDialogBody> createState() => _AddProviderDialogBodyState();
}

class _AddProviderDialogBodyState extends State<_AddProviderDialogBody> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  // OpenAI
  bool _openaiEnabled = true;
  final TextEditingController _openaiName = TextEditingController(text: 'OpenAI');
  final TextEditingController _openaiKey = TextEditingController();
  final TextEditingController _openaiBase = TextEditingController(text: 'https://api.openai.com/v1');
  final TextEditingController _openaiPath = TextEditingController(text: '/chat/completions');
  bool _openaiUseResponse = false;

  // Google
  bool _googleEnabled = true;
  final TextEditingController _googleName = TextEditingController(text: 'Google');
  final TextEditingController _googleKey = TextEditingController();
  final TextEditingController _googleBase = TextEditingController(text: 'https://generativelanguage.googleapis.com/v1beta');
  bool _googleVertex = false;
  final TextEditingController _googleLocation = TextEditingController(text: 'us-central1');
  final TextEditingController _googleProject = TextEditingController();
  final TextEditingController _googleSaJson = TextEditingController();

  // Claude
  bool _claudeEnabled = true;
  final TextEditingController _claudeName = TextEditingController(text: 'Claude');
  final TextEditingController _claudeKey = TextEditingController();
  final TextEditingController _claudeBase = TextEditingController(text: 'https://api.anthropic.com/v1');

  @override
  void dispose() {
    _tab.dispose();
    _openaiName.dispose();
    _openaiKey.dispose();
    _openaiBase.dispose();
    _openaiPath.dispose();
    _googleName.dispose();
    _googleKey.dispose();
    _googleBase.dispose();
    _googleLocation.dispose();
    _googleProject.dispose();
    _googleSaJson.dispose();
    _claudeName.dispose();
    _claudeKey.dispose();
    _claudeBase.dispose();
    super.dispose();
  }

  InputDecoration _deskInputDecoration(BuildContext context, {String? hint}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      isDense: true,
      hintText: hint,
      filled: true,
      fillColor: isDark ? Colors.white10 : const Color(0xFFF7F7F9),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.12), width: 0.6)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.12), width: 0.6)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cs.primary.withOpacity(0.35), width: 0.8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8))),
      );

  Widget _switchTile({required String label, required bool value, required ValueChanged<bool> onChanged}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [Expanded(child: Text(label, style: const TextStyle(fontSize: 13))), IosSwitch(value: value, onChanged: onChanged)]),
    );
  }

  Future<void> _importGoogleServiceAccount() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['json'], allowMultiple: false);
      if (result == null || result.files.isEmpty) return;
      final f = result.files.single.path;
      if (f == null) return;
      final text = await File(f).readAsString();
      _googleSaJson.text = text;
      try {
        final obj = jsonDecode(text) as Map<String, dynamic>;
        final pid = (obj['project_id'] as String?)?.trim();
        if ((pid ?? '').isNotEmpty && _googleProject.text.trim().isEmpty) _googleProject.text = pid!;
      } catch (_) {}
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _onAdd() async {
    final settings = context.read<SettingsProvider>();
    String uniqueKey(String prefix, String display) {
      final existing = context.read<SettingsProvider>().providerConfigs.keys.toSet();
      if (display.toLowerCase() == prefix.toLowerCase()) {
        int i = 1; String candidate = '$prefix - $i';
        while (existing.contains(candidate)) { i++; candidate = '$prefix - $i'; }
        return candidate;
      }
      String base = '$prefix - $display';
      if (!existing.contains(base)) return base;
      int i = 2; String candidate = '$base ($i)';
      while (existing.contains(candidate)) { i++; candidate = '$base ($i)'; }
      return candidate;
    }

    final idx = _tab.index;
    String createdKey = '';
    if (idx == 0) {
      final rawName = _openaiName.text.trim();
      final display = rawName.isEmpty ? 'OpenAI' : rawName;
      final keyName = uniqueKey('OpenAI', display);
      final base = _openaiBase.text.trim().isNotEmpty ? _openaiBase.text.trim() : 'https://api.openai.com/v1';
      final promo = base.toLowerCase().contains('aihubmix.com');
      final cfg = ProviderConfig(
        id: keyName,
        enabled: _openaiEnabled,
        name: display,
        apiKey: _openaiKey.text.trim(),
        baseUrl: base,
        providerType: ProviderKind.openai,
        chatPath: _openaiUseResponse ? null : (_openaiPath.text.trim().isNotEmpty ? _openaiPath.text.trim() : '/chat/completions'),
        useResponseApi: _openaiUseResponse,
        models: const [],
        modelOverrides: const {},
        proxyEnabled: false,
        proxyHost: '',
        proxyPort: '8080',
        proxyUsername: '',
        proxyPassword: '',
        aihubmixAppCodeEnabled: promo,
      );
      await settings.setProviderConfig(keyName, cfg);
      createdKey = keyName;
    } else if (idx == 1) {
      final rawName = _googleName.text.trim();
      final display = rawName.isEmpty ? 'Google' : rawName;
      final keyName = uniqueKey('Google', display);
      final base = _googleVertex
          ? 'https://aiplatform.googleapis.com'
          : (_googleBase.text.trim().isNotEmpty ? _googleBase.text.trim() : 'https://generativelanguage.googleapis.com/v1beta');
      final promo = base.toLowerCase().contains('aihubmix.com');
      final cfg = ProviderConfig(
        id: keyName,
        enabled: _googleEnabled,
        name: display,
        apiKey: _googleVertex ? '' : _googleKey.text.trim(),
        baseUrl: base,
        providerType: ProviderKind.google,
        vertexAI: _googleVertex,
        location: _googleVertex ? (_googleLocation.text.trim().isNotEmpty ? _googleLocation.text.trim() : 'us-central1') : '',
        projectId: _googleVertex ? _googleProject.text.trim() : '',
        serviceAccountJson: _googleVertex ? _googleSaJson.text.trim() : null,
        models: const [],
        modelOverrides: const {},
        proxyEnabled: false,
        proxyHost: '',
        proxyPort: '8080',
        proxyUsername: '',
        proxyPassword: '',
        aihubmixAppCodeEnabled: promo,
      );
      await settings.setProviderConfig(keyName, cfg);
      createdKey = keyName;
    } else {
      final rawName = _claudeName.text.trim();
      final display = rawName.isEmpty ? 'Claude' : rawName;
      final keyName = uniqueKey('Claude', display);
      final base = _claudeBase.text.trim().isNotEmpty ? _claudeBase.text.trim() : 'https://api.anthropic.com/v1';
      final promo = base.toLowerCase().contains('aihubmix.com');
      final cfg = ProviderConfig(
        id: keyName,
        enabled: _claudeEnabled,
        name: display,
        apiKey: _claudeKey.text.trim(),
        baseUrl: base,
        providerType: ProviderKind.claude,
        models: const [],
        modelOverrides: const {},
        proxyEnabled: false,
        proxyHost: '',
        proxyPort: '8080',
        proxyUsername: '',
        proxyPassword: '',
        aihubmixAppCodeEnabled: promo,
      );
      await settings.setProviderConfig(keyName, cfg);
      createdKey = keyName;
    }

    final order = List<String>.of(context.read<SettingsProvider>().providersOrder);
    order.remove(createdKey);
    order.insert(0, createdKey);
    await context.read<SettingsProvider>().setProvidersOrder(order);

    if (mounted) Navigator.of(context).pop(createdKey);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 580, maxWidth: 700, maxHeight: 640),
        child: Material(
          color: cs.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outlineVariant.withOpacity(0.25))),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  height: 52,
                  color: cs.surface,
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
                  child: Row(children: [
                    Expanded(child: Text(l10n.addProviderSheetTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    IconButton(tooltip: l10n.mcpPageClose, icon: Icon(lucide.Lucide.X, size: 20, color: cs.onSurface.withOpacity(0.9)), onPressed: () => Navigator.of(context).maybePop()),
                  ]),
                ),
                // Tabs
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: _SmallSegTabBar(controller: _tab, tabs: const ['OpenAI', 'Google', 'Claude']),
                ),
                // Body
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AnimatedBuilder(
                      animation: _tab,
                      builder: (_, __) {
                        final idx = _tab.index;
                        return ListView(
                          children: [
                            if (idx == 0) _openaiForm(l10n) else if (idx == 1) _googleForm(l10n) else _claudeForm(l10n),
                            const SizedBox(height: 20),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                // Footer
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(children: [const Spacer(), _PrimaryDeskButton(icon: lucide.Lucide.Plus, label: l10n.addProviderSheetAddButton, onTap: _onAdd)]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _openaiForm(AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Top switches: Enabled, then Use Responses API
      _switchTile(label: l10n.addProviderSheetEnabledLabel, value: _openaiEnabled, onChanged: (v) => setState(() => _openaiEnabled = v)),
      const SizedBox(height: 8),
      _switchTile(label: 'Use Responses API', value: _openaiUseResponse, onChanged: (v) => setState(() => _openaiUseResponse = v)),
      const SizedBox(height: 12),
      // Inputs
      _label(context, l10n.addProviderSheetNameLabel),
      TextField(controller: _openaiName, decoration: _deskInputDecoration(context)),
      const SizedBox(height: 10),
      _label(context, 'API Key'),
      TextField(controller: _openaiKey, decoration: _deskInputDecoration(context)),
      const SizedBox(height: 10),
      _label(context, 'Base URL'),
      TextField(controller: _openaiBase, decoration: _deskInputDecoration(context, hint: 'https://api.openai.com/v1')),
      const SizedBox(height: 10),
      _label(context, l10n.addProviderSheetApiPathLabel),
      TextField(controller: _openaiPath, decoration: _deskInputDecoration(context, hint: '/chat/completions')),
    ]);
  }

  Widget _googleForm(AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Top switches: Enabled, then Vertex AI
      _switchTile(label: l10n.addProviderSheetEnabledLabel, value: _googleEnabled, onChanged: (v) => setState(() => _googleEnabled = v)),
      const SizedBox(height: 8),
      _switchTile(label: 'Vertex AI', value: _googleVertex, onChanged: (v) => setState(() => _googleVertex = v)),
      const SizedBox(height: 12),
      // Inputs
      _label(context, l10n.addProviderSheetNameLabel),
      TextField(controller: _googleName, decoration: _deskInputDecoration(context)),
      const SizedBox(height: 10),
      _label(context, 'Base URL'),
      TextField(controller: _googleBase, enabled: !_googleVertex, decoration: _deskInputDecoration(context, hint: 'https://generativelanguage.googleapis.com/v1beta')),
      const SizedBox(height: 10),
      _label(context, 'API Key'),
      TextField(controller: _googleKey, enabled: !_googleVertex, decoration: _deskInputDecoration(context)),
      const SizedBox(height: 10),
      _label(context, l10n.addProviderSheetVertexAiLocationLabel),
      TextField(controller: _googleLocation, enabled: _googleVertex, decoration: _deskInputDecoration(context, hint: 'us-central1')),
      const SizedBox(height: 10),
      _label(context, l10n.addProviderSheetVertexAiProjectIdLabel),
      TextField(controller: _googleProject, enabled: _googleVertex, decoration: _deskInputDecoration(context)),
      const SizedBox(height: 10),
      _label(context, l10n.addProviderSheetVertexAiServiceAccountJsonLabel),
      TextField(controller: _googleSaJson, enabled: _googleVertex, minLines: 4, maxLines: 8, decoration: _deskInputDecoration(context, hint: '{\n  "type": "service_account", ...\n}')),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(onPressed: _googleVertex ? _importGoogleServiceAccount : null, icon: const Icon(Icons.file_open, size: 16), label: Text(l10n.addProviderSheetImportJsonButton)),
      ),
    ]);
  }

  Widget _claudeForm(AppLocalizations l10n) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _switchTile(label: l10n.addProviderSheetEnabledLabel, value: _claudeEnabled, onChanged: (v) => setState(() => _claudeEnabled = v)),
      const SizedBox(height: 10),
      _label(context, l10n.addProviderSheetNameLabel),
      TextField(controller: _claudeName, decoration: _deskInputDecoration(context)),
      const SizedBox(height: 10),
      _label(context, 'API Key'),
      TextField(controller: _claudeKey, decoration: _deskInputDecoration(context)),
      const SizedBox(height: 10),
      _label(context, 'Base URL'),
      TextField(controller: _claudeBase, decoration: _deskInputDecoration(context, hint: 'https://api.anthropic.com/v1')),
    ]);
  }
}

class _SmallSegTabBar extends StatefulWidget {
  const _SmallSegTabBar({required this.controller, required this.tabs});
  final TabController controller;
  final List<String> tabs;
  @override
  State<_SmallSegTabBar> createState() => _SmallSegTabBarState();
}

class _SmallSegTabBarState extends State<_SmallSegTabBar> {
  int _hover = -1;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    const double outerHeight = 40;
    const double innerPadding = 4;
    const double gap = 6;
    const double minSegWidth = 88;
    final double pillRadius = 14;
    final double innerRadius = ((pillRadius - innerPadding).clamp(0.0, pillRadius)).toDouble();

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return LayoutBuilder(builder: (context, constraints) {
          final double availWidth = constraints.maxWidth;
          final double innerAvailWidth = availWidth - innerPadding * 2;
          final double segWidth = (innerAvailWidth - gap * (widget.tabs.length - 1)) / widget.tabs.length;
          final double rowWidth = segWidth * widget.tabs.length + gap * (widget.tabs.length - 1);
          final Color shellBg = isDark ? Colors.white.withOpacity(0.08) : Colors.white;
          List<Widget> children = [];
          for (int index = 0; index < widget.tabs.length; index++) {
            final bool selected = widget.controller.index == index;
            final bool hovered = _hover == index;
            final Color bg = selected
                ? cs.primary.withOpacity(0.14)
                : hovered
                    ? (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.03))
                    : Colors.transparent;
            final Color fg = selected ? cs.primary : cs.onSurface.withOpacity(0.82);
            children.add(SizedBox(
              width: segWidth < minSegWidth ? minSegWidth : segWidth,
              height: double.infinity,
              child: MouseRegion(
                onEnter: (_) => setState(() => _hover = index),
                onExit: (_) => setState(() => _hover = -1),
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.controller.animateTo(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(innerRadius)),
                    alignment: Alignment.center,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(widget.tabs[index], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ),
            ));
            if (index != widget.tabs.length - 1) children.add(const SizedBox(width: gap));
          }
          return Container(
            height: outerHeight,
            decoration: BoxDecoration(color: shellBg, borderRadius: BorderRadius.circular(pillRadius)),
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
        });
      },
    );
  }
}

class _PrimaryDeskButton extends StatefulWidget {
  const _PrimaryDeskButton({required this.label, required this.onTap, this.icon});
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  @override
  State<_PrimaryDeskButton> createState() => _PrimaryDeskButtonState();
}

class _PrimaryDeskButtonState extends State<_PrimaryDeskButton> {
  bool _hover = false;
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = _pressed ? cs.primary.withOpacity(0.85) : (_hover ? cs.primary.withOpacity(0.92) : cs.primary);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (widget.icon != null) ...[Icon(widget.icon!, size: 16, color: cs.onPrimary), const SizedBox(width: 8)],
            Text(widget.label, style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}
