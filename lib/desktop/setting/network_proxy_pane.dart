import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:socks5_proxy/socks_client.dart' as socks;
import 'package:provider/provider.dart';
import '../../shared/widgets/ios_switch.dart';

import '../../l10n/app_localizations.dart';
import '../../core/providers/settings_provider.dart';

class DesktopNetworkProxyPane extends StatefulWidget {
  const DesktopNetworkProxyPane({super.key});

  @override
  State<DesktopNetworkProxyPane> createState() => _DesktopNetworkProxyPaneState();
}

class _DesktopNetworkProxyPaneState extends State<DesktopNetworkProxyPane> {
  late final TextEditingController _hostCtl;
  late final TextEditingController _portCtl;
  late final TextEditingController _userCtl;
  late final TextEditingController _passCtl;
  late final TextEditingController _bypassCtl;
  final FocusNode _hostFn = FocusNode();
  final FocusNode _portFn = FocusNode();
  final FocusNode _userFn = FocusNode();
  final FocusNode _passFn = FocusNode();
  final FocusNode _bypassFn = FocusNode();

  String _type = 'http';
  bool _enabled = false;

  // Test state
  final TextEditingController _testUrlCtl = TextEditingController(text: 'https://www.google.com');
  bool _testing = false;
  String? _testError;
  bool? _testOk;

  @override
  void initState() {
    super.initState();
    final sp = context.read<SettingsProvider>();
    _enabled = sp.globalProxyEnabled;
    _type = sp.globalProxyType;
    _hostCtl = TextEditingController(text: sp.globalProxyHost);
    _portCtl = TextEditingController(text: sp.globalProxyPort);
    _userCtl = TextEditingController(text: sp.globalProxyUsername);
    _passCtl = TextEditingController(text: sp.globalProxyPassword);
    _bypassCtl = TextEditingController(text: sp.globalProxyBypass);
    _hostFn.addListener(() { if (!_hostFn.hasFocus) sp.setGlobalProxyHost(_hostCtl.text); });
    _portFn.addListener(() { if (!_portFn.hasFocus) sp.setGlobalProxyPort(_portCtl.text); });
    _userFn.addListener(() { if (!_userFn.hasFocus) sp.setGlobalProxyUsername(_userCtl.text); });
    _passFn.addListener(() { if (!_passFn.hasFocus) sp.setGlobalProxyPassword(_passCtl.text); });
    _bypassFn.addListener(() { if (!_bypassFn.hasFocus) sp.setGlobalProxyBypass(_bypassCtl.text); });
  }

