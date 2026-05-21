import 'dart:ui' show PointerDeviceKind;

import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../icons/lucide_adapter.dart';
import '../../utils/plantuml_encoder.dart';
import 'export_capture_scope.dart';
import 'ios_tactile.dart';
import 'snackbar.dart';

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
    final colors = _PlantUMLBlockColors.resolve(isDark);

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
                              _PlantUMLTabButton(
                                label: l10n.mermaidImageTab,
                                selected: _selectedTab == _PlantUMLTab.image,
                                colors: colors,
                                onTap: () {
                                  setState(
                                    () => _selectedTab = _PlantUMLTab.image,
                                  );
                                },
                              ),
                              _PlantUMLTabButton(
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
                        _PlantUMLTextAction(
                          icon: Lucide.Copy,
                          label: l10n.shareProviderSheetCopyButton,
                          colors: colors,
                          onTap: () => _copyPlantUMLCode(context),
                        ),
                        const SizedBox(width: 4),
                        _PlantUMLTextAction(
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

  Widget _buildImageView(_PlantUMLBlockColors colors) {
    return Padding(
      key: const ValueKey('plantuml-image-body'),
      padding: const EdgeInsets.all(8),
      child: SvgPicture.network(
        _imageUrl,
        fit: BoxFit.contain,
        placeholderBuilder: (context) => _PlantUMLLoadingView(colors: colors),
        errorBuilder: (context, error, stackTrace) =>
            _PlantUMLErrorView(colors: colors),
      ),
    );
  }

  Widget _buildCodeView(BuildContext context, _PlantUMLBlockColors colors) {
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

class _PlantUMLBlockColors {
  const _PlantUMLBlockColors({
    required this.body,
    required this.header,
    required this.border,
    required this.tabTrack,
    required this.tabSelected,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
  });

  final Color body;
  final Color header;
  final Color border;
  final Color tabTrack;
  final Color tabSelected;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  static _PlantUMLBlockColors resolve(bool isDark) {
    if (isDark) {
      return const _PlantUMLBlockColors(
        body: Color(0xFF212121),
        header: Color(0xFF303030),
        border: Color(0xFF383838),
        tabTrack: Color(0xF2212121),
        tabSelected: Color(0xFF333333),
        textPrimary: Color(0xFFE6E6E6),
        textSecondary: Color(0xFFA0A0A0),
        textTertiary: Color(0xFF707070),
      );
    }

    return const _PlantUMLBlockColors(
      body: Color(0xFFF8F8F8),
      header: Color(0xFFEDEDED),
      border: Color(0xFFE0E0E0),
      tabTrack: Color(0xCCD9D9D9),
      tabSelected: Color(0xFFFFFFFF),
      textPrimary: Color(0xFF261208),
      textSecondary: Color(0xFF46352B),
      textTertiary: Color(0xFF5B4C43),
    );
  }
}

class _PlantUMLTabButton extends StatefulWidget {
  const _PlantUMLTabButton({
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final _PlantUMLBlockColors colors;
  final VoidCallback onTap;

  @override
  State<_PlantUMLTabButton> createState() => _PlantUMLTabButtonState();
}

class _PlantUMLTabButtonState extends State<_PlantUMLTabButton> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.selected
        ? widget.colors.tabSelected
        : Colors.transparent;
    final hoverColor = Color.alphaBlend(
      widget.colors.textPrimary.withValues(alpha: _pressed ? 0.10 : 0.06),
      baseColor,
    );
    final bg = widget.selected || _pressed || _hovered
        ? hoverColor
        : Colors.transparent;

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: SelectionContainer.disabled(
              child: Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: widget.selected
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: widget.selected
                      ? widget.colors.textPrimary
                      : widget.colors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlantUMLTextAction extends StatelessWidget {
  const _PlantUMLTextAction({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final _PlantUMLBlockColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = colors.textSecondary.withValues(alpha: 0.88);

    return Tooltip(
      message: label,
      child: IosIconButton(
        onTap: onTap,
        semanticLabel: label,
        color: color,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        builder: (buttonColor) => Icon(icon, size: 14, color: buttonColor),
      ),
    );
  }
}

class _PlantUMLLoadingView extends StatelessWidget {
  const _PlantUMLLoadingView({required this.colors});

  final _PlantUMLBlockColors colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: colors.textSecondary,
        ),
      ),
    );
  }
}

class _PlantUMLErrorView extends StatelessWidget {
  const _PlantUMLErrorView({required this.colors});

  final _PlantUMLBlockColors colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(Lucide.ImageOff, size: 48, color: colors.textTertiary),
    );
  }
}
