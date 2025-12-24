import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../scan/pages/qr_scan_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../core/services/haptics.dart';
import '../../../shared/widgets/ios_tile_button.dart';

class _ImportResult {
  final String key;
  final ProviderConfig cfg;
  _ImportResult(this.key, this.cfg);
}

enum _ImportProviderError {
  invalidPrefix,
  invalidJson,
  unsupportedFormat,
  unsupportedContent,
  qrNotDetected,
  unknownProviderType,
}

class _ImportProviderException implements Exception {
  final _ImportProviderError error;
  final String? detail;
  const _ImportProviderException(this.error, {this.detail});
  @override
  String toString() =>
      'ImportProviderException($error${detail == null ? '' : ': $detail'})';
}

String _localizeImportProviderError(
  AppLocalizations l10n,
  Object e, [
  StackTrace? st,
]) {
  if (e is _ImportProviderException) {
    switch (e.error) {
      case _ImportProviderError.invalidPrefix:
        return l10n.importProviderSheetErrorInvalidPrefix;
      case _ImportProviderError.invalidJson:
        return l10n.importProviderSheetErrorInvalidJson;
      case _ImportProviderError.unsupportedFormat:
        return l10n.importProviderSheetErrorUnsupportedFormat;
      case _ImportProviderError.unsupportedContent:
        return l10n.importProviderSheetErrorUnsupportedContent;
      case _ImportProviderError.qrNotDetected:
        return l10n.importProviderSheetErrorQrNotDetected;
      case _ImportProviderError.unknownProviderType:
        return l10n.importProviderSheetErrorUnknownProviderType(e.detail ?? '');
    }
  }

  if (e is FormatException) {
    final m = e.message;
    if (m == 'Invalid prefix')
      return l10n.importProviderSheetErrorInvalidPrefix;
    if (m == 'Unsupported format')
      return l10n.importProviderSheetErrorUnsupportedFormat;
    if (m == 'No valid lines')
      return l10n.importProviderSheetErrorUnsupportedContent;
    if (m.startsWith('Unknown provider type: ')) {
      final type = m.substring('Unknown provider type: '.length);
      return l10n.importProviderSheetErrorUnknownProviderType(type);
    }
    // Default: hide raw parse errors, etc.
    return l10n.importProviderSheetErrorInvalidJson;
  }

  final s = e.toString();
  if (s == 'QR not detected') return l10n.importProviderSheetErrorQrNotDetected;
  if (s == 'Unsupported content')
    return l10n.importProviderSheetErrorUnsupportedContent;
  if (s == 'Unsupported format')
    return l10n.importProviderSheetErrorUnsupportedFormat;
  if (s == 'Invalid prefix') return l10n.importProviderSheetErrorInvalidPrefix;

  // Unknown error: do not expose raw exception strings to the user.
  FlutterError.reportError(
    FlutterErrorDetails(
      exception: e,
      stack: st,
      library: 'import_provider_sheet',
      context: ErrorDescription('Import provider failed (unknown error)'),
    ),
  );
  return l10n.importProviderSheetErrorUnknown;
}