  @override
  void dispose() {
    _hostCtl.dispose();
    _portCtl.dispose();
    _userCtl.dispose();
    _passCtl.dispose();
    _bypassCtl.dispose();
    _hostFn.dispose();
    _portFn.dispose();
    _userFn.dispose();
    _passFn.dispose();
    _bypassFn.dispose();
    _testUrlCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    return Container(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            children: [
              SizedBox(
                height: 36,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(l10n.settingsPageNetworkProxy, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: cs.onSurface.withOpacity(0.9))),
                ),
              ),
              const SizedBox(height: 10),
              _sectionCard(children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Expanded(child: Text(l10n.networkProxySettingsHeader, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurface.withOpacity(0.95)))),
                  ]),
                ),
                _ItemRow(
                  label: l10n.networkProxyEnableLabel,
                  vpad: 4,
                  trailing: IosSwitch(
                    value: _enabled,
                    onChanged: (v) async {
                      setState(() => _enabled = v);
                      await context.read<SettingsProvider>().setGlobalProxyEnabled(v);
                    },
                  ),
                ),
                _rowDivider(context),
                _ItemRow(
                  label: l10n.networkProxyType,
                  trailing: SizedBox(
                    width: 220,
                    child: _ProxyTypeDropdown(
                      value: _type,
                      onChanged: (v) async {
                        if (v == null) return;
                        setState(() => _type = v);
                        await context.read<SettingsProvider>().setGlobalProxyType(v);
                      },
                    ),
                  ),
                ),
                _rowDivider(context),
                _ItemRow(
                  label: l10n.networkProxyServerHost,
                  trailing: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 140, maxWidth: 420),
                    child: TextField(
                      controller: _hostCtl,
                      focusNode: _hostFn,
                      style: const TextStyle(fontSize: 14),
                      decoration: _deskInputDecoration(context).copyWith(hintText: '127.0.0.1'),
                    ),
                  ),
                ),
                _rowDivider(context),
                _ItemRow(
                  label: l10n.networkProxyPort,
                  trailing: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 140, maxWidth: 420),
                    child: TextField(
                      controller: _portCtl,
                      focusNode: _portFn,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 14),
                      decoration: _deskInputDecoration(context).copyWith(hintText: '8080'),
                    ),
                  ),
                ),
                _rowDivider(context),
                _ItemRow(
                  label: l10n.networkProxyUsername,
                  trailing: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 140, maxWidth: 420),
                    child: TextField(
                      controller: _userCtl,
                      focusNode: _userFn,
                      style: const TextStyle(fontSize: 14),
                      decoration: _deskInputDecoration(context).copyWith(hintText: l10n.networkProxyOptionalHint),
                    ),
                  ),
                ),
                _rowDivider(context),
                _ItemRow(
                  label: l10n.networkProxyPassword,
                  trailing: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 140, maxWidth: 420),
                    child: TextField(
                      controller: _passCtl,
                      focusNode: _passFn,
                      obscureText: true,
                      style: const TextStyle(fontSize: 14),
                      decoration: _deskInputDecoration(context).copyWith(hintText: '••••••••'),
                    ),
                  ),
                ),
                _rowDivider(context),
                _ItemRow(
                  label: l10n.networkProxyBypassLabel,
                  trailing: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 140, maxWidth: 420),
                    child: TextField(
                      controller: _bypassCtl,
                      focusNode: _bypassFn,
                      minLines: 1,
                      maxLines: 3,
                      style: const TextStyle(fontSize: 14),
                      decoration: _deskInputDecoration(context).copyWith(hintText: l10n.networkProxyBypassHint),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Text(l10n.networkProxyPriorityNote, style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.6))),
                ),
              ]),

              const SizedBox(height: 10),
              _sectionCard(children: [
                _ItemRow(
                  label: l10n.networkProxyTestHeader,
                  trailing: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 140, maxWidth: 420),
                    child: TextField(
                      controller: _testUrlCtl,
                      style: const TextStyle(fontSize: 14),
                      decoration: _deskInputDecoration(context).copyWith(hintText: l10n.networkProxyTestUrlHint),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _DeskIosButton(
                      label: _testing ? l10n.networkProxyTesting : l10n.networkProxyTestButton,
                      filled: false,
                      dense: true,
                      onTap: _testing ? (){} : _onTest,
                    ),
                  ),
                ),
                if (_testOk == true)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Text(l10n.networkProxyTestSuccess, style: TextStyle(color: Colors.green.shade600, fontWeight: FontWeight.w600)),
                  ),
                if (_testOk == false)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Text(l10n.networkProxyTestFailed(_testError ?? ''), style: TextStyle(color: cs.error)),
                  ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onTest() async {
    final l10n = AppLocalizations.of(context)!;
    final url = _testUrlCtl.text.trim();
    if (url.isEmpty) {
      setState(() { _testOk = false; _testError = l10n.networkProxyNoUrl; });
      return;
    }
    setState(() { _testing = true; _testOk = null; _testError = null; });
    try {
      final host = _hostCtl.text.trim();
      final port = int.tryParse(_portCtl.text.trim()) ?? 8080;
      final user = _userCtl.text.trim();
      final pass = _passCtl.text;
      final io = HttpClient();
      if (_type == 'socks5') {
        try {
          final proxies = <socks.ProxySettings>[
            socks.ProxySettings(InternetAddress(host), port,
                username: user.isNotEmpty ? user : null, password: pass),
          ];
          socks.SocksTCPClient.assignToHttpClient(io, proxies);
        } catch (_) {}
      } else {
        io.findProxy = (_) => 'PROXY $host:$port';
        if (user.isNotEmpty) {
          io.addProxyCredentials(host, port, '', HttpClientBasicCredentials(user, pass));
        }
      }
      final client = IOClient(io);
      final uri = Uri.parse(url);
      final res = await client.get(uri).timeout(const Duration(seconds: 8));
      client.close();
      setState(() { _testing = false; _testOk = (res.statusCode >= 200 && res.statusCode < 400); _testError = _testOk == true ? null : 'HTTP ${res.statusCode}'; });
    } catch (e) {
      setState(() { _testing = false; _testOk = false; _testError = e.toString(); });
    }
  }
}

// --- Helpers (matched with backup pane style) ---
Widget _rowDivider(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Container(height: 1, color: cs.outlineVariant.withOpacity(isDark ? 0.08 : 0.06));
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.label, required this.trailing, this.vpad = 8});
  final String label; final Widget trailing; final double vpad;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: vpad),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: cs.onSurface.withOpacity(0.88)))),
          const SizedBox(width: 12),
          Align(alignment: Alignment.centerRight, child: trailing),
        ],
      ),
    );
  }
}

class _DeskIosButton extends StatefulWidget {
  const _DeskIosButton({required this.label, required this.filled, required this.dense, required this.onTap});
  final String label; final bool filled; final bool dense; final VoidCallback onTap;
  @override State<_DeskIosButton> createState() => _DeskIosButtonState();
}

