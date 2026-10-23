import 'dart:ui' show PointerDeviceKind;
import 'package:markstream/markstream.dart';
import '../markdown/diagram_chrome.dart';
import '../markdown/markdown_surface_scope.dart';

import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../icons/lucide_adapter.dart';
import '../../utils/plantuml_encoder.dart';
import 'export_capture_scope.dart';
import 'snackbar.dart';

enum _PlantUMLTab { image, code }

class PlantUMLBlock extends StatefulWidget {
  const PlantUMLBlock({
    super.key,
    required this.code,
    required this.theme,
    this.codeBuilder,
  });

  final String code;
  final MarkstreamTheme theme;

  /// Markdown supplies its source-indexed code view and selection owner.
  final WidgetBuilder? codeBuilder;

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
    final l10n = AppLocalizations.of(context)!;
    final exporting = ExportCaptureScope.of(context);
    final colors = widget.theme.colors;
    final preserveImageSurface =
        _selectedTab == _PlantUMLTab.image &&
        widget.theme.backdrop != MarkstreamBackdrop.plain &&
        MarkdownSurfaceScope.maybeOf(context)?.customBackground != null;
    var imageColors = colors;
    if (preserveImageSurface) {
      // Remote SVGs can be transparent and keep their own line/text colors.
      // Preserve the original canvas behind them when a custom bubble changes
      // the local syntax palette; source colors must not be interpreted as ink.
      final scheme = Theme.of(context).colorScheme;
      final dark = scheme.brightness == Brightness.dark;
      imageColors = colors.copyWith(
        fillBlock: Color.alphaBlend(
          Colors.white.withValues(alpha: dark ? .04 : .70),
          scheme.surface,
        ),
        ink2: scheme.onSurface.withValues(alpha: dark ? .70 : .72),
        ink3: scheme.onSurface.withValues(alpha: dark ? .48 : .50),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: colors.fillBlock,
        borderRadius: BorderRadius.circular(widget.theme.code.radius),
      ),
      clipBehavior: Clip.antiAlias,
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.theme.code.radius),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          DiagramChrome(
            theme: widget.theme,
            imageSelected: _selectedTab == _PlantUMLTab.image,
            onImage: () => setState(() => _selectedTab = _PlantUMLTab.image),
            onCode: () => setState(() => _selectedTab = _PlantUMLTab.code),
            actions: exporting
                ? const []
                : [
                    DiagramAction(
                      theme: widget.theme,
                      icon: Lucide.Copy,
                      label: l10n.shareProviderSheetCopyButton,
                      onTap: () => _copyPlantUMLCode(context),
                    ),
                    DiagramAction(
                      theme: widget.theme,
                      icon: Lucide.Link,
                      label: l10n.mermaidPreviewOpen,
                      onTap: () => _openPlantUMLPreview(context),
                    ),
                  ],
          ),
          SizedBox(
            key: const ValueKey('plantuml-preview-body'),
            width: double.infinity,
            height: _previewHeight,
            child: ColoredBox(
              color: preserveImageSurface
                  ? imageColors.fillBlock
                  : Colors.transparent,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) {
                  return currentChild ?? const SizedBox.shrink();
                },
                child: _selectedTab == _PlantUMLTab.code
                    ? _buildCodeView(context, colors)
                    : _buildImageView(imageColors),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageView(MarkstreamColors colors) {
    return Padding(
      key: const ValueKey('plantuml-image-body'),
      padding: const EdgeInsets.all(12),
      child: SvgPicture.network(
        _imageUrl,
        fit: BoxFit.contain,
        placeholderBuilder: (context) => _PlantUMLLoadingView(colors: colors),
        errorBuilder: (context, error, stackTrace) =>
            _PlantUMLErrorView(colors: colors),
      ),
    );
  }

  Widget _buildCodeView(BuildContext context, MarkstreamColors colors) {
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
              child:
                  widget.codeBuilder?.call(context) ??
                  SelectableText(widget.code, style: widget.theme.code.text),
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

class _PlantUMLLoadingView extends StatelessWidget {
  const _PlantUMLLoadingView({required this.colors});

  final MarkstreamColors colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2, color: colors.ink2),
      ),
    );
  }
}

class _PlantUMLErrorView extends StatelessWidget {
  const _PlantUMLErrorView({required this.colors});

  final MarkstreamColors colors;

  @override
  Widget build(BuildContext context) {
    return Center(child: Icon(Lucide.ImageOff, size: 48, color: colors.ink3));
  }
}