List<_ImportResult> _decodeChatboxJson(BuildContext context, String s) {
  final settings = context.read<SettingsProvider>();
  Map<String, dynamic> obj;
  try {
    obj = jsonDecode(s) as Map<String, dynamic>;
  } catch (_) {
    throw const _ImportProviderException(_ImportProviderError.invalidJson);
  }
  final providers =
      (obj['providers'] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ??
      {};
  final out = <_ImportResult>[];
  String uniqueKey(String prefix, String display) {
    final existing = settings.providerConfigs.keys.toSet();
    // If display equals prefix, generate '<prefix> - <n>' starting at 1
    if (display.toLowerCase() == prefix.toLowerCase()) {
      int i = 1;
      String candidate = '$prefix - $i';
      while (existing.contains(candidate)) {
        i++;
        candidate = '$prefix - $i';
      }
      return candidate;
    }
    // Otherwise prefer '<prefix> - <display>', then add ' (n)'
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

  // OpenAI
  final openai = providers['openai'] as Map?;
  if (openai != null) {
    final apiKey = (openai['apiKey'] ?? '').toString();
    final baseUrl = (openai['baseUrl'] ?? '').toString();
    final providedName = (openai['name'] ?? '').toString();
    if (apiKey.trim().isNotEmpty) {
      final name = providedName.isNotEmpty ? providedName : 'OpenAI';
      final key = uniqueKey('OpenAI', name);
      final cfg = ProviderConfig(
        id: key,
        enabled: true,
        name: name,
        apiKey: apiKey,
        baseUrl: baseUrl.isNotEmpty ? baseUrl : 'https://api.openai.com/v1',
        providerType: ProviderKind.openai,
        chatPath: '/chat/completions',
        useResponseApi: false,
        models: const [],
        modelOverrides: const {},
        proxyEnabled: false,
        proxyHost: '',
        proxyPort: '8080',
        proxyUsername: '',
        proxyPassword: '',
      );
      out.add(_ImportResult(key, cfg));
    }
  }
  // Claude
  final claude = providers['claude'] as Map?;
  if (claude != null) {
    final apiKey = (claude['apiKey'] ?? '').toString();
    final baseUrl = (claude['baseUrl'] ?? '').toString();
    final providedName = (claude['name'] ?? '').toString();
    if (apiKey.trim().isNotEmpty) {
      final name = providedName.isNotEmpty ? providedName : 'Claude';
      final key = uniqueKey('Claude', name);
      final cfg = ProviderConfig(
        id: key,
        enabled: true,
        name: name,
        apiKey: apiKey,
        baseUrl: baseUrl.isNotEmpty ? baseUrl : 'https://api.anthropic.com/v1',
        providerType: ProviderKind.claude,
        models: const [],
        modelOverrides: const {},
        proxyEnabled: false,
        proxyHost: '',
        proxyPort: '8080',
        proxyUsername: '',
        proxyPassword: '',
      );
      out.add(_ImportResult(key, cfg));
    }
  }
  // Gemini
  final gemini = providers['gemini'] as Map?;
  if (gemini != null) {
    final apiKey = (gemini['apiKey'] ?? '').toString();
    final providedName = (gemini['name'] ?? '').toString();
    if (apiKey.trim().isNotEmpty) {
      final name = providedName.isNotEmpty ? providedName : 'Gemini';
      final key = uniqueKey('Google', name);
      final cfg = ProviderConfig(
        id: key,
        enabled: true,
        name: name,
        apiKey: apiKey,
        baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
        providerType: ProviderKind.google,
        vertexAI: false,
        location: '',
        projectId: '',
        models: const [],
        modelOverrides: const {},
        proxyEnabled: false,
        proxyHost: '',
        proxyPort: '8080',
        proxyUsername: '',
        proxyPassword: '',
      );
      out.add(_ImportResult(key, cfg));
    }
  }
  return out;
}

_ImportResult _decodeSingle(BuildContext context, String s) {
  if (!s.trim().startsWith('ai-provider:v1:')) {
    throw const _ImportProviderException(_ImportProviderError.invalidPrefix);
  }
  final base64Str = s.trim().substring('ai-provider:v1:'.length);
  String jsonStr;
  try {
    jsonStr = utf8.decode(base64Decode(base64Str));
  } catch (_) {
    throw const _ImportProviderException(_ImportProviderError.invalidJson);
  }
  Map<String, dynamic> obj;
  try {
    obj = jsonDecode(jsonStr) as Map<String, dynamic>;
  } catch (_) {
    throw const _ImportProviderException(_ImportProviderError.invalidJson);
  }
  final type = (obj['type'] ?? '').toString();
  final name = (obj['name'] ?? '').toString();
  final apiKey = (obj['apiKey'] ?? '').toString();
  final baseUrl = (obj['baseUrl'] ?? '').toString();

  final settings = context.read<SettingsProvider>();
  String uniqueKey(String prefix, String display) {
    final existing = settings.providerConfigs.keys.toSet();
    if (display.toLowerCase() == prefix.toLowerCase()) {
      int i = 1;
      String candidate = '$prefix - $i';
      while (existing.contains(candidate)) {
        i++;
        candidate = '$prefix - $i';
      }
      return candidate;
    }
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

  if (type == 'openai') {
    final key = uniqueKey('OpenAI', name.isEmpty ? 'OpenAI' : name);
    final cfg = ProviderConfig(
      id: key,
      enabled: true,
      name: name.isEmpty ? 'OpenAI' : name,
      apiKey: apiKey,
      baseUrl: baseUrl.isNotEmpty ? baseUrl : 'https://api.openai.com/v1',
      providerType: ProviderKind.openai,
      chatPath: '/chat/completions',
      useResponseApi: false,
      models: const [],
      modelOverrides: const {},
      proxyEnabled: false,
      proxyHost: '',
      proxyPort: '8080',
      proxyUsername: '',
      proxyPassword: '',
    );
    return _ImportResult(key, cfg);
  } else if (type == 'google') {
    final key = uniqueKey('Google', name.isEmpty ? 'Google' : name);
    final cfg = ProviderConfig(
      id: key,
      enabled: true,
      name: name.isEmpty ? 'Google' : name,
      apiKey: apiKey,
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
      providerType: ProviderKind.google,
      vertexAI: false,
      location: '',
      projectId: '',
      models: const [],
      modelOverrides: const {},
      proxyEnabled: false,
      proxyHost: '',
      proxyPort: '8080',
      proxyUsername: '',
      proxyPassword: '',
    );
    return _ImportResult(key, cfg);
  } else if (type == 'claude') {
    final key = uniqueKey('Claude', name.isEmpty ? 'Claude' : name);
    final cfg = ProviderConfig(
      id: key,
      enabled: true,
      name: name.isEmpty ? 'Claude' : name,
      apiKey: apiKey,
      baseUrl: baseUrl.isNotEmpty ? baseUrl : 'https://api.anthropic.com/v1',
      providerType: ProviderKind.claude,
      models: const [],
      modelOverrides: const {},
      proxyEnabled: false,
      proxyHost: '',
      proxyPort: '8080',
      proxyUsername: '',
      proxyPassword: '',
    );
    return _ImportResult(key, cfg);
  } else {
    throw _ImportProviderException(
      _ImportProviderError.unknownProviderType,
      detail: type,
    );
  }
}

Future<void> showImportProviderSheet(BuildContext context) async {
  final cs = Theme.of(context).colorScheme;
  final controller = TextEditingController();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx)!;
      return SafeArea(
        top: false,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: () {
            final mq = MediaQuery.of(ctx);
            return EdgeInsets.fromLTRB(
              16,
              10,
              16,
              10 + mq.padding.bottom + mq.viewInsets.bottom,
            );
          }(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.8,
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // iOS-style header: centered title with left/right actions
                  SizedBox(
                    height: 36,
                    child: Stack(
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: Text(
                            l10n.importProviderSheetTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _TactileIconButton(
                            icon: Lucide.Camera,
                            color: cs.onSurface,
                            size: 22,
                            haptics: true,
                            semanticLabel:
                                l10n.importProviderSheetScanQrTooltip,
                            onTap: () async {
                              final code = await Navigator.of(ctx).push<String>(
                                MaterialPageRoute(
                                  builder: (_) => const QrScanPage(),
                                ),
                              );
                              if (code == null || code.isEmpty) return;
                              try {
                                final settings = ctx.read<SettingsProvider>();
                                final results = <_ImportResult>[];
                                // Support combined multi-provider QR content: newline-separated share strings or JSON
                                final parts = code
                                    .split(RegExp(r'\r?\n+'))
                                    .map((e) => e.trim())
                                    .where((e) => e.isNotEmpty)
                                    .toList();
                                if (parts.length > 1) {
                                  for (final p in parts) {
                                    try {
                                      if (p.startsWith('ai-provider:v1:')) {
                                        results.add(_decodeSingle(ctx, p));
                                      } else if (p.startsWith('{')) {
                                        results.addAll(
                                          _decodeChatboxJson(ctx, p),
                                        );
                                      }
                                    } catch (_) {}
                                  }
                                  if (results.isEmpty) {
                                    throw const _ImportProviderException(
                                      _ImportProviderError.unsupportedFormat,
                                    );
                                  }
                                } else {
                                  final p = parts.first;
                                  if (p.startsWith('ai-provider:v1:')) {
                                    results.add(_decodeSingle(ctx, p));
                                  } else if (p.startsWith('{')) {
                                    results.addAll(_decodeChatboxJson(ctx, p));
                                  } else {
                                    throw const _ImportProviderException(
                                      _ImportProviderError.unsupportedFormat,
                                    );
                                  }
                                }
                                for (final r in results) {
                                  await settings.setProviderConfig(
                                    r.key,
                                    r.cfg,
                                  );
                                  final order = List<String>.of(
                                    settings.providersOrder,
                                  );
                                  order.remove(r.key);
                                  order.insert(0, r.key);
                                  await settings.setProvidersOrder(order);
                                }
                                Navigator.of(ctx).pop();
                                showAppSnackBar(
                                  context,
                                  message: l10n
                                      .importProviderSheetImportSuccessMessage(
                                        results.length,
                                      ),
                                  type: NotificationType.success,
                                );
                              } catch (e, st) {
                                final err = _localizeImportProviderError(
                                  l10n,
                                  e,
                                  st,
                                );
                                showAppSnackBar(
                                  ctx,
                                  message: l10n
                                      .importProviderSheetImportFailedMessage(
                                        err,
                                      ),
                                  type: NotificationType.error,
                                );
                              }
                            },
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: _TactileIconButton(
                            icon: Lucide.Image,
                            color: cs.onSurface,
                            size: 22,
                            haptics: true,
                            semanticLabel:
                                l10n.importProviderSheetFromGalleryTooltip,
                            onTap: () async {
                              try {
                                // pick from gallery and analyze
                                final picker = ImagePicker();
                                final img = await picker.pickImage(
                                  source: ImageSource.gallery,
                                );
                                if (img == null) return;
                                final scanner = MobileScannerController();
                                String? code;
                                try {
                                  final BarcodeCapture? capture = await scanner
                                      .analyzeImage(img.path);
                                  for (final barcode
                                      in (capture?.barcodes ??
                                          const <Barcode>[])) {
                                    final v = barcode.rawValue;
                                    if (v != null && v.isNotEmpty) {
                                      code = v;
                                      break;
                                    }
                                  }
                                } finally {
                                  scanner.dispose();
                                }
                                if (code == null || code.isEmpty) {
                                  throw const _ImportProviderException(
                                    _ImportProviderError.qrNotDetected,
                                  );
                                }
                                final settings = ctx.read<SettingsProvider>();
                                final results = <_ImportResult>[];
                                final parts = code
                                    .split(RegExp(r'\r?\n+'))
                                    .map((e) => e.trim())
                                    .where((e) => e.isNotEmpty)
                                    .toList();
                                if (parts.length > 1) {
                                  for (final p in parts) {
                                    try {
                                      if (p.startsWith('ai-provider:v1:')) {
                                        results.add(_decodeSingle(ctx, p));
                                      } else if (p.startsWith('{')) {
                                        results.addAll(
                                          _decodeChatboxJson(ctx, p),
                                        );
                                      }
                                    } catch (_) {}
                                  }
                                  if (results.isEmpty) {
                                    throw const _ImportProviderException(
                                      _ImportProviderError.unsupportedContent,
                                    );
                                  }
                                } else {
                                  final p = parts.first;
                                  if (p.startsWith('ai-provider:v1:')) {
                                    results.add(_decodeSingle(ctx, p));
                                  } else if (p.startsWith('{')) {
                                    results.addAll(_decodeChatboxJson(ctx, p));
                                  } else {
                                    throw const _ImportProviderException(
                                      _ImportProviderError.unsupportedContent,
                                    );
                                  }
                                }
                                for (final r in results) {
                                  await settings.setProviderConfig(
                                    r.key,
                                    r.cfg,
                                  );
                                  final order = List<String>.of(
                                    settings.providersOrder,
                                  );
                                  order.remove(r.key);
                                  order.insert(0, r.key);
                                  await settings.setProvidersOrder(order);
                                }
                                Navigator.of(ctx).pop();
                                showAppSnackBar(
                                  context,
                                  message: l10n
                                      .importProviderSheetImportSuccessMessage(
                                        results.length,
                                      ),
                                  type: NotificationType.success,
                                );
                              } catch (e, st) {
                                final err = _localizeImportProviderError(
                                  l10n,
                                  e,
                                  st,
                                );
                                showAppSnackBar(
                                  ctx,
                                  message: l10n
                                      .importProviderSheetImportFailedMessage(
                                        err,
                                      ),
                                  type: NotificationType.error,
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    fit: FlexFit.loose,
                    child: ListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 8),
                      children: [
                        TextField(
                          controller: controller,
                          maxLines: 10,
                          decoration: InputDecoration(
                            hintText: l10n.importProviderSheetDescription,
                            filled: true,
                            fillColor:
                                Theme.of(ctx).brightness == Brightness.dark
                                ? Colors.white10
                                : Colors.white,
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
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: IosTileButton(
                          icon: Lucide.X,
                          label: l10n.importProviderSheetCancelButton,
                          onTap: () {
                            Haptics.light();
                            FocusScope.of(ctx).unfocus();
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (Navigator.of(ctx).canPop()) {
                                Navigator.of(ctx).maybePop();
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: IosTileButton(
                          icon: Lucide.Import,
                          label: l10n.importProviderSheetImportButton,
                          onTap: () async {
                            final raw = controller.text.trim();
                            if (raw.isEmpty) return;
                            try {
                              final settings = ctx.read<SettingsProvider>();
                              final results = <_ImportResult>[];
                              // Support multi-line input where each non-empty line is a share string or JSON
                              final lines = raw
                                  .split(RegExp(r'\r?\n'))
                                  .map((e) => e.trim())
                                  .where((e) => e.isNotEmpty)
                                  .toList();
                              if (lines.length > 1) {
                                for (final line in lines) {
                                  try {
                                    if (line.startsWith('ai-provider:v1:')) {
                                      results.add(_decodeSingle(ctx, line));
                                    } else if (line.startsWith('{')) {
                                      results.addAll(
                                        _decodeChatboxJson(ctx, line),
                                      );
                                    }
                                  } catch (_) {
                                    // skip invalid line
                                  }
                                }
                                if (results.isEmpty) {
                                  throw const _ImportProviderException(
                                    _ImportProviderError.unsupportedContent,
                                  );
                                }
                              } else {
                                final text = lines.first;
                                if (text.startsWith('ai-provider:v1:')) {
                                  results.add(_decodeSingle(ctx, text));
                                } else if (text.startsWith('{')) {
                                  results.addAll(_decodeChatboxJson(ctx, text));
                                } else {
                                  throw const _ImportProviderException(
                                    _ImportProviderError.unsupportedFormat,
                                  );
                                }
                              }
                              for (final r in results) {
                                await settings.setProviderConfig(r.key, r.cfg);
                                // Put to front
                                final order = List<String>.of(
                                  settings.providersOrder,
                                );
                                order.remove(r.key);
                                order.insert(0, r.key);
                                await settings.setProvidersOrder(order);
                              }
                              Navigator.of(ctx).pop();
                              showAppSnackBar(
                                context,
                                message: l10n
                                    .importProviderSheetImportSuccessMessage(
                                      results.length,
                                    ),
                                type: NotificationType.success,
                              );
                            } catch (e, st) {
                              final err = _localizeImportProviderError(
                                l10n,
                                e,
                                st,
                              );
                              showAppSnackBar(
                                ctx,
                                message: l10n
                                    .importProviderSheetImportFailedMessage(
                                      err,
                                    ),
                                type: NotificationType.error,
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

// Local iOS-like tactile icon button (no ripple, light haptics)
class _TactileIconButton extends StatefulWidget {
  const _TactileIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.semanticLabel,
    this.size = 22,
    this.haptics = true,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? semanticLabel;
  final double size;
  final bool haptics;

  @override
  State<_TactileIconButton> createState() => _TactileIconButtonState();
}

class _TactileIconButtonState extends State<_TactileIconButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final base = widget.color;
    final pressColor = base.withValues(alpha: 0.7);
    final icon = Icon(
      widget.icon,
      size: widget.size,
      color: _pressed ? pressColor : base,
      semanticLabel: widget.semanticLabel,
    );

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          if (widget.haptics) Haptics.light();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: icon,
          ),
        ),
      ),
    );
  }
}