class _DeskIosButtonState extends State<_DeskIosButton> {
  bool _hover = false; bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme; final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = widget.filled ? Colors.white : cs.onSurface.withOpacity(0.9);
    final bg = widget.filled
        ? (_hover ? cs.primary.withOpacity(0.92) : cs.primary)
        : (_hover ? (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05)) : Colors.transparent);
    final borderColor = widget.filled ? Colors.transparent : cs.outlineVariant.withOpacity(isDark ? 0.22 : 0.18);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: widget.dense ? 8 : 12, horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
            child: Text(widget.label, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: widget.dense ? 13 : 14)),
          ),
        ),
      ),
    );
  }
}

Widget _sectionCard({required List<Widget> children}) {
  return Builder(builder: (context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseBg = isDark ? Colors.white10 : Colors.white.withOpacity(0.96);
    return Container(
      decoration: BoxDecoration(
        color: baseBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withOpacity(isDark ? 0.12 : 0.08), width: 0.8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  });
}

InputDecoration _deskInputDecoration(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final cs = Theme.of(context).colorScheme;
  return InputDecoration(
    isDense: true,
    filled: true,
    fillColor: isDark ? Colors.white10 : const Color(0xFFF7F7F9),
    hintStyle: TextStyle(fontSize: 14, color: cs.onSurface.withOpacity(0.5)),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.12), width: 0.6),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.12), width: 0.6),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: cs.primary.withOpacity(0.35), width: 0.8),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );
}

class _ProxyTypeDropdown extends StatefulWidget {
  const _ProxyTypeDropdown({required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String?>? onChanged;
  @override
  State<_ProxyTypeDropdown> createState() => _ProxyTypeDropdownState();
}

class _ProxyTypeDropdownState extends State<_ProxyTypeDropdown> {
  bool _hover = false;
  bool _open = false;
  final LayerLink _link = LayerLink();
  final GlobalKey _triggerKey = GlobalKey();
  OverlayEntry? _entry;

  void _toggle() => _open ? _close() : _openMenu();
  void _close() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() => _open = false);
  }

  void _openMenu() {
    if (_entry != null) return;
    final rb = _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return;
    final size = rb.size;
    _entry = OverlayEntry(builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
      return Stack(children: [
        Positioned.fill(
          child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _close, child: const SizedBox.expand()),
        ),
        CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 6),
          child: _ProxyTypeOverlay(
            width: size.width,
            backgroundColor: bgColor,
            value: widget.value ?? 'http',
            onSelected: (v) {
              widget.onChanged?.call(v);
              _close();
            },
          ),
        ),
      ]);
    });
    Overlay.of(context)?.insert(_entry!);
    setState(() => _open = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseBorder = cs.outlineVariant.withOpacity(0.18);
    final hoverBorder = cs.primary;
    final borderColor = _open || _hover ? hoverBorder : baseBorder;

    String labelOf(String v) {
      switch (v) {
        case 'https': return l10n.networkProxyTypeHttps;
        case 'socks5': return l10n.networkProxyTypeSocks5;
        case 'http':
        default: return l10n.networkProxyTypeHttp;
      }
    }
    final selected = widget.value ?? 'http';

    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: _toggle,
          child: AnimatedContainer(
            key: _triggerKey,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
            constraints: const BoxConstraints(minWidth: 150, minHeight: 40),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141414) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: _open ? [BoxShadow(color: cs.primary.withOpacity(0.10), blurRadius: 0, spreadRadius: 2)] : null,
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: Text(labelOf(selected), overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: cs.onSurface.withOpacity(0.88))),
                  ),
                  const SizedBox(width: 24),
                ]),
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: AnimatedRotation(
                      turns: _open ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      child: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: cs.onSurface.withOpacity(0.6)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProxyTypeOverlay extends StatelessWidget {
  const _ProxyTypeOverlay({required this.width, required this.backgroundColor, required this.value, required this.onSelected});
  final double width; final Color backgroundColor; final String value; final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final items = [
      ('http', l10n.networkProxyTypeHttp),
      ('https', l10n.networkProxyTypeHttps),
      ('socks5', l10n.networkProxyTypeSocks5),
    ];
    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.18), width: 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 6),
          children: [
            for (final it in items)
              _ProxyTypeTile(
                label: it.$2,
                selected: value == it.$1,
                onTap: () => onSelected(it.$1),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProxyTypeTile extends StatefulWidget {
  const _ProxyTypeTile({required this.label, required this.selected, required this.onTap});
  final String label; final bool selected; final VoidCallback onTap;
  @override State<_ProxyTypeTile> createState() => _ProxyTypeTileState();
}

class _ProxyTypeTileState extends State<_ProxyTypeTile> {
  bool _hover = false; bool _active = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme; final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = widget.selected ? cs.primary.withOpacity(0.12) : (_hover ? (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04)) : Colors.transparent);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _active = true),
        onTapCancel: () => setState(() => _active = false),
        onTapUp: (_) => setState(() => _active = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _active ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: cs.onSurface.withOpacity(0.88), fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400),
                  ),
                ),
                const SizedBox(width: 8),
                Opacity(opacity: widget.selected ? 1 : 0, child: Icon(Icons.check, size: 14, color: cs.primary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
