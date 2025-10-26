import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../icons/lucide_adapter.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/ios_tile_button.dart';

String encodeProviderConfig(ProviderConfig cfg) {
  String type;
  final kind = ProviderConfig.classify(cfg.id, explicitType: cfg.providerType);
  switch (kind) {
    case ProviderKind.google:
      type = 'google';
      break;
    case ProviderKind.claude:
      type = 'claude';
      break;
    case ProviderKind.openai:
    default:
      type = 'openai-compat';
  }
  final map = <String, dynamic>{
    'type': type,
    'name': cfg.name,
    'apiKey': cfg.apiKey,
  };
  if (kind != ProviderKind.google) {
    map['baseUrl'] = cfg.baseUrl;
  }
  final jsonStr = jsonEncode(map);
  final b64 = base64Encode(utf8.encode(jsonStr));
  return 'ai-provider:v1:$b64';
}

Future<void> showShareProviderSheet(BuildContext context, String providerKey) async {
  final cs = Theme.of(context).colorScheme;
  final settings = context.read<SettingsProvider>();
  final cfg = settings.providerConfigs[providerKey] ?? settings.getProviderConfig(providerKey);
  final code = encodeProviderConfig(cfg);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx)!;
      Rect shareAnchorRect(BuildContext bctx) {
        try {
          final ro = bctx.findRenderObject();
          if (ro is RenderBox && ro.hasSize && ro.size.width > 0 && ro.size.height > 0) {
            final origin = ro.localToGlobal(Offset.zero);
            return origin & ro.size;
          }
        } catch (_) {}
        final size = MediaQuery.of(bctx).size;
        return Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: 1, height: 1);
      }
      return SafeArea(
        top: false,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.6,
          minChildSize: 0.4,
          builder: (c, sc) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(999))),
                ),
                const SizedBox(height: 12),
                Text(l10n.shareProviderSheetTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Text(l10n.shareProviderSheetDescription),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView(
                    controller: sc,
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            // Always use white background to ensure visibility in dark mode
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
                          ),
                          child: PrettyQr(
                            data: code,
                            size: 180,
                            roundEdges: true,
                            errorCorrectLevel: QrErrorCorrectLevel.M,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Show non-selectable text; use the copy button to copy
                      Text(
                        code,
                        style: const TextStyle(fontSize: 13.5, height: 1.35),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: IosTileButton(
                        icon: Lucide.Copy,
                        label: l10n.shareProviderSheetCopyButton,
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: code));
                          showAppSnackBar(
                            context,
                            message: l10n.shareProviderSheetCopiedMessage,
                            type: NotificationType.success,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: IosTileButton(
                        icon: Lucide.Share2,
                        label: l10n.shareProviderSheetShareButton,
                        onTap: () async {
                          final rect = shareAnchorRect(ctx);
                          await Share.share(code, subject: 'AI Provider', sharePositionOrigin: rect);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
