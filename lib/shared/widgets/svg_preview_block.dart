import 'dart:async';
import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:Cuplivo/l10n/app_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../icons/lucide_adapter.dart';
import 'export_capture_scope.dart';
import 'snackbar.dart';
import 'tabbed_preview_block.dart';

enum _SvgTab { image, code }

class SvgPreviewBlock extends StatefulWidget {
  const SvgPreviewBlock({
    super.key,
    required this.code,
    this.streaming = false,
  });

  final String code;
  final bool streaming;

  @override
  State<SvgPreviewBlock> createState() => _SvgPreviewBlockState();
}

class _SvgPreviewBlockState extends State<SvgPreviewBlock> {
  static const double _previewHeight = 406;
  static const int _maxSvgCodeUnits = 1024 * 1024; // 1 MB equivalent
  static const Duration _streamingRenderDelay = Duration(milliseconds: 360);
  static const Duration _settledRenderDelay = Duration(milliseconds: 220);

  _SvgTab _selectedTab = _SvgTab.image;
  late final ScrollController _codeScrollController;
  Timer? _renderDebounce;
  bool _renderReady = false;

  @override
  void initState() {
    super.initState();
    _codeScrollController = ScrollController();
    _selectedTab = widget.streaming ? _SvgTab.code : _SvgTab.image;
    if (!widget.streaming) _scheduleRender();
  }

  @override
  void didUpdateWidget(covariant SvgPreviewBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    final streamingJustEnded = oldWidget.streaming && !widget.streaming;
    if (streamingJustEnded) {
      // Streaming just ended — auto-switch to image and render once
      _selectedTab = _SvgTab.image;
      _renderReady = false;
      _scheduleRender();
    } else if (!widget.streaming && oldWidget.code != widget.code) {
      // Non-streaming code change (e.g. edited message) — re-render
      _selectedTab = _SvgTab.image;
      _renderReady = false;
      _scheduleRender();
    } else if (widget.streaming &&
        _selectedTab == _SvgTab.image &&
        oldWidget.code != widget.code) {
      // User switched to Image tab during streaming — keep deferring render
      // until streaming stops, to avoid isolate storm from repeated SvgPicture.string()
      _renderReady = false;
      _scheduleRender();
    }
  }

  @override
  void dispose() {
    _renderDebounce?.cancel();
    _codeScrollController.dispose();
    super.dispose();
  }

  void _scheduleRender() {
    _renderDebounce?.cancel();
    final delay = widget.streaming
        ? _streamingRenderDelay
        : _settledRenderDelay;
    _renderDebounce = Timer(delay, () {
      if (!mounted) return;
      setState(() => _renderReady = true);
    });
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
                                selected: _selectedTab == _SvgTab.image,
                                colors: colors,
                                onTap: () {
                                  setState(() => _selectedTab = _SvgTab.image);
                                  if (!_renderReady) _scheduleRender();
                                },
                              ),
                              PreviewTabButton(
                                label: l10n.mermaidCodeTab,
                                selected: _selectedTab == _SvgTab.code,
                                colors: colors,
                                onTap: () {
                                  setState(() => _selectedTab = _SvgTab.code);
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
                          onTap: () => _copySvgCode(context),
                        ),
                        const SizedBox(width: 4),
                        PreviewTextAction(
                          icon: Lucide.Download,
                          label: l10n.svgSaveFile,
                          colors: colors,
                          onTap: () => _saveSvgFile(context),
                        ),
                        const SizedBox(width: 4),
                        PreviewTextAction(
                          icon: Lucide.Link,
                          label: l10n.mermaidPreviewOpen,
                          colors: colors,
                          onTap: () => _openInBrowser(context),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            key: const ValueKey('svg-preview-body'),
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
                child: _selectedTab == _SvgTab.code
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
    final trimmed = widget.code.trim();
    final isValid = trimmed.startsWith('<svg') || trimmed.startsWith('<?xml');

    if (!isValid) {
      return Padding(
        key: const ValueKey('svg-image-error'),
        padding: const EdgeInsets.all(8),
        child: PreviewErrorView(colors: colors),
      );
    }

    if (widget.code.length > _maxSvgCodeUnits) {
      return Padding(
        key: const ValueKey('svg-image-oversized'),
        padding: const EdgeInsets.all(8),
        child: PreviewErrorView(colors: colors),
      );
    }

    if (!_renderReady) {
      return Padding(
        key: const ValueKey('svg-image-loading'),
        padding: const EdgeInsets.all(8),
        child: PreviewLoadingView(colors: colors),
      );
    }

    return Padding(
      key: const ValueKey('svg-image-body'),
      padding: const EdgeInsets.all(8),
      child: SvgPicture.string(
        widget.code,
        fit: BoxFit.contain,
        placeholderBuilder: (context) => PreviewLoadingView(colors: colors),
        errorBuilder: (context, error, stackTrace) =>
            PreviewErrorView(colors: colors),
      ),
    );
  }

  Widget _buildCodeView(BuildContext context, PreviewBlockColors colors) {
    return Padding(
      key: const ValueKey('svg-code-body'),
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

  Future<void> _copySvgCode(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      message: l10n.chatMessageWidgetCopiedToClipboard,
      type: NotificationType.success,
    );
  }

  Future<void> _saveSvgFile(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final suggested = 'diagram_${DateTime.now().millisecondsSinceEpoch}.svg';
    try {
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: l10n.svgSaveDialogTitle,
        fileName: suggested,
        type: FileType.custom,
        allowedExtensions: const ['svg'],
      );
      if (savePath == null || savePath.isEmpty) return;
      await File(savePath).parent.create(recursive: true);
      await File(savePath).writeAsString(widget.code);
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        message: l10n.svgSaveSuccess,
        type: NotificationType.success,
      );
    } catch (_) {
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        message: l10n.svgSaveFailed,
        type: NotificationType.error,
      );
    }
  }

  Future<void> _openInBrowser(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final dir = Directory.systemTemp;
    final file = File(
      p.join(
        dir.path,
        'svg_preview_${DateTime.now().millisecondsSinceEpoch}.svg',
      ),
    );
    try {
      await file.writeAsString(widget.code, flush: true);
      final ok = await launchUrl(
        Uri.file(file.path),
        mode: LaunchMode.externalApplication,
      );
      if (ok || !context.mounted) return;
    } catch (_) {
      if (!context.mounted) return;
    }
    showAppSnackBar(
      context,
      message: l10n.mermaidPreviewOpenFailed,
      type: NotificationType.error,
    );
  }
}
