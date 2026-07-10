import 'dart:ui' show PointerDeviceKind;

import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../icons/lucide_adapter.dart';
import '../../utils/plantuml_encoder.dart';
import 'export_capture_scope.dart';
import 'snackbar.dart';
import 'tabbed_preview_block.dart';

enum _PlantUMLTab { image, code }

class PlantUMLBlock extends StatefulWidget {
  const PlantUMLBlock({super.key, required this.code});

  final String code;

  @override
  State<PlantUMLBlock> createState() => _PlantUMLBlockState();
}

class _PlantUMLBlockState extends State<PlantUMLBlock> {
  static const double _previewHeight = 406;

  _PlantUMLTab _selectedTab = _PlantUMLTab.image;
  late final ScrollController _codeScrollController;
  late String _imageUrl;

  @override
  void initState() {
    super.initState();
    _codeScrollController = ScrollController();
    _updateUrl();
  }

  @override
  void didUpdateWidget(covariant PlantUMLBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code) {
      _updateUrl();
      _selectedTab = _PlantUMLTab.image;
    }
  }

  @override
  void dispose() {
    _codeScrollController.dispose();
    super.dispose();
  }

  void _updateUrl() {
    final encoded = PlantUmlEncoder.encode(widget.code);
    _imageUrl = 'https://www.plantuml.com/plantuml/svg/$encoded';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final exporting = ExportCaptureScope.of(context);
    final colors = PreviewBlockColors.resolve(isDark);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: colors.body,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: colors.header,
              border: Border(
                bottom: BorderSide(color: colors.border, width: 1),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 16,
                      end: 10,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.tabTrack,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PreviewTabButton(
                                label: l10n.mermaidImageTab,
                                selected: _selectedTab == _PlantUMLTab.image,
                                colors: colors,
                                onTap: () {
                                  setState(
                                    () => _selectedTab = _PlantUMLTab.image,
                                  );
                                },
                              ),
                              PreviewTabButton(
                                label: l10n.mermaidCodeTab,
                                selected: _selectedTab == _PlantUMLTab.code,
                                colors: colors,
                                onTap: () {
                                  setState(
                                    () => _selectedTab = _PlantUMLTab.code,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (!exporting)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PreviewTextAction(
                          icon: Lucide.Copy,
                          label: l10n.shareProviderSheetCopyButton,
                          colors: colors,
                          onTap: () => _copyPlantUMLCode(context),
                        ),
                        const SizedBox(width: 4),
                        PreviewTextAction(
                          icon: Lucide.Link,
                          label: l10n.mermaidPreviewOpen,
                          colors: colors,
                          onTap: () => _openPlantUMLPreview(context),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            key: const ValueKey('plantuml-preview-body'),
            width: double.infinity,
            height: _previewHeight,
            child: ColoredBox(
              color: colors.body,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) {
                  return currentChild ?? const SizedBox.shrink();
                },
                child: _selectedTab == _PlantUMLTab.code
                    ? _buildCodeView(context, colors)
                    : _buildImageView(colors),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageView(PreviewBlockColors colors) {
    return Padding(
      key: const ValueKey('plantuml-image-body'),
      padding: const EdgeInsets.all(8),
      child: SvgPicture.network(
        _imageUrl,
        fit: BoxFit.contain,
        placeholderBuilder: (context) => PreviewLoadingView(colors: colors),
        errorBuilder: (context, error, stackTrace) =>
            PreviewErrorView(colors: colors),
      ),
    );
  }

  Widget _buildCodeView(BuildContext context, PreviewBlockColors colors) {
    return Padding(
      key: const ValueKey('plantuml-code-body'),
      padding: const EdgeInsets.all(12),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.stylus,
            PointerDeviceKind.unknown,
          },
        ),
        child: Scrollbar(
          controller: _codeScrollController,
          thumbVisibility: true,
          interactive: true,
          notificationPredicate: (notif) => notif.metrics.axis == Axis.vertical,
          child: SingleChildScrollView(
            controller: _codeScrollController,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                widget.code,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _copyPlantUMLCode(BuildContext context) async {
    final copiedMessage = AppLocalizations.of(
      context,
    )!.chatMessageWidgetCopiedToClipboard;
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      message: copiedMessage,
      type: NotificationType.success,
    );
  }

  Future<void> _openPlantUMLPreview(BuildContext context) async {
    final failedMessage = AppLocalizations.of(
      context,
    )!.mermaidPreviewOpenFailed;
    try {
      final ok = await launchUrl(
        Uri.parse(_imageUrl),
        mode: LaunchMode.externalApplication,
      );
      if (ok || !context.mounted) return;
    } catch (_) {
      if (!context.mounted) return;
    }
    showAppSnackBar(
      context,
      message: failedMessage,
      type: NotificationType.error,
    );
  }
}
