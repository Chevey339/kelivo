import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../shared/widgets/ios_switch.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../icons/lucide_adapter.dart';
import 'package:file_picker/file_picker.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/services/haptics.dart';
import '../../../shared/widgets/ios_tile_button.dart';

Future<String?> showAddProviderSheet(BuildContext context) async {
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => const _AddProviderSheet(),
  );
}

class _AddProviderSheet extends StatefulWidget {
  const _AddProviderSheet();
  @override
  State<_AddProviderSheet> createState() => _AddProviderSheetState();
}

class _AddProviderSheetState extends State<_AddProviderSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  @override
  void initState() {
    super.initState();
    _tab.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tab.removeListener(_onTabChanged);
    _tab.dispose();
    super.dispose();
  }

  // OpenAI
  bool _openaiEnabled = true;
  late final TextEditingController _openaiName = TextEditingController(text: 'OpenAI');
  late final TextEditingController _openaiKey = TextEditingController();
  late final TextEditingController _openaiBase = TextEditingController(text: 'https://api.openai.com/v1');
  late final TextEditingController _openaiPath = TextEditingController(text: '/chat/completions');
  bool _openaiUseResponse = false;

  // Google
  bool _googleEnabled = true;
  late final TextEditingController _googleName = TextEditingController(text: 'Google');
  late final TextEditingController _googleKey = TextEditingController();
  late final TextEditingController _googleBase = TextEditingController(text: 'https://generativelanguage.googleapis.com/v1beta');
  bool _googleVertex = false;
  late final TextEditingController _googleLocation = TextEditingController(text: 'us-central1');
  late final TextEditingController _googleProject = TextEditingController();
  late final TextEditingController _googleSaJson = TextEditingController();

  // Claude
  bool _claudeEnabled = true;
  late final TextEditingController _claudeName = TextEditingController(text: 'Claude');
  late final TextEditingController _claudeKey = TextEditingController();
  late final TextEditingController _claudeBase = TextEditingController(text: 'https://api.anthropic.com/v1');

  Widget _inputRow({required String label, required TextEditingController controller, String? hint, bool obscure = false, bool enabled = true}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.8))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          enabled: enabled,
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

  Widget _switchTile({required String label, required bool value, required ValueChanged<bool> onChanged}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
          IosSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _switchRow({required String label, required bool value, required ValueChanged<bool> onChanged}) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
        IosSwitch(value: value, onChanged: onChanged),
      ],
    );
  }

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
              if (i > 0)
                Divider(height: 10, thickness: 0.6, color: cs.outlineVariant.withOpacity(0.18)),
              children[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget _openaiForm(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _iosCard(children: [
          _switchRow(label: l10n.addProviderSheetEnabledLabel, value: _openaiEnabled, onChanged: (v) => setState(() => _openaiEnabled = v)),
          _switchRow(label: 'Response API', value: _openaiUseResponse, onChanged: (v) => setState(() => _openaiUseResponse = v)),
        ]),
        const SizedBox(height: 10),
        _inputRow(label: l10n.addProviderSheetNameLabel, controller: _openaiName),
        const SizedBox(height: 10),
        _inputRow(label: 'API Key', controller: _openaiKey),
        const SizedBox(height: 10),
        _inputRow(label: 'API Base Url', controller: _openaiBase),
        const SizedBox(height: 10),
        if (!_openaiUseResponse)
          _inputRow(label: l10n.addProviderSheetApiPathLabel, controller: _openaiPath, hint: '/chat/completions'),
      ],
    );
  }

  Widget _googleForm(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _iosCard(children: [
          _switchRow(label: l10n.addProviderSheetEnabledLabel, value: _googleEnabled, onChanged: (v) => setState(() => _googleEnabled = v)),
          _switchRow(label: 'Vertex AI', value: _googleVertex, onChanged: (v) => setState(() => _googleVertex = v)),
        ]),
        const SizedBox(height: 10),
        _inputRow(label: l10n.addProviderSheetNameLabel, controller: _googleName),
        const SizedBox(height: 10),
        if (!_googleVertex) ...[
          _inputRow(label: 'API Key', controller: _googleKey),
          const SizedBox(height: 10),
          _inputRow(label: 'API Base Url', controller: _googleBase),
          const SizedBox(height: 10),
        ],
        if (_googleVertex) ...[
          _inputRow(label: l10n.addProviderSheetVertexAiLocationLabel, controller: _googleLocation, hint: 'us-central1'),
          const SizedBox(height: 10),
          _inputRow(label: l10n.addProviderSheetVertexAiProjectIdLabel, controller: _googleProject),
          const SizedBox(height: 10),
          _multilineRow(
            label: l10n.addProviderSheetVertexAiServiceAccountJsonLabel,
            controller: _googleSaJson,
            hint: '{\n  "type": "service_account", ...\n}',
            actions: [
              TextButton.icon(
                onPressed: _importGoogleServiceAccount,
                icon: const Icon(Icons.upload_file, size: 16),
                label: Text(l10n.addProviderSheetImportJsonButton),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _claudeForm(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _iosCard(children: [
          _switchRow(label: l10n.addProviderSheetEnabledLabel, value: _claudeEnabled, onChanged: (v) => setState(() => _claudeEnabled = v)),
        ]),
        const SizedBox(height: 10),
        _inputRow(label: l10n.addProviderSheetNameLabel, controller: _claudeName),
        const SizedBox(height: 10),
        _inputRow(label: 'API Key', controller: _claudeKey),
        const SizedBox(height: 10),
        _inputRow(label: 'API Base Url', controller: _claudeBase),
      ],
    );
  }

  Future<void> _onAdd() async {
    final settings = context.read<SettingsProvider>();
    String uniqueKey(String prefix, String display) {
      // Ensure the generated key is truly unique among existing keys
      final existing = context.read<SettingsProvider>().providerConfigs.keys.toSet();

      // Case 1: display equals prefix (user used default name), use: "<prefix> - <n>"
      if (display.toLowerCase() == prefix.toLowerCase()) {
        // Start from 1, bump until free
        int i = 1;
        String candidate = '$prefix - $i';
        while (existing.contains(candidate)) {
          i++;
          candidate = '$prefix - $i';
        }
        return candidate;
      }

      // Case 2: custom display name. Prefer "<prefix> - <display>", then suffix (n)
      String base = '$prefix - $display';
      if (!existing.contains(base)) return base;
      int i = 2;
      String candidate = '$base ($i)';
      while (existing.contains(candidate)) {
        i++;
        candidate = '$base ($i)';
      }
      return candidate;
    }
    final idx = _tab.index;
    String createdKey = '';
    if (idx == 0) {
      final rawName = _openaiName.text.trim();
      final display = rawName.isEmpty ? 'OpenAI' : rawName;
      final keyName = uniqueKey('OpenAI', display);
      final base = _openaiBase.text.trim().isEmpty ? 'https://api.openai.com/v1' : _openaiBase.text.trim();
      final promo = base.toLowerCase().contains('aihubmix.com');
      final cfg = ProviderConfig(
        id: keyName,
        enabled: _openaiEnabled,
        name: display,
        apiKey: _openaiKey.text.trim(),
        baseUrl: base,
        providerType: ProviderKind.openai,  // Explicitly set as OpenAI type
        chatPath: _openaiUseResponse ? null : (_openaiPath.text.trim().isEmpty ? '/chat/completions' : _openaiPath.text.trim()),
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
      final base = _googleVertex ? 'https://aiplatform.googleapis.com' : (_googleBase.text.trim().isEmpty ? 'https://generativelanguage.googleapis.com/v1beta' : _googleBase.text.trim());
      final promo = base.toLowerCase().contains('aihubmix.com');
      final cfg = ProviderConfig(
        id: keyName,
        enabled: _googleEnabled,
        name: display,
        apiKey: _googleVertex ? '' : _googleKey.text.trim(),
        baseUrl: base,
        providerType: ProviderKind.google,  // Explicitly set as Google type
        vertexAI: _googleVertex,
        location: _googleVertex ? (_googleLocation.text.trim().isEmpty ? 'us-central1' : _googleLocation.text.trim()) : '',
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
      final base = _claudeBase.text.trim().isEmpty ? 'https://api.anthropic.com/v1' : _claudeBase.text.trim();
      final promo = base.toLowerCase().contains('aihubmix.com');
      final cfg = ProviderConfig(
        id: keyName,
        enabled: _claudeEnabled,
        name: display,
        apiKey: _claudeKey.text.trim(),
        baseUrl: base,
        providerType: ProviderKind.claude,  // Explicitly set as Claude type
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

    // Ensure providers appear in order list at least once
    final order = List<String>.of(context.read<SettingsProvider>().providersOrder);
    // Put the newly created provider at the front
    order.remove(createdKey);
    order.insert(0, createdKey);
    await context.read<SettingsProvider>().setProvidersOrder(order);

    if (mounted) Navigator.of(context).pop(createdKey);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          maxChildSize: 0.8,
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
              SizedBox(
                height: 36,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        l10n.addProviderSheetTitle,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _TactileIconButton(
                          icon: Lucide.X,
                          color: cs.onSurface,
                          size: 22,
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SegTabBar(controller: _tab, tabs: const ['OpenAI', 'Google', 'Claude']),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView(
                    controller: controller,
                    children: [
                      AnimatedBuilder(
                        animation: _tab,
                        builder: (_, __) {
                          final idx = _tab.index;
                          return Column(
                            children: [
                              if (idx == 0) _openaiForm(l10n),
                              if (idx == 1) _googleForm(l10n),
                              if (idx == 2) _claudeForm(l10n),
                            ],
                          );
                        },
                      ),
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
                    icon: Lucide.Plus,
                    label: l10n.addProviderSheetAddButton,
                    backgroundColor: cs.primary,
                    // No need to set foreground/border; component tints background lightly,
                    // uses theme color for text, and draws a subtle same-hue border.
                    onTap: _onAdd,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _multilineRow({required String label, required TextEditingController controller, String? hint, List<Widget>? actions}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.8)))),
            if (actions != null) ...actions,
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: 8,
          minLines: 4,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: isDark ? Colors.white10 : Colors.white,
            border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Colors.transparent)),
            enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Colors.transparent)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary.withOpacity(0.4))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Future<void> _importGoogleServiceAccount() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final path = file.path;
      if (path == null) return;
      final text = await File(path).readAsString();
      _googleSaJson.text = text;
      try {
        final obj = jsonDecode(text) as Map<String, dynamic>;
        final pid = (obj['project_id'] as String?)?.trim();
        if ((pid ?? '').isNotEmpty && _googleProject.text.trim().isEmpty) {
          _googleProject.text = pid!;
        }
      } catch (_) {}
      if (mounted) setState(() {});
    } catch (_) {}
  }

}

// Copy of assistant _SegTabBar to ensure consistency
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

class _TactileRow extends StatefulWidget {
  const _TactileRow({required this.builder, this.onTap});
  final Widget Function(bool pressed) builder;
  final VoidCallback? onTap;
  @override
  State<_TactileRow> createState() => _TactileRowState();
}

class _TactileRowState extends State<_TactileRow> {
  bool _pressed = false;
  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _set(true),
      onTapUp: widget.onTap == null ? null : (_) => _set(false),
      onTapCancel: widget.onTap == null ? null : () => _set(false),
      onTap: widget.onTap,
      child: widget.builder(_pressed),
    );
  }
}

// Local tactile icon button (no ripple), for close "X"
class _TactileIconButton extends StatefulWidget {
  const _TactileIconButton({required this.icon, required this.color, required this.onTap, this.size = 22});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size;
  @override
  State<_TactileIconButton> createState() => _TactileIconButtonState();
}

class _TactileIconButtonState extends State<_TactileIconButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final base = widget.color;
    final press = base.withOpacity(0.7);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () { Haptics.light(); widget.onTap(); },
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Icon(widget.icon, size: widget.size, color: _pressed ? press : base),
        ),
      ),
    );
  }
}
