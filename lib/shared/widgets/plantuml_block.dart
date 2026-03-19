import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/plantuml_encoder.dart';
import '../../icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'snackbar.dart';
import 'export_capture_scope.dart';
import 'dart:io';

class PlantUMLBlock extends StatefulWidget {
  final String code;

  const PlantUMLBlock({super.key, required this.code});

  @override
  State<PlantUMLBlock> createState() => _PlantUMLBlockState();
}

class _PlantUMLBlockState extends State<PlantUMLBlock> {
  bool _expanded = true;
  late String _imageUrl;

  @override
  void initState() {
    super.initState();
    _updateUrl();
  }

  @override
  void didUpdateWidget(covariant PlantUMLBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code) {
      _updateUrl();
    }
  }

  void _updateUrl() {
    final encoded = PlantUmlEncoder.encode(widget.code);
    _imageUrl = 'https://www.plantuml.com/plantuml/svg/$encoded';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Use theme-tinted surfaces so headers follow the current theme color.
    final Color bodyBg = Color.alphaBlend(
      cs.primary.withValues(alpha: isDark ? 0.06 : 0.03),
      cs.surface,
    );
    final Color headerBg = Color.alphaBlend(
      cs.primary.withValues(alpha: isDark ? 0.16 : 0.10),
      cs.surface,
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Material(
            color: headerBg,
            elevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              splashColor: Platform.isIOS ? Colors.transparent : null,
              highlightColor: Platform.isIOS ? Colors.transparent : null,
              hoverColor: Platform.isIOS ? Colors.transparent : null,
              overlayColor: Platform.isIOS
                  ? const WidgetStatePropertyAll(Colors.transparent)
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: _expanded
                        ? BorderSide(
                            color: cs.outlineVariant.withValues(alpha: 0.28),
                            width: 1.0,
                          )
                        : BorderSide.none,
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 2),
                    Text(
                      'plantuml',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                        height: 1.0,
                      ),
                    ),
                    const Spacer(),
                    if (!ExportCaptureScope.of(context)) ...[
                      // Copy action
                      InkWell(
                        onTap: () async {
                          await Clipboard.setData(
                            ClipboardData(text: widget.code),
                          );
                          if (!context.mounted) return;
                          showAppSnackBar(
                            context,
                            message: AppLocalizations.of(
                              context,
                            )!.chatMessageWidgetCopiedToClipboard,
                            type: NotificationType.success,
                          );
                        },
                        splashColor: Platform.isIOS ? Colors.transparent : null,
                        highlightColor: Platform.isIOS
                            ? Colors.transparent
                            : null,
                        hoverColor: Platform.isIOS ? Colors.transparent : null,
                        overlayColor: Platform.isIOS
                            ? const WidgetStatePropertyAll(Colors.transparent)
                            : null,
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Lucide.Copy,
                                size: 14,
                                color: cs.onSurface.withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                AppLocalizations.of(
                                  context,
                                )!.shareProviderSheetCopyButton,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurface.withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Open in browser
                      InkWell(
                        onTap: () async {
                          final uri = Uri.parse(_imageUrl);
                          try {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          } catch (_) {
                            if (!context.mounted) return;
                            showAppSnackBar(
                              context,
                              message: AppLocalizations.of(
                                context,
                              )!.mermaidPreviewOpenFailed, // Reuse or add new string
                              type: NotificationType.error,
                            );
                          }
                        },
                        splashColor: Platform.isIOS ? Colors.transparent : null,
                        highlightColor: Platform.isIOS
                            ? Colors.transparent
                            : null,
                        hoverColor: Platform.isIOS ? Colors.transparent : null,
                        overlayColor: Platform.isIOS
                            ? const WidgetStatePropertyAll(Colors.transparent)
                            : null,
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Lucide.Link,
                            size: 14,
                            color: cs.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      AnimatedRotation(
                        turns: _expanded ? 0.25 : 0.0,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          Lucide.ChevronRight,
                          size: 16,
                          color: cs.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // Content
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SizeTransition(
                sizeFactor: anim,
                axisAlignment: -1.0,
                child: child,
              ),
            ),
            child: _expanded
                ? Container(
                    key: const ValueKey('plantuml-expanded'),
                    width: double.infinity,
                    color: bodyBg,
                    padding: const EdgeInsets.all(10),
                    child: SvgPicture.network(
                      _imageUrl,
                      fit: BoxFit.contain,
                      placeholderBuilder: (BuildContext context) => Container(
                        padding: const EdgeInsets.all(20),
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('plantuml-collapsed')),
          ),
        ],
      ),
    );
  }
}
