import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../l10n/app_localizations.dart';
import '../../shared/widgets/ios_tactile.dart';
import '../../shared/widgets/ios_form_text_field.dart';
import '../../hermes/hermes_backend_discovery.dart';

typedef BackendSavedCallback =
    void Function(
      String name,
      String url,
      String? token,
      String? profile,
      String authMode,
    );

/// Bottom sheet for adding a new Hermes backend.
///
/// Has 3 tabs:
/// 1. **Manual**: enter URL + token + profile manually
/// 2. **Scan QR**: use camera to scan the backend's QR code
/// 3. **Local Network**: mDNS discovered backends
class AddBackendSheet extends StatefulWidget {
  final BackendSavedCallback onSaved;

  const AddBackendSheet({super.key, required this.onSaved});

  @override
  State<AddBackendSheet> createState() => _AddBackendSheetState();
}

class _AddBackendSheetState extends State<AddBackendSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _tokenController = TextEditingController();
  final _profileController = TextEditingController();
  String _authMode = 'auto';
  bool _isTesting = false;
  String? _testResult;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _urlController.dispose();
    _tokenController.dispose();
    _profileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline.withAlpha(100),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.addBackendTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: l10n.addBackendTabManual),
              Tab(text: l10n.addBackendTabQr),
              Tab(text: l10n.addBackendTabLan),
            ],
          ),
          SizedBox(
            height: 340,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildManualTab(l10n),
                _buildQrTab(l10n),
                _buildLanTab(l10n),
              ],
            ),
          ),
          SizedBox(height: bottom + 16),
        ],
      ),
    );
  }

  Widget _buildManualTab(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          IosFormTextField(
            controller: _nameController,
            label: l10n.backendDetailTitle,
            hintText: 'My Hermes',
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          IosFormTextField(
            controller: _urlController,
            label: l10n.addBackendUrlLabel,
            hintText: 'ws://192.168.1.100:9119',
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          // Token field — use plain TextField for obscure text
          _PasswordFormField(
            controller: _tokenController,
            label: l10n.addBackendTokenLabel,
            hintText: l10n.addBackendTokenHint,
          ),
          const SizedBox(height: 12),
          IosFormTextField(
            controller: _profileController,
            label: l10n.addBackendProfileLabel,
            hintText: l10n.addBackendProfileHint,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 16),
          _AuthModeSelector(
            value: _authMode,
            onChanged: (v) => setState(() => _authMode = v),
            l10n: l10n,
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _testSuccess
                    ? Colors.green.withAlpha(25)
                    : Colors.red.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _testSuccess ? Icons.check_circle : Icons.error,
                    size: 18,
                    color: _testSuccess ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _testResult!,
                      style: TextStyle(
                        color: _testSuccess ? Colors.green : Colors.red,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: IosCardPress(
                  onTap: _isTesting ? null : _testConnection,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  baseColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                  child: Center(
                    child: _isTesting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.addBackendTestConnection),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: IosCardPress(
                  onTap: _isTesting ? null : _fetchSpaToken,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  baseColor: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                  child: Center(
                    child: Text(
                      '抓取 Token',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: IosCardPress(
                  onTap: _save,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  baseColor: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                  child: Center(
                    child: Text(
                      l10n.addBackendSave,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQrTab(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.qr_code_scanner,
            size: 80,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 20),
          Text(
            l10n.qrScanTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.qrScanHint,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          IosCardPress(
            onTap: _scanQr,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            baseColor: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(10),
            child: Text(
              'Open Camera',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanTab(AppLocalizations l10n) {
    return _LanDiscoveryTab(
      l10n: l10n,
      onSelected: (discovered) {
        setState(() {
          _urlController.text = discovered.url;
          _nameController.text = discovered.name;
        });
        _tabController.animateTo(0);
      },
    );
  }

  /// Fetch the SPA-injected session token from `<base>/`.
  ///
  /// Hermes Dashboard (when not in gated OAuth mode) injects
  /// `window.__HERMES_SESSION_TOKEN__` into the served HTML so the browser
  /// client can authenticate `/api/ws` via `?token=<value>`. Native clients
  /// need the same value; this helper pulls it from the dashboard HTML and
  /// populates the token field so the user doesn't have to dig through
  /// "View Source".
  ///
  /// Only runs when the token field is currently empty and the URL parses
  /// as http(s):// — does not touch the UI if the user has already typed
  /// something.
  Future<void> _fetchSpaToken() async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      _toast('请先填写服务器地址');
      return;
    }
    if (_tokenController.text.trim().isNotEmpty) {
      _toast('Token 已填写，无需抓取');
      return;
    }

    // Translate ws://host:port → http://host:port/
    final httpUrl = rawUrl
        .replaceFirst(RegExp(r'^ws://'), 'http://')
        .replaceFirst(RegExp(r'^wss://'), 'https://')
        .replaceFirst(RegExp(r'/api/ws/?$'), '');
    final probeUrl = httpUrl.endsWith('/') ? httpUrl : '$httpUrl/';

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    String? token;
    String? errMsg;
    try {
      final resp = await http
          .get(Uri.parse(probeUrl), headers: const {'Accept': 'text/html'})
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) {
        errMsg = 'HTTP ${resp.statusCode} from $probeUrl';
      } else {
        final body = resp.body;
        final m = RegExp(
          "__HERMES_SESSION_TOKEN__\\s*=\\s*[\"']([^\"']+)[\"']",
        ).firstMatch(body);
        if (m != null) {
          token = m.group(1);
        } else {
          errMsg = 'SPA HTML 中未找到 __HERMES_SESSION_TOKEN__';
        }
      }
    } catch (e) {
      errMsg = '请求失败: $e';
    }

    if (!mounted) return;
    setState(() {
      _isTesting = false;
      if (token != null) {
        _tokenController.text = token;
        _testResult = '已从 Dashboard 抓取 Token';
        _testSuccess = true;
      } else {
        _testResult = errMsg ?? '未知错误';
        _testSuccess = false;
      }
    });
  }

  /// Real WebSocket handshake probe: connects with `?token=<value>` and waits
  /// for the server's `gateway.ready` event (or a close). Surfaces the actual
  /// server reason on failure so the user knows whether it was auth, network,
  /// or something else.
  Future<void> _testConnection() async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      _toast('请先填写服务器地址');
      return;
    }

    final token = _tokenController.text.trim();
    final authMode = _authMode;

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    String result = '';
    bool success = false;
    var attempt = 0;
    try {
      // Build the same URL HermesGateway._wsConnect builds, but inline here
      // so we can await the first event without touching provider state.
      String wsUrl = '';
      if (authMode == 'loopback' || (authMode == 'auto' && token.isNotEmpty)) {
        if (token.isEmpty) {
          result = 'loopback 模式需要 Token';
        } else {
          wsUrl = '$rawUrl/api/ws?token=$token';
        }
      } else if (authMode == 'gated') {
        result = 'gated 模式暂未在测试中支持';
      } else {
        wsUrl = '$rawUrl/api/ws';
      }

      if (result.isNotEmpty) return;

      final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      attempt = 1;
      // Wait up to 5s for either a message or a close.
      final readyOrClose = await channel.stream.first.timeout(
        const Duration(seconds: 5),
      );
      final preview = readyOrClose.toString();
      if (preview.contains('"gateway.ready"')) {
        result = '连接成功（已收到 gateway.ready）';
        success = true;
      } else {
        result =
            '已连接但首帧非 ready: ${preview.length > 80 ? '${preview.substring(0, 80)}…' : preview}';
      }
      await channel.sink.close();
    } on TimeoutException {
      result = attempt == 0 ? '连接超时（5s 未收到任何响应）' : '已连上但 5s 内未收到消息';
    } catch (e) {
      result = '失败: $e';
    }

    if (!mounted) return;
    setState(() {
      _isTesting = false;
      _testResult = result;
      _testSuccess = success;
    });
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _scanQr() async {
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.showSnackBar(
      const SnackBar(content: Text('Camera scan — wiring in Phase 0.5')),
    );
  }

  void _save() {
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();
    if (name.isEmpty) {
      _toast('请填写后端名称');
      return;
    }
    if (url.isEmpty) {
      _toast('请填写服务器地址（如 ws://192.168.31.199:9119）');
      return;
    }
    if (!url.startsWith('ws://') && !url.startsWith('wss://')) {
      _toast('服务器地址必须以 ws:// 或 wss:// 开头');
      return;
    }

    widget.onSaved(
      name,
      url,
      _tokenController.text.trim().isNotEmpty
          ? _tokenController.text.trim()
          : null,
      _profileController.text.trim().isNotEmpty
          ? _profileController.text.trim()
          : null,
      _authMode,
    );
    Navigator.of(context).pop();
  }
}

/// Password field using a standard TextField (IosFormTextField doesn't support obscureText).
class _PasswordFormField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;

  const _PasswordFormField({
    required this.controller,
    required this.label,
    required this.hintText,
  });

  @override
  State<_PasswordFormField> createState() => _PasswordFormFieldState();
}

class _PasswordFormFieldState extends State<_PasswordFormField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: widget.controller,
          obscureText: _obscure,
          decoration: InputDecoration(
            hintText: widget.hintText,
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthModeSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final AppLocalizations l10n;

  const _AuthModeSelector({
    required this.value,
    required this.onChanged,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Chip(
          label: l10n.authModeAutoDetect,
          selected: value == 'auto',
          onTap: () => onChanged('auto'),
        ),
        const SizedBox(width: 8),
        _Chip(
          label: l10n.authModeLoopback,
          selected: value == 'loopback',
          onTap: () => onChanged('loopback'),
        ),
        const SizedBox(width: 8),
        _Chip(
          label: l10n.authModeGated,
          selected: value == 'gated',
          onTap: () => onChanged('gated'),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1.5,
                )
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// mDNS LAN discovery tab — shows discovered Hermes servers.
class _LanDiscoveryTab extends StatefulWidget {
  final AppLocalizations l10n;
  final ValueChanged<DiscoveredHermesBackend> onSelected;

  const _LanDiscoveryTab({required this.l10n, required this.onSelected});

  @override
  State<_LanDiscoveryTab> createState() => _LanDiscoveryTabState();
}

class _LanDiscoveryTabState extends State<_LanDiscoveryTab> {
  HermesBackendDiscovery? _discovery;
  List<DiscoveredHermesBackend> _found = [];

  @override
  void dispose() {
    _discovery?.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    _discovery = HermesBackendDiscovery();
    _discovery!.discovered.listen((backends) {
      if (mounted) setState(() => _found = backends);
    });
    await _discovery!.startScan();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_found.isEmpty) ...[
            Icon(
              Icons.wifi_find,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              widget.l10n.lanDiscoverySearching,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              widget.l10n.lanDiscoveryHint,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            IosCardPress(
              onTap: _startScan,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              baseColor: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(10),
              child: Text(
                'Start Scan',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ] else ...[
            Text(
              widget.l10n.lanDiscoveryFound(_found.length),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _found.length,
                itemBuilder: (context, index) {
                  final b = _found[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: IosCardPress(
                      onTap: () => widget.onSelected(b),
                      padding: const EdgeInsets.all(12),
                      baseColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                      child: Row(
                        children: [
                          const Icon(Icons.computer, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.name,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                Text(
                                  b.url,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.outline,
                                        fontFamily: 'monospace',
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.add_circle_outline),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
